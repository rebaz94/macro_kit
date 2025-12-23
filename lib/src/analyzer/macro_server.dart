import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:macro_kit/macro_kit.dart';
import 'package:macro_kit/src/analyzer/analyzer.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/channel.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/utils/hash.dart';
import 'package:macro_kit/src/analyzer/utils/lock.dart';
import 'package:macro_kit/src/analyzer/utils/upgrade.dart';
import 'package:macro_kit/src/common/common.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/common/models.dart';
import 'package:macro_kit/src/common/registered_process.dart';
import 'package:macro_kit/src/version/version.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';
import 'package:web_socket_channel/status.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef _AssetDirInfo = ({AssetMacroInfo macro, String relativeBasePath, String absoluteOutputPath});

/// The file watch subscription along running process for auto run macro generation
typedef _Subscription = ({StreamSubscription<WatchEvent>? fileSub, Process? autoRunMacroProcess});

class MacroAnalyzerServer implements MacroServerInterface {
  MacroAnalyzerServer({
    required this.logger,
    required this.processLogger,
    required this.analyzer,
  }) {
    _init();
  }

  static final MacroAnalyzerServer instance = () {
    final sink = MacroLogger.getFileAppendLogger('server.log');
    void logTo(Object? log) {
      print(log);
      sink.writeln(log);
    }

    final logger = MacroLogger.createLogger(name: 'MacroAnalyzer', into: logTo);
    final processLogSing = MacroLogger.getFileAppendLogger('macro_process.log');
    final processLogger = MacroLogger.createLogger(name: '', into: processLogSing.write, rawLog: true);

    final analyzer = MacroAnalyzer(logger: logger);
    final server = MacroAnalyzerServer(
      logger: logger,
      processLogger: processLogger,
      analyzer: analyzer,
    );
    analyzer.server = server;
    return server;
  }();

  final MacroLogger logger;
  final MacroLogger processLogger;
  final MacroAnalyzer analyzer;
  final CustomBasicLock lock = CustomBasicLock();
  final CustomBasicLock rebuildLock = CustomBasicLock();
  final Map<String, _Subscription> _subs = {};
  final Map<int, PluginChannelInfo> _pluginChannels = {};
  final List<StreamSubscription> _wsPluginSubs = [];

  /// List of connected client by client id with ws socket and supported macro names
  final Map<int, ClientChannelInfo> _clientChannels = {};
  final Map<String, Object /*int|Null*/> _cachedRunnableMacroClients = {};

  /// List of absolute asset directory mapping to each user macro
  final Map<String, Set<_AssetDirInfo>> _assetsDir = {};

  /// Single source of truth for all contexts with their configurations
  /// Key: absolute context path
  /// Value: ContextInfo containing path, package name, config, and state
  final Map<String, ContextInfo> _contextRegistry = {};

  /// List of requested code generation by request id
  final Map<int, Completer<RunMacroResultMsg>> _pendingOperations = {};

  Timer? _autoShutdownTimer;
  bool _scheduleToShutdown = false;
  bool _upgrading = false;

  void _init() {
    _autoShutdownTimer = Timer.periodic(const Duration(minutes: 10), _onAutoShutdownCB);
    trackSignalHandler(SignalType.any, () => dispose());
  }

  void _onAutoShutdownCB(Timer timer) async {
    if (_scheduleToShutdown || analyzer.analysisContextPaths.isNotEmpty) return;

    _scheduleToShutdown = true;
    await Future.delayed(const Duration(minutes: 5));

    // if there is context, return with activated timer
    if (analyzer.analysisContextPaths.isNotEmpty) {
      _scheduleToShutdown = false;
      return;
    }

    dispose();
    exit(0);
  }

  @override
  void requestPluginToConnect() {
    File(p.join(macroDirectory, macroPluginRequestFileName))
      ..createSync(recursive: true)
      ..writeAsStringSync('${DateTime.now().microsecondsSinceEpoch}:reconnect');
  }

  @override
  void requestClientToConnect() {
    // send macro generator to reconnect
    File(p.join(macroDirectory, macroClientRequestFileName))
      ..createSync(recursive: true)
      ..writeAsStringSync('${DateTime.now().microsecondsSinceEpoch}:reconnect');
  }

  Future<bool> shutdownMacroServer() async {
    try {
      final res = await http.post(Uri.parse('http://localhost:3232/shutdown'), body: '{}');
      return res.statusCode == HttpStatus.ok;
    } catch (e) {
      logger.error('Failed to shut down existing MacroServer', e);
      return false;
    }
  }

  Future<void> onContextChanged({ClientChannelInfo? connectedClient}) async {
    await lock.synchronized(() async {
      // Rebuild the context registry
      await _rebuildContextRegistry();

      // Get paths for analysis context collection
      final analysisContextPaths = _contextRegistry.keys.toList();

      // Get paths for file watching
      final watchPaths = _getWatchPaths(_contextRegistry.values);

      // Check if contexts actually changed
      final contextsChanged = !const DeepCollectionEquality().equals(
        analyzer.analysisContextPaths,
        analysisContextPaths,
      );

      if (contextsChanged) {
        analyzer.analysisContextPaths = analysisContextPaths;

        sendMessageMacroClients(
          GeneralMessage(
            message: 'Loading analysis context:\n${analysisContextPaths.map((e) => '\t-> $e').join('\n')}',
          ),
        );

        // Create new analysis context collection
        var old = analyzer.contextCollection;
        analyzer.contextCollection = AnalysisContextCollectionImpl(
          includedPaths: analysisContextPaths,
          byteStore: analyzer.byteStore,
          resourceProvider: PhysicalResourceProvider.INSTANCE,
        );

        // Dispose old context after delay
        Future.delayed(const Duration(seconds: 10)).then((_) => old.dispose());
      }

      final autoRunMacroContexts = _contextRegistry.values
          .where((c) => c.sourceContext.autoRun && c.sourceContext.runCommand.isNotEmpty)
          .toList();

      // Clear caches and setup watchers
      analyzer.fileCaches.clear();
      final assetContexts = _setupAssetMacroConfiguration();
      await _reWatchContexts(CombinedListView([watchPaths, assetContexts]), autoRunMacroContexts);
      await _prepareAutoRebuildForAllClient(connectedClient: connectedClient);
    });
  }

  /// Get all contexts that should be watched
  /// For non-dynamic contexts, watch lib/ subdirectory
  /// For dynamic contexts (tests), watch the entire context
  List<String> _getWatchPaths(Iterable<ContextInfo> contexts) {
    final paths = <String>[];
    for (final context in contexts) {
      if (context.isDynamic) {
        paths.add(context.path);
      } else {
        paths.add(p.join(context.path, 'lib'));
      }
    }
    return paths;
  }

  /// Rebuild the context registry from plugin channels
  Future<void> _rebuildContextRegistry() async {
    final newRegistry = <String, ContextInfo>{};

    // Collect all unique context paths from all plugins
    final Set<String> allContextPaths = {};
    for (final plugin in _pluginChannels.values) {
      allContextPaths.addAll(plugin.contextPaths);
    }

    // Build ContextInfo for each unique path
    for (final contextPath in allContextPaths) {
      // Preserve auto-rebuild state if context already exists
      final existingInfo = _contextRegistry[contextPath];

      final packageName = analyzer.loadContextPackageName(contextPath);
      final config = analyzer.loadMacroConfig(contextPath, packageName);
      final macroContextInfo = await analyzer.evaluateMacroContextConfiguration(
        existingSourceContext: existingInfo?.sourceContext,
        p.join(contextPath, 'lib', 'macro_context.dart'),
      );

      final contextInfo = ContextInfo(
        path: contextPath,
        packageName: packageName,
        isDynamic: existingInfo?.isDynamic ?? false,
        config: config,
        sourceContext: macroContextInfo,
      );

      // Preserve auto-rebuild execution state
      if (existingInfo != null) {
        contextInfo.autoRebuildExecuted = existingInfo.autoRebuildExecuted;
      }

      newRegistry[contextPath] = contextInfo;
    }

    // Clear existing and sort by longest context path first
    _contextRegistry
      ..clear()
      ..addEntries(newRegistry.entries.sorted((a, b) => b.key.length.compareTo(a.key.length)));

    logger.fine('Context registry rebuilt with ${_contextRegistry.length} contexts');
  }

  /// Setup asset macro and return a list of absolute asset directories to watch
  List<String> _setupAssetMacroConfiguration() {
    _assetsDir.clear();

    /// map each asset to absolute path with applied macros
    final Set<String> outputsDir = {};

    /// setup asset macro
    for (final clientChannel in _clientChannels.values.toList()) {
      inner:
      for (final entry in clientChannel.assetMacros.entries) {
        final assetDirRelative = entry.key;
        final assetMacros = entry.value;

        if (!p.isRelative(assetDirRelative)) {
          logger.warn('Skipping asset directory "$assetDirRelative": must be a relative path');
          continue inner;
        }

        // Combine each context with the provided asset directory
        for (final contextInfo in _contextRegistry.values) {
          final assetAbsolutePath = p.join(contextInfo.path, assetDirRelative);
          final assetAbsolutePaths = _assetsDir.putIfAbsent(assetAbsolutePath, () => {});

          macroLoop:
          for (final macro in assetMacros) {
            if (!p.isRelative(macro.output)) {
              final msg =
                  'Skipping output directory "${macro.output}" for macro "${macro.macroName}": must be a relative path';
              logger.warn(msg);

              sendMessageMacroClients(
                clientId: clientChannel.id,
                GeneralMessage(message: msg, level: Level.WARNING),
              );
              continue macroLoop;
            }

            final absoluteOutputPath = p.join(contextInfo.path, macro.output);
            outputsDir.add(absoluteOutputPath);
            assetAbsolutePaths.add((
              macro: macro,
              relativeBasePath: assetDirRelative,
              absoluteOutputPath: absoluteOutputPath,
            ));
          }
        }
      }
    }

    // Remove any macro that generates output to same asset dir (prevents recursion)
    final inputDirs = _assetsDir.keys.toList();
    for (final inputDir in inputDirs) {
      if (outputsDir.contains(inputDir)) {
        // remove input directory, because output to same location cause recursion
        _assetsDir.remove(inputDir);
        final msg =
            'Skipping asset directory "$inputDir": output directory cannot be the same as input '
            '(would cause infinite regeneration loop)';

        sendMessageMacroClients(
          GeneralMessage(message: msg, level: Level.WARNING),
        );
        logger.warn(msg);
      }
    }

    return _assetsDir.keys.toList();
  }

  Future<void> _reWatchContexts(List<String> contexts, List<ContextInfo> autoRunMacroContexts) async {
    if (contexts.isEmpty) return;

    // setup file watching
    final futures = <Future>[];
    for (final context in contexts) {
      if (_subs.containsKey(context)) continue;

      final watcher = Watcher(context);
      futures.add(watcher.ready);

      final sub = watcher.events.listen(_onWatchFileChanged, onError: _onWatchFileError);
      _subs[context] = (fileSub: sub, autoRunMacroProcess: null);
    }

    await Future.wait(futures);
    logger.info('Watching analysis context: \n->\t${contexts.join('\n->\t')}');

    var toRemove = _subs.keys.where((p) => !contexts.contains(p)).toList();
    for (final path in toRemove) {
      final sub = _subs[path];
      if (sub == null) {
        continue;
      }

      sub.fileSub?.cancel();

      // keep if has runnable process
      if (sub.autoRunMacroProcess != null) {
        _subs[path] = (fileSub: null, autoRunMacroProcess: sub.autoRunMacroProcess);
        continue;
      }

      _subs.remove(path);
    }

    // setup auto runnable macro
    final watchingPaths = _getWatchPaths(autoRunMacroContexts);
    for (int i = 0; i < autoRunMacroContexts.length; i++) {
      final runnable = autoRunMacroContexts[i];
      final watchPath = watchingPaths[i];
      var sub = _subs[watchPath] ?? (fileSub: null, autoRunMacroProcess: null);

      // already started
      if (sub.autoRunMacroProcess != null) continue;

      // start it and store process
      final (process, errMsg) = await _startClientMacroGenerator(runnable, watchPath);
      _subs[watchPath] = (fileSub: sub.fileSub, autoRunMacroProcess: process);

      if (errMsg != null) {
        sendMessageMacroClients(
          GeneralMessage(
            message: 'Unable to start Macro generator for: ${runnable.packageName}, details:\n$errMsg',
            level: Level.SEVERE,
          ),
        );
      } else if (process != null) {
        registerProcess(process);
      }
    }

    toRemove = _subs.keys.where((p) => !watchingPaths.contains(p)).toList();
    for (final path in toRemove) {
      final sub = _subs[path];
      if (sub == null) {
        continue;
      }

      if (sub.autoRunMacroProcess != null) {
        removeProcess(sub.autoRunMacroProcess!);
        sub.autoRunMacroProcess!.kill();
      }

      // keep if has watcher
      if (sub.fileSub != null) {
        _subs[path] = (fileSub: sub.fileSub, autoRunMacroProcess: null);
        continue;
      }

      _subs.remove(path);
    }
  }

  Future<(Process?, String?)> _startClientMacroGenerator(ContextInfo contextInfo, String watchPath) async {
    try {
      final cmd = contextInfo.sourceContext.runCommand;
      final process = await Process.start(
        cmd.first,
        cmd.sublist(1),
        runInShell: Platform.isWindows,
        workingDirectory: contextInfo.path,
        environment: const {'managed_by_macro_server': 'true'},
      );

      process.stdout.transform(utf8.decoder).listen((stdOut) {
        final channelId = getClientChannelIdByContextInfoOfAutoRunnableMacro(contextInfo);
        if (channelId != null) {
          sendMessageMacroClients(GeneralMessage(message: stdOut), clientId: channelId);
        }

        processLogger.info(stdOut);
      });
      process.stderr.transform(utf8.decoder).listen((stdErr) {
        final channelId = getClientChannelIdByContextInfoOfAutoRunnableMacro(contextInfo);
        if (channelId != null) {
          sendMessageMacroClients(GeneralMessage(message: stdErr), clientId: channelId);
        }

        processLogger.error(stdErr);
      });

      return (process, null);
    } catch (e, s) {
      logger.error('Failed to start client macro process', e, s);
      return (null, '$e\n$s');
    }
  }

  void onPluginConnected(WebSocketChannel webSocket) {
    int pluginId = -1;

    final sub = webSocket.stream.listen(
      (data) async {
        final (message, err, stack) = decodeMessage(data);
        if (err != null) {
          logger.error('Failed to decode message from plugin', err, stack);
          return;
        }

        switch (message) {
          case PluginConnectMsg msg:
            final current = PluginChannelInfo(channel: webSocket, contextPaths: []);
            pluginId = msg.id;
            _pluginChannels[pluginId] = current;

            _onPluginContextReceived(pluginId, current, msg.initialContexts);

            if (msg.versionCode > pluginVersionCode) {
              logger.warn(
                'Version mismatch detected: Plugin v${msg.versionName} (code: ${msg.versionCode}) '
                'is newer than Server v$pluginVersionName (code: $pluginVersionCode). '
                '${_upgrading ? '' : 'Attempting automatic upgrade...'}',
              );

              if (_upgrading) return;

              _upgrading = true;
              final (upgraded, errMsg) = await upgradedMacroServer(msg.versionName);
              if (!upgraded) {
                logger.error(
                  'MacroServer upgrade failed: $errMsg\n'
                  'Version conflict: Plugin v${msg.versionName} vs Server v$pluginVersionName\n'
                  'Please manually update the server by running:\n'
                  'dart pub global activate macro_kit ${msg.versionName}',
                );
                _upgrading = false;
                return;
              }

              logger.info(
                'MacroServer successfully upgraded to v${msg.versionName}. '
                'Restarting with new version...',
              );
              dispose();
              exit(0);
            } else if (pluginVersionCode > msg.versionCode) {
              logger.warn(
                'Version mismatch detected: Server v$pluginVersionName (code: $pluginVersionCode) '
                'is newer than Plugin v${msg.versionName} (code: ${msg.versionCode}). '
                'Please update macro_kit package in your pubspec.yaml into: $pluginVersionName',
              );
            }

          case AnalysisContextsMsg(contexts: var contexts):
            final current = pluginId == -1 ? null : _pluginChannels[pluginId];
            if (current == null) {
              logger.error('Plugin received context but no active channel exists, ignored');
              return;
            }

            _onPluginContextReceived(pluginId, current, contexts);

          default:
            logger.info('Unhandled message: $message');
        }
      },
      onError: (err) => logger.error('WebSocket channel error occurred', err),
      onDone: () async {
        final pluginInfo = _pluginChannels[pluginId];
        if (pluginInfo == null) {
          // Plugin already removed from tracking, trigger immediate context update
          onContextChanged();
          return;
        }

        // Wait 1 minute before fully removing the plugin context
        // This grace period handles temporary crashes/restarts.
        // If the plugin reconnects during this window with the same contexts, removing the old
        // plugin ID and calling onContextChanged() won't trigger analysis reload since the
        // contexts themselves remain unchanged and tracked.
        await Future.delayed(const Duration(minutes: 1));
        _pluginChannels.remove(pluginId);
        onContextChanged();
      },
    );

    _wsPluginSubs.add(sub);
  }

  Future<void> _onPluginContextReceived(int pluginId, PluginChannelInfo plugin, List<String> contexts) async {
    final excluded = excludedDirectory;
    contexts = contexts.where((path) => !excluded.any((word) => path.contains(word))).toList();

    // Remove auto-rebuild state for these contexts to trigger rebuild on reconnect
    for (final context in contexts) {
      _contextRegistry[context]?.autoRebuildExecuted = false;
    }

    _pluginChannels[pluginId] = plugin.copyWith(contextPaths: contexts);
    await onContextChanged();
  }

  void onMacroClientGeneratorConnected(WebSocketChannel webSocket) {
    WsChannel channel = WsChannel(channel: webSocket);

    int clientId = -1;
    StreamSubscription? sub;

    sub = webSocket.stream.listen(
      (data) async {
        final (message, err, stackTrace) = decodeMessage(data);
        if (err != null) {
          logger.error('Failed to decode message from client', err, stackTrace);
          return;
        }

        switch (message) {
          case ClientConnectMsg msg:
            final client = ClientChannelInfo(
              id: msg.id,
              channel: channel,
              package: msg.package,
              macros: msg.macros,
              assetMacros: msg.assetMacros,
              timeout: msg.runTimeout,
              autoRunMacro: msg.autoRunMacro,
              managedByMacroServer: msg.managedByMacroServer,
              sub: sub,
            );
            _clientChannels[msg.id] = client;
            clientId = msg.id;

            // this will trigger auto rebuild if configured
            await onContextChanged(connectedClient: client);
          default:
            _handleMessage(message, channel);
        }
      },
      onError: (err) => logger.error('WebSocket channel error occurred', err),
      onDone: () => _clientChannels.remove(clientId),
    );
  }

  void _handleMessage(Message? message, WsChannel channel) async {
    switch (message) {
      case RequestMacrosConfigMsg msg:
        await _syncClientMacrosConfig(msg.clientId, msg.filePath);

      case RunMacroResultMsg msg:
        final operation = _pendingOperations.remove(msg.id);
        if (operation == null) {
          logger.error('No pending operation found for result: ${msg.id}');
          return;
        }

        operation.complete(msg);
      case RequestPluginToConnectMsg():
        _onRequestPluginToConnect();
      default:
        logger.info('Unhandled message: $message');
    }
  }

  Future<void> _syncClientMacrosConfig(int clientId, String filePath) async {
    final clientChannel = _clientChannels[clientId];
    if (clientChannel == null) {
      return;
    }

    final fileContext = getContextInfoForPath(filePath);
    final UserMacroConfig config;
    if (fileContext == null) {
      config = const UserMacroConfig(id: 0, context: '', configs: {}, remapGeneratedFileTo: '');
    } else {
      config = UserMacroConfig(
        id: fileContext.config.id,
        context: filePath,
        configs: fileContext.config.userMacrosConfig,
        remapGeneratedFileTo: fileContext.config.remapGeneratedFileTo,
      );
    }
    final sent = await _addMessageToClient(clientId, SyncMacrosConfigMsg(config: config));
    if (!sent) {
      logger.error('Failed to send macro configuration to channel: $clientId');
    }
  }

  void _onRequestPluginToConnect() {
    File(p.join(macroDirectory, macroPluginRequestFileName))
      ..createSync(recursive: true)
      ..writeAsStringSync('${DateTime.now().microsecondsSinceEpoch}:reconnect');
  }

  FutureOr<bool> _addMessageToClient(int channelId, Message msg) async {
    try {
      await _clientChannels[channelId]?.channel.addMessage(msg);
      return true;
    } catch (e, s) {
      logger.error('Unable to add message to client', e, s);
      _removeClient(channelId);
      return false;
    }
  }

  void _removeClient(int channelId) {
    try {
      final channelInfo = _clientChannels.remove(channelId);
      channelInfo?.sub?.cancel();
    } catch (_) {}
  }

  Iterable<WebSocketChannel> getPluginChannelsByPath(String path) sync* {
    // Find the context this file belongs to
    final contextInfo = getContextInfoForPath(path);
    if (contextInfo == null) return;

    // Find plugins that manage this context
    for (final entry in _pluginChannels.entries) {
      if (entry.value.contextPaths.contains(contextInfo.path) && entry.value.channel != null) {
        yield entry.value.channel!;
      }
    }
  }

  /// Get context info for a given file path
  /// Returns null if no context contains this file
  ContextInfo? getContextInfoForPath(String filePath) {
    for (final entry in _contextRegistry.entries) {
      if (p.isWithin(entry.key, filePath)) {
        return entry.value;
      }
    }
    return null;
  }

  MacroClientConfiguration getMacroConfigFor(String path) {
    final contextInfo = getContextInfoForPath(path);
    return contextInfo?.config ?? MacroClientConfiguration.defaultConfig;
  }

  /// Get the client channel that supports a specific macro for a given file path
  /// This ensures we send requests to the correct client based on file location
  ///
  /// note: this does not return client that enabled autoRunMacro since it can't generate code
  @override
  int? getClientChannelIdByMacro(String targetMacro, String filePath) {
    // First, find which context this file belongs to
    final contextInfo = getContextInfoForPath(filePath);
    if (contextInfo == null) return null;

    // 1. Supports the requested macro
    // 2. Works within the context's package
    for (final entry in _clientChannels.entries) {
      final clientInfo = entry.value;

      // Check if client supports this macro
      if (!clientInfo.macros.contains(targetMacro)) {
        continue;
      }

      // Check if client works with this package/context
      if (!clientInfo.autoRunMacro && clientInfo.package.values.contains(contextInfo.packageName) ||
          clientInfo.package.values.contains(contextInfo.path)) {
        return entry.key;
      }
    }

    final msg = 'No client found for macro "$targetMacro" in context "${contextInfo.packageName}" for file: $filePath';
    sendMessageMacroClients(
      GeneralMessage(
        message: msg,
        level: Level.WARNING,
      ),
    );

    logger.warn(msg);
    return null;
  }

  /// Get the client channel that supports a given file path
  /// This ensures we send requests to the correct client based on file location
  ///
  /// note: this does not return client that enabled autoRunMacro since it can't generate code
  int? getClientChannelIdByContextInfo(ContextInfo contextInfo) {
    for (final entry in _clientChannels.entries) {
      final clientInfo = entry.value;

      if (!clientInfo.autoRunMacro && clientInfo.package.values.contains(contextInfo.packageName) ||
          clientInfo.package.values.contains(contextInfo.path)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Get the client channel that supports a given file path
  /// This ensures we send requests to the correct client based on file location
  ///
  /// note: this return a cached client id that enabled auto run macro and
  /// inside their app want to listen to generation output
  int? getClientChannelIdByContextInfoOfAutoRunnableMacro(ContextInfo contextInfo) {
    final value = _cachedRunnableMacroClients[contextInfo.packageName];
    if (value != null) {
      return value is int ? value : null;
    }

    for (final entry in _clientChannels.entries) {
      final clientInfo = entry.value;

      if (clientInfo.autoRunMacro && clientInfo.package.values.contains(contextInfo.packageName) ||
          clientInfo.package.values.contains(contextInfo.path)) {
        _cachedRunnableMacroClients[contextInfo.packageName] = entry.key;
        return entry.key;
      }
    }

    _cachedRunnableMacroClients[contextInfo.packageName] = Null;
    return null;
  }

  Future<void> _prepareAutoRebuildForAllClient({required ClientChannelInfo? connectedClient}) async {
    for (final client in _clientChannels.values.toList()) {
      await _prepareAndRunAutoRebuild(client, connectedClient);
    }
  }

  Future<void> _prepareAndRunAutoRebuild(
    ClientChannelInfo clientChannel,
    ClientChannelInfo? connectedClient,
  ) async {
    final clientId = clientChannel.id;
    final clientPkgNames = clientChannel.package.values;
    final autoRebuildConfigs = <ContextInfo>[];
    bool hasPackageContext = false;

    final isSameClient = connectedClient?.id == clientId;

    // Check each context in the registry
    for (final contextInfo in _contextRegistry.values) {
      if (!clientPkgNames.contains(contextInfo.packageName) && !clientPkgNames.contains(contextInfo.path)) {
        continue;
      }

      final config = contextInfo.config;
      if ((!config.autoRebuildOnConnect || contextInfo.autoRebuildExecuted) && !config.alwaysRebuildOnConnect) {
        continue;
      }

      if (config.alwaysRebuildOnConnect && !isSameClient && contextInfo.autoRebuildExecuted) {
        continue;
      }

      if (config.skipConnectRebuildWithAutoRun && clientChannel.autoRunMacro) {
        continue;
      }

      hasPackageContext = true;
      autoRebuildConfigs.add(contextInfo);
    }

    // Handle dynamic contexts (for testing)
    if (!hasPackageContext) {
      for (final pkgName in clientChannel.package.values) {
        if (!pkgName.contains('/') && !pkgName.contains('\\')) continue;

        final config = analyzer.loadMacroConfig(pkgName, pkgName);

        if (!config.autoRebuildOnConnect && !config.alwaysRebuildOnConnect) continue;
        if (config.alwaysRebuildOnConnect && !isSameClient) continue;

        final contextInfo = ContextInfo(
          path: pkgName,
          packageName: pkgName,
          isDynamic: true,
          config: config,
          sourceContext: MacroContextSourceCodeInfo.testContext(),
        );

        _contextRegistry[pkgName] = contextInfo;
        autoRebuildConfigs.add(contextInfo);
      }

      if (autoRebuildConfigs.isNotEmpty) {
        _addContextDynamically(autoRebuildConfigs, connectedClient);
        return;
      }
    }

    if (autoRebuildConfigs.isNotEmpty) {
      sendMessageMacroClients(
        GeneralMessage(
          message: 'Rebuilding macro generated code for: ${autoRebuildConfigs.map((e) => e.packageName).join(', ')}',
        ),
      );
      await _runAutoRebuildOnConnect(clientId, autoRebuildConfigs);
    }
  }

  void _addContextDynamically(
    List<ContextInfo> contextInfos,
    ClientChannelInfo? connectedClient,
  ) {
    final newContextPaths = contextInfos.map((info) => info.path).toList();

    var pluginInfo = _pluginChannels.entries.firstOrNull;
    if (pluginInfo == null) {
      _pluginChannels[newId()] = PluginChannelInfo(
        channel: null,
        contextPaths: newContextPaths,
      );
    } else {
      final updated = pluginInfo.value.contextPaths.toSet()..addAll(newContextPaths);
      _pluginChannels[pluginInfo.key] = pluginInfo.value.copyWith(
        contextPaths: updated.toList(),
      );
    }

    logger.info('Dynamically added new contexts for testing: ${newContextPaths.join(', ')}');
    onContextChanged(connectedClient: connectedClient);
  }

  Future<void> _runAutoRebuildOnConnect(
    int clientId,
    List<ContextInfo> contextInfos,
  ) async {
    await rebuildLock.synchronized(() async {
      final results = <RegeneratedContextResult>[];
      final s = Stopwatch();

      for (final contextInfo in contextInfos) {
        s
          ..reset()
          ..start();

        final err = await _forceRegenerateCodeFor(
          clientId: clientId,
          contextPath: contextInfo.path,
        );

        results.add(
          RegeneratedContextResult(
            package: contextInfo.packageName,
            context: contextInfo.path,
            error: err,
            completedInMilliseconds: s.elapsedMilliseconds,
          ),
        );

        logger.info('Completed regeneration in ${s.elapsed.inSeconds}s');
        if (err != null) {
          logger.error('Auto rebuild on start failed', err);
        } else {
          contextInfo.autoRebuildExecuted = true;
        }
      }

      _addMessageToClient(
        clientId,
        AutoRebuildOnConnectResultMsg(results: results),
      );
    });
  }

  Future<String?> _forceRegenerateCodeFor({
    required int clientId,
    required String contextPath,
  }) async {
    final clientInfo = _clientChannels[clientId];
    if (clientInfo == null) return 'No client registered with id: $clientId';

    (AnalysisContext?, StateError?) getContext(String path) {
      try {
        final context = analyzer.contextCollection.contextFor(contextPath);
        return (context, null);
      } on StateError catch (e) {
        return (null, e);
      }
    }

    var (context, err) = getContext(contextPath);
    if (err != null || context == null) {
      return 'No analysis context found for: $contextPath, Error: $err';
    }

    for (final file in context.contextRoot.analyzedFiles()) {
      _onFileChanged(file, ChangeType.MODIFY, startProcessing: false);
    }

    // start processing file
    _processNext();

    // wait until receive completed event
    await analyzer.pendingAnalyzeCompleted.stream.first;
    return null;
  }

  void _onWatchFileError(Object error, StackTrace _) {
    logger.error('File watch encountered an error', error);
  }

  void _onWatchFileChanged(WatchEvent event) {
    _onFileChanged(event.path, event.type);
  }

  void _onFileChanged(String path, ChangeType changeType, {bool startProcessing = true}) {
    const minimumThreshold = 30;
    if (analyzer.lastChangedPath == path &&
        analyzer.lastChangeType == changeType &&
        minimumThreshold > analyzer.getDiffFromLastExecution()) {
      // duplicate event, ignore it
      return;
    }

    analyzer.lastChangedPath = path;
    analyzer.lastChangeType = changeType;

    final assetMacros = _assetsDir.isEmpty ? null : _maybeRunAssetMacro(path);
    if (assetMacros == null && (p.extension(path, 2) != '.dart')) {
      logger.fine('Ignored: $path');
      return;
    } else if (assetMacros == null && changeType == ChangeType.REMOVE) {
      analyzer.mayContainsMacroCache.remove(path);
      final (:genFilePath, relativePartFilePath: _) = buildGeneratedFileInfo(path);
      analyzer.removeFile(genFilePath);
      return;
    }

    if (analyzer.currentAnalyzingPath == '' || analyzer.currentAnalyzingPath == path) {
      // its first time or file changed during current analyzing, so we have to run it again
      analyzer.pendingAnalyze[(path: path, type: changeType, force: true)] = assetMacros == null
          ? analyzer.defaultNullPendingAnalyzeValue
          : (asset: assetMacros);
    } else if (analyzer.pendingAnalyze.containsKey((path: path, type: changeType, force: false))) {
      // its already in pending list, so no duplicate, next time it process it
      return;
    }

    if (startProcessing) _processNext();
  }

  List<AnalyzingAsset>? _maybeRunAssetMacro(String path) {
    // Check if the file is in any monitored asset directory
    List<AnalyzingAsset>? appliedMacros;

    for (final entry in _assetsDir.entries) {
      final assetAbsoluteBasePath = entry.key;
      final macroInfos = entry.value;

      // Check if file is within this asset directory
      if (p.isWithin(assetAbsoluteBasePath, path)) {
        late final fileExtension = p.extension(path);

        // Check if any macro in this directory accepts this file extension
        for (final macroInfo in macroInfos) {
          if (macroInfo.macro.extension == '*') {
            (appliedMacros ??= []).add((
              macro: macroInfo.macro,
              absoluteBasePath: assetAbsoluteBasePath,
              relativeBasePath: macroInfo.relativeBasePath,
              absoluteOutputPath: macroInfo.absoluteOutputPath,
            ));
          } else if (macroInfo.macro.allExtensions.contains(fileExtension)) {
            (appliedMacros ??= []).add((
              macro: macroInfo.macro,
              absoluteBasePath: assetAbsoluteBasePath,
              relativeBasePath: macroInfo.relativeBasePath,
              absoluteOutputPath: macroInfo.absoluteOutputPath,
            ));
          }
        }

        // break it since, at least one macro handled it or its ignored
        break;
      }
    }

    return appliedMacros;
  }

  Future<void> _processNext() async {
    if (analyzer.isAnalyzingFile) return;

    if (analyzer.pendingAnalyze.isEmpty) {
      // broadcast no work(currently used only for force generation)
      if (analyzer.pendingAnalyzeCompleted.hasListener) {
        analyzer.pendingAnalyzeCompleted.sink.add(true);
      }
      return;
    }

    analyzer.isAnalyzingFile = true;
    final key = analyzer.pendingAnalyze.keys.first;
    final currentAnalyze = analyzer.pendingAnalyze.remove(key)!;

    try {
      if (key.path.endsWith('macro_context.dart')) {
        await _onMacroContextSourceChanged(key.path);
      } else if (currentAnalyze.asset != null) {
        await analyzer.processAssetSource(key.path, currentAnalyze.asset!, key.type);
      } else {
        await analyzer.processDartSource(key.path);
      }
    } catch (e, s) {
      logger.error('Failed to parse source code', e, s);
    } finally {
      analyzer.iterationCaches.clear();
      analyzer.isAnalyzingFile = false;
      // continue with next
      _processNext();
    }
  }

  Future<void> _onMacroContextSourceChanged(String filePath) async {
    final context = getContextInfoForPath(filePath);
    if (context == null) return;

    // find the process and kill if exist
    final watchPath = _getWatchPaths([context]).first;
    final sub = _subs[watchPath];
    final process = sub?.autoRunMacroProcess;
    final macroContextDartFile = File(p.join(filePath));

    // if not exist, reload to remove existing process
    if (!macroContextDartFile.existsSync()) {
      await onContextChanged();
      return;
    }

    // if hash changed, remove before reloading context so that make new process
    // if required based on new evaluated code
    final hashId = generateHash(macroContextDartFile.readAsStringSync());
    if (hashId != _contextRegistry[context.path]?.sourceContext.hashId) {
      if (process != null) {
        removeProcess(process);
        process.kill();
        _subs[watchPath] = (fileSub: sub!.fileSub, autoRunMacroProcess: null);
      }

      analyzer.pendingAnalyze.clear();
      analyzer.isAnalyzingFile = false;
      onContextChanged();
    }
  }

  @override
  Future<RunMacroResultMsg> runMacroGenerator(int channelId, RunMacroMsg message) async {
    final completer = Completer<RunMacroResultMsg>();
    if (!await _addMessageToClient(channelId, message)) {
      completer.complete(
        RunMacroResultMsg(
          id: message.id,
          result: '',
          error: 'No Macro Generator running!',
        ),
      );
      return completer.future;
    }

    _pendingOperations[message.id] = completer;

    return completer.future.timeout(
      _clientChannels[channelId]?.timeout ?? const Duration(seconds: 30),
      onTimeout: () => RunMacroResultMsg(
        id: message.id,
        result: '',
        error: 'Generation timeout!',
      ),
    );
  }

  @override
  ({String genFilePath, String relativePartFilePath}) buildGeneratedFileInfo(String path) {
    final contextInfo = getContextInfoForPath(path);
    final config = contextInfo?.config ?? MacroClientConfiguration.defaultConfig;

    return buildGeneratedFileInfoFor(
      forFilePath: path,
      inContextPath: contextInfo?.path,
      remapGeneratedFileTo: config.remapGeneratedFileTo,
    );
  }

  /// send message to all client or only specific one if [clientId] is provided
  @override
  void sendMessageMacroClients(GeneralMessage message, {int? clientId}) {
    if (clientId != null) {
      _addMessageToClient(clientId, message);
      return;
    }

    for (final client in _clientChannels.entries.toList()) {
      _addMessageToClient(client.key, message);
    }
  }

  @override
  void onClientError(int channelId, String message, [Object? err, StackTrace? trace]) {
    logger.error('Error on channel $channelId: $message', err, trace);
    sendMessageMacroClients(GeneralMessage(message: message), clientId: channelId);
  }

  void dispose() {
    _autoShutdownTimer?.cancel();
    // vmUtils?.dispose();

    void tryFn(void Function() fn) {
      try {
        fn();
      } catch (_) {}
    }

    for (final sub in _wsPluginSubs.toList()) {
      tryFn(sub.cancel);
    }

    for (final sub in _subs.values.toList()) {
      tryFn(() => sub.fileSub?.cancel());
      tryFn(() => sub.autoRunMacroProcess?.kill());
    }

    for (final channel in _pluginChannels.values.toList()) {
      tryFn(() => channel.channel?.sink.close(normalClosure, 'Server is closing'));
    }

    for (final channel in _clientChannels.values.toList()) {
      tryFn(() => channel.sub?.cancel);
      tryFn(() => channel.channel.close(normalClosure, 'Server is closing').catchError((_) {}));
    }

    tryFn(analyzer.contextCollection.dispose);
  }
}
