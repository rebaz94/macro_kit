import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:logging/logging.dart';
import 'package:macro_kit/macro_kit.dart';
import 'package:macro_kit/src/analyzer/analyze_class.dart';
import 'package:macro_kit/src/analyzer/analyze_class_ctor.dart';
import 'package:macro_kit/src/analyzer/analyze_class_field.dart';
import 'package:macro_kit/src/analyzer/analyze_class_method.dart';
import 'package:macro_kit/src/analyzer/analyze_enum_record.dart';
import 'package:macro_kit/src/analyzer/analyze_function.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/generator.dart';
import 'package:macro_kit/src/analyzer/types.dart';
import 'package:macro_kit/src/analyzer/types_ext.dart';
import 'package:macro_kit/src/analyzer/utils/hash.dart';
import 'package:macro_kit/src/common/models.dart';
import 'package:watcher/watcher.dart';

class MacroAnalyzer extends BaseAnalyzer
    with
        Types,
        AnalyzeClass,
        AnalyzeClassField,
        AnalyzeClassCtor,
        AnalyzeClassMethod,
        AnalyzeFunction,
        AnalyzeEnum,
        Generator {
  ///
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
      if (mayContainsMacroCache.length > 100) {
        mayContainsMacroCache.clear();
      }
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

    final hashFileId = path.hashCode;
    final mayContainMacro = mayContainsMacroCache.contains(hashFileId);
    // check content of the file only when already if we don't know yet contain macro or not
    if (!mayContainMacro) {
      if (session.getFile(path) case FileResult fileRes) {
        final hasMacro = fileRes.content.contains('Macro');
        if (!hasMacro) {
          // return as we don't need to analyzer since does not contain the macro definition
          return;
        }

        mayContainsMacroCache.add(hashFileId);
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
    bool containsMacro = false;
    for (final declaration in analysisResult.unit.declarations) {
      final decFrag = declaration.declaredFragment;
      if (decFrag == null) continue;

      switch (declaration) {
        case ClassDeclaration() when decFrag is ClassFragment:
          if (decFrag.metadata.annotations.isEmpty) continue;

          final macroClass = await parseClass(decFrag);
          containsMacro = containsMacro ? true : macroClass != null;

        case GenericTypeAlias() when decFrag.element is TypeAliasElement:
          if (decFrag.metadata.annotations.isEmpty) continue;

          final typeAliasElem = (decFrag.element as TypeAliasElement);
          if (typeAliasElem.aliasedType.element?.firstFragment case ClassFragment classFrag) {
            final macroClass = await parseClass(
              classFrag,
              typeAliasClassName: decFrag.name,
              typeAliasAnnotation: decFrag.metadata.annotations,
            );
            containsMacro = containsMacro ? true : macroClass != null;
          } else if (typeAliasElem.aliasedType is RecordType) {
            final macroRecord = await parseRecord(
              typeAliasElem.aliasedType as RecordType,
              typeAliasName: decFrag.name,
              typeAliasAnnotation: decFrag.metadata.annotations,
              typeArguments: typeAliasElem.aliasedType.alias?.typeArguments,
              fallbackUri: typeAliasElem.library.uri.toString(),
              includeInList: true,
            );
            containsMacro = containsMacro ? true : macroRecord != null;
          }

        case FunctionDeclaration() when decFrag is TopLevelFunctionFragment:
          final macroFunction = await parseTopLevelFunction(decFrag);
          containsMacro = containsMacro ? true : macroFunction != null;
      }
    }
    if (!containsMacro) {
      mayContainsMacroCache.remove(hashFileId);
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
    // step 5: remove duplicate macro, keep the first one and filter out external macro declaration
    final sharedClasses = _filterAnalyzedResult(analysisResult);

    // step:6 run macro
    await executeMacro(
      path: path,
      imports: imports,
      libraryPaths: libraryPathById,
      result: macroAnalyzeResult,
      sharedClasses: sharedClasses,
    );
  }

  Map<String, MacroClassDeclaration> _filterAnalyzedResult(ResolvedUnitResult analysisResult) {
    final sharedClasses = <String, MacroClassDeclaration>{};
    for (final entry in iterationCaches.entries) {
      final key = entry.key;
      final value = entry.value;
      var classVal = entry.value.value;
      // filter only class declaration with count grater than 1
      if (!key.startsWith('classDec') || !(value.count > 1) || classVal is! MacroClassDeclaration) {
        continue;
      }

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

      // function
      final newFunctions = <MacroFunctionDeclaration>[];
      for (var fn in entry.value.topLevelFunctions ?? const <MacroFunctionDeclaration>[]) {
        List<MacroConfig>? newConfigs;
        if (fn.configs.length > 1) {
          newConfigs = fn.configs.uniqueBy((v) => v.key.name);
        }

        if (newConfigs != null) {
          fn = fn.copyWith(configs: newConfigs);
        }

        if (fn.libraryId != generateForLibraryId) {
          // filter out from generation
          continue;
        }

        newFunctions.add(fn);
      }

      // records
      final newRecords = <MacroRecordDeclaration>[];
      for (var record in entry.value.records ?? const <MacroRecordDeclaration>[]) {
        List<MacroConfig>? newConfigs;
        if (record.configs.length > 1) {
          newConfigs = record.configs.uniqueBy((v) => v.key.name);
        }

        if (newConfigs != null) {
          record = record.copyWith(configs: newConfigs);
        }

        if (record.libraryId != generateForLibraryId) {
          // filter out from generation
          continue;
        }

        newRecords.add(record);
      }

      entry.value.update(
        classes: newClasses,
        topLevelFunctions: newFunctions,
        records: newRecords,
      );
    }

    return sharedClasses;
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
