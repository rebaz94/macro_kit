import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:macro_kit/src/analyzer/analyzer.dart';
import 'package:macro_kit/src/analyzer/logger.dart';
import 'package:macro_kit/src/analyzer/models.dart';
import 'package:macro_kit/src/analyzer/vm_utils.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart' as sync;
import 'package:watcher/watcher.dart';
import 'package:web_socket_channel/status.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const kRelease = bool.fromEnvironment("dart.vm.product");
const macroPluginRequestFileName = 'macro_plugin_request';
const macroClientRequestFileName = 'macro_client_request';

typedef _PluginChannelInfo = (WebSocketChannel, List<String>);
typedef _ClientChannelInfo = (WebSocketChannel, List<String>, Duration, StreamSubscription?);

abstract class BaseAnalyzer {
  BaseAnalyzer(this.logger);

  final MacroLogger logger;

  void requestPluginToConnect();

  void requestClientToConnect();

  Future<void> processSource(String path);

  void removeFile(String path);

  int? getClientChannelFor(String targetMacro);

  Future<RunMacroResultMsg> runMacroGenerator(int channelId, RunMacroMsg message);

  (String, String) buildGeneratedFileInfo(String path);

  void onClientError(int channelId, String message, [Object? err, StackTrace? trace]);
}

class MacroAnalyzerServer extends Analyzer {
  MacroAnalyzerServer(super.logger);

  static final MacroAnalyzerServer instance = () {
    void Function(Object? log)? logTo;
    if (kRelease) {
      final sink = MacroLogger.getFileAppendLogger('macro_analyze.log');
      logTo = sink.writeln;
    }

    final logger = MacroLogger.createLogger(name: 'MacroAnalyzer', into: logTo);
    return MacroAnalyzerServer(logger).._setupAutoShutdown();
  }();

  VmUtils? vmUtils;
  final sync.Lock lock = sync.Lock();
  final Map<String, StreamSubscription<WatchEvent>> _subs = {};
  final Map<int, _PluginChannelInfo> _pluginChannels = {};
  final List<StreamSubscription> _wsPluginSubs = [];

  /// List of connected client by client id with ws socket and supported macro names
  final Map<int, _ClientChannelInfo> _clientChannels = {};

  /// List of requested code generation by request id
  final Map<int, Completer<RunMacroResultMsg>> _pendingOperations = {};
  Client? httpClient;
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
    File('$macroDirectory/$macroPluginRequestFileName')
      ..createSync(recursive: true)
      ..writeAsStringSync('${DateTime.now().microsecondsSinceEpoch}:reconnect');
  }

  @override
  void requestClientToConnect() {
    // send macro generator to reconnect
    File('$macroDirectory/$macroClientRequestFileName')
      ..createSync(recursive: true)
      ..writeAsStringSync('${DateTime.now().microsecondsSinceEpoch}:reconnect');
  }

  Future<bool> shutdownMacroServer() async {
    try {
      httpClient ??= Client();
      final res = await httpClient!.post(Uri.parse('http://localhost:3232/shutdown'), body: '{}');
      return res.statusCode == HttpStatus.ok;
    } catch (e) {
      logger.error('Failed to shut down existing MacroServer', e);
      return false;
    }
  }

  Future<void> onContextChanged() async {
    return lock.synchronized(() async {
      final newContexts = Set<String>.of(_pluginChannels.values.map((e) => e.$2).expand((e) => e)).toList();
      if (const DeepCollectionEquality().equals(contexts, newContexts)) {
        return;
      }

      var old = contextCollection;
      contextCollection = AnalysisContextCollection(
        includedPaths: newContexts,
        resourceProvider: PhysicalResourceProvider.INSTANCE,
      );
      contexts = newContexts;
      old.dispose();
      await reWatchContexts(newContexts);
    });
  }

  Future<void> reWatchContexts(List<String> contexts) async {
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
    if (p.extension(event.path, 2) != '.dart') {
      logger.fine('Ignored: ${event.path}');
      return;
    } else if (event.type == ChangeType.REMOVE) {
      mayContainsMacroCache.remove(event.path);
      final (_, generatedFilePath) = buildGeneratedFileInfo(event.path);
      removeFile(generatedFilePath);
      return;
    }

    if (currentAnalyzingPath == '' || currentAnalyzingPath == event.path) {
      // its first time or file changed during current analyzing, so we have to run it again
      pendingAnalyze.add(event.path);
    } else if (pendingAnalyze.contains(event.path)) {
      // its already in pending list, so no duplicate, next time it process it
      return;
    }

    _processNext();
  }

  Future<void> _processNext() async {
    if (isAnalyzingFile || pendingAnalyze.isEmpty) return;

    isAnalyzingFile = true;
    final currentPath = pendingAnalyze.removeAt(0);

    try {
      await processSource(currentPath);
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
  void removeFile(String path) {
    try {
      (fileCaches[path] ?? File(path)).deleteSync();
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
            _pluginChannels[id] = (webSocket, const []);
            pluginId = id;
          case AnalysisContextsMsg(contexts: var contexts):
            final current = pluginId == -1 ? null : _pluginChannels[pluginId];
            if (current == null) {
              logger.error('Plugin received context but no active channel exists, ignored');
              return;
            }

            const excluded = [
              '.dart_tool',
              '.pub-cache',
              '.idea',
              '.vscode',
              'build/intermediates',
              '.symlinks/plugins',
              'Intermediates.noindex',
            ];
            contexts = contexts.where((path) => !excluded.any((word) => path.contains(word))).toList();

            _pluginChannels[pluginId] = (current.$1, contexts);
            onContextChanged();
          default:
            logger.info('Unhandled message: $message');
        }
      },
      onError: (err) => logger.error('WebSocket channel error occurred', err),
      onDone: () {
        _pluginChannels.remove(pluginId);
        onContextChanged();
      },
    );
    _wsPluginSubs.add(sub);
  }

  Iterable<WebSocketChannel> getChannelsForPath(String path) sync* {
    for (final entry in _pluginChannels.entries) {
      inner:
      for (final contextPath in entry.value.$2) {
        if (p.isWithin(contextPath, path)) {
          yield entry.value.$1;
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
            _clientChannels[msg.id] = (webSocket, msg.macros, msg.runTimeout, sub);
            clientId = msg.id;
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
      _clientChannels[channelId]?.$1.sink.add(encodeMessage(msg));
      return true;
    } catch (e, s) {
      logger.error('Unable to add message to client', e, s);
      final channelInfo = _clientChannels.remove(channelId);
      channelInfo?.$4?.cancel();
      return false;
    }
  }

  @override
  int? getClientChannelFor(String targetMacro) {
    for (final entry in _clientChannels.entries) {
      for (final macroName in entry.value.$2) {
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
      completer.complete(RunMacroResultMsg(id: message.id, result: '', error: 'No Macro Generator running!'));
      return completer.future;
    }

    _pendingOperations[message.id] = completer;

    return completer.future.timeout(
      _clientChannels[channelId]?.$3 ?? const Duration(seconds: 30),
      onTimeout: () => RunMacroResultMsg(id: message.id, result: '', error: 'Generation timeout!'),
    );
  }

  @override
  (String, String) buildGeneratedFileInfo(String path) {
    final dir = p.dirname(path);
    final base = p.basenameWithoutExtension(path);
    return ('$base.dart', p.join(dir, '$base.g.dart'));
  }

  @override
  void onClientError(int channelId, String message, [Object? err, StackTrace? trace]) {
    logger.error('Error on channel $channelId: $message', err, trace);
  }

  void dispose() {
    _autoShutdownTimer?.cancel();
    vmUtils?.dispose();

    for (final sub in _subs.values) {
      sub.cancel();
    }

    for (final channel in _pluginChannels.values) {
      channel.$1.sink.close(goingAway, 'Server is closing').catchError((_) {});
    }

    for (final channel in _clientChannels.values) {
      channel.$4?.cancel();
      channel.$1.sink.close(goingAway, 'Server is closing').catchError((_) {});
    }

    for (final sub in _wsPluginSubs) {
      sub.cancel();
    }

    contextCollection.dispose();
    httpClient?.close();
  }
}
