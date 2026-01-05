import 'dart:io';

import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/common/registered_process.dart';

Future<void> startLogHandler(List<String> args) async {
  final logNames = switch (args[0]) {
    '--log=server' => const ['server.log'],
    '--log=macro' => const ['macro_process.log'],
    '--log=all' => const ['server.log', 'macro_process.log'],
    _ when args[0].startsWith('--log') => const <String>['macro_process.log'],
    _ => const <String>[],
  };
  if (logNames.isEmpty) {
    stderr.writeln('Error: Invalid log type. Usage: --log=server|macro|all');
    exit(-1);
  }

  setupSignalHandler(trackedProcessDir: 'logs');
  await MacroLogger.readStreamingLogs(logNames.map(MacroLogger.getFilePath).toList());
}

const helpUsage = '''
MacroKit

Commands:
  restart-server        Restart the macro server
  restart-analyzer      Restart the macro analysis context

Options:
  --log=server          Stream macro server logs
  --log=macro           Stream macro process logs
  --log=all             Stream all macro-related logs
  --log                 Stream macro process logs (default)

  -h, --help            Show this help message

Behavior:
  • Running without arguments starts the macro server
  • Log streaming reads from the "logs/" directory
''';
