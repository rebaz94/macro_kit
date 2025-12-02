import 'dart:io';

import 'package:logging/logging.dart';
import 'package:macro_kit/src/analyzer/logger.dart';
import 'package:macro_kit/src/client/client_manager.dart';
import 'package:macro_kit/src/core/core.dart';

// copied from flutter
const bool _kReleaseMode = bool.fromEnvironment('dart.vm.product');
const bool _kProfileMode = bool.fromEnvironment('dart.vm.profile');
const bool _kDebugMode = !_kReleaseMode && !_kProfileMode;

/// Sets up and manages macro execution with optional asset monitoring.
///
/// This function initializes the macro system, connects to the macro server,
/// and optionally watches asset directories for changes to trigger regeneration.
///
/// Returns immediately if disabled.
Future<void> runMacro({
  /// Map of macro names to their initialization functions.
  ///
  /// Each key is a unique macro name, and each value is a function that
  /// creates and returns the macro instance.
  ///
  /// Example: `{'DataClass': DataClassMacro.initialize, 'JsonSchema': JsonSchemaMacro.initialize }`
  required Map<String, MacroInitFunction> macros,

  /// Logging verbosity level.
  ///
  /// Controls how much information is logged during macro execution.
  ///
  /// Default: [Level.INFO]
  Level logLevel = Level.INFO,

  /// Custom logging function.
  ///
  /// If provided, this function will be called for all log messages instead of
  /// using the default logging mechanism.
  ///
  /// Example: `log: (value) => print('Macro: $value')`
  void Function(Object? value)? log,

  /// Macro server WebSocket address.
  ///
  /// The address where the macro server is running. The macro client will
  /// connect to this server to receive analysis updates and send generated code.
  ///
  /// Default: `'http://localhost:3232'`
  String? serverAddress,

  /// Whether to automatically reconnect on connection loss.
  ///
  /// When `true`, the macro client will attempt to reconnect to the server
  /// if the connection is lost.
  ///
  /// Default: `true`
  bool autoReconnect = true,

  /// Maximum time to wait for code generation to complete.
  ///
  /// If generation takes longer than this duration, the operation will timeout.
  ///
  /// Default: 30 seconds
  Duration generateTimeout = const Duration(seconds: 30),

  /// Map of asset directories to their associated macro configurations.
  ///
  /// Each key is an asset directory path (relative to project root) to monitor for changes.
  /// Each value is a list of [AssetMacroInfo] objects that define which macros should process
  /// files from that directory and where to write the generated output.
  ///
  /// When files in these directories are created, modified, or deleted, all macros
  /// configured for that directory will automatically regenerate their output.
  ///
  /// Example:
  /// ```dart
  /// {
  ///   'assets/images': [
  ///     AssetMacroInfo(macroName: 'ResizeImageMacro', output: 'assets/images-gen'),
  ///   ],
  /// }
  /// ```
  Map<String, List<AssetMacroInfo>> assetMacros = const {},

  /// Whether the macro system is enabled.
  ///
  /// When `false`, this function returns null immediately without initializing
  /// the macro system.
  ///
  /// Default: `true` in debug mode, `false` in release mode
  bool enabled = _kDebugMode,
}) async {
  if (!enabled) return;

  final logger = MacroLogger.createLogger(name: 'MacroManager', into: log, level: logLevel);
  final manager = MacroManager(
    logger: logger,
    serverAddress:
        serverAddress ?? (Platform.isAndroid || Platform.isFuchsia ? 'http://10.0.2.2:3232' : 'http://localhost:3232'),
    macros: macros,
    autoReconnect: autoReconnect,
    generateTimeout: generateTimeout,
    assetMacros: assetMacros,
  );

  manager.connect();
}
