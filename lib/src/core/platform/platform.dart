import 'package:watcher/watcher.dart';

import './unknown/platform_stub.dart'
    if (dart.library.io) '././io/platform_io.dart'
    if (dart.library.html) '././web/platform_web.dart'
    if (dart.library.js_interop) '././web/platform_web.dart'
    show WatchFileRequestImpl;

export './unknown/platform_stub.dart'
    if (dart.library.io) '././io/platform_io.dart'
    if (dart.library.html) '././web/platform_web.dart'
    if (dart.library.js_interop) '././web/platform_web.dart';

enum MacroPlatform {
  macos,
  windows,
  linux,
  fuchsia,
  ios,
  android,
  web;

  bool get isDesktopPlatform => switch (this) {
    MacroPlatform.macos || MacroPlatform.windows || MacroPlatform.linux => true,
    _ => false,
  };
}

abstract class WatchFileRequest {
  factory WatchFileRequest({
    required String fileName,
    required String inDirectory,
  }) = WatchFileRequestImpl;

  void listen({
    required void Function(ChangeType fileSystemEventType, String data) onChanged,
    void Function(Object? error, StackTrace? stackTrace)? onError,
    void Function()? onClosed,
  });

  void close();
}
