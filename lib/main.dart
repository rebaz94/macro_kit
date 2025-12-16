import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/plugin/plugin.dart';

final sink = MacroLogger.getFileAppendLogger('plugin.log');
final logger = MacroLogger.createLogger(name: 'MacroPlugin', into: sink.writeln);
final plugin = MacroPlugin(logger: logger);
