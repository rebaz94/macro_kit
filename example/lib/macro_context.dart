import 'dart:async';

import 'package:macro_kit/macro_kit.dart';

/// Controls automatic macro execution behavior.
///
/// When `true`, macros run automatically in a separate process during development.
/// When `false`, macros must be triggered manually from your application.
///
/// **When to set to `false`:**
/// - Debugging macro code generation logic
/// - Need manual control over when macros execute
/// - Testing macro behavior in specific scenarios
///
/// **Warning:** Never run macros automatically AND manually at the same time.
/// They share the same execution context and will conflict with each other.
///
/// **Important:** Only change the value (`true`/`false`).
/// Do not modify the getter signature.
bool get autoRunMacro => true;

/// Defines the command used to launch macros in a separate process.
///
/// **Default command:**
/// ```bash
/// dart run lib/macro_context.dart
/// ```
///
/// // Use different Dart SDK or environment
/// ```dart
/// List<String> get autoRunMacroCommand => const [
///   'dart', 'run', 'lib/macro_context.dart', '--env=dev', '--enable-asserts'
/// ];
/// ```
///
/// **Important:** Only update the command list.
/// Do not modify the getter signature.
List<String> get autoRunMacroCommand => macroDartRunnerCommand;

/// Entry point for automatic macro execution.
///
/// This function is called by the macro system when [autoRunMacro] is `true`.
/// It runs in a separate process to generate code without required your application to run.
///
/// **Do not modify or remove this function.**
void main() async {
  await setupMacro();
}

/// Configures and initializes all macros for your project.
///
/// This function serves two purposes depending on [autoRunMacro]:
///
/// **When [autoRunMacro] is `true` (default):**
/// - The macro system automatically runs this in a **separate process**
/// - Code generation happens automatically in the background
/// - If you call this from your app's `main.dart`, it **only listens** to messages
///   from the macro server (doesn't generate code, avoids conflicts)
///
/// **When [autoRunMacro] is `false`:**
/// - The macro system does NOT run this automatically
/// - You **must** call this from your app's `main.dart` to generate code
/// - Code generation happens **inside your running application** during development
/// - Useful for debugging macro logic with breakpoints and logging
///
/// **Example usage in your `main.dart`:**
/// ```dart
/// import 'macro_context.dart' as macro;
///
/// void main() async {
///   await macro.setupMacro();
///   runApp(MyApp());
/// }
/// ```
///
/// **What this does:**
/// - If `autoRunMacro = true`: Only listens to macro server messages (safe, no side effects)
/// - If `autoRunMacro = false`: Generates code in your app process (required for generation)
Future<void> setupMacro() async {
  await runMacro(
    package: PackageInfo('example'),
    autoRunMacro: autoRunMacro,
    enabled: true,
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
    },
  );
}
