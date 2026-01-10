import 'package:analyzer/dart/element/element.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/core/core.dart';

mixin AnalyzeClassMethod on BaseAnalyzer {
  @override
  Future<(List<MacroMethod>?, bool)> parseClassMethods(
    MacroCapability capability,
    InterfaceFragment classFragment,
    List<MacroProperty>? classTypeParams,
  ) async {
    if (!capability.classMethods) {
      return const (null, false);
    }

    // return for nested class field with same type, only the first one
    // get types of the class fields, nested one is null,
    // its user code and its responsibility to handle that,
    if (lockOrReturnInProgressClassFieldsFor(classFragment)) {
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
    classTypeParams ??= await parseTypeParameter(
      capability,
      classFragment.typeParameters.map((e) => e.element).toList(),
    );

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

      final macroKeys = await computeMacroKeys(
        filter: capability.filterClassMethodMetadata,
        capability: capability,
        metadata: method.metadata,
      );

      if (capability.filterClassIncludeAnnotatedMethodOnly && macroKeys?.isNotEmpty != true) {
        // ignore unannotated method
        continue;
      }

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

    clearInProgressClassFieldsFor(classFragment);
    return (methods, false);
  }
}
