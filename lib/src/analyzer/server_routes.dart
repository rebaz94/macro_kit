import 'dart:convert';
import 'dart:io';

import 'package:macro_kit/src/analyzer/macro_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void startMacroServer() async {
  var app = Router();
  app
    ..get('/ping', _onPing) //
    ..get(
      '/plugin/connect',
      webSocketHandler(
        (webSocket, _) => _onNewPluginConnection(webSocket),
        pingInterval: const Duration(minutes: 1),
      ),
    )
    ..get(
      '/client/connect',
      webSocketHandler(
        (webSocket, _) => _onNewCodeGeneratorConnection(webSocket),
        pingInterval: const Duration(minutes: 1),
      ),
    )
    ..get('/contexts', _getServerContexts)
    ..post('/force_regenerate', _forceRegenerate)
    ..post('/shutdown', _onShutdown);

  final alreadyInUse = await _serveServer(app);
  if (alreadyInUse) {
    final shutdown = await MacroAnalyzerServer.instance.shutdownMacroServer();
    if (!shutdown) {
      MacroAnalyzerServer.instance.logger.error('Failed to shutdown existing MacroServer');
      exit(-1);
    }

    await Future.delayed(const Duration(seconds: 3));
    await _serveServer(app, throwErr: true);
  }

  // final vmUtils = await VmUtils.create(MacroAnalyzerServer.instance.logger, autoGCPerMin: 15);

  // request current context from dart analysis server
  MacroAnalyzerServer.instance
    // ..vmUtils = vmUtils
    ..requestPluginToConnect()
    ..requestClientToConnect();
}

Future<bool> _serveServer(Router app, {bool throwErr = false}) async {
  try {
    await shelf_io.serve(app.call, 'localhost', 3232);
    return false;
  } catch (e) {
    if (!throwErr && e.toString().contains('already in use')) {
      return true;
    }

    MacroAnalyzerServer.instance.logger.error('Failed to run MacroServer', e);
    exit(-1);
  }
}

Future<Response> _onPing(Request request) async {
  return Response.ok('');
}

void _onNewPluginConnection(WebSocketChannel webSocket) async {
  MacroAnalyzerServer.instance.onPluginConnected(webSocket);
}

void _onNewCodeGeneratorConnection(WebSocketChannel webSocket) async {
  MacroAnalyzerServer.instance.onMacroClientGeneratorConnected(webSocket);
}

Future<Response> _getServerContexts(Request request) async {
  return Response.ok(
    jsonEncode(MacroAnalyzerServer.instance.contexts),
    headers: {
      HttpHeaders.contentTypeHeader: ContentType.json.value,
    },
  );
}

Future<Response> _forceRegenerate(Request request) async {
  final data = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final clientId = (data['clientId'] as num).toInt();
  final context = data['context'] as String;
  final filterOnlyDirectory = data['filterOnlyDirectory'] as bool;
  final addToContext = data['addToContext'] as bool;
  final removeInContext = data['removeInContext'] as bool;

  if (context.isEmpty) {
    return Response.badRequest(
      body: jsonEncode({'status': false, 'error': 'context path required'}),
      headers: {HttpHeaders.contentTypeHeader: ContentType.json.value},
    );
  }

  final errMsg = await MacroAnalyzerServer.instance.forceRegenerateCodeFor(
    clientId: clientId,
    contextPath: context,
    filterOnlyDirectory: filterOnlyDirectory,
    addToContext: addToContext,
    removeInContext: removeInContext,
  );
  if (errMsg != null) {
    return Response.internalServerError(
      body: jsonEncode({'status': false, 'error': 'failed to regenerate: $errMsg'}),
      headers: {HttpHeaders.contentTypeHeader: ContentType.json.value},
    );
  }

  return Response.ok(
    jsonEncode({'status': true}),
    headers: {HttpHeaders.contentTypeHeader: ContentType.json.value},
  );
}

Future<Response> _onShutdown(Request request) async {
  MacroAnalyzerServer.instance.dispose();
  Future.delayed(const Duration(seconds: 2)).then((_) => exit(0));
  return Response.ok('');
}
