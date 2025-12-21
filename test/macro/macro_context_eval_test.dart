import 'package:hashlib/hashlib.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/utils/spawner.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('parse constant information from macro_context.dart', () {
    test('from arrow syntax success-1', () async {
      const source =
          'bool get autoRunMacro => true;\n'
          "List<String> get autoRunMacroCommand => const ['dart', 'run', 'lib/macro_context.dart'];";

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);

      expect(
        res,
        equals(
          SpawnData(
            data: MacroContextSourceCodeInfo(
              hashId: hashId,
              autoRun: true,
              runCommand: ['dart', 'run', 'lib/macro_context.dart'],
            ),
          ),
        ),
      );
    });

    test('from arrow syntax success-2', () async {
      const source =
          '/// some comment here\n'
          'bool get autoRunMacro => true;\n'
          "List<String> get autoRunMacroCommand => const [];";

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);

      expect(
        res,
        equals(
          SpawnData(
            data: MacroContextSourceCodeInfo(
              hashId: hashId,
              autoRun: true,
              runCommand: [],
            ),
          ),
        ),
      );
    });

    test('from arrow syntax success-3', () async {
      const source =
          'bool get autoRunMacro => false;\n'
          "List<String> get autoRunMacroCommand => const ['dart'];";

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);

      expect(
        res,
        equals(
          SpawnData(
            data: MacroContextSourceCodeInfo(
              hashId: hashId,
              autoRun: false,
              runCommand: ['dart'],
            ),
          ),
        ),
      );
    });

    test('from arrow syntax success-4', () async {
      const source =
          'bool get autoRunMacro => true;\n'
          'List<String> get autoRunMacroCommand => const ["dart"];';

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);

      expect(
        res,
        equals(
          SpawnData(
            data: MacroContextSourceCodeInfo(
              hashId: hashId,
              autoRun: true,
              runCommand: ['dart'],
            ),
          ),
        ),
      );
    });

    test('from arrow syntax success-5', () async {
      const source =
          'bool get autoRunMacro => true;\n'
          "List<String> get autoRunMacroCommand => ['d' + 'a' 'r' + 't'];";

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);

      expect(
        res,
        equals(
          SpawnData(
            data: MacroContextSourceCodeInfo(
              hashId: hashId,
              autoRun: true,
              runCommand: ['dart'],
            ),
          ),
        ),
      );
    });

    test('from block body success-1', () async {
      const source =
          'bool get autoRunMacro { return true; }\n'
          'List<String> get autoRunMacroCommand { return const ["dart"]; }';

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);

      expect(
        res,
        equals(
          SpawnData(
            data: MacroContextSourceCodeInfo(
              hashId: hashId,
              autoRun: true,
              runCommand: ['dart'],
            ),
          ),
        ),
      );
    });

    test('from block body success-2', () async {
      const source =
          'bool get autoRunMacro {\n'
          ' return true;\n'
          '}\n\n'
          'List<String> get autoRunMacroCommand { \n'
          ' return const ["dart"];\n'
          '}';

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);

      expect(
        res,
        equals(
          SpawnData(
            data: MacroContextSourceCodeInfo(
              hashId: hashId,
              autoRun: true,
              runCommand: ['dart'],
            ),
          ),
        ),
      );
    });

    test('from block body success-3', () async {
      const source =
          'bool get autoRunMacro {\n'
          ' return true;\n'
          '}\n\n'
          'List<String> get autoRunMacroCommand { \n'
          ' return const ["dart", \'run\'];\n'
          '}';

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);

      expect(
        res,
        equals(
          SpawnData(
            data: MacroContextSourceCodeInfo(
              hashId: hashId,
              autoRun: true,
              runCommand: ['dart', 'run'],
            ),
          ),
        ),
      );
    });

    test('from block body success-4', () async {
      const source =
          'bool get '
          ' autoRunMacro {\n'
          '       return true;\n'
          '}\n\n'
          'List<String> get'
          ' autoRunMacroCommand { \n'
          '   return const ["dart", \'run\'];\n'
          ' }';

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);

      expect(
        res,
        equals(
          SpawnData(
            data: MacroContextSourceCodeInfo(
              hashId: hashId,
              autoRun: true,
              runCommand: ['dart', 'run'],
            ),
          ),
        ),
      );
    });

    test('from block body success-5', () async {
      const source =
          'bool get '
          ' autoRunMacro {\n'
          '       return true;\n'
          '}\n\n'
          'List<String> get'
          ' autoRunMacroCommand { \n'
          '   return 10 / 2 == 5 ? const ["dart", \'run\'] : const [];\n'
          ' }';

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);

      expect(
        res,
        equals(
          SpawnData(
            data: MacroContextSourceCodeInfo(
              hashId: hashId,
              autoRun: true,
              runCommand: ['dart', 'run'],
            ),
          ),
        ),
      );
    });

    test('from block body success-7', () async {
      const source = r'''

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
List<String> get autoRunMacroCommand => const ['dart', 'run', 'lib/macro_context.dart'];

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
    package: PackageInfo('macro_flutter'),
    autoRunMacro: autoRunMacro,
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
      // 'JsonSchemaMacro': JsonSchemaMacro.initialize,
      // 'FormMacro': FormMacro.initialize,
      'AssetPathMacro': AssetPathMacro.initialize,
    },
    assetMacros: {
      'assets': [
        AssetMacroInfo(
          macroName: 'AssetPathMacro',
          extension: '*',
          output: 'lib',
          config: const AssetPathConfig().toJson(),
        ),
      ],
    },
  );
}

      
      ''';

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);

      expect(
        res,
        equals(
          SpawnData(
            data: MacroContextSourceCodeInfo(
              hashId: hashId,
              autoRun: true,
              runCommand: ['dart', 'run', 'lib/macro_context.dart'],
            ),
          ),
        ),
      );
    });

    test('from block body fails-1', () async {
      const source =
          'bool get '
          ' autoRunMacro {\n'
          '       return true;\n'
          '}\n\n'
          'List<String> get'
          ' autoRunMacroCommand { \n'
          '   return const ["dart"]\n' // missing semicolon
          ' }';

      final hashId = xxh3code(source);
      final res = await MacroContextSourceCodeInfo.fromSource(hashId, source);
      final err = res.toString();

      expect(res, isA<SpawnError<MacroContextSourceCodeInfo>>());
      expect(err, contains('Unable to spawn isolate'));
      expect(err, contains('Error: Expected \';\' after this.\n   return const ["dart"]'));
    });
  });
}
