import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:macro_kit/macro_kit.dart';
import 'package:macro_kit/src/analyzer/lock.dart';
import 'package:macro_kit/src/common/common.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/common/models.dart';
import 'package:macro_kit/src/common/watch_file_request.dart';
import 'package:path/path.dart' as p;
import 'package:web_socket_channel/web_socket_channel.dart';

typedef MacroInitFunction = MacroGenerator Function(MacroConfig config);

class MacroManager {
  MacroManager({
    required this.logger,
    required String serverAddress,
    required this.macros,
    required this.assetMacros,
    required this.autoReconnect,
    required this.packageInfo,
    required this.generateTimeout,
  }) : serverAddress = Uri.parse(serverAddress);

  static final List<Completer<AutoRebuildResult>> _waitAutoRebuildCompleteCompleter = [];

  static Future<AutoRebuildResult> waitUntilRebuildCompleted() {
    final c = Completer<AutoRebuildResult>();
    _waitAutoRebuildCompleteCompleter.add(c);
    return c.future;
  }

  final int clientId = 1000 + Random().nextInt(1000);
  final CustomBasicLock lock = CustomBasicLock();
  final MacroLogger logger;
  final Uri serverAddress;
  final Map<String, MacroInitFunction> macros;
  final Map<String, List<AssetMacroInfo>> assetMacros;
  final bool autoReconnect;
  final Duration generateTimeout;
  final PackageInfo packageInfo;
  UserMacroConfig? userMacrosConfig;
  final Map<String, (MacroGlobalConfig?,)> cachedUserMacrosConfig = {};
  Completer<bool> _isMacrosConfigSynced = Completer<bool>();

  final _clientRequestWatcher = WatchFileRequest(
    fileName: macroClientRequestFileName,
    inDirectory: macroDirectory,
  );

  /// A cache of generator keyed by hash of the json that build MacroGenerator instance
  final Map<int, MacroGenerator> _generatorCaches = {};
  final _mapStrDynamicTypeArg = [
    MacroProperty(name: '', importPrefix: '', type: 'String', typeInfo: TypeInfo.string, fieldInitializer: null),
    MacroProperty(name: '', importPrefix: '', type: 'dynamic', typeInfo: TypeInfo.dynamic, fieldInitializer: null),
  ];

  ConnectionStatus _status = ConnectionStatus.disconnected;

  ConnectionStatus get status => _status;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubs;

  bool get isMobilePlatform {
    return Platform.isAndroid || Platform.isIOS || Platform.isFuchsia;
  }

  void connect() {
    logger.info('Initializing MacroManager');
    _listenToManualRequest();
    _reconnect(force: true, delay: false);
  }

  /// setup a file watcher to be updated by macro server while in development mode
  /// so that the plugin establish connection to macro server and send their analysis contexts path
  void _listenToManualRequest() {
    if (isMobilePlatform) {
      // can't listen to file system in mobile
      return;
    }

    _clientRequestWatcher.listen(
      onChanged: (type, data) {
        final content = data.split(':');
        if (content.length != 2) {
          logger.error('invalid client request');
          return;
        }

        final [_, request] = content;
        switch (request) {
          case 'reconnect':
            _establishConnection();
        }
      },
    );
  }

  void _reconnect({bool force = false, bool delay = true}) async {
    lock.synchronized(
      () async {
        if (!autoReconnect && !force) return;

        if (delay) {
          if (isMobilePlatform) {
            logger.error(
              'MacroServer is not running. Restart the analyzer to automatically start the server.'
              '\nNote: When testing macOS Desktop or Windows applications, the server is started automatically.',
            );
          } else if (status == ConnectionStatus.disconnected) {
            logger.error('Reconnecting to MacroServer in 10 seconds');
          }
        }

        _requestPluginToConnect();
        await Future.delayed(delay ? const Duration(seconds: 10) : const Duration(seconds: 1));
        _establishConnection();
      },
    );
  }

  void _requestPluginToConnect() {
    if (isMobilePlatform) {
      // File system not work here, if auto starting macro server is enabled
      // restarting analyzer start the server
      return;
    }

    File(p.join(macroDirectory, macroPluginRequestFileName))
      ..createSync(recursive: true)
      ..writeAsStringSync('${DateTime.now().microsecondsSinceEpoch}:reconnect');
  }

  Future<void> _establishConnection() async {
    if (_status == ConnectionStatus.connected) {
      if (_wsChannel != null && _wsChannel!.closeCode == null && _wsChannel!.closeReason == null) {
        logger.fine('Using existing active connection..');
        return;
      }
    } else if (_status == ConnectionStatus.connecting) {
      return;
    }

    _status = ConnectionStatus.connecting;
    logger.fine('Establishing connection to MacroServer...');

    try {
      _wsChannel?.sink.close();
      _wsChannel = null;

      final wsUrl = Uri.parse('ws://${serverAddress.authority}/client/connect');
      final channel = WebSocketChannel.connect(wsUrl);
      await channel.ready;

      _status = ConnectionStatus.connected;
      _wsChannel = channel;

      _wsSubs = channel.stream.listen(
        _handleMessage,
        onError: (error) => logger.error('WebSocket error occurred', error),
        onDone: () async {
          _status = ConnectionStatus.disconnected;
          if (!_isMacrosConfigSynced.isCompleted) {
            _isMacrosConfigSynced.complete(false);
          }
          _isMacrosConfigSynced = Completer();
          _reconnect();
        },
      );

      _addMessage(
        ClientConnectMsg(
          id: clientId,
          package: packageInfo,
          macros: macros.keys.toList(),
          assetMacros: assetMacros,
          runTimeout: generateTimeout,
        ),
      );

      logger.info('Connected');
    } catch (e) {
      _status = ConnectionStatus.disconnected;
      logger.error('Unable to connect to MacroServer', e);
      _reconnect();
    }
  }

  bool _addMessage(Message msg) {
    try {
      _wsChannel?.sink.add(encodeMessage(msg));
      return true;
    } catch (e, s) {
      logger.error('Failed to add message', e, s);
      _reconnect();
      return false;
    }
  }

  void _handleMessage(Object? data) {
    final (message, err, stackTrace) = decodeMessage(data);
    if (err != null) {
      logger.error('Failed to decode message from MacroServer', err, stackTrace);
      return;
    }

    switch (message) {
      case RunMacroMsg msg:
        if (msg.assetDeclaration != null) {
          _runAssetMacro(message);
        } else {
          _runMacro(msg);
        }
      case SyncMacrosConfigMsg msg:
        userMacrosConfig = msg.config;
        if (!_isMacrosConfigSynced.isCompleted) {
          _isMacrosConfigSynced.complete(true);
        }

      case AutoRebuildOnConnectResultMsg msg:
        final list = _waitAutoRebuildCompleteCompleter.toList();
        _waitAutoRebuildCompleteCompleter.clear();

        final result = AutoRebuildResult(results: msg.results);

        for (final ctx in msg.results) {
          final duration = (ctx.completedInMilliseconds / 1000).toStringAsFixed(2);

          if (ctx.isSuccess) {
            logger.info('Regenerated successfully in ${duration}s: ${ctx.context}');
          } else {
            logger.error('Regeneration failed in ${duration}s: ${ctx.context} - ${ctx.error}');
          }
        }

        for (final c in list) {
          if (c.isCompleted) continue;

          c.complete(result);
        }

      case GeneralMessage msg:
        logger.logger.log(msg.level, msg.message);
    }
  }

  void _runMacro(RunMacroMsg message) async {
    final generated = StringBuffer();
    final synced = await _syncMacroConfiguration(message.path);
    if (!synced) return;

    try {
      for (final declaration in message.classes ?? const <MacroClassDeclaration>[]) {
        final hasMultipleMetadata = declaration.configs.length > 1;
        final isCombiningGenCodeMode = hasMultipleMetadata && declaration.configs.first.combine == true;
        String? combinedSuffixName;
        bool firstMacroApplied = false;
        StringBuffer? generatedNonCombinable;
        GeneratedType lastGeneratedType = GeneratedType.mixin;

        for (final (index, macroConfig) in declaration.configs.indexed) {
          // initialize or reuse generator
          final (macroGenrator, errMsg) = _getMacroGenerator(macroConfig);
          if (errMsg != null || macroGenrator == null) {
            _addMessage(RunMacroResultMsg(id: message.id, result: '', error: errMsg));
            return;
          }

          // get global config if exists
          MacroGlobalConfig? globalConfig;
          if (userMacrosConfig != null) {
            if (macroGenrator.globalConfigParser case final v?) {
              globalConfig = _getGlobalMacroConfig(macroConfig.key.name, v, userMacrosConfig!);
            }
          }

          // if combing generated code & first macro not applied yet, set the suffix and use that for all macro,
          // otherwise its if not combing or value is set, it fallback to MacroGenerator.suffixName
          if (isCombiningGenCodeMode && !firstMacroApplied) {
            combinedSuffixName = macroGenrator.suffixName;
          }

          // get current generator type
          final currentGeneratedType = macroGenrator.generatedType;

          // combine mode only if first macro applied and its same type as before
          final isCombingGenerator =
              firstMacroApplied &&
              isCombiningGenCodeMode && //
              lastGeneratedType == currentGeneratedType;

          lastGeneratedType = currentGeneratedType;

          // run the macro
          final state = MacroState(
            macro: macroConfig.key,
            remainingMacro: declaration.configs.whereIndexed((i, e) => i != index).map((e) => e.key),
            globalConfig: globalConfig,
            targetPath: message.path,
            targetType: TargetType.clazz,
            importPrefix: declaration.importPrefix,
            imports: message.imports,
            libraryPaths: message.libraryPaths,
            targetName: declaration.className,
            modifier: declaration.modifier,
            isCombingGenerator: isCombingGenerator,
            suffixName: isCombingGenerator || (isCombiningGenCodeMode && !firstMacroApplied)
                ? combinedSuffixName ?? macroGenrator.suffixName
                : macroGenrator.suffixName,
            classesById: message.sharedClasses,
            assetState: null,
          );

          final cap = macroConfig.capability;

          // init state and execute each capability as requested
          await macroGenrator.init(state);

          if (declaration.classTypeParameters != null) {
            await macroGenrator.onClassTypeParameter(state, declaration.classTypeParameters!);
          }

          if (cap.classFields) {
            final fields = declaration.classFields ?? const [];

            await switch ((hasMultipleMetadata, cap.filterClassStaticFields, cap.filterClassInstanceFields)) {
              (_, false, false) => Future.value(),
              (false, _, _) || (_, true, true) => macroGenrator.onClassFields(state, fields),
              (_, false, true) => macroGenrator.onClassFields(state, fields.where((e) => !e.isStatic).toList()),
              (_, true, false) => macroGenrator.onClassFields(state, fields.where((e) => e.isStatic).toList()),
            };
          }

          if (cap.classConstructors) {
            await macroGenrator.onClassConstructors(state, declaration.constructors ?? const []);
          }

          if (cap.classMethods) {
            final methods = declaration.methods ?? const [];

            await switch ((hasMultipleMetadata, cap.filterClassStaticMethod, cap.filterClassInstanceMethod)) {
              (_, false, false) => Future.value(),
              (false, _, _) || (_, true, true) => macroGenrator.onClassMethods(state, methods),
              (_, false, true) => macroGenrator.onClassMethods(
                state,
                methods.where((e) => !e.modifier.isStatic).toList(),
              ),
              (_, true, false) => macroGenrator.onClassMethods(
                state,
                methods.where((e) => e.modifier.isStatic).toList(),
              ),
            };
          }

          if (cap.collectClassSubTypes) {
            await macroGenrator.onClassSubTypes(state, declaration.subTypes ?? const []);
          }

          await macroGenrator.onGenerate(state);
          String generatedCode = state.generated;

          if (isCombiningGenCodeMode) {
            if (!firstMacroApplied) {
              // Remove the last closing bracket when combining with next macros
              final lastBracket = generatedCode.lastIndexOf('}');
              if (lastBracket != -1) {
                generatedCode = '${generatedCode.substring(0, lastBracket)}\n';
              }
            }
          }

          if (generatedCode.isNotEmpty) {
            // if in combining mode but isCombingGenerator = false, due to different in macro generatedType
            // then add the generated code to non combinable

            final shouldUseCombined = !isCombiningGenCodeMode || !firstMacroApplied || isCombingGenerator;
            final buffer = shouldUseCombined ? generated : (generatedNonCombinable ??= StringBuffer());

            buffer
              ..write('\n')
              ..write(generatedCode)
              ..write('\n');
          }

          if (state.generatedNonCombinable case String nonCombinableCode) {
            generatedNonCombinable ??= StringBuffer();
            generatedNonCombinable
              ..write('\n')
              ..write(nonCombinableCode)
              ..write('\n');
          }

          firstMacroApplied = true;
        }

        // add end bracket
        if (isCombiningGenCodeMode) {
          generated.write('\n}\n');
        }

        // add non combinable to end of current generated code
        if (generatedNonCombinable != null) {
          generated.write(generatedNonCombinable.toString());
          generatedNonCombinable = null;
        }
      }
    } catch (e, s) {
      logger.error('Macro execution failed', e, s);
      _addMessage(RunMacroResultMsg(id: message.id, result: '', error: 'Generation Failed: ${e.toString()}'));
      return;
    }

    // send
    final sent = _addMessage(RunMacroResultMsg(id: message.id, result: generated.toString()));
    if (!sent) {
      logger.error('Failed to publish generated code: MacroServer maybe down!');
    }

    // remove exceeded cache
    _removeExcessCache();
  }

  void _runAssetMacro(RunMacroMsg message) async {
    List<String> generatedFiles = [];

    try {
      final declaration = message.assetDeclaration!;
      final macroConfig = MacroConfig(
        capability: const MacroCapability(),
        combine: false,
        key: MacroKey(
          name: message.macroName,
          properties: [
            MacroProperty(
              name: 'config',
              importPrefix: '',
              type: 'Map<String, dynamic>',
              typeInfo: TypeInfo.map,
              typeArguments: _mapStrDynamicTypeArg,
              constantValue: message.assetConfig,
              fieldInitializer: null,
            ),
          ],
        ),
      );

      final (macroGenrator, errMsg) = _getMacroGenerator(macroConfig);
      if (errMsg != null || macroGenrator == null) {
        _addMessage(RunMacroResultMsg(id: message.id, result: '', error: errMsg));
        return;
      }

      assert(message.assetBasePath != null);
      assert(message.assetAbsoluteBasePath != null);
      assert(message.assetAbsoluteOutputPath != null);

      // get global config if exists
      MacroGlobalConfig? globalConfig;
      if (userMacrosConfig != null) {
        if (macroGenrator.globalConfigParser case final v?) {
          globalConfig = _getGlobalMacroConfig(macroConfig.key.name, v, userMacrosConfig!);
        }
      }

      final state = MacroState(
        macro: macroConfig.key,
        globalConfig: globalConfig,
        remainingMacro: const [],
        targetPath: message.path,
        targetType: TargetType.asset,
        importPrefix: '',
        imports: message.imports,
        libraryPaths: message.libraryPaths,
        targetName: declaration.name,
        modifier: MacroModifier(const {}),
        isCombingGenerator: false,
        suffixName: macroGenrator.suffixName,
        classesById: const {},
        assetState: AssetState(
          relativeBasePath: message.assetBasePath!,
          absoluteBasePath: message.assetAbsoluteBasePath!,
          absoluteBaseOutputPath: message.assetAbsoluteOutputPath!,
        ),
      );

      await macroGenrator.init(state);
      await macroGenrator.onAsset(state, declaration);
      await macroGenrator.onGenerate(state);

      generatedFiles.addAll(state.generatedFilePaths);
    } catch (e, s) {
      logger.error('Macro execution failed', e, s);
      _addMessage(RunMacroResultMsg(id: message.id, result: '', error: 'Generation Failed: ${e.toString()}'));
      return;
    }

    // send
    final sent = _addMessage(RunMacroResultMsg(id: message.id, result: '', generatedFiles: generatedFiles));
    if (!sent) {
      logger.error('Failed to publish generated files: MacroServer maybe down!');
    }

    // remove exceeded cache
    _removeExcessCache();
  }

  (MacroGenerator?, String?) _getMacroGenerator(MacroConfig config) {
    try {
      var generator = _generatorCaches[config.configHash];
      if (generator != null) {
        return (generator, null);
      }

      final macroInitFn = macros[config.key.name];
      if (macroInitFn == null) {
        return (null, 'Unrecognized macro: ${config.key.name}, supported macro is: ${macros.keys.join(', ')}');
      }

      generator = macroInitFn(config);
      if (config.configHash case final hash?) {
        _generatorCaches[hash] = generator;
      }

      return (generator, null);
    } catch (e, s) {
      logger.error('Failed to initialize Macro generator', e, s);
      return (null, 'Generation Failed: Unable to initialize Macro generator, ${e.toString()}');
    }
  }

  Future<bool> _syncMacroConfiguration(String path) async {
    if (_isMacrosConfigSynced.isCompleted) return true;

    _addMessage(RequestMacrosConfigMsg(clientId: clientId, filePath: path));

    try {
      final res = await _isMacrosConfigSynced.future;
      return res;
    } catch (_) {
      return false;
    }
  }

  MacroGlobalConfig? _getGlobalMacroConfig(
    String macroName,
    MacroGlobalConfigParser parser,
    UserMacroConfig rawConfig,
  ) {
    final cacheKey = '${rawConfig.id}_$macroName';
    final cached = cachedUserMacrosConfig[cacheKey];
    if (cached != null) return cached.$1;

    final macroConfigValue = rawConfig.configs[macroName];
    if (macroConfigValue == null || macroConfigValue is! Map<String, dynamic>) {
      cachedUserMacrosConfig[cacheKey] = (null,);
      return null;
    }

    try {
      final globalConfig = parser(macroConfigValue);
      cachedUserMacrosConfig[cacheKey] = (globalConfig,);
      return globalConfig;
    } catch (e, s) {
      logger.error('Failed to decode macro configuration for: $macroName', e, s);
      return null;
    }
  }

  void _removeExcessCache() {
    if (_generatorCaches.length > 30) {
      for (final k in _generatorCaches.keys.toList().reversed.take(15)) {
        _generatorCaches.remove(k);
      }
    }
  }

  void dispose() {
    _clientRequestWatcher.close();
    _wsSubs?.cancel();
    _wsSubs = null;
    _wsChannel?.sink.close().catchError((_) {});
  }
}
