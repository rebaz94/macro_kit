import 'dart:async';

import 'package:collection/collection.dart';
import 'package:macro_kit/macro_kit.dart';
import 'package:macro_kit/src/client/connection.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/common/models.dart';

typedef MacroInitFunction = MacroGenerator Function(MacroConfig config);

typedef CachedUserMacroConfig = ({MacroGlobalConfig? config, String contextPath, String remapGeneratedFileTo});

class MacroManager implements ConnectionListener {
  MacroManager({
    required this.logger,
    required String serverAddress,
    required PackageInfo packageInfo,
    required Map<String, MacroInitFunction> macros,
    required Map<String, List<AssetMacroInfo>> assetMacros,
    required bool autoReconnect,
    required Duration generateTimeout,
    required bool autoRunMacro,
  }) : connection = createConnection(
         logger: logger,
         packageInfo: packageInfo,
         macros: macros,
         assetMacros: assetMacros,
         autoRunMacro: autoRunMacro,
         autoReconnect: autoReconnect,
         generateTimeout: generateTimeout,
         serverAddress: Uri.parse(serverAddress),
       ) {
    connection.listener = this;
  }

  static final List<Completer<AutoRebuildResult>> _waitAutoRebuildCompleteCompleter = [];

  static Future<AutoRebuildResult> waitUntilRebuildCompleted() {
    final c = Completer<AutoRebuildResult>();
    _waitAutoRebuildCompleteCompleter.add(c);
    return c.future;
  }

  final MacroLogger logger;
  final Map<String, CachedUserMacroConfig> cachedUserMacrosConfig = {};
  UserMacroConfig? userMacrosConfig;
  late ClientConnection connection;

  /// A cache of generator keyed by hash of the json that build MacroGenerator instance
  final Map<int, MacroGenerator> _generatorCaches = {};

  void connect() {
    connection.connect();
  }

  @override
  void handleNewMessage(Object? data) {
    final (message, err, stackTrace) = decodeMessage(data);
    if (err != null) {
      logger.error('Failed to decode message from MacroServer', err, stackTrace);
      return;
    }

    switch (message) {
      case RunMacroMsg msg:
        if (connection.autoRunMacro && !connection.isManagedByMacroServer) {
          logger.warn(
            'Received macro generation request, but the client is in read-only mode because autoRunMacro is enabled.\n'
            '\n'
            'This typically means:\n'
            '  • The macro is already running in a separate process\n'
            '  • Manual macro execution is blocked to prevent conflicts\n'
            '\n'
            'To resolve this:\n'
            '  1. Set autoRunMacro to false if you want manual control\n'
            '  2. Ensure autoRunMacro matches in both configurations\n'
            '  3. Avoid running macros both automatically and manually\n'
            '\n'
            'If this seems incorrect, please file an issue at:\n'
            'https://github.com/rebaz94/macro_kit',
          );
          return;
        }

        if (msg.assetDeclaration != null) {
          _runAssetMacro(message);
        } else {
          _runMacro(msg);
        }
      case SyncMacrosConfigMsg msg:
        userMacrosConfig = msg.config;
        if (!connection.isMacrosConfigSynced.isCompleted) {
          connection.isMacrosConfigSynced.complete(true);
        }

      case AutoRebuildOnConnectResultMsg msg:
        final list = _waitAutoRebuildCompleteCompleter.toList();
        _waitAutoRebuildCompleteCompleter.clear();

        final result = AutoRebuildResult(results: msg.results);

        for (final ctx in msg.results) {
          final duration = (ctx.completedInMilliseconds ~/ 1000);

          if (ctx.isSuccess) {
            logger.info('Regenerated successfully in ${duration}s for: ${ctx.package}');
          } else {
            logger.error('Regeneration failed in ${duration}s: ${ctx.package} - ${ctx.error}');
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
            connection.addMessage(RunMacroResultMsg(id: message.id, result: '', error: errMsg));
            return;
          }

          // get global config if exists
          final (globalConfig, contentPath, remapGeneratedFileTo) = _getGlobalMacroConfig(
            macroConfig.key.name,
            macroGenrator.globalConfigParser,
            userMacrosConfig,
          );

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
            contentPath: contentPath,
            remapGeneratedFileTo: remapGeneratedFileTo,
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
      connection.addMessage(RunMacroResultMsg(id: message.id, result: '', error: 'Generation Failed: ${e.toString()}'));
      return;
    }

    // send
    final sent = connection.addMessage(RunMacroResultMsg(id: message.id, result: generated.toString()));
    if (!sent) {
      logger.error('Failed to publish generated code: MacroServer maybe down!');
    }

    // remove exceeded cache
    _removeExcessCache();
  }

  static final _mapStrDynamicTypeArg = [
    MacroProperty(name: '', importPrefix: '', type: 'String', typeInfo: TypeInfo.string, fieldInitializer: null),
    MacroProperty(name: '', importPrefix: '', type: 'dynamic', typeInfo: TypeInfo.dynamic, fieldInitializer: null),
  ];

  void _runAssetMacro(RunMacroMsg message) async {
    final synced = await _syncMacroConfiguration(message.path);
    if (!synced) return;

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
        connection.addMessage(RunMacroResultMsg(id: message.id, result: '', error: errMsg));
        return;
      }

      assert(message.assetBasePath != null);
      assert(message.assetAbsoluteBasePath != null);
      assert(message.assetAbsoluteOutputPath != null);

      // get global config if exists
      final (globalConfig, contextPath, remapGeneratedFileTo) = _getGlobalMacroConfig(
        macroConfig.key.name,
        macroGenrator.globalConfigParser,
        userMacrosConfig!,
      );

      final state = MacroState(
        macro: macroConfig.key,
        remainingMacro: const [],
        globalConfig: globalConfig,
        contentPath: contextPath,
        remapGeneratedFileTo: remapGeneratedFileTo,
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
      connection.addMessage(RunMacroResultMsg(id: message.id, result: '', error: 'Generation Failed: ${e.toString()}'));
      return;
    }

    // send
    final sent = connection.addMessage(RunMacroResultMsg(id: message.id, result: '', generatedFiles: generatedFiles));
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

      final macroInitFn = connection.macros[config.key.name];
      if (macroInitFn == null) {
        return (
          null,
          'Unrecognized macro: ${config.key.name}, supported macro is: ${connection.macros.keys.join(', ')}',
        );
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
    if (connection.isMacrosConfigSynced.isCompleted) return true;

    connection.addMessage(
      RequestMacrosConfigMsg(
        clientId: connection.clientId,
        filePath: path,
      ),
    );

    try {
      final res = await connection.isMacrosConfigSynced.future;
      return res;
    } catch (_) {
      return false;
    }
  }

  /// return the global config and relative path of remapping generated file
  (MacroGlobalConfig?, String?, String) _getGlobalMacroConfig(
    String macroName,
    MacroGlobalConfigParser? parser,
    UserMacroConfig? rawConfig,
  ) {
    if (rawConfig == null) {
      return const (null, null, '');
    }

    final cacheKey = '${rawConfig.id}_$macroName';
    final cached = cachedUserMacrosConfig[cacheKey];
    if (cached != null) {
      return (cached.config, cached.contextPath, cached.remapGeneratedFileTo);
    }

    final macroConfigValue = rawConfig.configs[macroName];
    if (macroConfigValue == null || macroConfigValue is! Map<String, dynamic> || parser == null) {
      cachedUserMacrosConfig[cacheKey] = (
        config: null,
        contextPath: rawConfig.context,
        remapGeneratedFileTo: rawConfig.remapGeneratedFileTo,
      );
      return (null, rawConfig.context, rawConfig.remapGeneratedFileTo);
    }

    try {
      final globalConfig = parser(macroConfigValue);
      cachedUserMacrosConfig[cacheKey] = (
        config: globalConfig,
        contextPath: rawConfig.context,
        remapGeneratedFileTo: rawConfig.remapGeneratedFileTo,
      );
      return (globalConfig, rawConfig.context, rawConfig.remapGeneratedFileTo);
    } catch (e, s) {
      logger.error('Failed to decode macro configuration for: $macroName', e, s);
      return (null, rawConfig.context, rawConfig.remapGeneratedFileTo);
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
    connection.dispose();
  }
}
