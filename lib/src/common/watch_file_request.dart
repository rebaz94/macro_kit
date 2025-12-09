import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

/// Watch a directory for specific file
class WatchFileRequest {
  WatchFileRequest({required this.fileName, required this.inDirectory});

  final String fileName;
  final String inDirectory;
  StreamSubscription<WatchEvent>? _sub;

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

  void close() {
    _sub?.cancel();
    _sub = null;
  }
}
