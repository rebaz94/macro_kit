import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:macro_kit/macro_kit.dart';

// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;

/// The compiled shader bundle written by [ShaderReloaderMacro].
const _bundleRelativePath = 'build/shaderbundles/flutter_example.shaderbundle';

/// Loads the compiled shader bundle and hot-reloads it whenever the macro
/// server reports that [ShaderReloaderMacro] regenerated the file.
///
/// There is no file watching here: the app is connected to the macro server
/// through `setupMacro()` and receives [onMacroFilesGenerated] push events,
/// then applies the new bytes with `ShaderLibrary.reinitializeFromBytes`.
final class CubeShaderController {
  CubeShaderController._(this.library);

  final gpu.ShaderLibrary library;

  StreamSubscription<List<String>>? _filesGeneratedSub;
  Timer? _debounceTimer;
  bool _reinitializing = false;
  bool _reloadAgain = false;
  VoidCallback? _onReload;

  static Future<CubeShaderController> load() async {
    final file = _bundleFile();
    if (!file.existsSync()) {
      throw StateError(
        'Missing $_bundleRelativePath. Save any file in shaders/ to trigger '
        'ShaderReloaderMacro, then try again.',
      );
    }
    final bytes = await file.readAsBytes();
    final library = await gpu.ShaderLibrary.fromBytes(ByteData.sublistView(bytes));
    if (library == null) {
      throw StateError('Failed to load $_bundleRelativePath from bytes.');
    }
    return CubeShaderController._(library);
  }

  void startWatching({required VoidCallback onReload}) {
    if (!kDebugMode || _filesGeneratedSub != null) {
      return;
    }

    if (!_bundleFile().existsSync()) {
      debugPrint('Shader reload disabled: $_bundleRelativePath was not found.');
      return;
    }

    _onReload = onReload;
    _filesGeneratedSub = onMacroFilesGenerated.listen(
      _handleFilesGenerated,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Shader event stream error: $error');
      },
    );
    debugPrint('Shader reload waiting for macro events on ${_bundleFile().path}');
  }

  void _handleFilesGenerated(List<String> files) {
    final bundlePath = _bundleFile().absolute.path;
    if (!files.any((file) => p.equals(file, bundlePath))) {
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 150),
      _reloadLatest,
    );
  }

  Future<void> _reloadLatest() async {
    if (_reinitializing) {
      _reloadAgain = true;
      return;
    }

    _reinitializing = true;
    try {
      do {
        _reloadAgain = false;
        await _reloadOnce();
      } while (_reloadAgain);
    } catch (error, stackTrace) {
      debugPrint('Shader reload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _reinitializing = false;
    }
  }

  Future<void> _reloadOnce() async {
    final bytes = await _bundleFile().readAsBytes();
    final error = library.reinitializeFromBytes(ByteData.sublistView(bytes));
    if (error != null) {
      throw StateError(error);
    }
    _onReload?.call();
    debugPrint('Shader reload complete.');
  }

  static File _bundleFile() {
    return File.fromUri(
      Directory.current.uri.resolve(_bundleRelativePath),
    );
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _filesGeneratedSub?.cancel();
  }
}
