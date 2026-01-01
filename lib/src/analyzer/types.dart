import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/constant/value.dart';
import 'package:collection/collection.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/types_ext.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/core/modifier.dart';

typedef TypeInfoResult = ({
  String importPrefix,
  String type,
  TypeInfo typeInfo,
  MacroClassDeclaration? classInfo,
  MacroMethod? fnInfo,
  List<MacroProperty>? typeArguments,

  /// The type that assigned to [Type] from dart
  MacroProperty? typeRefType,
});

mixin Types on BaseAnalyzer {
  @override
  bool isValidAnnotation(
    ElementAnnotation? annotation, {
    required String className,
    required String pkgName,
  }) {
    final (annotClassName, library) = switch (annotation?.element) {
      GetterElement elem => (elem.returnType.element?.displayName, elem.returnType.element?.library),
      _ => (annotation?.element?.displayName, annotation?.element?.library),
    };
    if (annotClassName != className) return false;

    final pkg = library?.uri.toString() ?? '';
    return pkg.startsWith('package:$pkgName');
  }

  bool interfaceTypesEqual(DartType a, DartType b) {
    if (a is InterfaceType && b is InterfaceType) {
      return a.element == b.element;
    }
    return a == b;
  }

  @override
  Future<MacroConfig?> computeMacroMetadata(ElementAnnotation macroMetadata) async {
    final macro = macroMetadata.computeConstantValue();
    if (macro == null) return null;

    final generator = macro.peek('generator');
    final combineGeneratedClasses = macro.peek('combine')?.toBoolValue() ?? false;
    if (generator == null) return null;

    final cap = generator.peek('capability');
    if (cap == null) return null;

    final fields = (generator as DartObjectImpl).fields?.keys.toList() ?? const [];
    final capability = MacroCapability(
      classFields: cap.peek('classFields')?.toBoolValue() ?? false,
      filterClassInstanceFields: cap.peek('filterClassInstanceFields')?.toBoolValue() ?? false,
      filterClassStaticFields: cap.peek('filterClassStaticFields')?.toBoolValue() ?? false,
      filterClassIgnoreSetterOnly: cap.peek('filterClassIgnoreSetterOnly')?.toBoolValue() ?? true,
      filterClassIncludeAnnotatedFieldOnly: cap.peek('filterClassIncludeAnnotatedFieldOnly')?.toBoolValue() ?? false,
      filterClassFieldMetadata: cap.peek('filterClassFieldMetadata')?.toStringValue() ?? '',
      classConstructors: cap.peek('classConstructors')?.toBoolValue() ?? false,
      filterClassConstructorParameterMetadata:
          cap.peek('filterClassConstructorParameterMetadata')?.toStringValue() ?? '',
      mergeClassFieldWithConstructorParameter:
          cap.peek('mergeClassFieldWithConstructorParameter')?.toBoolValue() ?? false,
      inspectFieldInitializer: cap.peek('inspectFieldInitializer')?.toBoolValue() ?? false,
      classMethods: cap.peek('classMethods')?.toBoolValue() ?? false,
      filterClassInstanceMethod: cap.peek('filterClassInstanceMethod')?.toBoolValue() ?? false,
      filterClassStaticMethod: cap.peek('filterClassStaticMethod')?.toBoolValue() ?? false,
      filterClassIncludeAnnotatedMethodOnly: cap.peek('filterClassIncludeAnnotatedMethodOnly')?.toBoolValue() ?? false,
      filterMethods: cap.peek('filterMethods')?.toStringValue() ?? '',
      filterClassMethodMetadata: cap.peek('filterClassMethodMetadata')?.toStringValue() ?? '',
      topLevelFunctions: cap.peek('topLevelFunctions')?.toBoolValue() ?? false,
      collectClassSubTypes: cap.peek('collectClassSubTypes')?.toBoolValue() ?? false,
      filterCollectSubTypes: cap.peek('filterCollectSubTypes')?.toStringValue() ?? '',
    );

    final List<MacroProperty> props = [];
    for (final fieldName in fields) {
      if (fieldName == 'capability' || fieldName == '(super)') continue;

      final fieldValue = generator.peek(fieldName);
      if (fieldValue == null) continue;

      final typeRes = await getTypeInfoFrom(fieldValue, const [], '', capability);
      final valueRes = await computeMacroKeyValue(fieldName, fieldValue, capability);

      props.add(
        MacroProperty(
          name: fieldName,
          importPrefix: typeRes.importPrefix,
          type: typeRes.type,
          typeInfo: typeRes.typeInfo,
          typeArguments: typeRes.typeArguments,
          classInfo: typeRes.classInfo,
          functionTypeInfo: typeRes.fnInfo,
          typeRefType: typeRes.typeRefType,
          fieldInitializer: null,
          constantModifier: valueRes.modifier,
          constantValue: valueRes.constantValue,
          requireConversionToLiteral: valueRes.reqConversion ? true : null,
        ),
      );
    }

    return MacroConfig(
      capability: capability,
      combine: combineGeneratedClasses,
      key: MacroKey(name: generator.type.element?.displayName ?? '', properties: props),
    );
  }

  @override
  Future<List<MacroKey>?> computeMacroKeys(String filter, Metadata metadata, MacroCapability capability) async {
    if (filter.isEmpty) return null;

    final targetKeys = filter == '*' ? null : filter.split(',');
    final keys = <MacroKey>[];

    for (final elem in metadata.annotations) {
      final name = switch (elem.element) {
        GetterElement getterElement => getterElement.returnType.element?.displayName ?? '',
        _ => elem.element?.displayName ?? '',
      };
      if (targetKeys?.contains(name) == false) continue;

      final res = await computeMacroKey(name, elem, capability);
      if (res != null) {
        keys.add(res);
      }
    }

    return keys.isEmpty ? null : keys;
  }

  @override
  Future<MacroKey?> computeMacroKey(String keyName, ElementAnnotation macroMetadata, MacroCapability capability) async {
    final DartObject? value = macroMetadata.computeConstantValue();
    if (value == null) return null;

    // use dart analyzer internal fields property
    final fields = (value as DartObjectImpl).fields?.keys.toList() ?? const [];
    final List<MacroProperty> props = [];

    for (final fieldName in fields) {
      final fieldValue = value.peek(fieldName);
      if (fieldValue == null) continue;

      final typeRes = await getTypeInfoFrom(fieldValue, const [], '', capability);
      final valueRes = await computeMacroKeyValue(fieldName, fieldValue, capability);

      props.add(
        MacroProperty(
          name: fieldName,
          importPrefix: typeRes.importPrefix,
          type: typeRes.type,
          typeInfo: typeRes.typeInfo,
          typeArguments: typeRes.typeArguments,
          classInfo: typeRes.classInfo,
          functionTypeInfo: typeRes.fnInfo,
          typeRefType: typeRes.typeRefType,
          fieldInitializer: null,
          constantValue: valueRes.constantValue,
          constantModifier: valueRes.modifier,
          requireConversionToLiteral: valueRes.reqConversion ? true : null,
        ),
      );
    }

    return MacroKey(name: keyName, properties: props);
  }

  @override
  Future<({Object? constantValue, MacroModifier modifier, bool reqConversion})?> computeConstantInitializerValue(
    String fieldName,
    DartObject fieldValue,
    MacroCapability capability,
  ) async {
    return computeMacroKeyValue(fieldName, fieldValue, capability);
  }

  /// return a tuple of dart representation of the literal along with
  /// regular value for the constant that can be encoded
  @override
  Future<({Object? constantValue, MacroModifier modifier, bool reqConversion})> computeMacroKeyValue(
    String fieldName,
    DartObject fieldValue,
    MacroCapability capability,
  ) async {
    if (fieldValue.literalValueOrNull() case final Object value) {
      return (constantValue: value, reqConversion: true, modifier: const MacroModifier({}));
    }

    final fieldFnValue = fieldValue.toFunctionValue();
    if (fieldFnValue != null && fieldFnValue.displayName.isNotEmpty) {
      // field value is a function or constructor
      final isConstructor = fieldFnValue is ConstructorElement;
      final invokeConst = (isConstructor && fieldFnValue.isConst) ? 'const ' : '';
      final result = '$invokeConst${fieldFnValue.qualifiedName}';
      return (
        constantValue: result,
        reqConversion: false,
        modifier: MacroModifier.create(
          isStatic: fieldFnValue.isStatic,
          // it consider a factory function if used function is constructor
          isFactory: fieldFnValue.kind == ElementKind.CONSTRUCTOR,
        ),
      );
    }
    // check maybe its enum
    else if (fieldValue.type?.element?.kind == ElementKind.ENUM) {
      final result = '${fieldValue.type!.element!.name}.${fieldValue.variable!.name}';
      return (constantValue: result, reqConversion: false, modifier: MacroModifier.create(isConst: true));
    }
    // check maybe its a constant constructor or a literal value
    else {
      if (fieldValue.hasKnownValue &&
          fieldValue.constructorInvocation != null &&
          fieldValue.constructorInvocation?.constructor.isConst == true) {
        // final result = 'const ${fieldValue.constructorInvocation!.constructor.qualifiedName}()';
        // library developer should use type information to build a literal dart constant value
        // we encode it, so that can be transferred between process
        final object = await runZoneGuarded(
          fn: () => fieldValue.literalForObject(fieldName, [], analyzer: this, capability: capability),
          values: {#imports: importPrefixByElements},
        );
        return (
          constantValue: object,
          reqConversion: true,
          modifier: MacroModifier.create(isConst: true),
        );
      } else {
        final object = await runZoneGuarded(
          fn: () => fieldValue.literalForObject(fieldName, [], analyzer: this, capability: capability),
          values: {#imports: importPrefixByElements},
        );
        if (object != null) {
          return (constantValue: object, reqConversion: true, modifier: MacroModifier.create(isConst: true));
        }

        return const (constantValue: null, reqConversion: false, modifier: MacroModifier({}));
      }
    }
  }

  @override
  Future<TypeInfoResult> getTypeInfoFrom(
    Object? /*Element?|DartType*/ elem,
    List<MacroProperty> genericParams,
    String filterMethodMetadata,
    MacroCapability capability,
  ) async {
    final DartType? type = switch (elem) {
      DartObject() => elem.type,
      FieldElement() => elem.type,
      FormalParameterElement() => elem.type,
      PropertyInducingElement() => elem.type,
      MethodElement() => elem.type,
      FunctionType() => elem,
      DartType() => elem,
      _ => () {
        if (elem != null) {
          logger.warn('Unable to extract type from element properly, elem type: ${elem.runtimeType}');
        }
        return null;
      }(),
    };
    if (type == null) {
      return (
        importPrefix: '',
        type: 'dynamic',
        typeInfo: TypeInfo.dynamic,
        typeArguments: null,
        fnInfo: null,
        classInfo: null,
        typeRefType: null,
      );
    }

    final dartType = type.toString();
    final importPrefix = importPrefixByElements[type.element] ?? importPrefixByElements[elem] ?? '';

    var typeInfo = TypeInfo.dynamic;
    List<MacroProperty>? macroTypeArguments;
    MacroMethod? fnTypeInfo;
    MacroClassDeclaration? classInfo;
    MacroProperty? typeRefType;

    if (type.isDartCoreInt) {
      typeInfo = TypeInfo.int;
    } else if (type.isDartCoreDouble) {
      typeInfo = TypeInfo.double;
    } else if (type.isDartCoreNum) {
      typeInfo = TypeInfo.num;
    } else if (type.isDartCoreString) {
      typeInfo = TypeInfo.string;
    } else if (type.isDartCoreBool) {
      typeInfo = TypeInfo.boolean;
    } else if (type.isDartCoreIterable) {
      typeInfo = TypeInfo.iterable;

      final typeArguments = getTypeArguments(type, 'iterable');
      macroTypeArguments = await createMacroTypeArguments(
        typeArguments,
        genericParams,
        capability,
        filterMethodMetadata,
        mustTake: 1,
      );
    } else if (type.isDartCoreList) {
      typeInfo = TypeInfo.list;

      final typeArguments = getTypeArguments(type, 'list');
      macroTypeArguments = await createMacroTypeArguments(
        typeArguments,
        genericParams,
        capability,
        filterMethodMetadata,
        mustTake: 1,
      );
    } else if (type.isDartCoreMap) {
      typeInfo = TypeInfo.map;

      final typeArguments = getTypeArguments(type, 'map');
      macroTypeArguments = await createMacroTypeArguments(
        typeArguments,
        genericParams,
        capability,
        filterMethodMetadata,
        mustTake: 2,
      );
    } else if (type.isDartCoreSet) {
      typeInfo = TypeInfo.set;

      final typeArguments = getTypeArguments(type, 'set');
      macroTypeArguments = await createMacroTypeArguments(
        typeArguments,
        genericParams,
        capability,
        filterMethodMetadata,
        mustTake: 1,
      );
    } else if (type.isDartCoreEnum) {
      // Consider the dart:core#Enum as Object because
      // we don't know how to initiate the value,
      // the user defined type considered as enum type which can be [Enum]
      typeInfo = TypeInfo.object;
    } else if (type.isDartCoreRecord) {
      typeInfo = TypeInfo.record;
    } else if (type.isDartCoreSymbol) {
      typeInfo = TypeInfo.symbol;
    } else if (type.isDartCoreFunction) {
      typeInfo = TypeInfo.function;
    } else if (type.isDartCoreNull) {
      typeInfo = TypeInfo.nullType;
    } else if (type.isDartCoreType) {
      typeInfo = TypeInfo.type;

      final mainType = type;
      if (elem is DartObject) {
        final typeRes = await getTypeInfoFrom(elem.toTypeValue(), [], '', capability);
        typeRefType = MacroProperty(
          name: typeRes.type,
          importPrefix: typeRes.importPrefix,
          type: typeRes.type,
          typeInfo: typeRes.typeInfo,
          functionTypeInfo: typeRes.fnInfo,
          classInfo: typeRes.classInfo,
          typeRefType: typeRes.typeRefType,
          typeArguments: typeRes.typeArguments,
          modifier: MacroModifier.getModifierInfoFrom(mainType),
          fieldInitializer: null,
        );
      }
    } else if (type.isDartCoreObject) {
      typeInfo = TypeInfo.object;
    } else if (type is VoidType) {
      typeInfo = TypeInfo.voidType;
    } else if (type is FunctionType) {
      typeInfo = TypeInfo.function;
      fnTypeInfo = await getFunctionInfo(
        type,
        genericParams,
        capability: capability,
        filterMethodMetadata: filterMethodMetadata,
        fnName: '',
        macroKeys: null, // TODO: does passing null is correct?
      );
    } else {
      final typeElem = type.element;
      final typeElemName = typeElem?.name;
      final isFromDartCore = typeElem?.library?.isDartCore == true;
      final isFromDartAsync = typeElem?.library?.isDartAsync == true;

      Future<TypeInfo> fallbackCase() async {
        String forName;
        (typeInfo, forName) = switch (typeElem?.kind) {
          _ when genericParams.firstWhereOrNull((e) => e.name == typeElemName) != null => const (
            TypeInfo.generic,
            'generic',
          ),
          ElementKind.CLASS => const (TypeInfo.clazz, 'class'),
          ElementKind.CLASS_AUGMENTATION => const (TypeInfo.clazzAugmentation, 'class_augmentation'),
          ElementKind.EXTENSION => const (TypeInfo.extension, 'extension'),
          ElementKind.EXTENSION_TYPE => const (TypeInfo.extensionType, 'extension_type'),
          ElementKind.ENUM => const (TypeInfo.enumData, 'enum'),
          _ => const (TypeInfo.dynamic, 'dynamic'),
        };

        final typeArguments = getTypeArguments(type, forName);
        if (typeArguments.isNotEmpty) {
          macroTypeArguments = await createMacroTypeArguments(
            typeArguments,
            genericParams,
            capability,
            filterMethodMetadata,
          );
        }

        if (typeInfo == TypeInfo.clazz && typeElem is ClassElement) {
          final classFragment = typeElem.firstFragment;
          classInfo = await parseClass(classFragment);
        } else if (typeInfo == TypeInfo.enumData && typeElem is EnumElement) {
          classInfo = await parseEnum(typeElem.firstFragment, fallbackCapability: capability);
        }
        // TODO: do we need to inspect augment class?

        return typeInfo;
      }

      if (isFromDartAsync) {
        if (typeElemName == 'Future' || typeElemName == 'Stream') {
          typeInfo = typeElemName!.startsWith('F') ? TypeInfo.future : TypeInfo.stream;

          final typeArguments = getTypeArguments(type, typeElemName.toLowerCase());
          macroTypeArguments = await createMacroTypeArguments(
            typeArguments,
            genericParams,
            capability,
            filterMethodMetadata,
            mustTake: 1,
          );
        } else {
          await fallbackCase();
        }
      } else if (isFromDartCore) {
        typeInfo = await switch (typeElemName) {
          'dynamic' => TypeInfo.dynamic,
          'Duration' => TypeInfo.duration,
          'DateTime' => TypeInfo.datetime,
          'BigInt' => TypeInfo.bigInt,
          'Uri' => TypeInfo.uri,
          _ => fallbackCase(),
        };
      } else {
        await fallbackCase();
      }
    }

    return (
      importPrefix: importPrefix,
      type: dartType,
      typeInfo: typeInfo,
      typeArguments: macroTypeArguments,
      fnInfo: fnTypeInfo,
      classInfo: classInfo,
      typeRefType: typeRefType,
    );
  }

  @override
  Future<MacroMethod> getFunctionInfo(
    Object? method,
    List<MacroProperty> genericParams, {
    required MacroCapability capability,
    required String filterMethodMetadata,
    required List<MacroKey>? macroKeys,
    String? fnName,
    bool isAsynchronous = false,
    bool isSynchronous = false,
    bool isGenerator = false,
    bool isAugmentation = false,
  }) async {
    final (fnType, returnType, methodName) = switch (method) {
      MethodElement() => (method.type, method.returnType, method.name),
      ExecutableElement() => (method.type, method.returnType, method.name),
      FunctionType() => (method, method.returnType, fnName ?? ''),
      _ => () {
        if (method != null) {
          logger.warn('Unable to extract type from element properly, elem type: ${method.runtimeType}');
        }
        return (null, null, null);
      }(),
    };
    if (fnType == null) {
      return MacroMethod(
        name: '',
        typeParams: const [],
        params: const [],
        returns: [
          MacroProperty(
            importPrefix: '',
            name: '',
            type: 'void',
            typeInfo: TypeInfo.voidType,
            fieldInitializer: null,
          ),
        ],
        modifier: const MacroModifier({}),
        keys: macroKeys,
      );
    }

    final typeParams = await parseTypeParameter(capability, fnType.typeParameters);
    final params = <MacroProperty>[];

    // parameters
    for (final param in fnType.formalParameters) {
      final typeRes = await getTypeInfoFrom(
        param,
        CombinedListView([typeParams, genericParams]),
        filterMethodMetadata,
        capability,
      );
      final macroKeys = await computeMacroKeys(filterMethodMetadata, param.metadata, capability);
      final defaultValue = param.computeConstantValue();
      final paramConstantValue = defaultValue == null
          ? null
          : await computeConstantInitializerValue(param.name ?? '', defaultValue, capability);

      params.add(
        MacroProperty(
          name: param.name ?? '',
          importPrefix: typeRes.importPrefix,
          type: typeRes.type,
          typeInfo: typeRes.typeInfo,
          typeArguments: typeRes.typeArguments,
          classInfo: typeRes.classInfo,
          functionTypeInfo: typeRes.fnInfo,
          typeRefType: typeRes.typeRefType,
          modifier: MacroModifier.getModifierInfoFrom(
            param,
            isNullable: param.type.nullabilitySuffix != NullabilitySuffix.none,
          ),
          keys: macroKeys,
          fieldInitializer: null,
          requireConversionToLiteral: paramConstantValue?.reqConversion,
          constantValue: paramConstantValue?.constantValue,
          constantModifier: paramConstantValue?.modifier,
        ),
      );
    }

    // return type
    final returnTypeRes = await getTypeInfoFrom(
      returnType,
      CombinedListView([typeParams, genericParams]),
      filterMethodMetadata,
      capability,
    );
    final returnTypeProp = MacroProperty(
      name: '',
      importPrefix: returnTypeRes.importPrefix,
      type: returnTypeRes.type,
      typeInfo: returnTypeRes.typeInfo,
      classInfo: returnTypeRes.classInfo,
      functionTypeInfo: returnTypeRes.fnInfo,
      typeRefType: returnTypeRes.typeRefType,
      typeArguments: returnTypeRes.typeArguments,
      modifier: MacroModifier.getModifierInfoFrom(
        returnType!,
        isNullable: returnType.nullabilitySuffix != NullabilitySuffix.none,
      ),
      fieldInitializer: null,
    );

    // fn modifier
    final fnModifier = MacroModifier.getModifierInfoFrom(
      method!,
      isNullable: fnType.nullabilitySuffix != NullabilitySuffix.none,
      isAsynchronous: isAsynchronous,
      isSynchronous: isSynchronous,
      isGenerator: isGenerator,
      isAugmentation: isAugmentation,
    );

    return MacroMethod(
      name: methodName ?? '',
      typeParams: typeParams,
      params: params,
      returns: [returnTypeProp],
      modifier: fnModifier,
      keys: macroKeys,
    );
  }

  @override
  List<DartType> getTypeArguments(DartType type, String forName) {
    if (type is ParameterizedType) {
      return type.typeArguments;
    } else if (type is TypeParameterType) {
      // type is T generic
      return const [];
    } else if (type is DynamicType) {
      return const [];
    }

    logger.warn(
      'Expected type arguments for request of: `$forName` with DarType of: `${type.toString()}` but the actual type is: ${type.runtimeType}',
    );

    return const [];
  }

  @override
  Future<List<MacroProperty>> createMacroTypeArguments(
    List<DartType> types,
    List<MacroProperty> genericParams,
    MacroCapability capability,
    String filterMethodMetadata, {
    int? mustTake,
  }) async {
    final macroTypeArguments = <MacroProperty>[];
    for (final genericType in (mustTake == null ? types : types.take(mustTake))) {
      final typeRes = await getTypeInfoFrom(genericType, genericParams, filterMethodMetadata, capability);

      macroTypeArguments.add(
        MacroProperty(
          name: '',
          importPrefix: typeRes.importPrefix,
          type: typeRes.type,
          typeInfo: typeRes.typeInfo,
          classInfo: typeRes.classInfo,
          typeArguments: typeRes.typeArguments,
          functionTypeInfo: typeRes.fnInfo,
          typeRefType: typeRes.typeRefType,
          fieldInitializer: null,
        ),
      );
    }

    if (mustTake != null) {
      for (int i = macroTypeArguments.length; i < mustTake; i++) {
        final typeRes = await getTypeInfoFrom(
          null,
          genericParams,
          filterMethodMetadata,
          capability,
        );

        macroTypeArguments.add(
          MacroProperty(
            name: '',
            importPrefix: typeRes.importPrefix,
            type: typeRes.type,
            typeInfo: typeRes.typeInfo,
            classInfo: typeRes.classInfo,
            typeArguments: typeRes.typeArguments,
            functionTypeInfo: typeRes.fnInfo,
            typeRefType: typeRes.typeRefType,
            fieldInitializer: null,
          ),
        );
      }
    }

    return macroTypeArguments;
  }

  @override
  Future<MacroProperty?> inspectStaticFromJson(
    DartType type,
    List<MacroProperty> genericParams,
    String filterMethodMetadata,
    MacroCapability capability,
  ) async {
    MethodElement? fromJsonFn;
    if (type.element case final InstanceElement v) {
      fromJsonFn = v.methods.firstWhereOrNull((e) => e.isStatic && e.name == 'fromJson');

      final firstParam = fromJsonFn?.formalParameters.firstOrNull;
      if (firstParam == null) {
        return null;
      }

      final paramTypeRes = await getTypeInfoFrom(
        firstParam.type,
        genericParams,
        filterMethodMetadata,
        capability,
      );

      return MacroProperty(
        name: '',
        importPrefix: paramTypeRes.importPrefix,
        type: paramTypeRes.type,
        typeInfo: paramTypeRes.typeInfo,
        classInfo: paramTypeRes.classInfo,
        functionTypeInfo: paramTypeRes.fnInfo,
        typeRefType: paramTypeRes.typeRefType,
        typeArguments: paramTypeRes.typeArguments,
        fieldInitializer: null,
      );
    }

    return null;
  }
}
