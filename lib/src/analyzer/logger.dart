import 'dart:io';

import 'package:logging/logging.dart';

String get homeDir {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '~';
    if (!home.contains('Library/Containers')) {
      return home;
    }

    final user = Platform.environment['USER'];
    return user != null ? '/Users/$user' : home;
  }

  final envKey = Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
  final envValue = Platform.environment[envKey];
  return envValue ?? '~';
}

String get macroDirectory {
  return '$homeDir/.dartServer/.plugin_manager/macro';
}

class MacroLogger {
  MacroLogger._(String name) : logger = Logger.detached(name);

  static IOSink getFileAppendLogger(String fileName) {
    final logFilePath = '$macroDirectory/$fileName';

    final file = File(logFilePath)
      ..createSync(recursive: true)
      ..writeAsStringSync('');

    return file.openWrite(mode: FileMode.append);
  }

  static MacroLogger createLogger({required String name, void Function(Object? obj)? into, Level level = Level.INFO}) {
    final logger = MacroLogger._(name);
    final log = into ?? print;

    logger.logger.level = level;
    logger.logger.onRecord.listen(
      (e) => log(
        '[${e.level.name.padRight(7)}] ${e.loggerName}: ${e.message}'
        '${e.error != null ? ': ${e.error}' : ''}'
        '${e.stackTrace != null ? ' stack: ${e.stackTrace}' : ''}',
      ),
    );
    return logger;
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
}
