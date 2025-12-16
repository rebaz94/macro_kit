import 'dart:async';
import 'dart:math';

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:macro_kit/src/analyzer/lock.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/plugin/macro_context_rule.dart';
import 'package:macro_kit/src/plugin/server_client.dart';

class MacroPlugin extends Plugin implements MacroServerListener {
  MacroPlugin({
    required this.logger,
  }) : client = MacroServerClient(pluginId: Random().nextInt(1000), logger: logger);

  final MacroLogger logger;
  final MacroServerClient client;
  final CustomBasicLock lock = CustomBasicLock();
  final Set<String> contexts = {};

  @override
  String get name => 'MacroPlugin';

  @override
  FutureOr<void> start() {
    _initialize();
  }

  @override
  FutureOr<void> register(PluginRegistry registry) async {
    registry.registerWarningRule(
      MacroContextRule(
        logger: logger,
        onNewAnalysisContext: _onNewAnalysisContextReceived,
      ),
    );
  }

  void _onNewAnalysisContextReceived(String contextPath) {
    contexts.add(contextPath);
    client.analysisContentChanged();
  }

  void _initialize() async {
    client.listener = this;

    client.listenToManualRequest();
    client.autoReconnect = !client.isDisabledAutoStartServer();

    reconnectToServer();
  }

  @override
  Future<void> reconnectToServer() async {
    logger.info('Reconnecting to MacroServer, lock: ${lock.locked}');

    return lock.synchronized(() async {
      logger.info('Checking MacroServer');

      final serverRunning = await client.isServerRunning();
      if (serverRunning) {
        logger.info('Server is running');
        await client.establishWSConnection();
        return;
      }

      final disableAutoStart = client.isDisabledAutoStartServer();
      client.autoReconnect = !disableAutoStart;
      if (disableAutoStart) {
        logger.info('Auto starting MacroServer is disabled');
        return;
      }

      logger.info('Starting MacroServer...');
      final started = await client.startMacroServer();
      if (!started) {
        Future.delayed(const Duration(seconds: 10)).then((_) => reconnectToServer());
        return;
      }

      await client.establishWSConnection();
    });
  }

  @override
  List<String> listAnalysisContexts() => contexts.toList();

  @override
  FutureOr<void> shutDown() {
    logger.info('shutting down');
    client.dispose();
  }
}
