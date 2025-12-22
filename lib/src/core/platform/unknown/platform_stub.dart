import 'package:macro_kit/src/core/platform/platform.dart';
import 'package:watcher/watcher.dart';

@pragma('vm:prefer-inline')
const MacroPlatform currentPlatform = MacroPlatform.web;

@pragma('vm:prefer-inline')
const Map<String, String> platformEnvironment = {};

@pragma('vm:prefer-inline')
Never exit(int code) {
  throw 'Never must be called';
}

@pragma('vm:prefer-inline')
void requestPluginToConnect() {}

/// Watch a directory for specific file
class WatchFileRequestImpl implements WatchFileRequest {
  WatchFileRequestImpl({
    required this.fileName,
    required this.inDirectory,
  });

  final String fileName;
  final String inDirectory;

  @override
  void listen({
    required void Function(ChangeType fileSystemEventType, String data) onChanged,
    void Function(Object? error, StackTrace? stackTrace)? onError,
    void Function()? onClosed,
  }) async {}

  @override
  void close() {}
}
