import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:collection/collection.dart';
import 'package:macro_kit/src/analyzer/analyzer.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/types.dart';
import 'package:macro_kit/src/core/core.dart';

extension AnalyzeClass on Analyzer {
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

  (List<MacroProperty>?, List<String>?, bool) parseClassFields(
    MacroCapability capability,
    ClassFragment classFragment,
    List<String>? classTypeParams,
  ) {
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

      final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = getTypeInfoFrom(
        fieldElem,
        classTypeParams,
        capability.filterClassMethodMetadata,
        capability,
      );

      if (capability.filterClassIgnoreSetterOnly && fieldElem.getter == null && fieldElem.setter != null) {
        // ignore setter property
        continue;
      }

      var macroKeys = computeMacroKeys(capability.filterClassFieldMetadata, field.metadata, capability);
      if (fieldElem.getter != null && fieldElem.getter!.metadata.annotations.isNotEmpty) {
        final getterMacroKeys = computeMacroKeys(
          capability.filterClassFieldMetadata,
          fieldElem.getter!.metadata,
          capability,
        );
        macroKeys ??= [];
        macroKeys.addAll(getterMacroKeys ?? const []);
      }

      if (fieldElem.setter != null && fieldElem.setter!.metadata.annotations.isNotEmpty) {
        final setterMacroKeys = computeMacroKeys(
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

  (List<MacroClassConstructor>, List<String>?, bool) parseClassConstructors(
    MacroCapability capability,
    ClassFragment classFragment,
    List<String>? classTypeParams,
    List<MacroProperty>? classFields,
  ) {
    if (!capability.classConstructors) {
      return ([], classTypeParams, true);
    }

    // return for nested class field with same type, only the first one
    // get types of the class fields, nested one is null,
    // its user code and its responsibility to handle that,
    if (lockOrReturnInProgressClassFieldsFor(classFragment.name)) {
      return ([], classTypeParams, true);
    }

    classTypeParams ??= classFragment.typeParameters.map((e) => e.name ?? '').toList();
    final constructors = <MacroClassConstructor>[];

    for (int k = 0; k < classFragment.constructors.length; k++) {
      final constructor = classFragment.constructors[k];
      List<MacroProperty> constructorPosFields = [];
      List<MacroProperty> constructorNamedFields = [];

      final params = constructor.formalParameters;
      for (int i = 0; i < params.length; i++) {
        final param = params[i];
        final paramElem = param.element;

        final (:type, :typeInfo, :typeArguments, :fnInfo, :classInfo, :deepEq) = getTypeInfoFrom(
          paramElem,
          classTypeParams,
          capability.filterClassMethodMetadata,
          capability,
        );

        final fieldName = param.name ?? '';

        // get @[Key] from the constructor or from classFields if exists
        var macroKeys = computeMacroKeys(
          capability.filterClassConstructorParameterMetadata,
          param.metadata,
          capability,
        );

        if (capability.mergeClassFieldWithConstructorParameter) {
          List<MacroKey>? fieldMacroKeys;

          if (classFields == null) {
            final fieldMetadata = classFragment.fields.firstWhereOrNull((e) => e.name == fieldName);
            if (fieldMetadata != null) {
              fieldMacroKeys = computeMacroKeys(
                capability.filterClassConstructorParameterMetadata,
                fieldMetadata.metadata,
                capability,
              );
            }
          } else {
            fieldMacroKeys = classFields.firstWhereOrNull((e) => e.name == fieldName)?.keys;
          }

          if (fieldMacroKeys != null) {
            if (macroKeys != null) {
              macroKeys.addAll(fieldMacroKeys);
            } else {
              macroKeys = fieldMacroKeys;
            }
          }
        } else {
          final fieldMacroKeys = classFields?.firstWhereOrNull((e) => e.name == fieldName)?.keys;
          macroKeys?.addAll(fieldMacroKeys ?? const []);
        }

        final macroParam = MacroProperty(
          name: fieldName,
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
          keys: macroKeys,
        );

        if (paramElem.isNamed) {
          constructorNamedFields.add(macroParam);
        } else {
          constructorPosFields.add(macroParam);
        }
      }

      constructors.add(
        MacroClassConstructor(
          constructorName: constructor.element.name ?? 'new',
          modifier: getModifierInfoFrom(constructor.element, isAugmentation: constructor.isAugmentation),
          redirectFactory: constructor.element.redirectedConstructor?.name,
          positionalFields: constructorPosFields,
          namedFields: constructorNamedFields,
        ),
      );
    }

    clearInProgressClassFieldsFor(classFragment.name);
    return (constructors, classTypeParams, false);
  }

  (List<MacroMethod>?, bool) parseClassMethods(
    MacroCapability capability,
    ClassFragment classFragment,
    List<String>? classTypeParams,
  ) {
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

      final macroKeys = computeMacroKeys(capability.filterClassMethodMetadata, method.metadata, capability);

      final function = getFunctionInfo(
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
}
