import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

extension type const MacroModifier(Map<String, bool> value) implements Map<String, bool> {
  static MacroModifier getModifierInfoFrom(
    Object elem, {
    bool isNullable = false,
    bool isAsynchronous = false,
    bool isSynchronous = false,
    bool isGenerator = false,
    bool isAugmentation = false,
    bool isGetterPropertyAbstract = false,
    bool isSetterPropertyAbstract = false,
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
        isGetterPropertyAbstract: isGetterPropertyAbstract,
        isSetterPropertyAbstract: isSetterPropertyAbstract,
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
        isGetterPropertyAbstract: isGetterPropertyAbstract,
        isSetterPropertyAbstract: isSetterPropertyAbstract,
        isCovariant: elem.isCovariant,
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isNamed: elem.isNamed,
        isRequiredNamed: elem.isRequiredNamed,
        isRequiredPositional: elem.isRequiredPositional,
        hasDefaultValue: elem.hasDefaultValue,
        isInitializingFormal: elem.isInitializingFormal,
        fieldFormalParameter: true,
        superFormalParameter: elem.isSuperFormal,
      ),
      FormalParameterElement() => MacroModifier.create(
        isConst: elem.isConst,
        isFinal: elem.isFinal,
        isLate: elem.isLate,
        isNullable: isNullable,
        isStatic: elem.isStatic,
        isPrivate: elem.isPrivate,
        isGetterPropertyAbstract: isGetterPropertyAbstract,
        isSetterPropertyAbstract: isSetterPropertyAbstract,
        isCovariant: elem.isCovariant,
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isNamed: elem.isNamed,
        isRequiredNamed: elem.isRequiredNamed,
        isRequiredPositional: elem.isRequiredPositional,
        hasDefaultValue: elem.hasDefaultValue,
        isInitializingFormal: elem.isInitializingFormal,
        formalParameter: true,
        superFormalParameter: elem.isSuperFormal,
      ),
      LocalVariableElement() => MacroModifier.create(
        isConst: elem.isConst,
        isFinal: elem.isFinal,
        isLate: elem.isLate,
        isGetterPropertyAbstract: isGetterPropertyAbstract,
        isSetterPropertyAbstract: isSetterPropertyAbstract,
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
        isGetterPropertyAbstract: isGetterPropertyAbstract,
        isSetterPropertyAbstract: isSetterPropertyAbstract,
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
        isGetterPropertyAbstract: isGetterPropertyAbstract,
        isSetterPropertyAbstract: isSetterPropertyAbstract,
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
        isGetterPropertyAbstract: isGetterPropertyAbstract,
        isSetterPropertyAbstract: isSetterPropertyAbstract,
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
        isGetterPropertyAbstract: isGetterPropertyAbstract,
        isSetterPropertyAbstract: isSetterPropertyAbstract,
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
        isGetterPropertyAbstract: isGetterPropertyAbstract,
        isSetterPropertyAbstract: isSetterPropertyAbstract,
      ),
      FunctionType() => MacroModifier.create(
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isNullable: isNullable,
        isStatic: true,
        isGetterPropertyAbstract: isGetterPropertyAbstract,
        isSetterPropertyAbstract: isSetterPropertyAbstract,
      ),
      DartType() => MacroModifier.create(
        isAsynchronous: isAsynchronous,
        isSynchronous: isSynchronous,
        isGenerator: isGenerator,
        isAugmentation: isAugmentation,
        isNullable: isNullable,
        isGetterPropertyAbstract: isGetterPropertyAbstract,
        isSetterPropertyAbstract: isSetterPropertyAbstract,
      ),
      _ => throw UnimplementedError('Getting modifier from: ${elem.runtimeType} is not implemented'),
    };
  }

  static MacroModifier create({
    bool isConst = false,
    bool isFactory = false,
    bool isGenerative = false,
    bool isDefaultConstructor = false,
    bool isFinal = false,
    bool isLate = false,
    bool isNullable = false,
    bool isStatic = false,
    bool isPrivate = false,
    bool isExternal = false,
    bool isAbstract = false,
    bool isGetterPropertyAbstract = false,
    bool isSetterPropertyAbstract = false,
    bool isSealed = false,
    bool isExhaustive = false,
    bool isAlias = false,
    // bool isExtendableOutside = false,
    // bool isImplementableOutside = false,
    // bool isMixableOutside = false,
    bool isMixinClass = false,
    bool isBase = false,
    bool isInterface = false,
    // bool isConstructable = false,
    bool hasNonFinalField = false,
    bool isCovariant = false,
    bool isOperator = false,
    bool isOverridden = false,
    bool isAsynchronous = false,
    bool isSynchronous = false,
    bool isGenerator = false,
    bool isAugmentation = false,
    bool isExtensionMember = false,
    bool isNamed = false,
    bool isRequiredNamed = false,
    bool isRequiredPositional = false,
    bool isGetProperty = false,
    bool isSetProperty = false,
    bool hasInitializer = false,
    bool hasDefaultValue = false,
    bool isInitializingFormal = false,
    bool fieldFormalParameter = false,
    bool formalParameter = false,
    bool superFormalParameter = false,
  }) {
    return MacroModifier({
      if (isConst) 'c': true,
      if (isFactory) 'fa': true,
      if (isGenerative) 'ga': true,
      if (isDefaultConstructor) 'dc': true,
      if (isFinal) 'f': true,
      if (isLate) 'l': true,
      if (isNullable) 'n': true,
      if (isStatic) 's': true,
      if (isPrivate) 'p': true,
      if (isExternal) 'ex': true,
      if (isAbstract) 'a': true,
      if (isGetterPropertyAbstract) 'gpa': true,
      if (isSetterPropertyAbstract) 'spa': true,
      if (isSealed) 'cs': true,
      if (isExhaustive) 'ce': true,
      if (isAlias) 'ai': true,
      // if (isExtendableOutside) 'eo': true,
      // if (isImplementableOutside) 'io': true,
      // if (isMixableOutside) 'mo': true,
      if (isMixinClass) 'mc': true,
      if (isBase) 'b': true,
      if (isInterface) 'ci': true,
      // if (isConstructable) 'cc': true,
      if (hasNonFinalField) 'hnf': true,
      if (isCovariant) 'co': true,
      if (isAsynchronous) 'ab': true,
      if (isSynchronous) 'sb': true,
      if (isOperator) 'op': true,
      if (isOverridden) 'o': true,
      if (isGenerator) 'g': true,
      if (isAugmentation) 'ag': true,
      if (isExtensionMember) 'e': true,
      if (isNamed) 'in': true,
      if (isRequiredNamed) 'rn': true,
      if (isRequiredPositional) 'rp': true,
      if (isGetProperty) 'gp': true,
      if (isSetProperty) 'sp': true,
      if (hasInitializer) 'hi': true,
      if (hasDefaultValue) 'hd': true,
      if (isInitializingFormal) 'if': true,
      if (fieldFormalParameter) 'ffp': true else if (formalParameter) 'fp': true,
      if (superFormalParameter) 'sfp': true,
    });
  }

  void setIsNullable(bool isNull) {
    this['n'] = isNull;
  }

  bool get isConst => value['c'] == true;

  bool get isFactory => value['fa'] == true;

  bool get isGenerative => value['ga'] == true;

  bool get isDefaultConstructor => value['dc'] == true;

  bool get isFinal => value['f'] == true;

  bool get isLate => value['l'] == true;

  bool get isNullable => value['n'] == true;

  bool get isStatic => value['s'] == true;

  bool get isPrivate => value['p'] == true;

  bool get isPublic => !isPrivate;

  bool get isExternal => value['ex'] == true;

  bool get isAbstract => value['a'] == true;

  bool get isGetterPropertyAbstract => value['gpa'] == true;

  bool get isSetterPropertyAbstract => value['spa'] == true;

  bool get isSealed => value['sc'] == true;

  bool get isExhaustive => value['ce'] == true;

  /// Whether the target value is an alias type
  bool get isAlias => value['ai'] == true;

  // bool get isExtendableOutside => value['eo'] == true;
  //
  // bool get isImplementableOutside => value['io'] == true;
  //
  // bool get isMixableOutside => value['mo'] == true;

  bool get isMixinClass => value['mc'] == true;

  bool get isBase => value['b'] == true;

  bool get isInterface => value['ci'] == true;

  // bool get isConstructable => value['cc'] == true;

  bool get hasNonFinalField => value['hnf'] == true;

  bool get isCovariant => value['co'] == true;

  /// Whether the body is marked as being asynchronous.
  bool get isAsynchronous => value['ab'] == true;

  /// Whether the body is marked as being synchronous.
  bool get isSynchronous => value['sb'] == true;

  bool get isOperator => value['op'] == true;

  bool get isOverridden => value['o'] == true;

  /// Whether the body is marked as being a generator.
  bool get isGenerator => value['g'] == true;

  /// Whether the element is an augmentation.
  bool get isAugmentation => value['ag'] == true;

  bool get isExtensionMember => value['e'] == true;

  bool get isNamed => value['in'] == true;

  bool get isRequiredNamed => value['rn'] == true;

  bool get isRequiredPositional => value['rp'] == true;

  bool get isGetProperty => value['gp'] == true;

  bool get isSetProperty => value['sp'] == true;

  /// Whether the variable has an initializer at declaration.
  bool get hasInitializer => value['hi'] == true;

  /// Whether the parameter has a default value
  bool get hasDefaultValue => value['hdv'] == true;

  ///  Whether the parameter is an initializing formal parameter.
  bool get isInitializingFormal => value['if'] == true;

  /// Whether the parameter defined in constructor and as a field
  bool get isFieldFormalParameter => value['ffp'] == true;

  /// Whether the parameter defined in constructor only
  bool get isFormalParameter => value['fp'] == true;

  /// Whether the parameter is a super formal parameter.
  bool get isSuperFormalParameter => value['sfp'] == true;

  String stringify() {
    final buffer = StringBuffer();
    var first = true;

    void add(String name) {
      if (!first) buffer.write(', ');
      buffer.write(name);
      first = false;
    }

    if (isConst) add('isConst');
    if (isFactory) add('isFactory');
    if (isGenerative) add('isGenerative');
    if (isDefaultConstructor) add('isDefaultConstructor');
    if (isFinal) add('isFinal');
    if (isLate) add('isLate');
    if (isNullable) add('isNullable');
    if (isStatic) add('isStatic');
    if (isPrivate) add('isPrivate');
    if (isExternal) add('isExternal');
    if (isAbstract) add('isAbstract');
    if (isGetterPropertyAbstract) add('isGetterPropertyAbstract');
    if (isSetterPropertyAbstract) add('isSetterPropertyAbstract');
    if (isSealed) add('isSealed');
    if (isExhaustive) add('isExhaustive');
    if (isAlias) add('isAlias');
    if (isMixinClass) add('isMixinClass');
    if (isBase) add('isBase');
    if (isInterface) add('isInterface');
    if (hasNonFinalField) add('hasNonFinalField');
    if (isCovariant) add('isCovariant');
    if (isAsynchronous) add('isAsynchronous');
    if (isSynchronous) add('isSynchronous');
    if (isOperator) add('isOperator');
    if (isOverridden) add('isOverridden');
    if (isGenerator) add('isGenerator');
    if (isAugmentation) add('isAugmentation');
    if (isExtensionMember) add('isExtensionMember');
    if (isNamed) add('isNamed');
    if (isRequiredNamed) add('isRequiredNamed');
    if (isRequiredPositional) add('isRequiredPositional');
    if (isGetProperty) add('isGetProperty');
    if (isSetProperty) add('isSetProperty');
    if (hasInitializer) add('hasInitializer');
    if (hasDefaultValue) add('hasDefaultValue');
    if (isInitializingFormal) add('isInitializingFormal');
    if (isFieldFormalParameter) add('isFieldFormalParameter');
    if (isFormalParameter) add('isFormalParameter');
    if (isSuperFormalParameter) add('isSuperFormalParameter');

    return buffer.toString();
  }
}
