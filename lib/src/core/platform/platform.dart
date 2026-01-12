import 'package:watcher/watcher.dart';

import './unknown/platform_stub.dart'
    if (dart.library.io) '././io/platform_io.dart'
    if (dart.library.html) '././web/platform_web.dart'
    if (dart.library.js_interop) '././web/platform_web.dart'
    show WatchFileRequestImpl, currentPlatform;

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

// copied from dart source
final RegExp _absoluteWindowsPathPattern = RegExp(
  r'^(?:\\\\|[a-zA-Z]:[/\\])',
);

// Finds the next-to-last component when dividing at path separators.
final RegExp _parentRegExp = currentPlatform == MacroPlatform.windows
    ? RegExp(r'[^/\\][/\\]+[^/\\]')
    : RegExp(r'[^/]/+[^/]');

String parentPathOf(String path) {
  int rootEnd = -1;
  if (currentPlatform == MacroPlatform.windows) {
    if (path.startsWith(_absoluteWindowsPathPattern)) {
      // Root ends at first / or \ after the first two characters.
      rootEnd = path.indexOf(RegExp(r'[/\\]'), 2);
      if (rootEnd == -1) return path;
    } else if (path.startsWith('\\') || path.startsWith('/')) {
      rootEnd = 0;
    }
  } else if (path.startsWith('/')) {
    rootEnd = 0;
  }
  // Ignore trailing slashes.
  // All non-trivial cases have separators between two non-separators.
  int pos = path.lastIndexOf(_parentRegExp);
  if (pos > rootEnd) {
    return path.substring(0, pos + 1);
  } else if (rootEnd > -1) {
    return path.substring(0, rootEnd + 1);
  } else {
    return '.';
  }
}
