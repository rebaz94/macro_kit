import 'dart:async';

import 'package:logging/logging.dart';
import 'package:macro_kit/src/client/client_manager.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/common/models.dart';
import 'package:macro_kit/src/core/core.dart' show AssetMacroInfo, PackageInfo;
import 'package:macro_kit/src/core/platform/platform.dart';

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

  /// Whether to run automatic macro execution.
  ///
  /// Set this to `false` when debugging macros in your running process to prevent
  /// conflicts from concurrent macro execution.
  ///
  /// **Important:** This value must match the property defined in `macro_context.dart`:
  /// ```dart
  /// // macro_context.dart
  /// bool get autoRunMacro => true;
  /// ```
  ///
  /// **Warning:** Never run macros automatically and manually at the same time,
  /// as they share the same execution context and will interfere with each other.
  required bool autoRunMacro,

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
  if (!enabled) {
    return null;
  }

  if (!currentPlatform.isDesktopPlatform) {
    return null;
  }

  final logger = MacroLogger.createLogger(
    name: 'MacroManager',
    into: log,
    level: logLevel,
  );

  logger.info('Initializing MacroManager');
  final manager = MacroManager(
    logger: logger,
    serverAddress: serverAddress ?? 'http://localhost:3232',
    packageInfo: package,
    macros: macros,
    assetMacros: assetMacros,
    autoReconnect: autoReconnect,
    generateTimeout: generateTimeout,
    autoRunMacro: autoRunMacro,
  );

  manager.connect();
  return manager.connection.clientId;
}

/// Waits until the macro code regeneration process completes
///
/// This method blocks until the MacroManager finishes rebuilding macro
/// definitions. Use this when you need to ensure macros are fully generated
/// before proceeding with dependent operations.
Future<AutoRebuildResult> waitUntilRebuildCompleted() async {
  return MacroManager.waitUntilRebuildCompleted();
}

/// Default command to run the macro runner using Dart VM
///
/// Use this when your macro has no Flutter dependencies. Runs the macro
/// context file directly with the Dart runtime.
///
/// Command: `dart run lib/macro_context.dart`
List<String> get macroDartRunnerCommand {
  return const ['dart', 'run', 'lib/macro_context.dart'];
}

/// Command to run the macro runner using Flutter test runner
///
/// Use this when your macro dependencies include Flutter packages. Runs the
/// macro context file via the Flutter test runner with no timeout, keeping
/// the process alive until terminated by the macro server.
///
/// Requires [keepMacroRunner] to be called after `setupMacro()` in your
/// `macro_context.dart` to prevent the test runner from exiting.
///
/// Command: `flutter test --timeout none lib/macro_context.dart`
List<String> get macroFlutterRunnerCommand {
  return const ['flutter', 'test', '--timeout', 'none', 'lib/macro_context.dart'];
}

/// Keeps the macro runner process alive when launched via test runners
///
/// Use this after `setupMacro()` in your `macro_context.dart` when your macro
/// dependencies include Flutter packages. This allows running macros with
/// `flutter test` or `dart test` commands instead of `dart run`.
///
/// The function detects if the process was started by a test runner and blocks
/// to keep it alive until terminated by the macro server. In normal execution,
/// it completes immediately.
///
/// ## Usage
///
/// ```dart
/// bool get autoRunMacro => true;
///
/// List<String> get autoRunMacroCommand => const ['flutter', 'test', '--timeout', 'none', 'lib/macro_context.dart'];
///
/// void main() async {
///   await setupMacro();
///   await keepMacroRunner(); // Add this line too keep the runner process
/// }
/// ```
Future<void> keepMacroRunner() async {
  if (platformEnvironment.containsKey('FLUTTER_TEST') ||
      Zone.current[const Symbol('test.declarer')] != null ||
      Zone.current[const Symbol('test.openChannelCallback')] != null) {
    await Future.delayed(const Duration(days: 33));
  }
}
