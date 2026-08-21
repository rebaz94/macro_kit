import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/utils/hash.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/core/modifier.dart';
import 'package:path/path.dart' as p;

/// Mixin that provides generic top-level variable analysis for any macro.
///
/// This mixin detects `@Macro(...)` annotations on top-level variables,
/// checks the [MacroCapability.topLevelVariables] flag, and creates
/// [MacroVariableDeclaration] instances that can be used by any macro generator.
mixin AnalyzeVariable on BaseAnalyzer {
  /// Parse a top-level variable declaration that has a `@Macro(...)` annotation.
  ///
  /// Only macros with [MacroCapability.topLevelVariables] = true are included.
  /// Returns a [MacroVariableDeclaration] if the variable has qualifying macro
  /// annotations, null otherwise. The declaration is also added to
  /// [macroAnalyzeResult].
  ///
  /// [astNode] and [sourceContent] are used to extract the compute body source
  /// text and compute content hashes for incremental caching.
  /// [resolvedUnit] is used to resolve dependency identifiers for targeted hashing.
  Future<MacroVariableDeclaration?> parseTopLevelVariable(
    VariableElement element, {
    TopLevelVariableDeclaration? astNode,
    String? sourceContent,
    ResolvedUnitResult? resolvedUnit,
  }) async {
    final macroConfigs = <MacroConfig>[];
    final macroNames = <String>{};
    for (final annotation in element.metadata.annotations) {
      if (!isValidAnnotation(annotation, className: 'Macro', pkgName: 'macro')) {
        continue;
      }

      final config = await computeMacroMetadata(annotation);
      if (config == null) continue;

      // Skip macros that don't request top-level variable data
      if (!config.capability.topLevelVariables) {
        final variableName = element.name ?? '<unknown>';
        logger.info('Variable: $variableName does not define topLevelVariables capability, ignored');
        continue;
      }

      macroConfigs.add(config);
      macroNames.add(config.key.name);
    }

    if (macroConfigs.isEmpty) return null;

    final fragment = element.firstFragment;
    final nameOffset = fragment.nameOffset ?? 0;
    final nameLength = fragment.name?.length ?? 0;

    final importPrefix = importPrefixByElements[element] ?? '';
    final libraryPath = element.library?.uri.toString() ?? '';
    final libraryId = generateHash(libraryPath);
    libraryPathById[libraryId] = libraryPath;

    final variableName = element.name ?? '<unknown>';

    // Extract compute body and compute content hashes if AST + source available
    final data = <String, dynamic>{};
    if (astNode != null && sourceContent != null) {
      final computeInfo = _extractComputeBody(astNode);
      if (computeInfo != null) {
        data['computeBody'] = computeInfo.body;
        if (computeInfo.encode != null) {
          data['encode'] = computeInfo.encode;
        }
        if (computeInfo.decode != null) {
          data['decode'] = computeInfo.decode;
        }

        // Parse deps list from compute() call
        final depsInfo = _extractDeps(astNode);
        if (depsInfo != null &&
            (depsInfo.identifiers.isNotEmpty || depsInfo.filePaths.isNotEmpty) &&
            resolvedUnit != null) {
          // Targeted hash: body + each dependency's source + file dep content hashes
          final buffer = StringBuffer();
          buffer.write(computeInfo.body);

          if (depsInfo.identifiers.isNotEmpty) {
            data['deps'] = depsInfo.identifiers;
            // Resolve dependency source text for targeted hashing
            final depSources = await _resolveDepsSource(depsInfo.identifiers, resolvedUnit, sourceContent);
            data['depSources'] = depSources;
            for (final entry in depSources.entries) {
              buffer.write(entry.key);
              buffer.write(entry.value);
            }
          }

          if (depsInfo.filePaths.isNotEmpty) {
            data['fileDeps'] = depsInfo.filePaths;
            final fileHashes = _resolveFileDepsHashes(depsInfo.filePaths, resolvedUnit);
            for (final entry in fileHashes.entries) {
              buffer.write(entry.key);
              buffer.write(entry.value);
            }
          }

          data['combinedHash'] = generateHash(buffer.toString());
        } else {
          // Full file hash: hash entire source content
          data['combinedHash'] = generateHash(sourceContent);
        }
      } else {
        // No compute body — full file hash
        data['combinedHash'] = generateHash(sourceContent);
      }
    }

    final declaration = MacroVariableDeclaration(
      libraryId: libraryId,
      variableId: '${element.name}:${generateHash(libraryPath)}',
      configs: macroConfigs,
      importPrefix: importPrefix,
      variableName: variableName,
      startLine: nameOffset,
      endLine: nameOffset + nameLength,
      modifier: MacroModifier.create(
        isPrivate: element.isPrivate,
        isLate: element.isLate,
        isFinal: element.isFinal,
        isConst: element.isConst,
      ),
      data: data,
    );

    for (final name in macroNames) {
      macroAnalyzeResult.putIfAbsent(name, () => AnalyzeResult()).addTopLevelVariable(declaration);
    }

    return declaration;
  }

  /// Extract the compute body source text and optional encode/decode functions
  /// from a [TopLevelVariableDeclaration] AST node.
  ///
  /// Returns a record containing:
  /// - `body`: The source text of the compute function (e.g., `() => 42`)
  /// - `encode`: The source text of the optional encode function, or null
  /// - `decode`: The source text of the optional decode function, or null
  ///
  /// Returns null if no `compute(...)` call is found in the initializer.
  ({String body, String? encode, String? decode})? _extractComputeBody(TopLevelVariableDeclaration node) {
    final varList = node.variables;
    if (varList.variables.isEmpty) return null;

    final firstVar = varList.variables.first;
    final initializer = firstVar.initializer;
    if (initializer == null) return null;

    // Top-level function calls like compute(...) resolve as MethodInvocation
    if (initializer is MethodInvocation) {
      // Verify it's actually a compute() call
      if (initializer.methodName.name != 'compute') return null;
      return _parseComputeArgs(initializer.argumentList);
    }

    // Function expression invocations like localCompute() resolve as FunctionExpressionInvocation
    if (initializer is FunctionExpressionInvocation) {
      return _parseComputeArgs(initializer.argumentList);
    }

    return null;
  }

  /// Parse the arguments of a `compute()` call to extract body, encode, and decode.
  ///
  /// Extracts:
  /// - First positional argument as the compute body source text
  /// - `encode` named argument (optional): function that serializes the runtime result
  ///   to a string before it's sent back from the temp file execution
  /// - `decode` named argument (optional): function that converts the encoded string
  ///   back to a Dart literal for code generation
  ///
  /// Returns null if the argument list is empty.
  ({String body, String? encode, String? decode})? _parseComputeArgs(ArgumentList argumentList) {
    final args = argumentList.arguments;
    if (args.isEmpty) return null;

    // First positional argument is the compute body
    final body = args.first.toString();

    // Look for named 'encode' and 'decode' arguments
    String? encode;
    String? decode;
    for (final arg in args) {
      if (arg is NamedArgument) {
        if (arg.name.lexeme == 'encode') {
          encode = arg.argumentExpression.toString();
        } else if (arg.name.lexeme == 'decode') {
          decode = arg.argumentExpression.toString();
        }
      }
    }

    return (body: body, encode: encode, decode: decode);
  }

  /// Extract dependency identifiers and file paths from the `deps:` named argument of a compute() call.
  ///
  /// Supports three forms:
  /// - **List literal**: `deps: [a, b, 'assets/data.json']` — extracts each identifier from the list,
  ///   plus string elements containing a path separator (`/`) as file paths. String elements
  ///   without `/` are invalid and skipped with a warning.
  /// - **Constant list literal**: `deps: const [a, b]` — same as above (const keyword is ignored)
  /// - **Bare variable reference**: `deps: myList` — returns the variable name itself;
  ///   resolution of the variable's source text is deferred to [_resolveDepsSource]
  ///
  /// Returns the extracted identifiers/file paths, or null if no `deps` argument is provided.
  ({List<String> identifiers, List<String> filePaths})? _extractDeps(TopLevelVariableDeclaration node) {
    final varList = node.variables;
    if (varList.variables.isEmpty) return null;

    final firstVar = varList.variables.first;
    final initializer = firstVar.initializer;
    if (initializer == null) return null;

    ArgumentList? argumentList;
    if (initializer is MethodInvocation && initializer.methodName.name == 'compute') {
      argumentList = initializer.argumentList;
    } else if (initializer is FunctionExpressionInvocation) {
      argumentList = initializer.argumentList;
    }
    if (argumentList == null) return null;

    for (final arg in argumentList.arguments) {
      if (arg is NamedArgument && arg.name.lexeme == 'deps') {
        return _extractDepsFromExpression(arg.argumentExpression);
      }
    }
    return null;
  }

  /// Extract dependency names and file paths from an AST expression.
  ///
  /// Handles multiple expression forms:
  /// - [ListLiteral]: `[a, b, 'assets/data.json']` or `const [a, b]` — extracts identifiers directly,
  ///   and string elements containing `/` as file paths resolved relative to the project root
  /// - [Identifier]: bare variable reference like `deps: myList` — returns the name
  ///   for later resolution by [_resolveDepsSource]
  ({List<String> identifiers, List<String> filePaths})? _extractDepsFromExpression(Expression expr) {
    // Case 1 & 2: [a, b, c] or const [a, b, c] — list literal (const has constKeyword set)
    if (expr is ListLiteral) {
      final identifiers = <String>[];
      final filePaths = <String>[];
      for (final element in expr.elements) {
        if (element is Identifier) {
          identifiers.add(element.name);
        } else if (element is SimpleStringLiteral) {
          final value = element.stringValue;
          if (value != null && value.contains('/')) {
            filePaths.add(value);
          } else {
            logger.warn(
              'Compute dep "$value" must contain a path separator "/" to be treated as a file dependency, ignored',
            );
          }
        }
      }
      return (identifiers: identifiers, filePaths: filePaths);
    }

    // Case 3: Variable reference — e.g., deps: myList
    // Return the variable name itself; _resolveDepsSource will handle resolution.
    if (expr is Identifier) {
      return (identifiers: [expr.name], filePaths: const []);
    }

    return null;
  }

  /// Compute a content hash for each file dependency.
  ///
  /// Paths are relative to the project root of the context that owns [resolvedUnit]
  /// (e.g. `'assets/data.json'`, `'./data.json'`, `'../shared/x.json'`). Absolute
  /// paths are used as-is.
  ///
  /// Missing or unreadable files log a warning and contribute an empty value,
  /// but their path name still participates in the combined hash so adding
  /// the file later triggers a rebuild.
  Map<String, String> _resolveFileDepsHashes(List<String> filePaths, ResolvedUnitResult resolvedUnit) {
    final result = <String, String>{};
    final root = server.getContextRootForPath(resolvedUnit.path);
    for (final rel in filePaths) {
      String value = '';
      if (root == null) {
        logger.warn('Unable to resolve project root for compute file dependency "$rel" in ${resolvedUnit.path}');
      } else {
        final absPath = p.normalize(p.isAbsolute(rel) ? rel : p.join(root, rel));
        try {
          final file = File(absPath);
          if (file.existsSync()) {
            value = hashFile(file).toString();
          } else {
            logger.warn('Compute file dependency not found: $absPath');
          }
        } catch (e, s) {
          logger.error('Failed to read compute file dependency: $absPath', e, s);
        }
      }
      result[rel] = value;
    }
    return result;
  }

  /// Resolve the source text of each dependency identifier for hashing.
  ///
  /// Performs a two-pass resolution:
  /// 1. **Same-file pass**: checks [resolvedUnit]'s declarations for variables,
  ///    functions, classes, and other top-level declarations matching the dep name
  /// 2. **Imported pass**: uses [Scope.lookup] to find the element, resolves the
  ///    containing library via [getResolvedLibraryByElement], then locates the
  ///    declaration node by source offset or name matching across all units
  ///
  /// Returns a map of `depName -> sourceText` for all successfully resolved deps.
  /// Unresolvable deps are silently skipped with a log message.
  Future<Map<String, String>> _resolveDepsSource(
    List<String> depNames,
    ResolvedUnitResult resolvedUnit,
    String sourceContent,
  ) async {
    final result = <String, String>{};
    final remaining = Set<String>.from(depNames);

    // First pass: check same-file declarations via VariableDeclaration fragments
    for (final decl in resolvedUnit.unit.declarations) {
      if (remaining.isEmpty) break;
      if (decl is TopLevelVariableDeclaration) {
        for (final variable in decl.variables.variables) {
          final fragment = variable.declaredFragment;
          if (fragment == null) continue;

          final element = fragment.element;
          if (remaining.remove(element.name)) {
            result[element.name!] = sourceContent.substring(decl.offset, decl.end);
          }
        }
      } else {
        final fragment = decl.declaredFragment;
        if (fragment == null) continue;

        final element = fragment.element;
        if (remaining.remove(element.name)) {
          result[element.name!] = sourceContent.substring(decl.offset, decl.end);
        }
      }
    }

    if (remaining.isEmpty) return result;

    // Second pass: resolve imported identifiers not found in same file
    for (final depName in remaining) {
      // Look up in library scope
      final lookupResult = resolvedUnit.libraryFragment.scope.lookup(depName);
      final element = lookupResult.getter;
      if (element == null) {
        logger.info('dep "$depName" not found in scope, skipping');
        continue;
      }

      // Get the source file for this element
      try {
        final libElement = element.library;
        if (libElement == null) continue;

        final resolvedLib = await resolvedUnit.session.getResolvedLibraryByElement(libElement);
        if (resolvedLib is! ResolvedLibraryResult) continue;

        // Find the declaration node by looking at the element's source location.
        // Try to get offset from the element's fragment.
        final fragment = element.firstFragment;
        final nameOffset = fragment.nameOffset ?? 0;

        AstNode? node;
        // First try: find by source offset in resolved units
        if (nameOffset > 0) {
          for (final unitResult in resolvedLib.units) {
            final cu = unitResult.unit;
            for (final decl in cu.declarations) {
              if (decl.offset <= nameOffset && nameOffset < decl.end) {
                node = decl;
                break;
              }
            }
            if (node != null) break;
          }
        }

        // Second try: match by declaration name across all declaration types
        if (node == null) {
          for (final unitResult in resolvedLib.units) {
            final cu = unitResult.unit;
            for (final decl in cu.declarations) {
              if (decl is TopLevelVariableDeclaration) {
                for (final v in decl.variables.variables) {
                  if (v.name.lexeme == depName) {
                    node = decl;
                    break;
                  }
                }
              } else if (decl.declaredFragment?.element.name == depName) {
                node = decl;
              }
              if (node != null) break;
            }
            if (node != null) break;
          }
        }

        if (node == null) continue;

        // Read the source file
        final source = libElement.firstFragment.source;
        final file = File(source.fullName);
        if (!file.existsSync()) continue;
        final fileContent = file.readAsStringSync();

        result[depName] = fileContent.substring(node.offset, node.end);
      } catch (e) {
        logger.info('Failed to resolve dep "$depName": $e');
      }
    }

    return result;
  }
}
