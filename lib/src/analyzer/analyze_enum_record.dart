import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
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
      if (!capability.hasAnyCapability) {
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

  @override
  Future<MacroRecordDeclaration?> parseRecord(
    RecordType recordType, {
    MacroCapability? fallbackCapability,
    String? fallbackUri,
    String? typeAliasName,
    List<DartType>? typeArguments,
    List<ElementAnnotation>? typeAliasAnnotation,
    bool forceParse = false,
    bool includeInList = false,
  }) async {
    // combine all declared macro in one list and share with each config
    // (one class can have many metadata attached, we parsed config based on each metadata)
    List<MacroConfig> macroConfigs = [];
    Set<String> macroNames = {};
    bool combined = false;

    final recordName = typeAliasName ?? recordType.alias?.element.name ?? recordType.getDisplayString();

    // 1. get all metadata attached to the record
    final annotations = typeAliasAnnotation ?? recordType.alias?.element.metadata.annotations ?? const [];

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
      if (!capability.typeDefRecords) {
        // if there is no capability, return it
        if (!forceParse) {
          logger.info('Record $recordName does not defined any Macro capability, ignored');
        }
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
      if ((fallbackCapability == null || !fallbackCapability.typeDefRecords) && !forceParse) {
        return null;
      }

      fallbackCapability ??= const MacroCapability();
      macroConfigs = [
        MacroConfig(
          capability: fallbackCapability,
          combine: false,
          key: MacroKey(name: '', properties: []),
        ),
      ];
      capability = fallbackCapability;
    } else {
      capability = fallbackCapability != null
          ? fallbackCapability.combine(macroConfigs.first.capability)
          : macroConfigs.first.capability;
    }

    // combine capability
    for (final config in macroConfigs.skip(1)) {
      capability = capability.combine(config.capability);
      combined = true;
    }

    List<MacroProperty>? recordTypeParams;
    List<MacroProperty>? recordFields;

    final (cacheKey, recordId) = recordDeclarationCachedKey(
      recordType,
      capability,
      typeAliasName,
      typeArguments,
    );
    if (iterationCaches[cacheKey]?.value case MacroRecordDeclaration declaration) {
      iterationCaches[cacheKey] = iterationCaches[cacheKey]!.increaseCount();
      // override library id?
      return declaration.copyWith(recordId: recordId, configs: macroConfigs);
    }

    final recordAliasElem = recordType.alias?.element;
    final importPrefix = importPrefixByElements[recordAliasElem] ?? '';
    final libraryPath = recordAliasElem?.library.uri.toString() ?? fallbackUri ?? '';
    final libraryId = generateHash(libraryPath);
    libraryPathById[libraryId] = libraryPath;

    final recordModifier = MacroModifier.create(
      isAlias: typeAliasName?.isNotEmpty == true,
      isPrivate: recordAliasElem?.isPrivate ?? false,
    );

    (recordFields, recordTypeParams) = await parseRecordFields(capability, recordType);

    final declaration = MacroRecordDeclaration(
      libraryId: libraryId,
      recordId: recordId,
      configs: macroConfigs,
      importPrefix: importPrefix,
      recordName: recordName,
      modifier: recordModifier,
      recordTypeParameters: recordTypeParams,
      fields: recordFields,
    );

    if (includeInList) {
      if (combined) {
        macroAnalyzeResult.putIfAbsent(macroNames.first, () => AnalyzeResult()).addRecord(declaration);
      } else {
        for (final name in macroNames) {
          macroAnalyzeResult.putIfAbsent(name, () => AnalyzeResult()).addRecord(declaration);
        }
      }
    }

    iterationCaches[cacheKey] = CountedCache(declaration);
    return declaration;
  }

  Future<(List<MacroProperty>?, List<MacroProperty>?)> parseRecordFields(
    MacroCapability capability,
    RecordType recordType,
  ) async {
    final fields = <MacroProperty>[];
    final recordTypeParams = await parseRecordTypeParameter(
      capability,
      recordType.alias?.typeArguments ?? const [],
    );

    final positionalLen = recordType.positionalFields.length;
    final namedLen = recordType.namedFields.length;
    for (int i = 0; i < positionalLen + namedLen; i++) {
      final isPositionalField = i < positionalLen;
      final field = isPositionalField ? recordType.positionalFields[i] : recordType.namedFields[i - positionalLen];

      final fieldTypeRes = await getTypeInfoFrom(
        field.type,
        recordTypeParams,
        capability.filterClassMethodMetadata,
        capability,
      );

      List<MacroKey>? macroKeys;
      if (field.type.element?.metadata != null) {
        macroKeys = await computeMacroKeys(
          capability.filterClassFieldMetadata,
          field.type.element!.metadata,
          capability,
        );
      }

      if (fieldTypeRes.typeInfo == TypeInfo.generic && !recordTypeParams.any((tp) => tp.type == fieldTypeRes.type)) {
        recordTypeParams.add(
          MacroProperty(
            name: '',
            importPrefix: fieldTypeRes.importPrefix,
            type: fieldTypeRes.type,
            typeInfo: fieldTypeRes.typeInfo,
            functionTypeInfo: fieldTypeRes.fnInfo,
            classInfo: fieldTypeRes.classInfo,
            recordInfo: fieldTypeRes.recordInfo,
            typeRefType: fieldTypeRes.typeRefType,
            typeArguments: fieldTypeRes.typeArguments,
            fieldInitializer: null,
            modifier: const MacroModifier({}),
            keys: macroKeys,
          ),
        );
      }

      fields.add(
        MacroProperty(
          name: isPositionalField ? '\$${i + 1}' : (field as RecordTypeNamedField).name,
          importPrefix: fieldTypeRes.importPrefix,
          type: fieldTypeRes.type,
          typeInfo: fieldTypeRes.typeInfo,
          functionTypeInfo: fieldTypeRes.fnInfo,
          classInfo: fieldTypeRes.classInfo,
          recordInfo: fieldTypeRes.recordInfo,
          typeRefType: fieldTypeRes.typeRefType,
          typeArguments: fieldTypeRes.typeArguments,
          fieldInitializer: null,
          modifier: MacroModifier.getModifierInfoFrom(
            field,
            isNullable: field.type.nullabilitySuffix != NullabilitySuffix.none,
          ),
          keys: macroKeys,
        ),
      );
    }

    return (fields, recordTypeParams);
  }

  @override
  Future<List<MacroProperty>> parseRecordTypeParameter(
    MacroCapability capability,
    List<DartType> typeArguments,
  ) async {
    // fake it all type parameter in case of referenced it
    // do not use allTypeParams as final result
    final allTypeParams = typeArguments
        .map((e) => MacroProperty(name: '', importPrefix: '', type: e.getDisplayString(), typeInfo: TypeInfo.generic))
        .toList();

    final typeParams = <MacroProperty>[];

    for (final tp in typeArguments) {
      if (tp is TypeParameterType && tp.bound is! DynamicType) {
        final typeBoundRes = await getTypeInfoFrom(
          tp.bound,
          allTypeParams,
          capability.filterClassMethodMetadata,
          capability,
        );
        final bound = MacroProperty(
          name: '',
          importPrefix: typeBoundRes.importPrefix,
          type: typeBoundRes.type,
          typeInfo: typeBoundRes.typeInfo,
          functionTypeInfo: typeBoundRes.fnInfo,
          classInfo: typeBoundRes.classInfo,
          recordInfo: typeBoundRes.recordInfo,
          typeArguments: typeBoundRes.typeArguments,
          typeRefType: typeBoundRes.typeRefType,
          modifier: const MacroModifier({}),
          // constantValue: tp.element.bound!.getDisplayString(), // not needed since type has it
        );

        typeParams.add(
          MacroProperty(
            name: '',
            importPrefix: '',
            type: tp.getDisplayString(),
            typeInfo: TypeInfo.generic,
            bound: bound,
          ),
        );
        continue;
      }

      typeParams.add(
        MacroProperty(
          name: '',
          importPrefix: '',
          type: tp.getDisplayString(),
          typeInfo: TypeInfo.generic,
        ),
      );
    }

    return typeParams;
  }
}
