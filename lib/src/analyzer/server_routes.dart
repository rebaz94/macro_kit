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
    ..post('/shutdown', _onShutdown);

  await _serveServer(app, throwErr: true);

  // request current context from dart analysis server
  MacroAnalyzerServer.instance
    ..requestPluginToConnect()
    ..requestClientToConnect();

  MacroAnalyzerServer.instance.logger.info('MacroServer started');
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
    jsonEncode(MacroAnalyzerServer.instance.contexts.map((e) => e.path).toList()),
    headers: {
      HttpHeaders.contentTypeHeader: ContentType.json.value,
    },
  );
}

Future<Response> _onShutdown(Request request) async {
  MacroAnalyzerServer.instance.dispose();
  Future.delayed(const Duration(seconds: 2)).then((_) => exit(0));
  return Response.ok('');
}
