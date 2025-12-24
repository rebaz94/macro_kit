import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:logging/logging.dart';
import 'package:macro_kit/macro_kit.dart';
import 'package:macro_kit/src/analyzer/analyze_class.dart';
import 'package:macro_kit/src/analyzer/analyze_class_ctor.dart';
import 'package:macro_kit/src/analyzer/analyze_class_field.dart';
import 'package:macro_kit/src/analyzer/analyze_class_method.dart';
import 'package:macro_kit/src/analyzer/analyze_enum.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/generator.dart';
import 'package:macro_kit/src/analyzer/types.dart';
import 'package:macro_kit/src/analyzer/types_ext.dart';
import 'package:macro_kit/src/analyzer/utils/hash.dart';
import 'package:macro_kit/src/common/models.dart';
import 'package:watcher/watcher.dart';

class MacroAnalyzer extends BaseAnalyzer
    with Types, AnalyzeClass, AnalyzeClassField, AnalyzeClassCtor, AnalyzeClassMethod, AnalyzeEnum, Generator {
  MacroAnalyzer({
    required super.logger,
    super.server = const DefaultFakeServerInterface(),
  });

  Future<void> processDartSource(String path) async {
    stopWatch
      ..reset()
      ..start();

    try {
      await _analyzeCodeAndRun(path);
    } catch (e, s) {
      logger.error('Processing code failed', e, s);
      server.sendMessageMacroClients(GeneralMessage(message: 'Processing code failed\n$e\n$s', level: Level.SEVERE));
    } finally {
      importPrefixByElements.clear();
      imports.clear();
      macroAnalyzeResult.clear();
      pendingClassRequiredSubTypes.clear();
      currentAnalyzingPath = '';
      final time = stopWatch.elapsedMilliseconds;
      logger.info('Completed in ${time > 1000 ? '${time ~/ 1000}s' : '${time}ms'}');
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

    // step:1 track element that used prefixed import
    for (var i in analysisResult.libraryFragment.libraryImports) {
      final importDirective = i.toString();
      String importPrefix = '';

      if (i.prefix?.name case String prefix) {
        importPrefix = '$prefix.';
        for (final e in i.namespace.definedNames2.entries) {
          importPrefixByElements[e.value] = importPrefix;
        }
      }

      imports[importDirective] = importPrefix;
    }

    // step:2 analyze the code
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

    // step:3 get pending class sub types
    if (pendingClassRequiredSubTypes.isNotEmpty) {
      await collectClassSubTypes(
        pendingClassRequiredSubTypes,
        analysisResult.libraryFragment,
        macroAnalyzeResult,
      );
    }

    // step:4 get any class that used more than once from iteration cache
    //        and use it as shared class declaration to automatically assign prepared data by class id
    final sharedClasses = <String, MacroClassDeclaration>{};
    for (final entry in iterationCaches.entries) {
      final key = entry.key;
      final value = entry.value;
      var classVal = entry.value.value;
      if (!key.startsWith('classDec') || value.count < 1 || classVal is! MacroClassDeclaration) continue;

      // remove duplicate macro, keep the first one
      if (classVal.configs.length > 1) {
        classVal = classVal.copyWith(configs: classVal.configs.uniqueBy((k) => k.key.name));
      }

      sharedClasses[classVal.classId] = classVal;
    }

    // only generate for declaration in this library
    final generateForLibrary = analysisResult.libraryElement.uri.toString();
    final generateForLibraryId = generateHash(generateForLibrary);

    // step:5 remove duplicate macro, keep the first one and filter out external macro declaration
    for (final entry in macroAnalyzeResult.entries) {
      final newClasses = <MacroClassDeclaration>[];
      for (var clazz in entry.value.classes) {
        List<MacroConfig>? newConfigs;
        if (clazz.configs.length > 1) {
          newConfigs = clazz.configs.uniqueBy((v) => v.key.name);
        }

        if (newConfigs != null) {
          clazz = clazz.copyWith(configs: newConfigs);
        }

        if (clazz.libraryId != generateForLibraryId) {
          // ensure class still exist in shared classes
          if (!sharedClasses.containsKey(clazz.classId)) {
            sharedClasses[clazz.classId] = clazz;
          }

          // filter out from generation
          continue;
        }

        newClasses.add(clazz);
      }

      entry.value.classes = newClasses;
    }

    // step:6 run macro
    await executeMacro(
      path: path,
      imports: imports,
      libraryPaths: libraryPathById,
      result: macroAnalyzeResult,
      sharedClasses: sharedClasses,
    );
  }

  Future<void> processAssetSource(String path, List<AnalyzingAsset> assetMacros, ChangeType type) async {
    stopWatch
      ..reset()
      ..start();

    try {
      final assetChangeType = switch (type) {
        ChangeType.ADD => AssetChangeType.add,
        ChangeType.MODIFY => AssetChangeType.modify,
        ChangeType.REMOVE => AssetChangeType.remove,
        _ => AssetChangeType.modify,
      };
      await executeAssetMacro(path: path, changeType: assetChangeType, macros: assetMacros);
    } catch (e, s) {
      logger.error('Processing asset failed', e, s);
      server.sendMessageMacroClients(GeneralMessage(message: 'Processing asset failed\n$e\n$s', level: Level.SEVERE));
    } finally {
      currentAnalyzingPath = '';
      logger.info('Completed in ${stopWatch.elapsedMilliseconds.toString()} ms');
    }
  }
}
