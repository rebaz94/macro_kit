import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:macro_kit/macro.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/types_ext.dart';

extension Types on BaseAnalyzer {
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

  Future<MacroConfig?> computeMacroMetadata(ElementAnnotation macroMetadata) async {
    final macro = macroMetadata.computeConstantValue();
    if (macro == null) return null;

    final generator = macro.peek('generator');
    final combineGeneratedClasses = macro.peek('combine')?.toBoolValue() ?? false;
    if (generator == null) return null;

    final cap = generator.peek('capability');
    if (cap == null) return null;

    List<String> fields;
    if (generator.type?.element case ClassElement cls) {
      fields = cls.fields.map((e) => e.name ?? '').toList();
    } else {
      return null;
    }

    final capability = MacroCapability(
      classConstructors: cap.peek('classConstructors')?.toBoolValue() ?? false,
      filterClassConstructorParameterMetadata:
          cap.peek('filterClassConstructorParameterMetadata')?.toStringValue() ?? '',
      mergeClassFieldWithConstructorParameter:
          cap.peek('mergeClassFieldWithConstructorParameter')?.toBoolValue() ?? false,
      classFields: cap.peek('classFields')?.toBoolValue() ?? false,
      filterClassInstanceFields: cap.peek('filterClassInstanceFields')?.toBoolValue() ?? false,
      filterClassStaticFields: cap.peek('filterClassStaticFields')?.toBoolValue() ?? false,
      filterClassIgnoreSetterOnly: cap.peek('filterClassIgnoreSetterOnly')?.toBoolValue() ?? true,
      filterClassFieldMetadata: cap.peek('filterClassFieldMetadata')?.toStringValue() ?? '',
      classMethods: cap.peek('classMethods')?.toBoolValue() ?? false,
      filterClassInstanceMethod: cap.peek('filterClassInstanceMethod')?.toBoolValue() ?? false,
      filterClassStaticMethod: cap.peek('filterClassStaticMethod')?.toBoolValue() ?? false,
      filterMethods: cap.peek('filterMethods')?.toStringValue() ?? '',
      filterClassMethodMetadata: cap.peek('filterClassMethodMetadata')?.toStringValue() ?? '',
      collectClassSubTypes: cap.peek('collectClassSubTypes')?.toBoolValue() ?? false,
      filterCollectSubTypes: cap.peek('filterCollectSubTypes')?.toStringValue() ?? '',
    );

    final List<MacroProperty> props = [];
    for (final fieldName in fields) {
      if (fieldName == 'capability') continue;

      final fieldValue = generator.peek(fieldName);
      if (fieldValue == null) continue;

      final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
        fieldValue.type,
        const [],
        '',
        capability,
      );
      final (:constantValue, :reqConversion, :modifier) = await computeMacroKeyValue(fieldName, fieldValue, capability);

      props.add(
        MacroProperty(
          name: fieldName,
          type: type,
          typeInfo: typeInfo,
          typeArguments: typeArguments,
          classInfo: classInfo,
          deepEquality: deepEq,
          functionTypeInfo: fnInfo,
          constantModifier: modifier,
          constantValue: constantValue,
          requireConversionToLiteral: reqConversion ? true : null,
        ),
      );
    }

    return MacroConfig(
      capability: capability,
      combine: combineGeneratedClasses,
      key: MacroKey(name: generator.type?.element?.displayName ?? '', properties: props),
    );
  }

  Future<List<MacroKey>?> computeMacroKeys(
    String filter,
    Metadata metadata,
    MacroCapability capability,
  ) async {
    List<MacroKey>? macroKeys;
    if (filter == '*') {
      macroKeys = (await Future.wait(
        metadata.annotations.map((e) => computeMacroKey(e, capability)),
      )).nonNulls.toList();
    } else if (filter.isNotEmpty) {
      final targetKeys = filter.split(',');
      macroKeys = (await Future.wait(
        metadata.annotations
            .where((elem) => targetKeys.contains(elem.element?.displayName))
            .map((e) => computeMacroKey(e, capability)),
      )).nonNulls.toList();
    }

    return macroKeys;
  }

  Future<MacroKey?> computeMacroKey(ElementAnnotation macroMetadata, MacroCapability capability) async {
    final frag = macroMetadata.element?.firstFragment;
    if (frag is! ConstructorFragment) return null;

    final fields = frag.formalParameters.map((e) => e.name ?? '').toList();

    final value = macroMetadata.computeConstantValue();
    if (value == null) {
      return null;
    }

    final List<MacroProperty> props = [];
    for (final fieldName in fields) {
      final fieldValue = value.peek(fieldName);
      if (fieldValue == null) continue;

      final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
        fieldValue.type,
        const [],
        '',
        capability,
      );
      final (:constantValue, :reqConversion, :modifier) = await computeMacroKeyValue(fieldName, fieldValue, capability);

      props.add(
        MacroProperty(
          name: fieldName,
          type: type,
          typeInfo: typeInfo,
          typeArguments: typeArguments,
          classInfo: classInfo,
          deepEquality: deepEq,
          functionTypeInfo: fnInfo,
          constantValue: constantValue,
          constantModifier: modifier,
          requireConversionToLiteral: reqConversion ? true : null,
        ),
      );
    }

    return MacroKey(name: macroMetadata.element?.displayName ?? '', properties: props);
  }

  Future<({Object? constantValue, MacroModifier modifier, bool reqConversion})?> computeConstantInitializerValue(
    String fieldName,
    DartObject fieldValue,
    MacroCapability capability,
  ) async {
    return computeMacroKeyValue(fieldName, fieldValue, capability);
  }

  /// return a tuple of dart representation of the literal along with
  /// regular value for the constant that can be encoded
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
        modifier: MacroModifier.create(isStatic: fieldFnValue.isStatic),
      );
    }
    // check maybe its Type
    else if (fieldValue.toTypeValue() case DartType typeValue) {
      final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
        typeValue,
        [],
        '',
        capability,
      );

      final typeProp = MacroProperty(
        name: '',
        type: type,
        typeInfo: typeInfo,
        functionTypeInfo: fnInfo,
        deepEquality: deepEq,
        classInfo: classInfo,
        typeArguments: typeArguments,
        modifier: getModifierInfoFrom(typeValue),
      );
      return (constantValue: typeProp, reqConversion: false, modifier: typeProp.modifier);
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
        return (
          constantValue: fieldValue.literalForObject(fieldName, []),
          reqConversion: true,
          modifier: MacroModifier.create(isConst: true),
        );
      } else {
        final object = fieldValue.literalForObject(fieldName, []);
        if (object != null) {
          return (constantValue: object, reqConversion: true, modifier: MacroModifier.create(isConst: true));
        }

        return const (constantValue: null, reqConversion: false, modifier: MacroModifier({}));
      }
    }
  }

  Future<
    ({
      MacroClassDeclaration? classInfo,
      bool? deepEq,
      MacroMethod? fnInfo,
      String type,
      List<MacroProperty>? typeArguments,
      TypeInfo typeInfo,
    })
  >
  getTypeInfoFrom(
    Object? /*Element?|DartType*/ elem,
    List<String> genericParams,
    String filterMethodMetadata,
    MacroCapability capability,
  ) async {
    final type = switch (elem) {
      FieldElement() => elem.type,
      FormalParameterElement() => elem.type,
      PropertyInducingElement() => elem.type,
      MethodElement() => elem.type,
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
        type: 'dynamic',
        typeInfo: TypeInfo.dynamic,
        typeArguments: null,
        fnInfo: null,
        classInfo: null,
        deepEq: false,
      );
    }

    final dartType = type.toString();

    var typeInfo = TypeInfo.dynamic;
    List<MacroProperty>? macroTypeArguments;
    MacroMethod? fnTypeInfo;
    MacroClassDeclaration? classInfo;
    bool? deepEquality;

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
      deepEquality = true;

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
      deepEquality = true;

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
      deepEquality = true;

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
      deepEquality = true;

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
          _ when genericParams.contains(typeElemName) => const (TypeInfo.generic, 'generic'),
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
      type: dartType,
      typeInfo: typeInfo,
      typeArguments: macroTypeArguments,
      fnInfo: fnTypeInfo,
      classInfo: classInfo,
      deepEq: deepEquality,
    );
  }

  Future<MacroMethod> getFunctionInfo(
    Object? method,
    List<String> genericParams, {
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
            name: '',
            type: 'void',
            typeInfo: TypeInfo.voidType,
          ),
        ],
        modifier: const MacroModifier({}),
        keys: macroKeys,
      );
    }

    final typeParams = fnType.typeParameters.map((e) => e.name ?? '').toList();
    final params = <MacroProperty>[];

    // parameters
    for (final param in fnType.formalParameters) {
      final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
        param,
        CombinedListView([typeParams, genericParams]),
        filterMethodMetadata,
        capability,
      );

      final macroKeys = await computeMacroKeys(filterMethodMetadata, param.metadata, capability);

      params.add(
        MacroProperty(
          name: param.name ?? '',
          type: type,
          typeInfo: typeInfo,
          deepEquality: deepEq,
          typeArguments: typeArguments,
          classInfo: classInfo,
          functionTypeInfo: fnInfo,
          modifier: getModifierInfoFrom(
            param,
            isNullable: param.type.nullabilitySuffix != NullabilitySuffix.none,
          ),
          keys: macroKeys,
        ),
      );
    }

    // returns
    final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
      returnType,
      CombinedListView([typeParams, genericParams]),
      filterMethodMetadata,
      capability,
    );

    final fnModifier = getModifierInfoFrom(
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
      returns: [
        MacroProperty(
          name: '',
          type: type,
          typeInfo: typeInfo,
          deepEquality: deepEq,
          classInfo: classInfo,
          functionTypeInfo: fnInfo,
          typeArguments: typeArguments,
          modifier: getModifierInfoFrom(
            returnType!,
            isNullable: returnType.nullabilitySuffix != NullabilitySuffix.none,
          ),
        ),
      ],
      modifier: fnModifier,
      keys: macroKeys,
    );
  }

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

  Future<List<MacroProperty>> createMacroTypeArguments(
    List<DartType> types,
    List<String> genericParams,
    MacroCapability capability,
    String filterMethodMetadata, {
    int? mustTake,
  }) async {
    final macroTypeArguments = <MacroProperty>[];
    for (final genericType in (mustTake == null ? types : types.take(mustTake))) {
      final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
        genericType,
        genericParams,
        filterMethodMetadata,
        capability,
      );
      macroTypeArguments.add(
        MacroProperty(
          name: '',
          type: type,
          typeInfo: typeInfo,
          deepEquality: deepEq,
          classInfo: classInfo,
          typeArguments: typeArguments,
          functionTypeInfo: fnInfo,
        ),
      );
    }

    if (mustTake != null) {
      for (int i = macroTypeArguments.length; i < mustTake; i++) {
        final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
          null,
          genericParams,
          filterMethodMetadata,
          capability,
        );

        macroTypeArguments.add(
          MacroProperty(
            name: '',
            type: type,
            typeInfo: typeInfo,
            deepEquality: deepEq,
            classInfo: classInfo,
            typeArguments: typeArguments,
            functionTypeInfo: fnInfo,
          ),
        );
      }
    }

    return macroTypeArguments;
  }

  Future<MacroProperty?> inspectStaticFromJson(
    DartType type,
    List<String> genericParams,
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

      final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
        firstParam.type,
        genericParams,
        filterMethodMetadata,
        capability,
      );
      return MacroProperty(
        name: '',
        type: type,
        typeInfo: typeInfo,
        deepEquality: deepEq,
        classInfo: classInfo,
        functionTypeInfo: fnInfo,
        typeArguments: typeArguments,
      );
    }

    return null;
  }

  MacroModifier getModifierInfoFrom(
    Object elem, {
    bool isNullable = false,
    bool isAsynchronous = false,
    bool isSynchronous = false,
    bool isGenerator = false,
    bool isAugmentation = false,
  }) {
    return switch (elem) {
      FieldElement() => MacroModifier.create(
        isConst: elem.isConst,
        isFinal: elem.isFinal,
        isLate: elem.isLate,
        isNullable: isNullable,
        isStatic: elem.isStatic,
        isPrivate: elem.isPrivate,
        isExternal: elem.isExternal,
        isAbstract: elem.isAbstract,
        isCovariant: elem.isCovariant,
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isGetProperty: elem.getter != null,
        isSetProperty: elem.setter != null,
        hasInitializer: elem.hasInitializer,
      ),
      FieldFormalParameterElement() => MacroModifier.create(
        isConst: elem.isConst,
        isFinal: elem.isFinal,
        isLate: elem.isLate,
        isNullable: isNullable,
        isStatic: elem.isStatic,
        isPrivate: elem.isPrivate,
        isCovariant: elem.isCovariant,
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isRequiredNamed: elem.isRequiredNamed,
        isRequiredPositional: elem.isRequiredPositional,
        hasDefaultValue: elem.hasDefaultValue,
        isInitializingFormal: elem.isInitializingFormal,
        fieldFormalParameter: true,
      ),
      FormalParameterElement() => MacroModifier.create(
        isConst: elem.isConst,
        isFinal: elem.isFinal,
        isLate: elem.isLate,
        isNullable: isNullable,
        isStatic: elem.isStatic,
        isPrivate: elem.isPrivate,
        isCovariant: elem.isCovariant,
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isRequiredNamed: elem.isRequiredNamed,
        isRequiredPositional: elem.isRequiredPositional,
        hasDefaultValue: elem.hasDefaultValue,
        isInitializingFormal: elem.isInitializingFormal,
        formalParameter: true,
      ),
      LocalVariableElement() => MacroModifier.create(
        isConst: elem.isConst,
        isFinal: elem.isFinal,
        isLate: elem.isLate,
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isNullable: isNullable,
        isStatic: elem.isStatic,
        isPrivate: elem.isPrivate,
        hasInitializer: elem.constantInitializer != null,
      ),
      TopLevelVariableElement() => MacroModifier.create(
        isConst: elem.isConst,
        isFinal: elem.isFinal,
        isLate: elem.isLate,
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isNullable: isNullable,
        isStatic: elem.isStatic,
        isPrivate: elem.isPrivate,
        isExternal: elem.isExternal,
        isGetProperty: elem.getter != null,
        isSetProperty: elem.setter != null,
        hasInitializer: elem.hasInitializer,
      ),
      VariableElement() => MacroModifier.create(
        isConst: elem.isConst,
        isFinal: elem.isFinal,
        isLate: elem.isLate,
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isNullable: isNullable,
        isStatic: elem.isStatic,
        isPrivate: elem.isPrivate,
      ),
      MethodElement() => MacroModifier.create(
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isNullable: isNullable,
        isStatic: elem.isStatic,
        isPrivate: elem.isPrivate,
        isExternal: elem.isExternal,
        isAbstract: elem.isAbstract,
        isOperator: elem.isOperator,
        isExtensionMember: elem.isExtensionTypeMember,
      ),
      ConstructorElement() => MacroModifier.create(
        isConst: elem.isConst,
        isFactory: elem.isFactory,
        isGenerative: elem.isGenerative,
        isDefaultConstructor: elem.isDefaultConstructor,
        isAugmentation: isAugmentation,
        isPrivate: elem.isPrivate,
        isExternal: elem.isExternal,
      ),
      ExecutableElement() => MacroModifier.create(
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isNullable: isNullable,
        isStatic: elem.isStatic,
        isPrivate: elem.isPrivate,
        isExternal: elem.isExternal,
        isAbstract: elem.isAbstract,
        isExtensionMember: elem.isExtensionTypeMember,
      ),
      DartType() => MacroModifier.create(
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isNullable: isNullable,
      ),
      _ => throw UnimplementedError('Getting modifier from: ${elem.runtimeType} is not implemented'),
    };
  }
}
