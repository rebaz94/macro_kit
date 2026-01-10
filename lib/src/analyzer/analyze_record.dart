import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/utils/hash.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/core/modifier.dart';

mixin AnalyzeRecord on BaseAnalyzer {
  @override
  Future<MacroRecordDeclaration?> parseRecord({
    required RecordType recordType,
    TypeAliasElement? recordTypeAliasElement,
    GenericTypeAlias? recordTypeAliasNode,
    Uri? libraryUri,
    List<Object /*DartType|TypeParameterElement*/>? typeArgumentOrParam,
    MacroCapability? fallbackCapability,
    bool forceParse = false,
    bool included = false,
  }) async {
    final typeAliasName = recordTypeAliasElement?.name;
    final typeAliasAnnotation = recordTypeAliasElement?.metadata.annotations;

    // combine all declared macro in one list and share with each config
    // (one class can have many metadata attached, we parsed config based on each metadata)
    List<MacroConfig> macroConfigs = [];
    Set<String> macroNames = {};
    bool combined = false;

    final recordName = typeAliasName ?? recordType.getDisplayString();

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

    final importPrefix = importPrefixByElements[recordTypeAliasElement] ?? '';
    final libraryPath = recordTypeAliasElement?.library.uri.toString() ?? libraryUri?.toString() ?? '';
    final libraryId = generateHash(libraryPath);
    libraryPathById[libraryId] = libraryPath;

    final (cacheKey, recordId) = recordDeclarationCachedKey(recordType, capability, typeAliasName, libraryPath);
    if (iterationCaches[cacheKey]?.value case MacroRecordDeclaration declaration) {
      iterationCaches[cacheKey] = iterationCaches[cacheKey]!.increaseCount();
      // override library id?
      return declaration.copyWith(recordId: recordId, configs: macroConfigs);
    }

    final recordModifier = MacroModifier.create(
      isAlias: typeAliasName?.isNotEmpty == true,
      isPrivate: recordTypeAliasElement?.isPrivate ?? false,
    );

    (recordFields, recordTypeParams) = await parseRecordFields(
      capability,
      recordType,
      recordTypeAliasNode,
      typeArgumentOrParam,
    );

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

    if (included) {
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
    GenericTypeAlias? recordTypeAliasNode,
    List<Object /*DartType|TypeParameterElement*/>? typeArgumentOrParam,
  ) async {
    final fields = <MacroProperty>[];
    final recordTypeParams = typeArgumentOrParam != null
        ? await parseRecordTypeParameter(capability, typeArgumentOrParam)
        : <MacroProperty>[];

    // Extract field metadata from AST
    Map<String, List<ElementAnnotation>> fieldMetadataMap = {};
    if (recordTypeAliasNode == null && recordType.alias?.element != null) {
      recordTypeAliasNode ??= await _getTypeAliasAstNode(recordType.alias!.element);
    }

    if (recordTypeAliasNode != null) {
      fieldMetadataMap = _extractRecordFieldMetadata(recordTypeAliasNode);
    }

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

      // Get metadata from the AST mapping
      List<MacroKey>? macroKeys;
      final fieldName = isPositionalField ? '\$${i + 1}' : (field as RecordTypeNamedField).name;
      final fieldAnnotations = fieldMetadataMap[fieldName];

      if (fieldAnnotations?.isNotEmpty == true) {
        macroKeys = await computeMacroKeys(
          filter: capability.filterClassFieldMetadata,
          capability: capability,
          annotations: fieldAnnotations!,
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
          name: fieldName,
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

  /// Get the AST node for a TypeAliasElement
  Future<GenericTypeAlias?> _getTypeAliasAstNode(TypeAliasElement aliasElement) async {
    final libraryFragment = aliasElement.library.firstFragment;
    final source = libraryFragment.source;

    final session = currentSession!;
    final result = await session.getResolvedUnit(source.fullName);
    if (result is! ResolvedUnitResult) return null;

    // Find the typedef declaration
    for (final declaration in result.unit.declarations) {
      if (declaration is GenericTypeAlias) {
        if (declaration.declaredFragment?.element == aliasElement) {
          return declaration;
        }
      }
    }

    return null;
  }

  /// Extract metadata from the AST
  Map<String, List<ElementAnnotation>> _extractRecordFieldMetadata(GenericTypeAlias typeAliasNode) {
    final result = <String, List<ElementAnnotation>>{};

    final typeAnnotation = typeAliasNode.type;
    if (typeAnnotation is! RecordTypeAnnotation) return result;

    // positional fields
    for (final (index, field) in typeAnnotation.positionalFields.indexed) {
      if (field.metadata.isNotEmpty) {
        final annotations = field.metadata.map((m) => m.elementAnnotation).whereType<ElementAnnotation>().toList();
        result['\$${index + 1}'] = annotations;
      }
    }

    // named fields
    for (final field in typeAnnotation.namedFields?.fields ?? const <RecordTypeAnnotationNamedField>[]) {
      if (field.metadata.isNotEmpty) {
        final annotations = field.metadata.map((m) => m.elementAnnotation).whereType<ElementAnnotation>().toList();
        result[field.name.lexeme] = annotations;
      }
    }

    return result;
  }

  @override
  Future<List<MacroProperty>> parseRecordTypeParameter(
    MacroCapability capability,
    List<Object /*DartType|TypeParameterElement*/> typeArgumentsOrParams,
  ) async {
    // fake it all type parameter in case of referenced it
    // do not use allTypeParams as final result
    assert(typeArgumentsOrParams is List<DartType> || typeArgumentsOrParams is List<TypeParameterElement>);

    final allTypeParams = typeArgumentsOrParams
        .map(
          (e) => MacroProperty(
            name: '',
            importPrefix: '',
            type: e is DartType ? e.getDisplayString() : (e as TypeParameterElement).name ?? '',
            typeInfo: TypeInfo.generic,
          ),
        )
        .toList();

    final typeParams = <MacroProperty>[];
    for (final tp in typeArgumentsOrParams) {
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

      if (tp is DartType) {
        typeParams.add(
          MacroProperty(
            name: '',
            importPrefix: '',
            type: tp.getDisplayString(),
            typeInfo: TypeInfo.generic,
          ),
        );
      }
    }

    return typeParams;
  }
}
