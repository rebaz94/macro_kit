import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:collection/collection.dart';
import 'package:hashlib/hashlib.dart';
import 'package:macro_kit/src/analyzer/lock.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/plugin/macro_context_rule.dart';
import 'package:macro_kit/src/plugin/server_client.dart';

class MacroPlugin extends Plugin implements MacroServerListener {
  MacroPlugin._({
    required int pluginId,
    required this.logger,
  }) : client = MacroServerClient(pluginId: pluginId, logger: logger);

  factory MacroPlugin() {
    final pluginId = Random().nextInt(100);
    final pluginLogId = xxh32code(Platform.packageConfig ?? pluginId.toString());
    final sink = MacroLogger.getFileAppendLogger('plugin_$pluginLogId.log');
    final logger = MacroLogger.createLogger(name: 'MacroPlugin', into: sink.writeln);
    return MacroPlugin._(pluginId: pluginId, logger: logger);
  }

  final MacroLogger logger;
  final MacroServerClient client;
  final CustomBasicLock lock = CustomBasicLock();
  Set<String> contexts = {};

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
    final newContexts = {...contexts, contextPath};
    if (const DeepCollectionEquality().equals(contexts, newContexts)) {
      return;
    }

    logger.info('Analysis context discovered: $contextPath');
    contexts = newContexts;
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
