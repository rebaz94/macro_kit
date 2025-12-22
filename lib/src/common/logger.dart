import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:macro_kit/src/common/common.dart';
import 'package:macro_kit/src/common/registered_process.dart';
import 'package:path/path.dart' as p;

class MacroLogger {
  MacroLogger._(String name) : logger = Logger.detached(name);

  static IOSink getFileAppendLogger(String fileName) {
    final logFilePath = p.join(macroDirectory, fileName);
    final file = File(logFilePath)
      ..createSync(recursive: true)
      ..writeAsStringSync('');

    return file.openWrite(mode: FileMode.append);
  }

  static String getFilePath(String fileName) {
    final logFilePath = p.join(macroDirectory, fileName);
    final file = File(logFilePath)..createSync(recursive: true);

    return file.path;
  }

  static MacroLogger createLogger({
    required String name,
    void Function(Object? obj)? into,
    Level level = Level.INFO,
    bool rawLog = false,
  }) {
    final logger = MacroLogger._(name);
    final log = into ?? print;

    logger.logger.level = level;
    if (rawLog) {
      logger.logger.onRecord.listen((e) => log(e.message));
    } else {
      logger.logger.onRecord.listen(
        (e) => log(
          '[${e.level.name.padRight(7)}] ${e.loggerName}: ${e.message}'
          '${e.error != null ? ': ${e.error}' : ''}'
          '${e.stackTrace != null ? '\nStack trace: ${e.stackTrace}' : ''}',
        ),
      );
    }
    return logger;
  }

  static Future<void> readStreamingLogs(List<String> paths) async {
    final process = await Future.wait(paths.map(_startWatchingLog));
    await Future.wait(process.map(_readLog));
  }

  static Future<Process> _startWatchingLog(String filePath) async {
    final file = File(filePath)..createSync(recursive: true);

    final Process process;
    if (Platform.isWindows) {
      process = await Process.start(
        'powershell',
        ['-Command', 'Get-Content -Path "${file.path}" -Wait'],
        runInShell: true,
      );
    } else {
      process = await Process.start('tail', ['-f', file.path]);
    }

    registerProcess(process);
    return process;
  }

  static Future<void> _readLog(Process process) async {
    await for (final data in process.stdout.transform(utf8.decoder).transform(LineSplitter())) {
      print(data);
    }
  }

  final Logger logger;

  @pragma('vm:prefer-inline')
  void info(Object? message, [Object? error, StackTrace? stackTrace]) {
    logger.info(message, error, stackTrace);
  }

  @pragma('vm:prefer-inline')
  void fine(Object? message, [Object? error, StackTrace? stackTrace]) {
    logger.fine(message, error, stackTrace);
  }

  @pragma('vm:prefer-inline')
  void warn(Object? message, [Object? error, StackTrace? stackTrace]) {
    logger.warning(message, error, stackTrace);
  }

  @pragma('vm:prefer-inline')
  void error(Object? message, [Object? error, StackTrace? stackTrace]) {
    logger.severe(message, error, stackTrace);
  }

  @pragma('vm:prefer-inline')
  void log(Level level, Object? message, [Object? error, StackTrace? stackTrace]) {
    logger.log(level, message, error, stackTrace);
  }
}
