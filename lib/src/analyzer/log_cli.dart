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
