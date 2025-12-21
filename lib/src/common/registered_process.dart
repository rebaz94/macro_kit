import 'dart:async';
import 'dart:io';

import 'package:macro_kit/src/analyzer/utils/lock.dart';
import 'package:macro_kit/src/common/common.dart';
import 'package:path/path.dart' as p;

enum SignalType { any, sigint, sigterm, sighup }

final _processRegistry = <Process>[];
final _signalHandler = <(SignalType, FutureOr Function())>[];
var _trackedProcessDir = 'all';
bool _setupSignal = false;

/// register a process to be automatically killed if server closing
///
/// if [trackDetached] is true, it store the pid so that for any reason(force close)
/// server not have a change to clean the process, the next starting server wll automatically close it
void registerProcess(Process process, {bool trackDetached = true}) {
  _processRegistry.add(process);
  if (trackDetached) {
    _trackProcessPid(process.pid);
  }
}

void removeProcess(Process process) {
  _processRegistry.remove(process);
  _removeTrackedProcessPid(process.pid);
}

void _trackProcessPid(int id) {
  try {
    final file = File(p.join(macroDirectory, '.process', _trackedProcessDir, 'p_$id'));
    file.createSync(recursive: true);
  } catch (e) {
    print('Failed to track process id: $id, details: $e');
  }
}

void _removeTrackedProcessPid(int id) {
  try {
    final file = File(p.join(macroDirectory, '.process', _trackedProcessDir, 'p_$id'));
    file.deleteSync();
  } catch (e) {
    print('Failed to remove tracked process id: $id, details: $e');
  }
}

void _removeStaleProcess() {
  try {
    final dir = Directory(p.join(macroDirectory, '.process', _trackedProcessDir))..createSync(recursive: true);
    for (final entity in dir.listSync(recursive: false, followLinks: false)) {
      if (entity is File) {
        final basename = p.basename(entity.path);
        if (!basename.startsWith('p_')) continue;

        final pid = int.tryParse(basename.substring(2));
        if (pid == null) continue;

        entity.deleteSync();
        Process.killPid(pid);
      }
    }
  } catch (e) {
    print('Failed to removed staled process, details: $e');
  }
}

/// Setup and watch process signal
///
/// it should only be called when application start
void setupSignalHandler({String? trackedProcessDir}) {
  if (_setupSignal) {
    throw StateError('setupSignalHandler must be only called once from entire application process');
  }

  _setupSignal = true;
  _trackedProcessDir = trackedProcessDir ?? '';
  final lock = CustomBasicLock();
  void handleCallback(SignalType type) async {
    lock.synchronized(
      () async {
        if (_processRegistry.isNotEmpty) {
          print('cleaning up process');
          for (var p in _processRegistry) {
            p.kill();
            _removeTrackedProcessPid(p.pid);
          }
          _processRegistry.clear();
        }

        final toRemove = <(SignalType, FutureOr)>[];
        for (final handler in _signalHandler) {
          if (handler.$1 != type && handler.$1 != SignalType.any) continue;

          toRemove.add(handler);
          await handler.$2();
        }

        for (final removed in toRemove) {
          _signalHandler.remove(removed);
        }

        // nothing remains, call exit
        if (_signalHandler.isEmpty) {
          exit(0);
        }
      },
    );
  }

  _removeStaleProcess();
  ProcessSignal.sigint.watch().listen((_) => handleCallback(SignalType.sigint));
  ProcessSignal.sigterm.watch().listen((_) => handleCallback(SignalType.sigterm));
  ProcessSignal.sighup.watch().listen((_) => handleCallback(SignalType.sighup));
}

void trackSignalHandler(SignalType type, FutureOr Function() future) {
  _signalHandler.add((type, future));
}
