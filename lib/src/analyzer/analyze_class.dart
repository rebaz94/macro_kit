import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:collection/collection.dart';
import 'package:hashlib/hashlib.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/types.dart';
import 'package:macro_kit/src/core/core.dart';

mixin AnalyzeClass on BaseAnalyzer {
  bool lockOrReturnInProgressClassFieldsFor(String? clsName) {
    final key = 'inProgress:$clsName';
    if (iterationCaches.containsKey(key)) {
      return true;
    }

    iterationCaches[key] = CountedCache(true);
    return false;
  }

  void clearInProgressClassFieldsFor(String? clsName) {
    iterationCaches.remove('inProgress:$clsName');
  }

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

    final className = typeAliasClassName ?? classFragment.element.name;

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

    final (cacheKey, classId) = _classDeclarationCachedKey(classFragment, capability, typeAliasClassName);
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
      (classFields, classTypeParams, isInProgress) = await parseClassFields(capability, classFragment, null);
      if (isInProgress) {
        return MacroClassDeclaration.pendingDeclaration(
          classId: classId,
          className: className ?? '',
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
          classId: classId,
          className: className ?? '',
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
          classId: classId,
          className: className ?? '',
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
      className: className ?? '',
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

  Future<(List<MacroProperty>?, List<String>?, bool)> parseClassFields(
    MacroCapability capability,
    ClassFragment classFragment,
    List<String>? classTypeParams,
  ) async {
    if (!capability.classFields) {
      return (null, classTypeParams, false);
    }

    bool? onlyInstanceField;
    {
      final inst = capability.filterClassInstanceFields;
      final stat = capability.filterClassStaticFields;

      if (!inst && !stat) return (null, classTypeParams, false);

      onlyInstanceField = inst == stat
          ? null
          : inst
          ? true
          : false;
    }

    // return for nested class field with same type, only the first one
    // get types of the class fields, nested one is null,
    // its user code and its responsibility to handle that,
    if (lockOrReturnInProgressClassFieldsFor(classFragment.name)) {
      return (null, classTypeParams, true);
    }

    final classFields = <MacroProperty>[];
    classTypeParams ??= classFragment.typeParameters.map((e) => e.name ?? '').toList();

    for (int i = 0; i < classFragment.fields.length; i++) {
      final field = classFragment.fields[i];
      final fieldElem = field.element;

      if (onlyInstanceField != null) {
        final isInstance = !fieldElem.isStatic;
        if (onlyInstanceField != isInstance) {
          continue;
        }
      }

      final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
        fieldElem,
        classTypeParams,
        capability.filterClassMethodMetadata,
        capability,
      );

      if (capability.filterClassIgnoreSetterOnly && fieldElem.getter == null && fieldElem.setter != null) {
        // ignore setter property
        continue;
      }

      var macroKeys = await computeMacroKeys(capability.filterClassFieldMetadata, field.metadata, capability);
      if (fieldElem.getter != null && fieldElem.getter!.metadata.annotations.isNotEmpty) {
        final getterMacroKeys = await computeMacroKeys(
          capability.filterClassFieldMetadata,
          fieldElem.getter!.metadata,
          capability,
        );
        macroKeys ??= [];
        macroKeys.addAll(getterMacroKeys ?? const []);
      }

      if (fieldElem.setter != null && fieldElem.setter!.metadata.annotations.isNotEmpty) {
        final setterMacroKeys = await computeMacroKeys(
          capability.filterClassFieldMetadata,
          fieldElem.setter!.metadata,
          capability,
        );
        macroKeys ??= [];
        macroKeys.addAll(setterMacroKeys ?? const []);
      }

      classFields.add(
        MacroProperty(
          name: field.name ?? '',
          type: type,
          typeInfo: typeInfo,
          functionTypeInfo: fnInfo,
          deepEquality: deepEq,
          classInfo: classInfo,
          typeArguments: typeArguments,
          modifier: getModifierInfoFrom(
            fieldElem,
            isNullable: field.element.type.nullabilitySuffix != NullabilitySuffix.none,
            isAugmentation: field.isAugmentation,
          ),
          keys: macroKeys,
        ),
      );
    }

    clearInProgressClassFieldsFor(classFragment.name);
    return (classFields, classTypeParams, false);
  }

  Future<(List<MacroClassConstructor>, List<String>?, bool)> parseClassConstructors(
    MacroCapability capability,
    ClassFragment classFragment,
    List<String>? classTypeParams,
    List<MacroProperty>? classFields,
  ) async {
    if (!capability.classConstructors) {
      return (<MacroClassConstructor>[], classTypeParams, true);
    }

    // return for nested class field with same type, only the first one
    // get types of the class fields, nested one is null,
    // its user code and its responsibility to handle that,
    if (lockOrReturnInProgressClassFieldsFor(classFragment.name)) {
      return (<MacroClassConstructor>[], classTypeParams, true);
    }

    classTypeParams ??= classFragment.typeParameters.map((e) => e.name ?? '').toList();
    final constructors = <MacroClassConstructor>[];

    for (int k = 0; k < classFragment.constructors.length; k++) {
      final ConstructorFragment constructor = classFragment.constructors[k];
      List<MacroProperty> constructorPosFields = [];
      List<MacroProperty> constructorNamedFields = [];

      final constructorDec = await getConstructorDeclaration(constructor.element);
      Map<String, MacroProperty>? constructorInitializer;

      final params = constructor.formalParameters;
      for (int i = 0; i < params.length; i++) {
        final param = params[i];
        final paramElem = param.element;

        final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
          paramElem,
          classTypeParams,
          capability.filterClassMethodMetadata,
          capability,
        );

        final paramName = param.name ?? '';

        // get @[Key] from the constructor or from classFields if exists
        var macroKeys = await computeMacroKeys(
          capability.filterClassConstructorParameterMetadata,
          param.metadata,
          capability,
        );

        if (capability.mergeClassFieldWithConstructorParameter) {
          List<MacroKey>? fieldMacroKeys;

          if (classFields == null) {
            final classField = classFragment.fields.firstWhereOrNull((e) => e.name == paramName);
            if (classField != null) {
              fieldMacroKeys = await computeMacroKeys(
                capability.filterClassConstructorParameterMetadata,
                classField.metadata,
                capability,
              );
            }
          } else {
            fieldMacroKeys = classFields.firstWhereOrNull((e) => e.name == paramName)?.keys;
          }

          if (fieldMacroKeys != null) {
            if (macroKeys != null) {
              macroKeys.addAll(fieldMacroKeys);
            } else {
              macroKeys = fieldMacroKeys;
            }
          }
        } else {
          final fieldMacroKeys = classFields?.firstWhereOrNull((e) => e.name == paramName)?.keys;
          macroKeys?.addAll(fieldMacroKeys ?? const []);
        }

        Object? paramConstantValue;
        MacroModifier? paramConstantModifier;
        bool? paramConstantConversionToLiteral;

        if (paramElem.computeConstantValue() case DartObject constantValue) {
          final computed = await computeConstantInitializerValue(paramName, constantValue, capability);

          if (computed != null) {
            (
              constantValue: paramConstantValue,
              modifier: paramConstantModifier,
              reqConversion: paramConstantConversionToLiteral,
            ) = computed;
          }
        }

        final macroParam = MacroProperty(
          name: paramName,
          type: type,
          typeInfo: typeInfo,
          classInfo: classInfo,
          functionTypeInfo: fnInfo,
          deepEquality: deepEq,
          typeArguments: typeArguments,
          modifier: getModifierInfoFrom(
            paramElem,
            isNullable: paramElem.type.nullabilitySuffix != NullabilitySuffix.none,
          ),
          constantModifier: paramConstantModifier,
          constantValue: paramConstantValue,
          requireConversionToLiteral: paramConstantConversionToLiteral,
          keys: macroKeys,
        );

        if (paramElem.isNamed) {
          constructorNamedFields.add(macroParam);
        } else {
          constructorPosFields.add(macroParam);
        }

        final fieldInitializer = _analyzeInitializer(paramElem, constructorDec);
        if (fieldInitializer != null) {
          constructorInitializer ??= {};

          final fieldName = fieldInitializer.name ?? '';
          final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
            fieldInitializer,
            classTypeParams,
            capability.filterClassMethodMetadata,
            capability,
          );

          constructorInitializer[paramName] = MacroProperty(
            name: fieldName,
            type: type,
            typeInfo: typeInfo,
            typeArguments: typeArguments,
            functionTypeInfo: fnInfo,
            classInfo: classInfo,
            deepEquality: deepEq,
            constantValue: fieldInitializer.constantInitializer?.toSource(),
          );
        }
      }

      // List<ConstructorInitializer>? constantFieldInitializer;
      // try {
      //   // TODO: find a way to get constantInitializers
      //   constantFieldInitializer = (constructor as dynamic).constantInitializers;
      //
      //   // create constant initializer mapping
      //   if (constantFieldInitializer != null) {
      //     constructorInitializer = {};
      //     for (final ci in constantFieldInitializer) {
      //       if (ci is! ConstructorFieldInitializer) continue;
      //
      //       final fieldName = ci.fieldName.name;
      //       final fieldElem = classFragment.element.fields.firstWhereOrNull((f) => f.name == fieldName);
      //       final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = await getTypeInfoFrom(
      //         fieldElem,
      //         classTypeParams,
      //         capability.filterClassMethodMetadata,
      //         capability,
      //       );
      //
      //       constructorInitializer[fieldName] = MacroProperty(
      //         name: fieldName,
      //         type: type,
      //         typeInfo: typeInfo,
      //         typeArguments: typeArguments,
      //         functionTypeInfo: fnInfo,
      //         classInfo: classInfo,
      //         deepEquality: deepEq,
      //         constantValue: ci.expression.toSource(),
      //       );
      //     }
      //   }
      // } catch (_) {}

      constructors.add(
        MacroClassConstructor(
          constructorName: constructor.element.name ?? 'new',
          modifier: getModifierInfoFrom(constructor.element, isAugmentation: constructor.isAugmentation),
          redirectFactory: constructor.element.redirectedConstructor?.name,
          positionalFields: constructorPosFields,
          namedFields: constructorNamedFields,
          constantInitializers: constructorInitializer,
        ),
      );
    }

    clearInProgressClassFieldsFor(classFragment.name);
    return (constructors, classTypeParams, false);
  }

  Future<ConstructorDeclaration?> getConstructorDeclaration(ConstructorElement ctor) async {
    final session = ctor.session ?? currentSession!;
    final library = ctor.library;

    final resolved = await session.getResolvedLibraryByElement(library);
    if (resolved is! ResolvedLibraryResult) return null;

    for (final unitResult in resolved.units) {
      final cu = unitResult.unit;

      for (final decl in cu.declarations) {
        if (decl is ClassDeclaration) {
          for (final member in decl.members) {
            if (member is ConstructorDeclaration) {
              if (member.declaredFragment?.element == ctor) {
                return member;
              }
            }
          }
        }
      }
    }

    return null;
  }

  PropertyInducingElement? _analyzeInitializer(
    FormalParameterElement param,
    ConstructorDeclaration? constructor,
  ) {
    if (constructor == null) {
      return null;
    }

    for (var initializer in constructor.initializers) {
      if (initializer is ConstructorFieldInitializer) {
        var p = initializer.expression.accept(InitializerExpressionVisitor());
        if (p == param) {
          var f = initializer.fieldName.element;
          if (f is PropertyInducingElement) {
            return f;
          }
        }
      }
    }

    return null;
  }

  Future<(List<MacroMethod>?, bool)> parseClassMethods(
    MacroCapability capability,
    ClassFragment classFragment,
    List<String>? classTypeParams,
  ) async {
    if (!capability.classConstructors) {
      return const (null, false);
    }

    // return for nested class field with same type, only the first one
    // get types of the class fields, nested one is null,
    // its user code and its responsibility to handle that,
    if (lockOrReturnInProgressClassFieldsFor(classFragment.name)) {
      return (null, true);
    }

    bool? onlyInstanceMethod;
    {
      final instance = capability.filterClassInstanceMethod;
      final static = capability.filterClassStaticMethod;

      if (!instance && !static) return const (null, false);

      onlyInstanceMethod = instance == static
          ? null
          : instance
          ? true
          : false;
    }

    final methods = <MacroMethod>[];
    classTypeParams ??= classFragment.typeParameters.map((e) => e.name ?? '').toList();

    // static method can use class type parameter, so make it empty
    if (onlyInstanceMethod == false) {
      classTypeParams = const [];
    }

    final filteredMethods = capability.filterMethods == '*' ? null : capability.filterMethods.split(',');

    for (int i = 0; i < classFragment.methods.length; i++) {
      final method = classFragment.methods[i];
      final methodElem = method.element;

      if (onlyInstanceMethod != null) {
        final isInstance = !methodElem.isStatic;
        if (onlyInstanceMethod != isInstance) {
          continue;
        }
      }

      if (filteredMethods?.contains(methodElem.name) == false) {
        continue;
      }

      final macroKeys = await computeMacroKeys(capability.filterClassMethodMetadata, method.metadata, capability);

      final function = await getFunctionInfo(
        methodElem,
        classTypeParams,
        capability: capability,
        filterMethodMetadata: capability.filterClassMethodMetadata,
        macroKeys: macroKeys,
        isAsynchronous: method.isAsynchronous,
        isSynchronous: method.isSynchronous,
        isGenerator: method.isGenerator,
        isAugmentation: method.isAugmentation,
      );
      methods.add(function);
    }

    clearInProgressClassFieldsFor(classFragment.name);
    return (methods, false);
  }

  Future<void> collectClassSubTypes(
    List<(List<MacroConfig>, ClassFragment)> pendingRequiredSubTypes,
    LibraryFragment libraryFragment,
  ) async {
    for (final (capability, classFragment) in pendingRequiredSubTypes) {
      // get sub types
      final subTypes = findSubTypesOf(classFragment.element, libraryFragment);
      if (subTypes.isEmpty) continue;

      // convert to macro declaration
      final classDeclaration = <MacroClassDeclaration>[];
      for (final classSubType in subTypes) {
        final declaration = await parseClass(classSubType, collectSubTypeConfig: capability);
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

  (String, String) _classDeclarationCachedKey(
    ClassFragment classFragment,
    MacroCapability capability, [
    String? typeAliasName,
  ]) {
    final className = typeAliasName ?? classFragment.element.name;
    final uri = classFragment.element.library.uri.toString();
    final id = '$className:${xxh32code('$capability$className$uri')}';
    return ('classDec:$id', id);
  }
}

class InitializerExpressionVisitor extends SimpleAstVisitor<Element> {
  @override
  Element? visitSimpleIdentifier(SimpleIdentifier node) {
    return node.element;
  }

  @override
  Element? visitAssignedVariablePattern(AssignedVariablePattern node) {
    return node.element;
  }

  @override
  Element? visitParenthesizedExpression(ParenthesizedExpression node) {
    return node.expression.accept(this);
  }

  @override
  Element? visitNullAssertPattern(NullAssertPattern node) {
    return node.pattern.accept(this);
  }

  @override
  Element? visitNullCheckPattern(NullCheckPattern node) {
    return node.pattern.accept(this);
  }

  @override
  Element? visitBinaryExpression(BinaryExpression node) {
    if (node.operator.lexeme == '??') {
      var left = node.leftOperand.accept(this);
      var right = node.rightOperand.accept(this);
      if (left == null || right == null) {
        return left ?? right;
      }
    }

    return null;
  }
}
