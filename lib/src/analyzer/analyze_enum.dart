import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/utils/hash.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/core/modifier.dart';

mixin AnalyzeEnum on BaseAnalyzer {
  @override
  Future<MacroClassDeclaration?> parseEnum(
    EnumFragment enumFragment, {
    required MacroCapability fallbackCapability,
    List<ElementAnnotation>? typeAliasAnnotation,
    String? typeAliasClassName,
  }) async {
    // combine all declared macro in one list and share with each config
    // (one class can have many metadata attached, we parsed config based on each metadata)
    List<MacroConfig> macroConfigs = [];
    Set<String> macroNames = {};
    bool combined = false;

    final enumName = typeAliasClassName ?? enumFragment.element.name ?? '';

    // 1. get all metadata attached to the class
    final annotations = typeAliasAnnotation != null
        ? CombinedListView([typeAliasAnnotation, enumFragment.metadata.annotations])
        : enumFragment.metadata.annotations;

    for (final macroAnnotation in annotations) {
      if (!isValidAnnotation(macroAnnotation, className: 'Macro', pkgName: 'macro')) {
        continue;
      }

      final macroConfig = await computeMacroMetadata(macroAnnotation);
      if (macroConfig == null) {
        // if no compute macro metadata, return
        continue;
      }

      final capability = macroConfig.capability;
      if (!capability.classFields && !capability.classConstructors && !capability.classMethods) {
        // if there is no capability, return it
        logger.info('Enum $enumName does not defined any Macro capability, ignored');
        continue;
      }

      macroConfigs.add(macroConfig);
      macroNames.add(macroConfig.key.name);
    }

    // 2. combine each requested capability to produce one result, then
    //    at execution time only provide the requested capability.
    //    * the generator maybe get extra data if not easily removed or for performance reason
    MacroCapability capability;
    if (macroConfigs.isEmpty) {
      macroConfigs = [
        MacroConfig(
          capability: fallbackCapability,
          combine: false,
          key: MacroKey(name: '', properties: []),
        ),
      ];
      capability = fallbackCapability;
    } else {
      capability = fallbackCapability.combine(macroConfigs.first.capability);
    }

    // combine capability
    for (final config in macroConfigs.skip(1)) {
      capability = capability.combine(config.capability);
      combined = true;
    }

    List<MacroProperty>? enumTypeParams;
    List<MacroProperty>? enumFields;
    List<MacroClassConstructor>? constructors;
    List<MacroMethod>? methods;
    bool isInProgress;

    final (cacheKey, enumId) = enumDeclarationCachedKey(enumFragment, capability, typeAliasClassName);
    if (iterationCaches[cacheKey]?.value case MacroClassDeclaration declaration) {
      iterationCaches[cacheKey] = iterationCaches[cacheKey]!.increaseCount();
      // override library id?
      return declaration.copyWith(classId: enumId, configs: macroConfigs);
    }

    final enumElem = enumFragment.element;
    final importPrefix = importPrefixByElements[enumElem] ?? '';
    final libraryPath = enumElem.library.uri.toString();
    final libraryId = generateHash(libraryPath);
    libraryPathById[libraryId] = libraryPath;

    final classModifier = MacroModifier.create(
      isAlias: typeAliasClassName?.isNotEmpty == true,
      isPrivate: enumElem.isPrivate,
    );

    if (capability.classFields) {
      (enumFields, enumTypeParams, isInProgress) = await parseClassFields(capability, enumFragment, null);
      if (isInProgress) {
        return MacroClassDeclaration.pendingDeclaration(
          libraryId: libraryId,
          classId: enumId,
          importPrefix: importPrefix,
          className: enumName,
          configs: macroConfigs,
          modifier: classModifier,
          classTypeParameters: enumTypeParams,
          subTypes: null,
        );
      }
    }

    if (capability.classConstructors) {
      (constructors, enumTypeParams, isInProgress) = await parseClassConstructors(
        capability,
        enumFragment,
        enumTypeParams,
        enumFields,
      );
      if (isInProgress) {
        return MacroClassDeclaration.pendingDeclaration(
          libraryId: libraryId,
          classId: enumId,
          importPrefix: importPrefix,
          className: enumName,
          configs: macroConfigs,
          modifier: classModifier,
          classTypeParameters: enumTypeParams,
          subTypes: null,
        );
      }
    }

    if (capability.classMethods) {
      (methods, isInProgress) = await parseClassMethods(capability, enumFragment, enumTypeParams);
      if (isInProgress) {
        return MacroClassDeclaration.pendingDeclaration(
          libraryId: libraryId,
          classId: enumId,
          importPrefix: importPrefix,
          className: enumName,
          configs: macroConfigs,
          modifier: classModifier,
          classTypeParameters: enumTypeParams,
          subTypes: null,
        );
      }
    }

    final declaration = MacroClassDeclaration(
      libraryId: libraryId,
      classId: enumId,
      configs: macroConfigs,
      importPrefix: importPrefix,
      className: enumName,
      modifier: classModifier,
      classTypeParameters: enumTypeParams,
      classFields: enumFields,
      constructors: constructors,
      methods: methods,
      subTypes: null,
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
}
