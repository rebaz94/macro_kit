import 'dart:isolate';

import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/starter.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/plugin/plugin.dart';

void start(List<String> args, SendPort sendPort) {
  final sink = MacroLogger.getFileAppendLogger('plugin.log');
  final logger = MacroLogger.createLogger(name: 'MacroPlugin', into: sink.writeln);
  ServerPluginStarter(MacroPlugin(PhysicalResourceProvider.INSTANCE, logger)).start(sendPort);
}
