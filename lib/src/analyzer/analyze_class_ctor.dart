import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:collection/collection.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/core/modifier.dart';

mixin AnalyzeClassCtor on BaseAnalyzer {
  @override
  Future<(List<MacroClassConstructor>, List<MacroProperty>?, bool)> parseClassConstructors(
    MacroCapability capability,
    InterfaceFragment classFragment,
    List<MacroProperty>? classTypeParams,
    List<MacroProperty>? classFields,
  ) async {
    if (!capability.classConstructors) {
      return (<MacroClassConstructor>[], classTypeParams, true);
    }

    // return for nested class field with same type, only the first one
    // get types of the class fields, nested one is null,
    // its user code and its responsibility to handle that,
    if (lockOrReturnInProgressClassFieldsFor(classFragment)) {
      return (<MacroClassConstructor>[], classTypeParams, true);
    }

    classTypeParams ??= await parseTypeParameter(
      capability,
      classFragment.typeParameters.map((e) => e.element).toList(),
    );

    final constructors = <MacroClassConstructor>[];

    for (int k = 0; k < classFragment.constructors.length; k++) {
      final ConstructorFragment constructor = classFragment.constructors[k];
      List<MacroProperty> constructorPosFields = [];
      List<MacroProperty> constructorNamedFields = [];

      final constructorDec = await getConstructorDeclaration(constructor.element);

      final params = constructor.formalParameters;
      for (int i = 0; i < params.length; i++) {
        final param = params[i];
        final paramElem = param.element;

        final (macroParam, namedField) = await _getParameter(
          classFragment: classFragment,
          param: param,
          paramElem: paramElem,
          classTypeParams: classTypeParams,
          capability: capability,
          classFields: classFields,
          constructorDec: constructorDec,
        );

        if (namedField) {
          constructorNamedFields.add(macroParam);
        } else {
          constructorPosFields.add(macroParam);
        }
      }

      constructors.add(
        MacroClassConstructor(
          constructorName: constructor.element.name ?? 'new',
          modifier: MacroModifier.getModifierInfoFrom(constructor.element, isAugmentation: constructor.isAugmentation),
          redirectFactory: constructor.element.redirectedConstructor?.name,
          positionalFields: constructorPosFields,
          namedFields: constructorNamedFields,
        ),
      );
    }

    clearInProgressClassFieldsFor(classFragment);
    return (constructors, classTypeParams, false);
  }

  Future<(MacroProperty, bool)> _getParameter({
    required InterfaceFragment classFragment,
    required FormalParameterFragment param,
    required FormalParameterElement paramElem,
    required List<MacroProperty> classTypeParams,
    required MacroCapability capability,
    required List<MacroProperty>? classFields,
    required ConstructorDeclaration? constructorDec,
  }) async {
    final paramTypeRes = await getTypeInfoFrom(
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

    // merge metadata with class field or get only the one from clas field
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

    // compute constant initialized value
    Object? constantValue;
    MacroModifier? constantModifier;
    bool? constantConversionToLiteral;

    if (paramElem.computeConstantValue() case DartObject constantDartValue) {
      final computed = await computeConstantInitializerValue(paramName, constantDartValue, capability);

      if (computed != null) {
        (:constantValue, modifier: constantModifier, reqConversion: constantConversionToLiteral) = computed;
      }
    }

    // get field initializer
    MacroProperty? macroFieldInitializer;
    if (capability.inspectFieldInitializer) {
      macroFieldInitializer = await _getParameterFieldInitializer(
        classFragment: classFragment,
        classTypeParams: classTypeParams,
        constructorDec: constructorDec,
        capability: capability,
        paramElem: paramElem,
      );
    }

    final macroParam = MacroProperty(
      name: paramName,
      importPrefix: paramTypeRes.importPrefix,
      type: paramTypeRes.type,
      typeInfo: paramTypeRes.typeInfo,
      classInfo: paramTypeRes.classInfo,
      recordInfo: paramTypeRes.recordInfo,
      functionTypeInfo: paramTypeRes.fnInfo,
      typeArguments: paramTypeRes.typeArguments,
      typeRefType: paramTypeRes.typeRefType,
      modifier: MacroModifier.getModifierInfoFrom(
        paramElem,
        isNullable: paramElem.type.nullabilitySuffix != NullabilitySuffix.none,
      ),
      fieldInitializer: macroFieldInitializer,
      constantModifier: constantModifier,
      constantValue: constantValue,
      requireConversionToLiteral: constantConversionToLiteral,
      keys: macroKeys,
    );

    return (macroParam, paramElem.isNamed);
  }

  /// this function will get field initializer recursively directly or from super param if any
  Future<MacroProperty?> _getParameterFieldInitializer({
    required InterfaceFragment classFragment,
    required ConstructorDeclaration? constructorDec,
    required List<MacroProperty> classTypeParams,
    required MacroCapability capability,
    required FormalParameterElement paramElem,
  }) async {
    if (paramElem is FieldFormalParameterElement) {
      // // TODO: fix this
      // final superField = _getSuperField(
      //   field: paramElem.field!,
      //   extendsElement: classFragment.element.supertype?.element.firstFragment,
      //   interfaceElements: [],
      // );
      // if (superField != null) {
      //   print('FieldFormalParameterElement: super field: $superField');
      // }

      return null;
    } else if (paramElem is SuperFormalParameterElement && classFragment.element.supertype?.element != null) {
      final superType = classFragment.element.supertype!.element;
      final superConsParam = paramElem.superConstructorParameter;
      if (superConsParam == null) {
        logger.info('Cannot resolve formal super parameter: ${paramElem.name}');
        return null;
      }

      final constructorElem = constructorDec?.declaredFragment?.element;
      final superConstructorElem = constructorElem?.redirectedConstructor ?? constructorElem?.superConstructor;
      if (superConstructorElem == null) {
        logger.info('Cannot resolve super constructor for formal super parameter: ${paramElem.name}');
        return null;
      }

      final resolvedLib = await superConstructorElem.session?.getResolvedLibraryByElement(
        superConstructorElem.library,
      );
      if (resolvedLib is! ResolvedLibraryResult) {
        logger.info(
          'Unable to resolve super constructor for formal super parameter: ${paramElem.name}, '
          'constructor name: ${superConstructorElem.name}',
        );
        return null;
      }

      final superConstructorDec = resolvedLib.getFragmentDeclaration(superConstructorElem.firstFragment);
      final node = superConstructorDec?.node;
      if (node is! ConstructorDeclaration) {
        logger.info('Unable to resolve super constructor for formal super parameter: ${paramElem.name}');
        return null;
      }

      final classTypeParams = await parseTypeParameter(
        capability,
        superType.firstFragment.typeParameters.map((e) => e.element).toList(),
      );

      final (macroParam, _) = await _getParameter(
        classFragment: superType.firstFragment,
        param: superConsParam.firstFragment,
        paramElem: superConsParam.baseElement,
        classTypeParams: classTypeParams,
        capability: capability,
        classFields: null,
        constructorDec: node,
      );

      return macroParam;
    } else if (classFragment.element.supertype != null) {
      final (superParam, macroParam) = await _findSuperParameter(
        param: paramElem,
        constructor: constructorDec,
        superElement: classFragment.element.supertype!.element.firstFragment,
        capability: capability,
      );

      if (macroParam != null) return macroParam;

      if (superParam != null) {
        final superType = classFragment.element.supertype!.element;
        final classTypeParams = await parseTypeParameter(
          capability,
          superType.firstFragment.typeParameters.map((e) => e.element).toList(),
        );

        final (macroParam, _) = await _getParameter(
          classFragment: superType.firstFragment,
          param: superParam.firstFragment,
          paramElem: superParam.baseElement,
          classTypeParams: classTypeParams,
          capability: capability,
          classFields: null,
          constructorDec: constructorDec,
        );

        return macroParam;
      }
    }

    // default if not match any top case
    final fieldInitializer = _analyzeInitializer(paramElem, constructorDec);
    if (fieldInitializer == null) return null;

    final fieldName = fieldInitializer.name ?? '';
    final fieldInitializerTypeRes = await getTypeInfoFrom(
      fieldInitializer,
      classTypeParams,
      capability.filterClassMethodMetadata,
      capability,
    );

    return MacroProperty(
      name: fieldName,
      importPrefix: fieldInitializerTypeRes.importPrefix,
      type: fieldInitializerTypeRes.type,
      typeInfo: fieldInitializerTypeRes.typeInfo,
      typeArguments: fieldInitializerTypeRes.typeArguments,
      functionTypeInfo: fieldInitializerTypeRes.fnInfo,
      classInfo: fieldInitializerTypeRes.classInfo,
      recordInfo: fieldInitializerTypeRes.recordInfo,
      typeRefType: fieldInitializerTypeRes.typeRefType,
      fieldInitializer: null,
      constantValue: fieldInitializer.constantInitializer?.toSource(),
    );
  }

  Future<ConstructorDeclaration?> getConstructorDeclaration(ConstructorElement ctor) async {
    final session = ctor.session ?? currentSession!;
    final library = ctor.library;

    final resolved = await session.getResolvedLibraryByElement(library);
    if (resolved is! ResolvedLibraryResult) return null;

    for (final unitResult in resolved.units) {
      final cu = unitResult.unit;

      for (final dec in cu.declarations) {
        if (dec is ClassDeclaration) {
          for (final member in dec.members) {
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

  // ignore: unused_element
  PropertyInducingElement? _getSuperField({
    required PropertyInducingElement field,
    required InterfaceFragment? extendsElement,
    required List<InterfaceFragment> interfaceElements,
  }) {
    return [if (extendsElement != null) extendsElement, ...interfaceElements]
        .expand((e) => e.fields) //
        .where((f) => f.name == field.name)
        .map((f) => f.element)
        .firstOrNull;
  }

  Future<(FormalParameterElement?, MacroProperty?)> _findSuperParameter({
    required FormalParameterElement param,
    required ConstructorDeclaration? constructor,
    required InterfaceFragment? superElement,
    required MacroCapability capability,
  }) async {
    if (superElement == null) return (null, null);

    var node = constructor;
    if (node is ConstructorDeclaration && node.initializers.isNotEmpty) {
      var last = node.initializers.last;
      if (last is SuperConstructorInvocation) {
        final superConstructorName = last.constructorName?.name ?? 'new';
        ConstructorElement? superConstructor;

        if (superElement.element.thisType.isDartCoreObject &&
            last.element != null &&
            last.element?.returnType.element != null) {
          final superType = last.element!.returnType.element;

          final superConstructorElem = last.element!;
          final session = superConstructorElem.session ?? currentSession!;
          final resolvedLib = await session.getResolvedLibraryByElement(last.element!.library);
          if (resolvedLib is! ResolvedLibraryResult) {
            logger.info(
              'Unable to resolve super constructor for formal super parameter: ${param.name}, '
              'constructor name: $superConstructorName',
            );
            return (null, null);
          }

          final superConstructorDec = resolvedLib.getFragmentDeclaration(superConstructorElem.firstFragment);
          final node = superConstructorDec?.node;
          if (node is! ConstructorDeclaration) {
            logger.info('Unable to resolve super constructor for formal super parameter: ${param.name}');
            return (null, null);
          }

          final classTypeParams = await parseTypeParameter(
            capability,
            superType.firstFragment.typeParameters.map((e) => e.element).toList(),
          );

          final (macroParam, _) = await _getParameter(
            classFragment: superType.firstFragment,
            param: param.firstFragment,
            paramElem: param.baseElement,
            classTypeParams: classTypeParams,
            capability: capability,
            classFields: null,
            constructorDec: node,
          );
          if (macroParam.fieldInitializer != null) {
            return (null, macroParam.fieldInitializer);
          }

          return (null, macroParam);
        }

        superConstructor = superElement.element.constructors.firstWhereOrNull(
          (c) => c.name == superConstructorName,
        );
        superConstructor ??= last.element;

        var args = last.argumentList.arguments;
        var i = 0;
        for (var arg in args) {
          if (arg is SimpleIdentifier) {
            if (arg.name == param.name) {
              return (superConstructor?.formalParameters.elementAtOrNull(i), null);
            }
          } else if (arg is NamedExpression) {
            var exp = arg.expression;
            if (exp is SimpleIdentifier) {
              if (exp.name == param.name) {
                var superName = arg.name.label.name;
                return (
                  superConstructor?.formalParameters.firstWhereOrNull(
                    (p) => p.isNamed && p.name == superName,
                  ),
                  null,
                );
              }
            }
          }
          i++;
        }
      }
    }
    return (null, null);
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

      // final f = (node.parent?.parent?.accept(this));
    }

    return null;
  }
}
