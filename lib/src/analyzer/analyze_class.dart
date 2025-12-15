import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/hash.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/core/modifier.dart';

mixin AnalyzeClass on BaseAnalyzer {
  @override
  Future<MacroClassDeclaration?> parseClass(
    ClassFragment classFragment, {
    List<MacroConfig>? collectSubTypeConfig,
    List<ElementAnnotation>? typeAliasAnnotation,
    String? typeAliasClassName,
  }) async {
    // combine all declared macro in one list and share with each config
    // (one class can have many metadata attached, we parsed config based on each metadata)
    List<MacroConfig> macroConfigs = [];
    Set<String> macroNames = {};
    bool combined = false;

    final className = typeAliasClassName ?? classFragment.element.name ?? '';

    // 1. get all metadata attached to the class
    if (collectSubTypeConfig == null) {
      final annotations = typeAliasAnnotation != null
          ? CombinedListView([typeAliasAnnotation, classFragment.metadata.annotations])
          : classFragment.metadata.annotations;

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
          logger.info('Class $className does not defined any Macro capability, ignored');
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

    List<MacroProperty>? classTypeParams;
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

    final (cacheKey, classId) = classDeclarationCachedKey(classFragment, capability, typeAliasClassName);
    if (iterationCaches[cacheKey]?.value case MacroClassDeclaration declaration) {
      iterationCaches[cacheKey] = iterationCaches[cacheKey]!.increaseCount();
      // override library id?
      return collectSubTypeConfig == null ? declaration.copyWith(classId: classId, configs: macroConfigs) : declaration;
    }

    final classElem = classFragment.element;
    final importPrefix = importPrefixByElements[classElem] ?? '';
    final libraryPath = classElem.library.uri.toString();
    final libraryId = generateHash(libraryPath);
    libraryPathById[libraryId] = libraryPath;

    final classModifier = MacroModifier.create(
      isAbstract: classElem.isAbstract,
      isSealed: classElem.isSealed,
      isAlias: typeAliasClassName?.isNotEmpty == true,
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
      (classFields, classTypeParams, isInProgress) = await parseClassFields(capability, classFragment, null);
      if (isInProgress) {
        return MacroClassDeclaration.pendingDeclaration(
          libraryId: libraryId,
          classId: classId,
          importPrefix: importPrefix,
          className: className,
          configs: macroConfigs,
          modifier: classModifier,
          classTypeParameters: classTypeParams,
          subTypes: effectiveCollectClassSubTypes ? [] : null,
        );
      }
    }

    if (capability.classConstructors) {
      (constructors, classTypeParams, isInProgress) = await parseClassConstructors(
        capability,
        classFragment,
        classTypeParams,
        classFields,
      );
      if (isInProgress) {
        return MacroClassDeclaration.pendingDeclaration(
          libraryId: libraryId,
          classId: classId,
          importPrefix: importPrefix,
          className: className,
          configs: macroConfigs,
          modifier: classModifier,
          classTypeParameters: classTypeParams,
          subTypes: effectiveCollectClassSubTypes ? [] : null,
        );
      }
    }

    if (capability.classMethods) {
      (methods, isInProgress) = await parseClassMethods(capability, classFragment, classTypeParams);
      if (isInProgress) {
        return MacroClassDeclaration.pendingDeclaration(
          libraryId: libraryId,
          classId: classId,
          importPrefix: importPrefix,
          className: className,
          configs: macroConfigs,
          modifier: classModifier,
          classTypeParameters: classTypeParams,
          subTypes: effectiveCollectClassSubTypes ? [] : null,
        );
      }
    }

    final declaration = MacroClassDeclaration(
      libraryId: libraryId,
      classId: classId,
      configs: macroConfigs,
      importPrefix: importPrefix,
      className: className,
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

  @override
  Future<List<MacroProperty>> parseTypeParameter(
    MacroCapability capability,
    List<TypeParameterElement> typeParameterElements,
  ) async {
    // fake all type parameter just passed in case it referenced by
    // do not use allTypeParams as final result
    final allTypeParams = typeParameterElements
        .map((e) => MacroProperty(name: e.name ?? '', importPrefix: '', type: '', typeInfo: TypeInfo.generic))
        .toList();

    final typeParams = <MacroProperty>[];

    for (final tp in typeParameterElements) {
      if (tp.bound != null) {
        final typeBoundRes = await getTypeInfoFrom(
          tp.bound,
          allTypeParams,
          capability.filterClassMethodMetadata,
          capability,
        );

        typeParams.add(
          MacroProperty(
            name: tp.name ?? '',
            importPrefix: typeBoundRes.importPrefix,
            type: typeBoundRes.type,
            typeInfo: typeBoundRes.typeInfo,
            functionTypeInfo: typeBoundRes.fnInfo,
            classInfo: typeBoundRes.classInfo,
            typeArguments: typeBoundRes.typeArguments,
            typeRefType: typeBoundRes.typeRefType,
            modifier: const MacroModifier({}),
            // constantValue: tp.element.bound!.getDisplayString(), // not needed since type has it
          ),
        );
      } else {
        typeParams.add(
          MacroProperty(
            name: tp.name ?? '',
            importPrefix: '',
            type: '',
            typeInfo: TypeInfo.generic,
            functionTypeInfo: null,
            classInfo: null,
            typeArguments: null,
            modifier: const MacroModifier({}),
          ),
        );
      }
    }

    return typeParams;
  }
}
