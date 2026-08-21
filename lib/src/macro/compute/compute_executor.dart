import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:macro_kit/src/analyzer/utils/hash.dart';
import 'package:macro_kit/src/analyzer/utils/spawner.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/macro/compute/dart_code.dart';
import 'package:path/path.dart' as p;

/// Strategy for executing compute macro bodies.
enum ComputeStrategy {
  /// Pure Dart isolate via Isolate.spawnUri.
  /// Only works with pure Dart code, no Flutter imports.
  isolate,

  /// Dart VM via Process.start(['dart', 'run', tempFile]).
  dartRun,

  /// Flutter test runner via Process.start(['flutter', 'test', ...]).
  /// Handles Flutter-dependent code.
  flutterTest,
}

/// Result of executing a compute body
class ComputeResult {
  const ComputeResult({
    required this.dartLiteral,
    this.error,
  });

  /// The pre-serialized Dart literal string (e.g., `'1.0.0'` or `{'key': 'value'}`)
  final String dartLiteral;

  /// Error message if execution failed
  final String? error;

  bool get isSuccess => error == null;
}

/// Executes compute macro bodies and returns Dart literal strings.
///
/// This class handles:
/// 1. Copying the original source file to a temp file in the same directory
/// 2. Appending a main() entrypoint that calls each compute variable
/// 3. Executing the temp file via isolate or Process.start
/// 4. Parsing the JSON result protocol
/// 5. Serializing results to Dart literal strings
/// 6. Cleaning up temp files
class ComputeExecutor {
  ComputeExecutor._();

  static const _isolateComment = '// --macro-use-isolate-computer';
  static const _flutterComment = '// --macro-use-flutter-computer';
  static const _dartComment = '// --macro-use-dart-computer';

  /// Execute multiple compute bodies and return results.
  ///
  /// [sourceFilePath] is the path to the original source file.
  /// [computeBodies] maps variableName to the compute body info.
  /// [defaultStrategy] is the project-level default (from macro server context).
  static Future<Map<String, ComputeResult>> executeAll({
    required String sourceFilePath,
    required Map<String, ComputeBodyInfo> computeBodies,
    required ComputeStrategy defaultStrategy,
  }) async {
    if (computeBodies.isEmpty) return {};

    // Detect strategy from source file comments
    final strategy = _detectStrategy(sourceFilePath) ?? defaultStrategy;

    // Generate executable temp file
    final tempFile = _createTempSourceFile(
      sourceFilePath: sourceFilePath,
      computeBodies: computeBodies,
      strategy: strategy,
    );

    if (tempFile == null) {
      final results = <String, ComputeResult>{};
      for (final entry in computeBodies.entries) {
        results[entry.key] = const ComputeResult(
          dartLiteral: '',
          error: 'Failed to generate executable code',
        );
      }
      return results;
    }

    try {
      final results = switch (strategy) {
        ComputeStrategy.isolate => await _executeViaIsolate(tempFile, computeBodies),
        ComputeStrategy.dartRun => await _executeViaProcess(
          'dart',
          ['run', tempFile.path],
          tempFile,
          computeBodies,
        ),
        ComputeStrategy.flutterTest => await _executeViaProcess(
          'flutter',
          ['test', '--timeout', 'none', '--ignore-timeouts', tempFile.path],
          tempFile,
          computeBodies,
        ),
      };
      return results;
    } finally {
      try {
        // tempFile.deleteSync();
      } catch (_) {}
    }
  }

  /// Execute a single compute body and return the Dart literal string.
  static Future<ComputeResult> execute({
    required String sourceFilePath,
    required String computeBodySource,
    required String variableName,
    required ComputeStrategy defaultStrategy,
  }) async {
    final results = await executeAll(
      sourceFilePath: sourceFilePath,
      computeBodies: {
        variableName: ComputeBodyInfo(body: computeBodySource),
      },
      defaultStrategy: defaultStrategy,
    );

    return results[variableName] ?? const ComputeResult(dartLiteral: '', error: 'No result returned');
  }

  /// Detect compute strategy from inline comments in the source file.
  /// Returns null if no directive found (use default).
  /// Uses openSync and reads only the first 1KB to avoid loading the full file.
  static ComputeStrategy? _detectStrategy(String sourceFilePath) {
    try {
      final file = File(sourceFilePath);
      if (!file.existsSync()) return null;

      final raf = file.openSync(mode: FileMode.read);
      try {
        // Read only first 64 bytes — enough for directive comments at top of file
        final bytes = raf.readSync(64);
        final content = utf8.decode(bytes, allowMalformed: true);
        final lines = content.split('\n');

        for (var i = 0; i < lines.length; i++) {
          final trimmed = lines[i].trim();
          if (trimmed == _isolateComment) return ComputeStrategy.isolate;
          if (trimmed == _flutterComment) return ComputeStrategy.flutterTest;
          if (trimmed == _dartComment) return ComputeStrategy.dartRun;
        }
      } finally {
        raf.closeSync();
      }
    } catch (_) {}
    return null;
  }

  /// Execute temp file via Isolate.spawnUri (pure Dart only).
  static Future<Map<String, ComputeResult>> _executeViaIsolate(
    File tempFile,
    Map<String, ComputeBodyInfo> computeBodies,
  ) async {
    final results = <String, ComputeResult>{};

    final result = await Spawner.evaluateCode<Map>(
      codeUri: tempFile.uri,
      onData: (data) {
        if (data is! Map) {
          throw 'Expected Map result but got: ${data.runtimeType}';
        }
        return data;
      },
      debugName: 'ComputeMacro_batch',
    );

    switch (result) {
      case SpawnData<Map>():
        final data = result.data;
        final type = data['type'] as String?;

        if (type == 'error') {
          final error = data['message'] as String? ?? 'Unknown error';
          for (final entry in computeBodies.entries) {
            results[entry.key] = ComputeResult(dartLiteral: '', error: error);
          }
        } else if (type == 'value') {
          final batchResults = data['data'] as Map<String, dynamic>? ?? {};
          for (final entry in computeBodies.entries) {
            final varResult = batchResults[entry.key];
            if (varResult is Map && varResult.containsKey('error')) {
              results[entry.key] = ComputeResult(
                dartLiteral: '',
                error: varResult['error'] as String,
              );
            } else {
              // Decode DartCodeResult from isolate and serialize to literal
              final decoded = decodeComputeResult(varResult);
              results[entry.key] = ComputeResult(
                dartLiteral: serializeComputeResult(decoded),
              );
            }
          }
        }

      case SpawnError<Map>():
        final error = 'Execution failed: ${result.error}';
        for (final entry in computeBodies.entries) {
          results[entry.key] = ComputeResult(dartLiteral: '', error: error);
        }
    }

    return results;
  }

  /// Execute temp file via Process.start (dart run or flutter test).
  /// Uses a result temp file instead of stdout to avoid pollution from flutter test output.
  static Future<Map<String, ComputeResult>> _executeViaProcess(
    String executable,
    List<String> arguments,
    File tempFile,
    Map<String, ComputeBodyInfo> computeBodies,
  ) async {
    final results = <String, ComputeResult>{};
    final resultFile = File('${tempFile.path}.result');

    try {
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory: p.dirname(tempFile.path),
        environment: const {'managed_by_macro_server': 'true'},
      );

      // Drain stderr to prevent blocking, log on failure
      // final stdoutFuture = await process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      final stderr = await stderrFuture;

      // code 79: no test found
      if (exitCode != 0 && exitCode != 79) {
        final error = 'Process exited with code $exitCode: $stderr';
        for (final entry in computeBodies.entries) {
          results[entry.key] = ComputeResult(dartLiteral: '', error: error);
        }
        return results;
      }

      // Read result from temp file
      if (!resultFile.existsSync()) {
        for (final entry in computeBodies.entries) {
          results[entry.key] = const ComputeResult(
            dartLiteral: '',
            error: 'No result file produced by process',
          );
        }
        return results;
      }

      final jsonContent = resultFile.readAsStringSync();
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'error') {
        final error = data['message'] as String? ?? 'Unknown error';
        for (final entry in computeBodies.entries) {
          results[entry.key] = ComputeResult(dartLiteral: '', error: error);
        }
      } else if (type == 'value') {
        final batchResults = data['data'] as Map<String, dynamic>? ?? {};
        for (final entry in computeBodies.entries) {
          final varResult = batchResults[entry.key];
          if (varResult is String && varResult.startsWith('Error:')) {
            results[entry.key] = ComputeResult(
              dartLiteral: '',
              error: varResult,
            );
          } else if (varResult is Map && varResult.containsKey('__dartCode__')) {
            // DartCode result from temp file
            results[entry.key] = ComputeResult(
              dartLiteral: varResult['__dartCode__'] as String,
            );
          } else if (entry.value.encode != null) {
            // encode/decode was used — result is already a Dart literal from decode
            results[entry.key] = ComputeResult(
              dartLiteral: varResult?.toString() ?? 'null',
            );
          } else {
            // No encode — result is a raw runtime value, serialize to Dart literal
            results[entry.key] = ComputeResult(
              dartLiteral: MacroProperty.toLiteralValue(varResult),
            );
          }
        }
      }
    } catch (e) {
      for (final entry in computeBodies.entries) {
        results[entry.key] = ComputeResult(dartLiteral: '', error: e.toString());
      }
    } finally {
      try {
        resultFile.deleteSync();
      } catch (_) {}
    }

    return results;
  }

  /// Create a temp source file by copying the original file content,
  /// commenting out part directives, and appending a main() entrypoint.
  static File? _createTempSourceFile({
    required String sourceFilePath,
    required Map<String, ComputeBodyInfo> computeBodies,
    required ComputeStrategy strategy,
  }) {
    try {
      final sourceFile = File(sourceFilePath);
      if (!sourceFile.existsSync()) return null;

      final sourceContent = sourceFile.readAsStringSync();
      final sourceDir = p.dirname(sourceFilePath);
      final baseName = p.basenameWithoutExtension(sourceFilePath);

      // Deterministic temp file name based on original file name hash
      final fileHash = generateHash(p.basename(sourceFilePath));
      final tempFile = File(
        p.join(sourceDir, '${baseName}_$fileHash.g.dart'),
      );
      final resultFilePath = p.join(sourceDir, '${baseName}_compute_$fileHash.g.dart.result');

      final buf = StringBuffer();
      final lines = sourceContent.split('\n');

      // Add required imports at the top
      buf.writeln("import 'dart:convert';");
      buf.writeln("import 'dart:io';");
      buf.writeln("import 'dart:async';");
      buf.writeln("import 'dart:isolate';");

      // Copy original file content, commenting out part directives
      // and removing any existing main() to avoid conflicts with generated main
      bool skipMain = false;
      int braceDepth = 0;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith("part '") || trimmed.startsWith('part "')) {
          buf.writeln('// $line');
          continue;
        }
        if (!skipMain && RegExp(r'^void\s+main\s*\(').hasMatch(trimmed)) {
          skipMain = true;
          braceDepth = 0;
        }
        if (skipMain) {
          for (final ch in trimmed.runes) {
            if (ch == 0x7B) braceDepth++; // {
            if (ch == 0x7D) braceDepth--; // }
          }
          if (braceDepth <= 0) {
            skipMain = false;
          }
          continue;
        }
        buf.writeln(line);
      }

      // Append the main() entrypoint
      buf.writeln();
      if (strategy == ComputeStrategy.isolate) {
        _writeIsolateMain(buf, computeBodies);
      } else {
        _writeProcessMain(buf, computeBodies, resultFilePath);
      }

      tempFile.writeAsStringSync(buf.toString());
      return tempFile;
    } catch (e) {
      return null;
    }
  }

  /// Write main() for isolate execution (uses SendPort).
  /// Flow: compute body → encode(raw) [if provided] → decode(encoded) [if provided] → send
  static void _writeIsolateMain(
    StringBuffer buf,
    Map<String, ComputeBodyInfo> computeBodies,
  ) {
    buf.writeln('dynamic _processResult<T>(T raw, [String Function(T)? enc, String Function(String)? dec]) {');
    buf.writeln('  if (raw case DartCode raw) return {\'__dartCode__\': raw.code};');
    buf.writeln('  final String encoded = enc != null ? enc(raw).toString() : raw.toString();');
    buf.writeln('  return dec != null ? dec(encoded) : encoded;');
    buf.writeln('}');
    buf.writeln();
    buf.writeln('void main(List<String> _, SendPort port) async {');
    buf.writeln('  try {');
    buf.writeln('    final results = <String, dynamic>{};');
    for (final entry in computeBodies.entries) {
      final variableName = entry.key;
      final encode = entry.value.encode;
      final decode = entry.value.decode;
      final args = <String>[
        'await $variableName.call()',
        if (decode != null || encode != null) encode ?? 'null',
        ?decode,
      ];
      buf.writeln('    results[\'$variableName\'] = _processResult(${args.join(', ')});');
    }
    buf.writeln('    port.send({\'type\': \'value\', \'data\': results});');
    buf.writeln('  } catch (e, s) {');
    buf.writeln('    port.send({\'type\': \'error\', \'message\': e.toString(), \'stackTrace\': s.toString()});');
    buf.writeln('  }');
    buf.writeln('}');
  }

  /// Write main() for Process.start execution (writes result to temp file).
  /// Flow: compute body → encode(raw) [if provided] → decode(encoded) [if provided] → write
  static void _writeProcessMain(
    StringBuffer buf,
    Map<String, ComputeBodyInfo> computeBodies,
    String resultFilePath,
  ) {
    buf.writeln('dynamic _processResult<T>(T raw, [String Function(T)? enc, String Function(String)? dec]) {');
    buf.writeln('  if (raw case DartCode raw) return {\'__dartCode__\': raw.code};');
    buf.writeln('  if (enc == null && dec == null) return raw;');
    buf.writeln('  final String encoded = enc != null ? enc(raw).toString() : raw.toString();');
    buf.writeln('  return dec != null ? dec(encoded) : encoded;');
    buf.writeln('}');
    buf.writeln();
    buf.writeln('void main() async {');
    buf.writeln("  final resultFile = File('$resultFilePath')..createSync(recursive: true);");
    buf.writeln('  try {');
    buf.writeln('    final results = <String, dynamic>{};');
    for (final entry in computeBodies.entries) {
      final variableName = entry.key;
      final encode = entry.value.encode;
      final decode = entry.value.decode;
      final args = <String>[
        'await $variableName.call()',
        if (decode != null || encode != null) encode ?? 'null',
        ?decode,
      ];

      buf.writeln('    results[\'$variableName\'] = _processResult(${args.join(', ')});');
    }
    buf.writeln("    resultFile.writeAsStringSync(jsonEncode({'type': 'value', 'data': results}));");
    buf.writeln('  } catch (e, s) {');
    buf.writeln(
      "    resultFile.writeAsStringSync(jsonEncode({'type': 'error', 'message': e.toString(), 'stackTrace': s.toString()}));",
    );
    buf.writeln('  }');
    buf.writeln('}');
  }
}

/// Information about a compute body to execute.
class ComputeBodyInfo {
  const ComputeBodyInfo({
    required this.body,
    this.encode,
    this.decode,
  });

  /// The compute body source text (e.g., `() => '1.0.0'`).
  final String body;

  /// Optional encode function source (e.g., `(v) => v.toIso8601String()`).
  /// When provided, called on the result before serialization.
  /// Not called for DartCode results.
  final String? encode;

  /// Optional decode function source (e.g., `(v) => "DateTime.parse('$v')"`).
  /// When provided, called on the encoded string to produce a Dart literal.
  final String? decode;
}
