import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:macro_kit/src/common/common.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/common/models.dart';
import 'package:macro_kit/src/common/watch_file_request.dart';
import 'package:path/path.dart' as p;
import 'package:web_socket_channel/web_socket_channel.dart';

abstract class MacroServerListener {
  void reconnectToServer({bool forceStart = false});

  List<String> listAnalysisContexts();
}

class MacroServerClient {
  MacroServerClient({
    required this.pluginId,
    required this.logger, //
    String serverAddress = 'http://localhost:3232',
  }) : serverAddress = Uri.parse(serverAddress);

  final int pluginId;
  final MacroLogger logger;
  final Uri serverAddress;
  final Client httpClient = Client();
  final _pluginRequestWatcher = WatchFileRequest(
    fileName: macroPluginRequestFileName,
    inDirectory: macroDirectory,
  );
  late MacroServerListener listener;
  ConnectionStatus status = ConnectionStatus.disconnected;
  bool autoReconnect = true;

  Process? _process;
  WebSocketChannel? wsChannel;
  StreamSubscription? _wsSubs;

  Future<bool> isServerRunning() async {
    try {
      final res = await httpClient.get(
        serverAddress.replace(path: '/ping'),
        headers: const {'Content-Type': 'application/json'},
      );
      return res.statusCode == HttpStatus.ok;
    } catch (e, s) {
      logger.error('Failed to determine if MacroServer is running', e, s);
      return false;
    }
  }

  bool isDisabledAutoStartServer() {
    try {
      final file = File(p.join(macroDirectory, 'macro_config.json'));
      if (!file.existsSync()) {
        return false;
      }

      final res = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      logger.info('macro_config loaded: $res');

      if (res['disableAutoStart'] == true) {
        return true;
      }

      return false;
    } catch (e, s) {
      logger.error('Failed to check if MacroServer auto start is disabled', e, s);
      return false;
    }
  }

  /// setup a file watcher to be updated by macro server while in development mode
  /// so that the plugin establish connection to macro server and send their analysis contexts path
  void listenToManualRequest() {
    // here we listen to change coming from MacroServer in order to
    // reconnect to it in case of disabling auto starting in development or crashing server
    _pluginRequestWatcher.listen(
      onChanged: (changeType, data) {
        logger.info('on plugin request: $data');

        final content = data.split(':');
        if (content.length != 2) {
          logger.error('invalid plugin request');
          return;
        }

        final [_, request] = content;
        switch (request) {
          case 'reconnect':
            listener.reconnectToServer(forceStart: true);
        }
      },
      onError: (Object? err, StackTrace? s) => logger.info('An error occurred in watching plugin request file', err, s),
      onClosed: () => logger.info('watching plugin request closed'),
    );
  }

  Future<bool> startMacroServer() async {
    final home = homeDir;
    var path = Platform.environment['PATH'] ?? '';
    final addToPath = [
      'fvm/default/bin',
      'fvm/default/.pub-cache/bin',
      '.pub-cache/bin',
    ].map((e) => p.join(home, e)).join(':');
    path += ':$sdkBin:$addToPath';

    logger.info('System path: $path');

    try {
      const args = ['macro'];
      _process = await Process.start(
        args.first,
        args.sublist(1),
        environment: {...Platform.environment, 'PATH': path},
      );

      // wait until macro server initialize itself
      await Future.delayed(const Duration(seconds: 3));
      return true;
    } catch (e, s) {
      if (e.toString().contains('Address already in use')) {
        logger.info('MacroServer is already running...');
        return true;
      }

      logger.error('Failed to start MacroServer', e, s);
      return false;
    }
  }

  Future<void> establishWSConnection() async {
    if (status == ConnectionStatus.connected) {
      if (wsChannel != null && wsChannel!.closeCode == null && wsChannel!.closeReason == null) {
        logger.fine('Using existing active connection..');
        return;
      }
    } else if (status == ConnectionStatus.connecting) {
      return;
    }

    status = ConnectionStatus.connecting;
    logger.fine('Establishing connection to MacroServer...');

    try {
      wsChannel?.sink.close();
      wsChannel = null;

      Uri.parse('http://localhost:3232').host;
      final wsUrl = Uri.parse('ws://${serverAddress.authority}/plugin/connect');
      final channel = WebSocketChannel.connect(wsUrl);
      await channel.ready;

      status = ConnectionStatus.connected;
      wsChannel = channel;

      _wsSubs = channel.stream.listen(
        (data) {
          final _ = decodeMessage(data);
        },
        onError: (error) => logger.error('WebSocket error occurred', error),
        onDone: () async => status = ConnectionStatus.disconnected,
      );

      _addMessage(
        PluginConnectMsg(
          id: pluginId,
          initialContexts: listener.listAnalysisContexts(),
        ),
      );

      logger.info('Connected');
    } catch (e) {
      status = ConnectionStatus.disconnected;
      logger.error('Unable to connect to MacroServer');
    }
  }

  bool _addMessage(Message msg) {
    try {
      wsChannel?.sink.add(encodeMessage(msg));
      return true;
    } catch (e, s) {
      logger.error('Failed to add message', e, s);
      return false;
    }
  }

  Future<bool> analysisContentChanged() async {
    try {
      final context = listener.listAnalysisContexts();
      _addMessage(AnalysisContextsMsg(contexts: context));
      return false;
    } catch (e, s) {
      logger.error('Failed to send analysis context', e, s);
      return false;
    }
  }

  void dispose() {
    _process?.kill(ProcessSignal.sighup);
    _pluginRequestWatcher.close();
    _wsSubs?.cancel();
    _wsSubs = null;
    wsChannel?.sink.close();
    wsChannel = null;
  }
}
