import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:path/path.dart' as p;

class MacroContextRule extends AnalysisRule {
  MacroContextRule({
    required this.logger,
    required this.onNewAnalysisContext,
  }) : super(
         name: 'macro_context',
         description:
             'Allows macros to discover and apply contextual information from analysis contexts during code generation',
       );

  final MacroLogger logger;
  final void Function(String) onNewAnalysisContext;

  @override
  DiagnosticCode get diagnosticCode => LintCode(
    'macro_context',
    'macro context',
    uniqueName: 'macro_context',
    correctionMessage: '',
    hasPublishedDocs: false,
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    final visitor = _Visitor(rule: this);
    registry.addCompilationUnit(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor({required this.rule});

  final MacroContextRule rule;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    const macroContextFileName = 'macro_context.dart';

    final element = node.declaredFragment?.element;
    if (element == null) return;

    // Get the file name
    final fileName = element.library.firstFragment.source.shortName;

    // Check if this is macro file or not
    if (fileName != macroContextFileName) return;

    // Get the full file path
    final filePath = element.library.firstFragment.source.fullName;
    final file = File(filePath);

    if (p.basenameWithoutExtension(file.parent.path) != 'lib') {
      // Must be in lib folder
      return;
    }

    // Find the project root
    final contextRoot = _findProjectRoot(file);
    if (contextRoot == null) {
      rule.logger.warn('project root not found');
      rule.reportAtOffset(
        0,
        0,
        arguments: ['Could not find pubspec.yaml for macro_context.dart'],
      );
      return;
    }

    try {
      if (file.lengthSync() == 0) {
        file.writeAsStringSync(defaultContextFileConfiguration);
      }
    } catch (_) {}

    rule.onNewAnalysisContext(contextRoot);
  }

  String? _findProjectRoot(File file) {
    const maxLevels = 3;
    var directory = file.parent;
    var levelsChecked = 0;

    // Traverse up the directory tree looking for pubspec.yaml
    while (levelsChecked < maxLevels) {
      var pubspecPath = p.join(directory.path, 'pubspec.yaml');

      if (File(pubspecPath).existsSync()) {
        return directory.path;
      }

      // Move to parent directory & Check if we've reached the filesystem root
      final parent = directory.parent;
      if (parent.path == directory.path) {
        return null;
      }

      directory = parent;
      levelsChecked++;
    }

    return null;
  }
}

const defaultContextFileConfiguration = '''import 'dart:async';

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
bool get autoRunMacro => true;

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
List<String> get autoRunMacroCommand => macroDartRunnerCommand;

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
    // TODO: Update to match your package name from pubspec.yaml
    package: PackageInfo('my_package_name'),
    autoRunMacro: autoRunMacro,
    enabled: true,
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
    },
  );
}
''';
