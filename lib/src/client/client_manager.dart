import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:macro_kit/macro.dart';
import 'package:macro_kit/src/analyzer/logger.dart';
import 'package:macro_kit/src/analyzer/macro_server.dart';
import 'package:macro_kit/src/analyzer/models.dart';
import 'package:macro_kit/src/analyzer/watch_file_request.dart';
import 'package:macro_kit/src/plugin/server_client.dart';
import 'package:synchronized/synchronized.dart' as sync;
import 'package:web_socket_channel/web_socket_channel.dart';

typedef MacroInitFunction = MacroGenerator Function(MacroConfig config);

class MacroManager {
  MacroManager({
    required this.logger,
    required String serverAddress,
    required this.macros,
    required this.autoReconnect,
    required this.generateTimeout,
  }) : serverAddress = Uri.parse(serverAddress);

  final int clientId = 1000 + Random().nextInt(1000);
  final sync.Lock lock = sync.Lock();
  final MacroLogger logger;
  final Uri serverAddress;
  final Map<String, MacroInitFunction> macros;
  final bool autoReconnect;
  final Duration generateTimeout;
  final _clientRequestWatcher = WatchFileRequest(
    fileName: macroClientRequestFileName,
    inDirectory: macroDirectory,
  );

  /// A cache of generator keyed by hash of the json that build MacroGenerator instance
  final Map<int, MacroGenerator> _generatorCaches = {};

  ConnectionStatus _status = ConnectionStatus.disconnected;

  ConnectionStatus get status => _status;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubs;

  void connect() {
    _listenToManualRequest();
    _reconnect(force: true, delay: false);
  }

  /// setup a file watcher to be updated by macro server while in development mode
  /// so that the plugin establish connection to macro server and send their analysis contexts path
  void _listenToManualRequest() {
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
          logger.error('Reconnecting to MacroServer in 10 seconds');
        }

        _requestPluginToConnect();
        await Future.delayed(delay ? const Duration(seconds: 10) : const Duration(seconds: 1));
        _establishConnection();
      },
    );
  }

  void _requestPluginToConnect() {
    File('$macroDirectory/$macroPluginRequestFileName')
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
          _reconnect();
        },
      );

      _addMessage(
        ClientConnectMsg(
          id: clientId,
          runTimeout: generateTimeout,
          macros: macros.keys.toList(),
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
        _runMacro(msg);
    }
  }

  void _runMacro(RunMacroMsg message) async {
    final generated = StringBuffer();

    try {
      for (final declaration in message.classes ?? const <MacroClassDeclaration>[]) {
        final hasMultipleMetadata = declaration.configs.length > 1;
        final isCombiningGenCode = hasMultipleMetadata && declaration.configs.first.combine == true;
        String? suffixName;
        bool firstMacroApplied = false;
        StringBuffer? generatedNonCombinable;

        for (final (index, macroConfig) in declaration.configs.indexed) {
          // initialize or reuse generator
          final (generator, errMsg) = _getMacroGenerator(macroConfig);
          if (errMsg != null || generator == null) {
            _addMessage(RunMacroResultMsg(id: message.id, result: '', error: errMsg));
            return;
          }

          // if combing generated code & first macro not applied yet, set the suffix and use that for all macro,
          // otherwise its if not combing or value is set, it fallback to MacroGenerator.suffixName
          if (isCombiningGenCode && !firstMacroApplied) {
            suffixName = generator.suffixName;
          }

          // run the macro
          final state = MacroState(
            macro: macroConfig.key,
            remainingMacro: declaration.configs.whereIndexed((i, e) => i != index).map((e) => e.key),
            targetType: TargetType.clazz,
            targetName: declaration.className,
            modifier: declaration.modifier,
            isCombingGenerator: firstMacroApplied && isCombiningGenCode,
            suffixName: suffixName ?? generator.suffixName,
            classesById: message.sharedClasses,
          );

          final cap = macroConfig.capability;

          // init state and execute each capability as requested
          await generator.init(state);

          if (declaration.classTypeParameters != null) {
            await generator.onClassTypeParameter(state, declaration.classTypeParameters!);
          }

          if (cap.classFields) {
            final fields = declaration.classFields ?? const [];

            await switch ((hasMultipleMetadata, cap.filterClassStaticFields, cap.filterClassInstanceFields)) {
              (_, false, false) => Future.value(),
              (false, _, _) || (_, true, true) => generator.onClassFields(state, fields),
              (_, false, true) => generator.onClassFields(state, fields.where((e) => !e.modifier.isStatic).toList()),
              (_, true, false) => generator.onClassFields(state, fields.where((e) => e.modifier.isStatic).toList()),
            };
          }

          if (cap.classConstructors) {
            await generator.onClassConstructors(state, declaration.constructors ?? const []);
          }

          if (cap.classMethods) {
            final methods = declaration.methods ?? const [];

            await switch ((hasMultipleMetadata, cap.filterClassStaticMethod, cap.filterClassInstanceMethod)) {
              (_, false, false) => Future.value(),
              (false, _, _) || (_, true, true) => generator.onClassMethods(state, methods),
              (_, false, true) => generator.onClassMethods(state, methods.where((e) => !e.modifier.isStatic).toList()),
              (_, true, false) => generator.onClassMethods(state, methods.where((e) => e.modifier.isStatic).toList()),
            };
          }

          if (cap.collectClassSubTypes) {
            await generator.onClassSubTypes(state, declaration.subTypes ?? const []);
          }

          await generator.onGenerate(state);
          String generatedCode = state.generated;

          if (isCombiningGenCode) {
            if (!firstMacroApplied) {
              // Remove the last closing bracket when combining with previous macros
              final lastBracket = generatedCode.lastIndexOf('}');
              if (lastBracket != -1) {
                generatedCode = '${generatedCode.substring(0, lastBracket)}\n';
              }
            }
          }

          if (generatedCode.isNotEmpty) {
            generated
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
        if (isCombiningGenCode) {
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
