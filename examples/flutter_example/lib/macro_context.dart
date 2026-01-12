import 'dart:async';

import 'package:flutter_example/example_macro/form_macro.dart';
import 'package:flutter_example/example_macro/json_schema_macro.dart';
import 'package:flutter_example/example_macro/record_macro.dart';
import 'package:flutter_example/example_macro/timed_macro.dart';
import 'package:macro_kit/macro_kit.dart';

/// Controls automatic macro execution behavior.
///
/// When `true` (default): Macros run automatically in a separate background process.
/// When `false`: You must call [setupMacro] from your app to run macros manually.
///
/// **When to set to `false`:**
/// - Debugging macro code generation with breakpoints
/// - Need precise control over macro execution timing
/// - Testing macro behavior in specific scenarios
///
/// **Critical Warning:**
/// Never run macros both automatically AND manually simultaneously.
/// They share the same execution context and will conflict, causing unpredictable behavior.
///
/// **Important:** Only change the value (`true`/`false`).
/// Do not modify the getter name or signature.
bool get autoRunMacro => false;

/// Defines the command used to launch macros in a separate process.
///
/// **Default command:**
/// ```bash
/// dart run lib/macro_context.dart
/// ```
///
/// **Customization examples:**
///
/// For macros with custom arguments:
/// ```dart
/// List<String> get autoRunMacroCommand => [
///   'dart', 'run', 'lib/macro_context.dart', '--env=dev', '--enable-asserts',
/// ];
/// ```
///
/// **Available presets:**
/// * `macroDartRunnerCommand` - For pure Dart macros (no Flutter dependencies)
/// * `macroFlutterRunnerCommand` - For macros that depend on Flutter SDK
///
/// **Important:** Only update the command list.
/// Do not modify the getter name or signature.
List<String> get autoRunMacroCommand => macroFlutterRunnerCommand;

/// Entry point for automatic macro execution.
///
/// This function is automatically invoked by the macro system when [autoRunMacro] is `true`.
/// It runs in a separate background process to generate code without requiring your app to run.
///
/// **Do not call, modify, or remove this function.**
/// The macro system handles this automatically.
void main() async {
  await setupMacro();
  await keepMacroRunner();
}

/// Configures and initializes all macros for your project.
///
/// **Behavior depends on [autoRunMacro] setting:**
///
/// ## When `autoRunMacro = true` (default, recommended):
/// - Macro system runs this automatically in a **separate background process**
/// - Code generation happens automatically during development
/// - If you call this from your app's `main()` (desktop only - ignored on mobile/web),
///   it only **listens** to messages sent by the macro server without generating code to avoid conflicts
/// - No action needed in your app code
///
/// ## When `autoRunMacro = false` (manual mode):
/// - Macro system does NOT run automatically
/// - You **must** call this from your app's `main()` to trigger code generation
/// - Code generation runs **inside your application process** (desktop only -
///   no-op on mobile/web)
/// - Useful for debugging macro logic with breakpoints
///
/// **Example: Manual mode setup in `main.dart`**
/// ```dart
/// import 'macro_context.dart' as macro;
///
/// void main() async {
///   // Only needed when autoRunMacro = false
///   await macro.setupMacro();
///   runApp(MyApp());
/// }
/// ```
Future<void> setupMacro() async {
  await runMacro(
    package: PackageInfo('flutter_example'),
    autoRunMacro: autoRunMacro,
    enabled: true,
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
      'AssetPathMacro': AssetPathMacro.initialize,
      'JsonSchemaMacro': JsonSchemaMacro.initialize,
      'FormMacro': FormMacro.initialize,
      'TimedMacro': TimedMacro.initialize,
      'RecordMacro': RecordMacro.initialize,
      'EmbedMacro': EmbedMacro.initialize,
    },
    assetMacros: {
      'assets': [
        AssetMacroInfo(
          macroName: 'AssetPathMacro',
          output: 'lib',
          config: AssetPathConfig().toJson(),
        ),
        AssetMacroInfo(
          macroName: 'EmbedMacro',
          output: 'lib/embed',
          config: EmbedMacroConfig(extension: '.jpg,.txt,.svg').toJson(),
        ),
      ],
    },
  );
}
