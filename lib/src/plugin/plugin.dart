import 'dart:async';
import 'dart:math';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:collection/collection.dart';
import 'package:macro_kit/src/analyzer/logger.dart';
import 'package:macro_kit/src/plugin/server_client.dart';
import 'package:synchronized/synchronized.dart' as sync;

class MacroPlugin extends ServerPlugin implements MacroServerListener {
  MacroPlugin(ResourceProvider provider, this.logger)
    : client = MacroServerClient(pluginId: Random().nextInt(1000), logger: logger),
      super(resourceProvider: provider) {
    _initialize();
  }

  final MacroLogger logger;
  final MacroServerClient client;
  final sync.Lock lock = sync.Lock();
  AnalysisContextCollection? lastContextCollection;

  void _initialize() async {
    client.listener = this;

    client.listenToManualRequest();
    if (client.isDisabledAutoStartSever()) {
      client.autoReconnect = false;
    }

    reconnectToServer();
  }

  @override
  Future<void> reconnectToServer({bool forceStart = false}) async {
    logger.info('Reconnect to MacroServer, lock: ${lock.locked}');

    return lock.synchronized(() async {
      logger.info('Checking MacroServer, lock: ${lock.locked}');

      final serverRunning = await client.isServerRunning();
      if (serverRunning) {
        logger.info('Server is running');
        await client.establishWSConnection();
        return;
      }

      final disableAutoStart = client.isDisabledAutoStartSever();
      if (disableAutoStart && !forceStart) {
        logger.info('Auto starting MacroServer is disabled');
        return;
      }

      logger.info('Starting MacroServer...');
      final started = await client.startMacroServer();
      if (!started) {
        Future.delayed(const Duration(seconds: 5)).then((_) => reconnectToServer(forceStart: forceStart));
        return;
      }

      client.establishWSConnection();
    });
  }

  @override
  List<String> listAnalysisContexts() {
    return lastContextCollection?.contexts
            .map((e) => e.contextRoot.included.map((e) => e.path)) //
            .flattened
            .toList() ??
        [];
  }

  @override
  List<String> get fileGlobsToAnalyze => ['**/*.dart'];

  @override
  String get name => 'Macro Plugin';

  @override
  String get version => '1.40.0';

  @override
  Future<AnalysisHandleWatchEventsResult> handleAnalysisHandleWatchEvents(
    AnalysisHandleWatchEventsParams parameters,
  ) async {
    // do not trigger any loading file
    if (client.status != ConnectionStatus.connected && client.autoReconnect) {
      await Future.delayed(const Duration(seconds: 3));
      reconnectToServer();
    }

    return AnalysisHandleWatchEventsResult();
  }

  @override
  Future<void> afterNewContextCollection({required AnalysisContextCollection contextCollection}) async {
    // do not analyze anything
    lastContextCollection = contextCollection;
    final sent = await client.analysisContentChanged();
    if (!sent) {
      Future.delayed(const Duration(seconds: 3)).then((_) => reconnectToServer());
    }
  }

  @override
  Future<void> analyzeFile({required AnalysisContext analysisContext, required String path}) async {
    // do not analyze
  }

  @override
  Future<PluginShutdownResult> handlePluginShutdown(PluginShutdownParams parameters) {
    logger.info('shutting down');
    client.dispose();
    return super.handlePluginShutdown(parameters);
  }
}
