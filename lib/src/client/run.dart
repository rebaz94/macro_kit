import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:macro_kit/src/client/client_manager.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/common/models.dart';
import 'package:macro_kit/src/core/core.dart' show AssetMacroInfo, PackageInfo;

// copied from flutter
const bool _kReleaseMode = bool.fromEnvironment('dart.vm.product');
const bool _kProfileMode = bool.fromEnvironment('dart.vm.profile');
const bool _kDebugMode = !_kReleaseMode && !_kProfileMode;

/// Sets up and manages macro execution with optional asset monitoring.
///
/// This function initializes the macro system, connects to the macro server,
/// and optionally watches asset directories for changes to trigger regeneration.
///
/// Return the client id if successful or null if disabled.
Future<int?> runMacro({
  /// The package name(s) for establishing connection with the MacroPlugin server.
  ///
  /// This should match the `name` field in your `pubspec.yaml`. For most projects,
  /// use `PackageInfo('your_package_name')`. For multi-package setups, use
  /// `PackageInfo.multiple(['pkg1', 'pkg2'])`.
  required PackageInfo package,

  /// Map of macro names to their initialization functions.
  ///
  /// Each key is a unique macro name, and each value is a function that
  /// creates and returns the macro instance.
  ///
  /// Example: `{'DataClass': DataClassMacro.initialize, 'JsonSchema': JsonSchemaMacro.initialize }`
  required Map<String, MacroInitFunction> macros,

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
  /// Default: `http://localhost:3232`
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

  /// Whether the macro system is enabled.
  ///
  /// When `false`, this function returns null immediately without initializing
  /// the macro system.
  ///
  /// Default: `true` in debug mode, `false` in release mode
  bool enabled = _kDebugMode,
}) async {
  if (!enabled) return null;

  final isAndroid = Platform.isAndroid || Platform.isFuchsia;
  final logger = MacroLogger.createLogger(name: 'MacroManager', into: log, level: logLevel);
  final manager = MacroManager(
    logger: logger,
    serverAddress: serverAddress ?? 'http://${isAndroid ? '10.0.2.2' : 'localhost'}:3232',
    packageInfo: package,
    macros: macros,
    assetMacros: assetMacros,
    autoReconnect: autoReconnect,
    generateTimeout: generateTimeout,
  );

  manager.connect();
  return manager.clientId;
}

/// Waits until the macro code regeneration process completes
///
/// This method blocks until the MacroManager finishes rebuilding macro
/// definitions. Use this when you need to ensure macros are fully generated
/// before proceeding with dependent operations.
Future<AutoRebuildResult> waitUntilRebuildCompleted() async {
  return MacroManager.waitUntilRebuildCompleted();
}
