import 'dart:async';
import 'dart:io';

import 'package:macro_kit/src/common/common.dart';
import 'package:macro_kit/src/core/platform/platform.dart' show MacroPlatform, WatchFileRequest;
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

export 'dart:io' show exit;

@pragma('vm:prefer-inline')
MacroPlatform currentPlatform = Platform.isMacOS
    ? MacroPlatform.macos
    : Platform.isWindows
    ? MacroPlatform.windows
    : Platform.isLinux
    ? MacroPlatform.linux
    : Platform.isFuchsia
    ? MacroPlatform.fuchsia
    : Platform.isIOS
    ? MacroPlatform.ios
    : Platform.isAndroid
    ? MacroPlatform.android
    : MacroPlatform.macos;

@pragma('vm:prefer-inline')
Map<String, String> platformEnvironment = Platform.environment;

@pragma('vm:prefer-inline')
void requestPluginToConnect() {
  if (currentPlatform.isDesktopPlatform) {
    File(p.join(macroDirectory, macroPluginRequestFileName))
      ..createSync(recursive: true)
      ..writeAsStringSync('${DateTime.now().microsecondsSinceEpoch}:reconnect');
  }
}

/// Watch a directory for specific file
class WatchFileRequestImpl implements WatchFileRequest {
  WatchFileRequestImpl({
    required this.fileName,
    required this.inDirectory,
  });

  final String fileName;
  final String inDirectory;
  StreamSubscription<WatchEvent>? _sub;

  @override
  void listen({
    required void Function(ChangeType fileSystemEventType, String data) onChanged,
    void Function(Object? error, StackTrace? stackTrace)? onError,
    void Function()? onClosed,
  }) async {
    final file = File(p.join(inDirectory, fileName));
    final watcher = Watcher(inDirectory);

    _sub = watcher.events.listen(
      (event) {
        if (event.path != file.path) return;

        switch (event.type) {
          case ChangeType.ADD:
          case ChangeType.MODIFY:
            final content = file.readAsStringSync();
            onChanged(event.type, content);
        }
      },
      onDone: onClosed,
      onError: onError,
    );
  }

  @override
  void close() {
    _sub?.cancel();
    _sub = null;
  }
}
