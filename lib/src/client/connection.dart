import 'dart:async';
import 'dart:math' show Random;

import 'package:macro_kit/src/analyzer/utils/lock.dart';
import 'package:macro_kit/src/client/client_manager.dart' show MacroInitFunction;
import 'package:macro_kit/src/common/common.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/common/models.dart';
import 'package:macro_kit/src/core/core.dart' show PackageInfo, AssetMacroInfo;
import 'package:macro_kit/src/core/platform/platform.dart';
import 'package:web_socket_channel/status.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

abstract class ClientConnection {
  ClientConnection({
    required this.logger,
    required this.serverAddress,
    required this.packageInfo,
    required this.macros,
    required this.assetMacros,
    required this.autoReconnect,
    required this.generateTimeout,
    required this.autoRunMacro,
  });

  final int clientId = 1000 + Random().nextInt(1000);
  final MacroLogger logger;
  final Uri serverAddress;
  final PackageInfo packageInfo;
  final Map<String, MacroInitFunction> macros;
  final Map<String, List<AssetMacroInfo>> assetMacros;
  final bool autoReconnect;
  final Duration generateTimeout;
  final bool autoRunMacro;
  late ConnectionListener listener;

  final CustomBasicLock lock = CustomBasicLock();

  ConnectionStatus status = ConnectionStatus.disconnected;
  Completer<bool> isMacrosConfigSynced = Completer<bool>();

  bool get isManagedByMacroServer;

  void connect();

  bool addMessage(Message message);

  void dispose();
}

abstract class ConnectionListener {
  void handleNewMessage(Object? data);
}

ClientConnection createConnection({
  required MacroLogger logger,
  required Uri serverAddress,
  required PackageInfo packageInfo,
  required Map<String, MacroInitFunction> macros,
  required Map<String, List<AssetMacroInfo>> assetMacros,
  required bool autoReconnect,
  required Duration generateTimeout,
  required bool autoRunMacro,
}) {
  return WsClientConnection(
    logger: logger,
    serverAddress: serverAddress,
    packageInfo: packageInfo,
    macros: macros,
    assetMacros: assetMacros,
    autoRunMacro: autoRunMacro,
    autoReconnect: autoReconnect,
    generateTimeout: generateTimeout,
  );
}

class WsClientConnection extends ClientConnection {
  WsClientConnection({
    required super.logger,
    required super.serverAddress,
    required super.packageInfo,
    required super.macros,
    required super.assetMacros,
    required super.autoRunMacro,
    required super.autoReconnect,
    required super.generateTimeout,
  });

  final _clientRequestWatcher = WatchFileRequest(
    fileName: macroClientRequestFileName,
    inDirectory: currentPlatform.isDesktopPlatform ? macroDirectory : '',
  );

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubs;

  @override
  final bool isManagedByMacroServer = platformEnvironment['managed_by_macro_server'] == 'true';

  @override
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
          logger.error('Invalid client request');
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

        requestPluginToConnect();
        await Future.delayed(delay ? const Duration(seconds: 10) : const Duration(seconds: 1));
        _establishConnection();
      },
    );
  }

  Future<void> _establishConnection() async {
    if (status == ConnectionStatus.connected) {
      if (_wsChannel != null && _wsChannel!.closeCode == null && _wsChannel!.closeReason == null) {
        logger.fine('Using existing active connection..');
        return;
      } else if (_wsChannel?.closeCode == normalClosure && isManagedByMacroServer) {
        _onGotClosingMessage();
      }
    } else if (status == ConnectionStatus.connecting) {
      return;
    }

    status = ConnectionStatus.connecting;
    logger.fine('Establishing connection to MacroServer...');

    try {
      _wsChannel?.sink.close();
      _wsChannel = null;

      final wsUrl = Uri.parse('ws://${serverAddress.authority}/client/connect');
      final channel = WebSocketChannel.connect(wsUrl);
      await channel.ready;

      status = ConnectionStatus.connected;
      _wsChannel = channel;

      _wsSubs = channel.stream.listen(
        listener.handleNewMessage,
        onError: (error) => logger.error('WebSocket error occurred', error),
        onDone: () async {
          status = ConnectionStatus.disconnected;
          if (!isMacrosConfigSynced.isCompleted) {
            isMacrosConfigSynced.complete(false);
          }
          isMacrosConfigSynced = Completer();
          if (_wsChannel?.closeCode == normalClosure && isManagedByMacroServer) {
            _onGotClosingMessage();
          }

          _reconnect();
        },
      );

      final isAutoRunMacro = autoRunMacro && !isManagedByMacroServer;

      addMessage(
        ClientConnectMsg(
          id: clientId,
          platform: currentPlatform,
          package: packageInfo,
          macros: macros.keys.toList(),
          assetMacros: assetMacros,
          runTimeout: generateTimeout,
          managedByMacroServer: isManagedByMacroServer,
          autoRunMacro: isAutoRunMacro,
        ),
      );

      logger.info('Connected');
    } on WebSocketChannelException catch (_) {
      logger.error('Unable to connect to MacroServer: Is MacroServer is running?');
      status = ConnectionStatus.disconnected;
      _reconnect();
    } catch (e) {
      logger.error('Unable to connect to MacroServer', e);
      status = ConnectionStatus.disconnected;
      _reconnect();
    }
  }

  Never _onGotClosingMessage() {
    logger.info('got closing message');
    dispose();
    exit(0);
  }

  @override
  bool addMessage(Message message) {
    try {
      _wsChannel?.sink.add(encodeMessage(message));
      return true;
    } catch (e, s) {
      logger.error('Failed to add message', e, s);
      _reconnect();
      return false;
    }
  }

  @override
  void dispose() {
    _clientRequestWatcher.close();
    _wsSubs?.cancel();
    _wsSubs = null;
    _wsChannel?.sink.close().catchError((_) {});
  }
}
