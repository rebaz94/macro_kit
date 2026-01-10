import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/core/modifier.dart';

mixin AnalyzeClassField on BaseAnalyzer {
  @override
  Future<(List<MacroProperty>?, List<MacroProperty>?, bool)> parseClassFields(
    MacroCapability capability,
    InterfaceFragment classFragment,
    List<MacroProperty>? classTypeParams,
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
    if (lockOrReturnInProgressClassFieldsFor(classFragment)) {
      return (null, classTypeParams, true);
    }

    final classFields = <MacroProperty>[];
    classTypeParams ??= await parseTypeParameter(
      capability,
      classFragment.typeParameters.map((e) => e.element).toList(),
    );

    for (int i = 0; i < classFragment.fields.length; i++) {
      final field = classFragment.fields[i];
      final fieldElem = field.element;

      if (onlyInstanceField != null) {
        final isInstance = !fieldElem.isStatic;
        if (onlyInstanceField != isInstance) {
          continue;
        }
      }

      final fieldTypeRes = await getTypeInfoFrom(
        fieldElem,
        classTypeParams,
        capability.filterClassMethodMetadata,
        capability,
      );

      if (capability.filterClassIgnoreSetterOnly && fieldElem.getter == null && fieldElem.setter != null) {
        // ignore setter property
        continue;
      }

      bool? isGetterPropertyAbstract, isSetterPropertyAbstract;
      var macroKeys = await computeMacroKeys(capability.filterClassFieldMetadata, field.metadata, capability);
      if (fieldElem.getter != null && fieldElem.getter!.metadata.annotations.isNotEmpty) {
        final getterMacroKeys = await computeMacroKeys(
          capability.filterClassFieldMetadata,
          fieldElem.getter!.metadata,
          capability,
        );
        macroKeys ??= [];
        macroKeys.addAll(getterMacroKeys ?? const []);
        isGetterPropertyAbstract = fieldElem.getter!.isAbstract;
      }

      if (fieldElem.setter != null && fieldElem.setter!.metadata.annotations.isNotEmpty) {
        final setterMacroKeys = await computeMacroKeys(
          capability.filterClassFieldMetadata,
          fieldElem.setter!.metadata,
          capability,
        );
        macroKeys ??= [];
        macroKeys.addAll(setterMacroKeys ?? const []);
        isSetterPropertyAbstract = fieldElem.setter!.isAbstract;
      }

      if (capability.filterClassIncludeAnnotatedFieldOnly && macroKeys?.isNotEmpty != true) {
        // ignore unannotated field
        continue;
      }

      classFields.add(
        MacroProperty(
          name: field.name ?? '',
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
            fieldElem,
            isNullable: field.element.type.nullabilitySuffix != NullabilitySuffix.none,
            isAugmentation: field.isAugmentation,
            isGetterPropertyAbstract: isGetterPropertyAbstract ?? false,
            isSetterPropertyAbstract: isSetterPropertyAbstract ?? false,
          ),
          keys: macroKeys,
        ),
      );
    }

    clearInProgressClassFieldsFor(classFragment);
    return (classFields, classTypeParams, false);
  }
}
