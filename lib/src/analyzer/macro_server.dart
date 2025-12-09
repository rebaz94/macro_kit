import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:macro_kit/macro.dart';
import 'package:macro_kit/src/analyzer/analyzer.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/common/common.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/common/models.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart' as sync;
import 'package:watcher/watcher.dart';
import 'package:web_socket_channel/status.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yaml/yaml.dart';

import 'base.dart';

typedef _PluginChannelInfo = ({WebSocketChannel ch, List<String> contexts});

typedef _ClientChannelInfo = ({
  WebSocketChannel ch,
  List<String> macros,
  Map<String, List<AssetMacroInfo>> assetMacros,
  Duration timeout,
  StreamSubscription? sub,
});

typedef _AssetDirInfo = ({AssetMacroInfo macro, String relativeBasePath, String absoluteOutputPath});

class MacroAnalyzerServer extends MacroAnalyzer {
  MacroAnalyzerServer({required super.logger});

  static final MacroAnalyzerServer instance = () {
    final sink = MacroLogger.getFileAppendLogger('server.log');
    void logTo(Object? log) {
      print(log);
      sink.writeln(log);
    }

    final logger = MacroLogger.createLogger(name: 'MacroAnalyzer', into: logTo);
    return MacroAnalyzerServer(logger: logger).._setupAutoShutdown();
  }();

  final sync.Lock lock = sync.Lock();
  final Map<String, StreamSubscription<WatchEvent>> _subs = {};
  final Map<int, _PluginChannelInfo> _pluginChannels = {};
  final List<StreamSubscription> _wsPluginSubs = [];

  // VmUtils? vmUtils;

  /// List of connected client by client id with ws socket and supported macro names
  final Map<int, _ClientChannelInfo> _clientChannels = {};

  /// List of absolute asset directory mapping to each user macro
  final Map<String, Set<_AssetDirInfo>> _assetsDir = {};

  /// A map of all loaded context with plugin configuration and state of
  /// first rebuild is executed or not
  final Map<String, (MacroClientConfiguration, bool)> _macroClientConfigs = {};

  /// List of requested code generation by request id
  final Map<int, Completer<RunMacroResultMsg>> _pendingOperations = {};
  Timer? _autoShutdownTimer;
  bool _scheduleToShutdown = false;

  void _setupAutoShutdown() {
    _autoShutdownTimer = Timer.periodic(const Duration(minutes: 10), _onAutoShutdownCB);
  }

  void _onAutoShutdownCB(Timer timer) async {
    if (_scheduleToShutdown || contexts.isNotEmpty) return;

    _scheduleToShutdown = true;
    await Future.delayed(const Duration(minutes: 5));

    // if there is context, return with activated timer
    if (contexts.isNotEmpty) {
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

  Future<void> onContextChanged() async {
    await Future.wait([
      lock.synchronized(() async {
        final newContexts = Set<String>.of(_pluginChannels.values.map((e) => e.contexts).expand((e) => e)).toList();
        if (const DeepCollectionEquality().equals(contexts, newContexts)) {
          _reloadMacroConfiguration(contexts);
          return;
        }

        var old = contextCollection;
        contextCollection = AnalysisContextCollectionImpl(
          includedPaths: newContexts,
          byteStore: byteStore,
          resourceProvider: PhysicalResourceProvider.INSTANCE,
        );

        // set new context, reload configuration and re-watch context
        contexts = newContexts;
        _reloadMacroConfiguration(contexts);
        await _reWatchContexts(newContexts);

        // remove after some delay, in case of processing source not completed while context changes
        Future.delayed(const Duration(seconds: 10)).then((_) => old.dispose());
      }),
      // synchronize future call to be called before returning
      Future.delayed(const Duration(milliseconds: 10)),
    ]);
  }

  void _reloadMacroConfiguration(List<String> contexts) {
    logger.info('Reloading context configuration');
    final oldMacroClientConfigs = {..._macroClientConfigs};
    _macroClientConfigs.clear();
    _assetsDir.clear();
    fileCaches.clear();

    /// reload macro config defined in the project
    for (final context in contexts) {
      final autoRebuildExecuted = oldMacroClientConfigs[context]?.$2 == true;
      MacroClientConfiguration config;

      try {
        final content = loadYamlNode(File(p.join(context, '.macro.yaml')).readAsStringSync());
        config = switch (content.value['config']) {
          YamlMap map => MacroClientConfiguration.fromYaml(context, map),
          _ => MacroClientConfiguration.withDefault(context),
        };
      } on PathNotFoundException {
        config = MacroClientConfiguration.withDefault(context);
      } catch (e) {
        logger.error('Failed to read macro configuration for: $context');
        config = MacroClientConfiguration.withDefault(context);
      }

      _macroClientConfigs[context] = (config, autoRebuildExecuted);
    }

    /// reload asset macro configuration
    _setupAssetMacroConfiguration();
  }

  void _setupAssetMacroConfiguration() {
    /// map each asset to absolute path with applied macros
    final Set<String> outputsDir = {};

    /// setup asset macro
    for (final clientChannel in _clientChannels.values) {
      inner:
      for (final entry in clientChannel.assetMacros.entries) {
        final assetDirRelative = entry.key;
        final assetMacros = entry.value;

        if (!p.isRelative(assetDirRelative)) {
          logger.warn('Skipping asset directory "$assetDirRelative": must be a relative path');
          continue inner;
        }

        // combine context with provided asset directory
        for (final ctx in contexts) {
          final assetAbsolutePath = p.join(ctx, assetDirRelative);
          final assetAbsolutePaths = _assetsDir.putIfAbsent(assetAbsolutePath, () => {});

          macroLoop:
          for (final macro in assetMacros) {
            if (!p.isRelative(macro.output)) {
              logger.warn(
                'Skipping output directory "${macro.output}" for macro "${macro.macroName}": must be a relative path',
              );
              continue macroLoop;
            }

            final absoluteOutputPath = p.join(ctx, macro.output);
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

    /// remove any macro that generated output to same asset dir to prevent recursion
    final inputDirs = _assetsDir.keys.toList();
    for (final inputDir in inputDirs) {
      if (outputsDir.contains(inputDir)) {
        // remove input directory, because output to same location cause recursion
        _assetsDir.remove(inputDir);
        logger.warn(
          'Skipping asset directory "$inputDir": output directory cannot be the same as input '
          '(would cause infinite regeneration loop)',
        );
      }
    }
  }

  Future<void> _reWatchContexts(List<String> contexts) async {
    if (contexts.isEmpty) return;

    final futures = <Future>[];
    for (final context in contexts) {
      if (_subs.containsKey(context)) continue;

      final watcher = Watcher(context);
      futures.add(watcher.ready);

      final sub = watcher.events.listen(_onWatchFileChanged, onError: _onWatchFileError);
      _subs[context] = sub;
    }

    await Future.wait(futures);
    logger.info('Watching Analysis context: ${contexts.join(', ')}');

    final toRemove = _subs.keys.where((p) => !contexts.contains(p)).toList();
    for (final path in toRemove) {
      _subs[path]?.cancel();
      _subs.remove(path);
    }
  }

  void _onWatchFileError(Object? error) {
    logger.error('File watch encountered an error', error);
  }

  void _onWatchFileChanged(WatchEvent event) {
    _onFileChanged(event.path, event.type);
  }

  void _onFileChanged(String path, ChangeType changeType, {bool startProcessing = true}) {
    final assetMacros = _assetsDir.isEmpty ? null : _maybeRunAssetMacro(path);
    if (assetMacros == null && (p.extension(path, 2) != '.dart')) {
      logger.fine('Ignored: $path');
      return;
    } else if (assetMacros == null && changeType == ChangeType.REMOVE) {
      mayContainsMacroCache.remove(path);
      final (:genFilePath, relativePartFilePath: _) = buildGeneratedFileInfo(path);
      removeFile(genFilePath);
      return;
    }

    if (currentAnalyzingPath == '' || currentAnalyzingPath == path) {
      // its first time or file changed during current analyzing, so we have to run it again
      final type = switch (changeType) {
        ChangeType.ADD => AssetChangeType.add,
        ChangeType.MODIFY => AssetChangeType.modify,
        ChangeType.REMOVE => AssetChangeType.remove,
        _ => AssetChangeType.modify,
      };
      pendingAnalyze.add((path: path, asset: assetMacros, type: type));
    } else if (pendingAnalyze.firstWhereOrNull((e) => e.path == path) != null) {
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
    if (isAnalyzingFile) return;

    if (pendingAnalyze.isEmpty) {
      // broadcast no work(currently used only for force generation)
      if (pendingAnalyzeCompleted.hasListener) {
        pendingAnalyzeCompleted.sink.add(true);
      }
      return;
    }

    isAnalyzingFile = true;
    final currentAnalyze = pendingAnalyze.removeAt(0);

    try {
      if (currentAnalyze.asset != null) {
        await processAssetSource(currentAnalyze.path, currentAnalyze.asset!, currentAnalyze.type);
      } else {
        await processDartSource(currentAnalyze.path);
      }
    } catch (e, s) {
      logger.error('Failed to parse source code', e, s);
    } finally {
      iterationCaches.clear();
      isAnalyzingFile = false;
      // continue with next
      _processNext();
    }
  }

  @override
  MacroClientConfiguration getMacroConfigFor(String path) {
    for (final entry in _macroClientConfigs.entries) {
      // check if path with the context of configuration
      if (p.isWithin(entry.key, path)) {
        return entry.value.$1;
      }
    }

    return MacroClientConfiguration.defaultConfig;
  }

  @override
  void removeFile(String path) {
    try {
      (fileCaches[path] ?? File(path)).deleteSync();
    } on PathNotFoundException {
      return;
    } catch (e) {
      logger.error('Failed to delete file', e);
    }
  }

  void onPluginConnected(WebSocketChannel webSocket) {
    int pluginId = -1;

    final sub = webSocket.stream.listen(
      (data) {
        final (message, err, stack) = decodeMessage(data);
        if (err != null) {
          logger.error('Failed to decode message from plugin', err, stack);
          return;
        }

        switch (message) {
          case PluginConnectMsg(id: final id):
            _pluginChannels[id] = (ch: webSocket, contexts: const []);
            pluginId = id;
          case AnalysisContextsMsg(contexts: var contexts):
            final current = pluginId == -1 ? null : _pluginChannels[pluginId];
            if (current == null) {
              logger.error('Plugin received context but no active channel exists, ignored');
              return;
            }

            const excluded = [
              '.dart_tool', '.pub-cache', '.idea', '.vscode', 'build/intermediates', //
              '.symlinks/plugins', 'Intermediates.noindex', 'build/macos', //
            ];
            contexts = contexts.where((path) => !excluded.any((word) => path.contains(word))).toList();

            // remove configuration to trigger auto rebuild as plugin connected
            // so any restart can cause to rebuild if configured
            for (final context in contexts) {
              _macroClientConfigs.remove(context);
            }

            _pluginChannels[pluginId] = (ch: current.ch, contexts: contexts);
            onContextChanged();
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

  Iterable<WebSocketChannel> getPluginChannelsByPath(String path) sync* {
    for (final entry in _pluginChannels.entries) {
      inner:
      for (final contextPath in entry.value.contexts) {
        if (p.isWithin(contextPath, path)) {
          yield entry.value.ch;
          break inner;
        }
      }
    }
  }

  void onMacroClientGeneratorConnected(WebSocketChannel webSocket) {
    int clientId = -1;

    StreamSubscription? sub;
    sub = webSocket.stream.listen(
      (data) {
        final (message, err, stackTrace) = decodeMessage(data);
        if (err != null) {
          logger.error('Failed to decode message from client', err, stackTrace);
          return;
        }

        switch (message) {
          case ClientConnectMsg msg:
            _clientChannels[msg.id] = (
              ch: webSocket,
              macros: msg.macros,
              timeout: msg.runTimeout,
              sub: sub,
              assetMacros: msg.assetMacros,
            );
            clientId = msg.id;

            onContextChanged();
          case RunMacroResultMsg msg:
            final operation = _pendingOperations.remove(msg.id);
            if (operation == null) {
              logger.error('No pending operation found for result: ${msg.id}');
              return;
            }

            operation.complete(msg);
          default:
            logger.info('Unhandled message: $message');
        }
      },
      onError: (err) => logger.error('WebSocket channel error occurred', err),
      onDone: () => _clientChannels.remove(clientId),
    );
  }

  bool _addMessageToClient(int channelId, Message msg) {
    try {
      _clientChannels[channelId]?.ch.sink.add(encodeMessage(msg));
      return true;
    } catch (e, s) {
      logger.error('Unable to add message to client', e, s);
      final channelInfo = _clientChannels.remove(channelId);
      channelInfo?.sub?.cancel();
      return false;
    }
  }

  Future<String?> forceRegenerateCodeFor({
    required int clientId,
    required String contextPath,
    required bool filterOnlyDirectory,
    required bool addToContext,
    required bool removeInContext,
  }) async {
    final clientInfo = _clientChannels[clientId];
    if (clientInfo == null) return 'No Client registered with id: $clientId';

    (AnalysisContext?, StateError?) getContext(String path) {
      try {
        final context = contextCollection.contextFor(contextPath);
        return (context, null);
      } on StateError catch (e) {
        return (null, e);
      }
    }

    MapEntry<int, _PluginChannelInfo>? firstPlugin;
    var (context, err) = getContext(contextPath);
    if (err != null) {
      if (!addToContext) {
        return 'No analysis context found for: $contextPath, please ensure plugin installed';
      }

      firstPlugin = _pluginChannels.entries.firstOrNull;
      if (firstPlugin == null) {
        return 'No plugin registered, please ensure plugin installed';
      }

      _pluginChannels[firstPlugin.key] = (
        ch: firstPlugin.value.ch,
        contexts: firstPlugin.value.contexts.toList()..add(contextPath),
      );
      await onContextChanged();

      (context, err) = getContext(contextPath);
      if (err != null) {
        _pluginChannels[firstPlugin.key] = firstPlugin.value;
        return 'No analysis context found for: $contextPath after trying to load it';
      }
    } else if (context == null) {
      return 'Unexpected state: context must not null';
    }

    final isRootContext = contexts.contains(contextPath);
    final List<String> files;

    if (!isRootContext && filterOnlyDirectory) {
      files = Directory(contextPath).listSync(recursive: true).whereType<File>().map((e) => e.path).toList();
    } else {
      files = context!.contextRoot.analyzedFiles().toList();
    }

    for (final file in files) {
      _onFileChanged(file, ChangeType.MODIFY, startProcessing: false);
    }

    // start processing file
    _processNext();

    // wait until receive completed event
    await pendingAnalyzeCompleted.stream.first;

    if (firstPlugin != null && removeInContext) {
      _pluginChannels[firstPlugin.key] = firstPlugin.value;
      await onContextChanged();
    }

    return null;
  }

  /// return first connected client channel id that has a [targetMacro]
  @override
  int? getClientChannelIdByMacro(String targetMacro) {
    for (final entry in _clientChannels.entries) {
      for (final macroName in entry.value.macros) {
        if (macroName == targetMacro) {
          return entry.key;
        }
      }
    }
    return null;
  }

  @override
  Future<RunMacroResultMsg> runMacroGenerator(int channelId, RunMacroMsg message) async {
    final completer = Completer<RunMacroResultMsg>();
    if (!_addMessageToClient(channelId, message)) {
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
    final config = getMacroConfigFor(path);
    final String relativeToSource;

    if (config.remapGeneratedFileTo.isNotEmpty && config.context.length <= path.length) {
      var relativePath = p.relative(path, from: config.context);
      if (relativePath.startsWith('lib/')) {
        relativePath = relativePath.substring(4);
      }

      final newPath = p.absolute(config.context, config.remapGeneratedFileTo, relativePath);

      // Calculate relative path from generated file back to original source file
      relativeToSource = p.posix.relative(path, from: p.dirname(newPath));

      // Add generated suffix
      final dir = p.dirname(newPath);
      final fileName = p.basenameWithoutExtension(newPath);
      final generatedFile = p.join(dir, '$fileName.g.dart');

      return (genFilePath: generatedFile, relativePartFilePath: relativeToSource);
    } else {
      // Fallback: just use the filename
      final fileName = p.basenameWithoutExtension(path);
      final dir = p.dirname(path);
      final generatedFile = p.join(dir, '$fileName.g.dart');
      relativeToSource = '$fileName.dart';

      return (genFilePath: generatedFile, relativePartFilePath: relativeToSource);
    }
  }

  @override
  void onClientError(int channelId, String message, [Object? err, StackTrace? trace]) {
    logger.error('Error on channel $channelId: $message', err, trace);
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
      tryFn(sub.cancel);
    }

    for (final channel in _pluginChannels.values.toList()) {
      tryFn(() => channel.ch.sink.close(normalClosure, 'Server is closing'));
    }

    for (final channel in _clientChannels.values.toList()) {
      tryFn(() => channel.sub?.cancel);
      tryFn(() => channel.ch.sink.close(normalClosure, 'Server is closing').catchError((_) {}));
    }

    tryFn(contextCollection.dispose);
  }
}
