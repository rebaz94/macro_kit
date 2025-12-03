import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:macro_kit/macro.dart';
import 'package:macro_kit/src/analyzer/analyze_class.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/generator.dart';
import 'package:macro_kit/src/analyzer/types_ext.dart';

abstract class MacroAnalyzer extends BaseAnalyzer with AnalyzeClass, Generator {
  MacroAnalyzer({required super.logger});

  Future<void> processDartSource(String path) async {
    final s = Stopwatch()..start();

    try {
      await _analyzeCodeAndRun(path);
    } catch (e, s) {
      logger.error('Processing code failed', e, s);
    } finally {
      macroAnalyzeResult.clear();
      pendingClassRequiredSubTypes.clear();
      currentAnalyzingPath = '';
      logger.info('Completed in ${s.elapsedMilliseconds.toString()} ms');
    }
  }

  Future<void> _analyzeCodeAndRun(String path) async {
    // ensure context is fresh
    final analysisContext = contextCollection.contextFor(path);
    analysisContext.changeFile(path);

    await analysisContext.applyPendingFileChanges();
    final session = currentSession = analysisContext.currentSession;

    final mayContainMacro = mayContainsMacroCache.contains(path);
    // check content of the file only when already if we don't know yet contain macro or not
    if (!mayContainMacro) {
      if (session.getFile(path) case FileResult fileRes) {
        final hasMacro = fileRes.content.contains('Macro');
        if (!hasMacro) {
          // return as we don't need to analyzer since does not contain the macro definition
          return;
        }

        mayContainsMacroCache.add(path);
      }
    }

    // resolve the file
    final analysisResult = await session.getResolvedUnit(path);
    if (analysisResult is! ResolvedUnitResult) {
      throw MacroException('Failed to resolve path: $path, got: $analysisResult');
    }

    // step:1 analyze the code
    var containsMacro = false;
    for (final declaration in analysisResult.unit.declarations) {
      final decFrag = declaration.declaredFragment;
      if (decFrag == null) continue;

      MacroClassDeclaration? macroClass;
      switch (declaration) {
        case ClassDeclaration() when decFrag is ClassFragment:
          macroClass = await parseClass(decFrag);
        case GenericTypeAlias() when decFrag.element is TypeAliasElement:
          final typeAliasElem = (decFrag.element as TypeAliasElement);
          if (typeAliasElem.aliasedType.element?.firstFragment case ClassFragment classFrag) {
            macroClass = await parseClass(
              classFrag,
              typeAliasAnnotation: decFrag.metadata.annotations,
              typeAliasClassName: decFrag.name,
            );
          }
      }

      if (macroClass != null) {
        containsMacro = true;
      }
    }
    if (!containsMacro) {
      mayContainsMacroCache.remove(path);
    }

    // step:2 get pending class sub types
    await collectClassSubTypes(pendingClassRequiredSubTypes, analysisResult.libraryFragment);

    // step:3 get any class that used more than once from iteration cache
    //        and use it as shared class declaration to automatically assign prepared data by class id
    final sharedClasses = <String, MacroClassDeclaration>{};
    for (final entry in iterationCaches.entries) {
      final key = entry.key;
      final value = entry.value;
      var classVal = entry.value.value;
      if (!key.startsWith('classDec') || value.count < 1 || classVal is! MacroClassDeclaration) continue;

      if (classVal.configs.length > 1) {
        classVal = classVal.copyWith(configs: classVal.configs.uniqueBy((k) => k.key.name));
      }

      sharedClasses[classVal.classId] = classVal;
    }

    for (final entry in macroAnalyzeResult.entries) {
      for (final (i, cls) in entry.value.classes.indexed) {
        if (cls.configs.length <= 1) continue;

        entry.value.classes[i] = cls.copyWith(configs: cls.configs.uniqueBy((v) => v.key.name));
      }
    }

    // step:4 run macro
    await executeMacro(
      path: path,
      result: macroAnalyzeResult,
      sharedClasses: sharedClasses,
    );
  }

  Future<void> processAssetSource(String path, List<AnalyzingAsset> assetMacros, AssetChangeType type) async {
    final s = Stopwatch()..start();

    try {
      await executeAssetMacro(path: path, changeType: type, macros: assetMacros);
    } catch (e, s) {
      logger.error('Processing asset failed', e, s);
    } finally {
      currentAnalyzingPath = '';
      logger.info('Completed in ${s.elapsedMilliseconds.toString()} ms');
    }
  }
}

// insert DataClass
// final r = declaration.withClause?.mixinTypes.any((e) => e.name.lexeme.endsWith('DataClass')) ?? false;
// if (!r) {
//   final insertOffset = declaration.name.end;
//   final text = File(currentAnalyzingPath).readAsStringSync();
//
//   if (insertOffset < 0 || insertOffset > text.length) {
//     print('Offset out of bounds: $insertOffset');
//   } else {
//     final updated = '${text.substring(0, insertOffset)} with TestDataClass${text.substring(insertOffset)}';
//     File(currentAnalyzingPath).writeAsStringSync(updated);
//     print(insertOffset);
//   }
// }

// get sub types
// final libraries = session.analysisContext.contextRoot.analyzedFiles().where((path) => path.endsWith('.dart'));
// final libraries = _currentSession!.analysisContext.contextRoot.analyzedFiles().where((path) {
//   return path.endsWith('.dart') && !path.endsWith('g.dart');
// });

// for (final path in libraries) {
//   final unitResult = await session.getUnitElement(path);
//   if (unitResult is! UnitElementResult) continue;
//
//   for (final classElem in unitResult.fragment.element.classes) {
//     if (_isSubTypeOf(classElem, baseClass, session)) {
//       result.add(classElem);
//     }
//   }
// }
