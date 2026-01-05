import 'dart:io';

import 'package:macro_kit/src/analyzer/log_cli.dart';
import 'package:macro_kit/src/analyzer/macro_server.dart';
import 'package:macro_kit/src/analyzer/server_routes.dart';

void main(List<String> args) async {
  if (args.isNotEmpty) {
    switch (args) {
      case ['--help'] || ['-h']:
        print(helpUsage);
        exit(0);
      case ['restart-server']:
        final shutdown = await MacroAnalyzerServer.shutdownMacroServer();
        exit(shutdown ? 0 : 1);
      case ['restart-analyzer']:
        final shutdown = await MacroAnalyzerServer.restartMacroAnalyzer();
        exit(shutdown ? 0 : 1);
      default:
        return await startLogHandler(args);
    }
  }

  startMacroServer();
}
