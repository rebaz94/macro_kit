import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:dart_style/dart_style.dart';
import 'package:hashlib/hashlib.dart';
import 'package:macro_kit/macro.dart';
import 'package:macro_kit/src/analyzer/analyze_class.dart';
import 'package:macro_kit/src/analyzer/generator.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/macro_server.dart';
import 'package:macro_kit/src/analyzer/types.dart';

abstract class Analyzer extends BaseAnalyzer {
  Analyzer(super.logger);

  final random = Random();
  final DartFormatter formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
    pageWidth: 120,
    trailingCommas: TrailingCommas.preserve,
  );

  List<String> contexts = <String>[];
  AnalysisContextCollection contextCollection = AnalysisContextCollection(
    includedPaths: [],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );

  final Map<String, File> fileCaches = {};

  /// per analyze cache for reusing common parsing like computing a class type info
  final Map<String, CountedCache> iterationCaches = {};
  final Set<String> mayContainsMacroCache = {};
  final List<String> pendingAnalyze = [];
  String currentAnalyzingPath = '';
  bool isAnalyzingFile = false;

  /// --- internal state of required of sub types, reset per [processSource] call
  Map<String, AnalyzeResult> macroAnalyzeResult = {};
  List<(List<MacroConfig>, ClassFragment)> pendingClassRequiredSubTypes = [];

  int newId() => random.nextInt(100000);

  @override
  Future<void> processSource(String path) async {
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
    final session = analysisContext.currentSession;

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
      if (declaration is ClassDeclaration && declaration.declaredFragment != null) {
        final macroClass = parseClass(declaration.declaredFragment!);
        if (macroClass != null) {
          containsMacro = true;
        }
      }
    }
    if (!containsMacro) {
      mayContainsMacroCache.remove(path);
    }

    // step:2 get pending class sub types
    collectClassSubTypes(pendingClassRequiredSubTypes, analysisResult.libraryFragment);

    // step:3 get any class that used more than once from iteration cache
    //        and use it as shared class declaration to automatically assign prepared data by class id
    final sharedClasses = <String, MacroClassDeclaration>{};
    for (final entry in iterationCaches.entries) {
      final key = entry.key;
      final value = entry.value;
      final classVal = entry.value.value;
      if (!key.startsWith('classDec') || value.count < 1 || classVal is! MacroClassDeclaration) continue;

      sharedClasses[classVal.classId] = classVal;
    }

    // step:4 run macro
    await executeMacro(path: path, result: macroAnalyzeResult, sharedClasses: sharedClasses);
  }

  MacroClassDeclaration? parseClass(ClassFragment classFragment, {List<MacroConfig>? collectSubTypeConfig}) {
    // combine all declared macro in one list and share with each config
    // (one class can have many metadata attached, we parsed config based on each metadata)
    List<MacroConfig> macroConfigs = [];
    Set<String> macroNames = {};
    bool combined = false;

    // 1. get all metadata attached to the class
    if (collectSubTypeConfig == null) {
      for (final macroAnnotation in classFragment.metadata.annotations) {
        if (!isValidAnnotation(macroAnnotation, className: 'Macro', pkgName: 'macro')) {
          continue;
        }

        final macroConfig = computeMacroMetadata(macroAnnotation);
        if (macroConfig == null) {
          // if no compute macro metadata, return
          continue;
        }

        final capability = macroConfig.capability;
        if (!capability.classFields && !capability.classConstructors && !capability.classMethods) {
          // if there is no capability, return it
          logger.info('Class ${classFragment.name} does not defined any Macro capability, ignored');
          continue;
        }

        macroConfigs.add(macroConfig);
        macroNames.add(macroConfig.key.name);
      }
    } else {
      macroConfigs = collectSubTypeConfig;
      macroNames = collectSubTypeConfig.map((e) => e.key.name).toSet();
    }

    // 2. combine each requested capability to produce one result, then
    //    at execution time only provide the requested capability.
    //    * the generator maybe get extra data if not easily removed or for performance reason
    MacroCapability capability;
    if (macroConfigs.isEmpty) {
      // does not contain macro and not allowed
      return null;
    }

    capability = macroConfigs.first.capability;

    // combine capability
    for (final config in macroConfigs.skip(1)) {
      capability = capability.combine(config.capability);
      combined = true;
    }

    List<String>? classTypeParams;
    List<MacroProperty>? classFields;
    List<MacroClassConstructor>? constructors;
    List<MacroMethod>? methods;
    bool isInProgress;

    final effectiveCollectClassSubTypes = () {
      if (!capability.collectClassSubTypes || capability.filterCollectSubTypes == '') {
        return false;
      }

      final isSealed = classFragment.element.isSealed;
      final isAbstract = classFragment.element.isAbstract;
      if (capability.filterCollectSubTypes == '*') {
        return isSealed || isAbstract;
      }

      final parts = capability.filterCollectSubTypes.split(',');
      if (isSealed && parts.contains('sealed') || (isAbstract && parts.contains('abstract'))) {
        return true;
      }

      return false;
    }();

    // only add to pending while not preparing the sub types
    if (effectiveCollectClassSubTypes && collectSubTypeConfig == null) {
      pendingClassRequiredSubTypes.add((macroConfigs, classFragment));
    }

    final (cacheKey, classId) = _classDeclarationCachedKey(classFragment, capability);
    if (iterationCaches[cacheKey]?.value case MacroClassDeclaration declaration) {
      iterationCaches[cacheKey] = iterationCaches[cacheKey]!.increaseCount();
      return collectSubTypeConfig == null ? declaration.copyWith(classId: classId, configs: macroConfigs) : declaration;
    }

    final classElem = classFragment.element;
    final classModifier = MacroModifier.create(
      isAbstract: classElem.isAbstract,
      isSealed: classElem.isSealed,
      isExhaustive: classElem.isExhaustive,
      // isExtendableOutside: classElem.isExtendableOutside,
      // isImplementableOutside: classElem.isImplementableOutside,
      // isMixableOutside: classElem.isMixableOutside,
      isMixinClass: classElem.isMixinClass,
      isBase: classElem.isBase,
      isInterface: classElem.isInterface,
      // isConstructable: classElem.isConstructable,
      hasNonFinalField: classElem.hasNonFinalField,
    );

    if (capability.classFields) {
      (classFields, classTypeParams, isInProgress) = parseClassFields(capability, classFragment, null);
      if (isInProgress) {
        return MacroClassDeclaration.pendingDeclaration(
          classId: classId,
          className: classElem.name ?? '',
          configs: macroConfigs,
          modifier: classModifier,
          classTypeParameters: classTypeParams,
          subTypes: effectiveCollectClassSubTypes ? [] : null,
        );
      }
    }

    if (capability.classConstructors) {
      (constructors, classTypeParams, isInProgress) = parseClassConstructors(
        capability,
        classFragment,
        classTypeParams,
        classFields,
      );
      if (isInProgress) {
        return MacroClassDeclaration.pendingDeclaration(
          classId: classId,
          className: classElem.name ?? '',
          configs: macroConfigs,
          modifier: classModifier,
          classTypeParameters: classTypeParams,
          subTypes: effectiveCollectClassSubTypes ? [] : null,
        );
      }
    }

    if (capability.classMethods) {
      (methods, isInProgress) = parseClassMethods(capability, classFragment, classTypeParams);
      if (isInProgress) {
        return MacroClassDeclaration.pendingDeclaration(
          classId: classId,
          className: classElem.name ?? '',
          configs: macroConfigs,
          modifier: classModifier,
          classTypeParameters: classTypeParams,
          subTypes: effectiveCollectClassSubTypes ? [] : null,
        );
      }
    }

    final declaration = MacroClassDeclaration(
      classId: classId,
      configs: macroConfigs,
      className: classElem.name ?? '',
      modifier: classModifier,
      classTypeParameters: classTypeParams,
      classFields: classFields,
      constructors: constructors,
      methods: methods,
      subTypes: effectiveCollectClassSubTypes ? [] : null,
    );

    if (combined) {
      macroAnalyzeResult.putIfAbsent(macroNames.first, () => AnalyzeResult()).classes.add(declaration);
    } else {
      for (final name in macroNames) {
        macroAnalyzeResult.putIfAbsent(name, () => AnalyzeResult()).classes.add(declaration);
      }
    }

    iterationCaches[cacheKey] = CountedCache(declaration);
    return declaration;
  }

  void collectClassSubTypes(
    List<(List<MacroConfig>, ClassFragment)> pendingRequiredSubTypes,
    LibraryFragment libraryFragment,
  ) {
    for (final (capability, classFragment) in pendingRequiredSubTypes) {
      // get sub types
      final subTypes = findSubTypesOf(classFragment.element, libraryFragment);
      if (subTypes.isEmpty) continue;

      // convert to macro declaration
      final classDeclaration = <MacroClassDeclaration>[];
      for (final classSubType in subTypes) {
        final declaration = parseClass(classSubType, collectSubTypeConfig: capability);
        if (declaration != null) {
          classDeclaration.add(declaration);
        }
      }

      final targetClassRequestedSubTypes = classFragment.element.name ?? '';
      // add subtypes only for the class that requested and has collectSubTypes capability
      for (final analyzeRes in macroAnalyzeResult.values) {
        classLoop:
        for (final clazz in analyzeRes.classes) {
          if (clazz.className != targetClassRequestedSubTypes) continue;

          for (final config in clazz.configs) {
            if (config.capability.collectClassSubTypes) {
              //  clazz.subTypes never be null because we init with empty
              clazz.subTypes?.addAll(classDeclaration);
              continue classLoop;
            }
          }
        }
      }
    }
  }

  List<ClassFragment> findSubTypesOf(ClassElement baseClass, LibraryFragment libraryFragment) {
    final result = <ClassFragment>[];
    for (final classElem in libraryFragment.element.classes) {
      if (_isSubTypeOf(classElem, baseClass, libraryFragment)) {
        result.add(classElem.firstFragment);
      }
    }

    return result;
  }

  bool _isSubTypeOf(InterfaceElement type, ClassElement target, LibraryFragment libraryFragment) {
    final superType = type.supertype;
    if (superType != null && superType.element == target) return true;

    // Check implements
    for (final interface in type.interfaces) {
      if (interface.element == target) return true;
    }

    // Check mixins
    for (final mixin in type.mixins) {
      if (mixin.element == target) return true;
    }

    // OPTIONAL: recursively check inherited subtypes
    if (type.supertype != null) {
      return _isSubTypeOf(type.supertype!.element, target, libraryFragment);
    }

    return false;
  }

  (String, String) _classDeclarationCachedKey(ClassFragment classFragment, MacroCapability capability) {
    final uri = classFragment.element.library.uri.toString();
    final id = '${classFragment.element.name}:${xxh32code('$capability${classFragment.element.name}$uri')}';
    return ('classDec:$id', id);
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
