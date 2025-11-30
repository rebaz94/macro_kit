import 'dart:core';

import 'package:dart_style/dart_style.dart';
import 'package:hashlib/hashlib.dart';
import 'package:macro_kit/macro.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/types_ext.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// Macro used to attach metadata to a Dart declaration.
///
/// A `Macro` defines:
///   * which code generator should run, and
///   * whether its output should be merged with other macros applied
///     to the same declaration.
class Macro {
  const Macro(
    this.generator, {
    this.combine = false,
  });

  /// The macro code generator responsible for producing the output.
  final MacroGenerator generator;

  /// Whether this macro's generated code should be merged with code
  /// produced by *other* macros applied to the same class or mixin.
  ///
  /// When `true` and this macro is the first one applied to the declaration:
  ///   * The *first* macro determines whether the generated output is
  ///     a class, mixin or anything.
  ///   * Subsequent macros append their generated members to that same
  ///     output type rather than creating separate classes/mixins.
  ///
  /// This is useful when multiple macros must collaborate to build a
  /// single combined implementation.
  final bool combine;
}

/// A `MacroCapability` describes which elements of a class (constructors,
/// fields, methods, metadata, and subtypes) should be collected and made
/// available to the macro during generation.
///
/// Each flag enables a specific category of information.
/// Some options only apply when their parent category is enabled
/// (e.g., field filters only apply when [classFields] is `true`).
///
/// This allows each macro to precisely control the level of detail it needs,
/// improving performance and avoiding unnecessary analysis work.
class MacroCapability {
  const MacroCapability({
    this.classConstructors = false,
    this.filterClassConstructorParameterMetadata = '',
    this.mergeClassFieldWithConstructorParameter = false,
    this.classFields = false,
    this.filterClassInstanceFields = false,
    this.filterClassStaticFields = false,
    this.filterClassIgnoreSetterOnly = true,
    this.filterClassFieldMetadata = '',
    this.classMethods = false,
    this.filterClassInstanceMethod = false,
    this.filterClassStaticMethod = false,
    this.filterMethods = '',
    this.filterClassMethodMetadata = '',
    this.collectClassSubTypes = false,
    this.filterCollectSubTypes = '',
  });

  static MacroCapability fromJson(Map<String, dynamic> json) {
    return MacroCapability(
      classFields: (json['cf'] as bool?) ?? false,
      filterClassInstanceFields: (json['fcif'] as bool?) ?? false,
      filterClassStaticFields: (json['fcsf'] as bool?) ?? false,
      filterClassIgnoreSetterOnly: (json['fciso'] as bool?) ?? false,
      filterClassFieldMetadata: (json['fcfm'] as String?) ?? '',
      classConstructors: (json['cc'] as bool?) ?? false,
      filterClassConstructorParameterMetadata: (json['fccpm'] as String?) ?? '',
      mergeClassFieldWithConstructorParameter: (json['mcfwcp'] as bool?) ?? false,
      classMethods: (json['cm'] as bool?) ?? false,
      filterClassInstanceMethod: (json['fcim'] as bool?) ?? false,
      filterClassStaticMethod: (json['fcsm'] as bool?) ?? false,
      filterMethods: (json['fm'] as String?) ?? '',
      filterClassMethodMetadata: (json['fcmm'] as String?) ?? '',
      collectClassSubTypes: (json['ccst'] as bool?) ?? false,
      filterCollectSubTypes: (json['fccst'] as String?) ?? '',
    );
  }

  /// Whether to retrieve all fields declared in the class.
  final bool classFields;

  /// Whether to include only instance fields.
  ///
  /// Only applies when [classFields] is `true`.
  final bool filterClassInstanceFields;

  /// Whether to include only static fields.
  ///
  /// Only applies when [classFields] is `true`.
  final bool filterClassStaticFields;

  /// Whether to include only property (getter, setter or variable declaration).
  ///
  /// Only applies when [classFields] is `true`.
  final bool filterClassIgnoreSetterOnly;

  /// Filter specified custom metadata defined on the field.
  ///
  /// To get all metadata, use '*' or filter by providing comma separated key 'JsonKey,CustomMetadata'
  ///
  /// Only applies when [classFields] is `true`.
  final String filterClassFieldMetadata;

  /// Whether to retrieve all constructors declared in the class.
  final bool classConstructors;

  /// Filter specified custom metadata defined on the constructor parameter.
  ///
  /// To get all metadata, use '*' or filter by providing comma separated key 'JsonKey,CustomMetadata'
  ///
  /// Only applies when [classConstructors] is `true`.
  final String filterClassConstructorParameterMetadata;

  /// Whether to merge metadata declared in the class field with
  /// the parameter defined in the constructor.
  ///
  /// Only applies when [classConstructors] is true.
  final bool mergeClassFieldWithConstructorParameter;

  /// Whether to retrieve all methods declared in the class.
  final bool classMethods;

  /// Whether to include only instance methods.
  ///
  /// Only applies when [classMethods] is `true`.
  final bool filterClassInstanceMethod;

  /// Whether to include only static methods.
  ///
  /// Only applies when [classMethods] is `true`.
  final bool filterClassStaticMethod;

  /// Filters which methods should be included from the class.
  ///
  /// This works only when [classMethods] is `true`, and the instance/static
  /// filtering (via [filterClassInstanceMethod] and [filterClassStaticMethod])
  /// has already been applied.
  ///
  /// Use:
  ///   * '*' to include all methods
  ///   * a comma-separated list to include specific methods
  ///     e.g. `'build,toJson'`
  ///
  /// The names must match the method identifiers in the class.
  final String filterMethods;

  /// Filter specified custom metadata defined on the constructor parameter.
  ///
  /// To get all metadata, use '*' or filter by providing comma separated key 'JsonKey,CustomMetadata'
  ///
  /// Only applies when [classConstructors] is `true`.
  final String filterClassMethodMetadata;

  /// Whether to include all subclasses (subtypes) of this class.
  ///
  /// When set to `true`, the generator will automatically discover and include
  /// every class that extends this class. This is primarily used
  /// for polymorphic code generation, where the base class needs to know all of
  /// its concrete implementations.
  ///
  /// Only applies to abstract or sealed classes.
  final bool collectClassSubTypes;

  /// Determines **which kinds of classes are allowed to perform subtype
  /// collection** when [collectClassSubTypes] is `true`.
  ///
  /// This filter applies to the *current class*, not the subtypes.
  /// In other words: it decides whether this class is eligible for subtype
  /// discovery based on whether it is `sealed`, `abstract`, or both.
  ///
  /// Supported values:
  ///   - `"sealed"` — only sealed classes can collect subtypes
  ///   - `"abstract"` — only abstract classes can collect subtypes
  ///   - `"sealed,abstract"` — both sealed and abstract classes
  ///   - `"*"` — any class may collect subtypes
  final String filterCollectSubTypes;

  MacroCapability combine(MacroCapability c) {
    String combineFilter(String base, String other) {
      if (base == '*' || other == '*') return '*';
      if (base.isEmpty) return other;
      if (other.isEmpty) return base;

      return '$base,$other';
    }

    return MacroCapability(
      classFields: c.classFields ? true : classFields,
      filterClassInstanceFields: c.filterClassInstanceFields ? true : filterClassInstanceFields,
      filterClassStaticFields: c.filterClassStaticFields ? true : filterClassStaticFields,
      filterClassIgnoreSetterOnly: c.filterClassIgnoreSetterOnly ? true : filterClassIgnoreSetterOnly,
      filterClassFieldMetadata: combineFilter(filterClassFieldMetadata, c.filterClassFieldMetadata),
      classConstructors: c.classConstructors ? true : classConstructors,
      filterClassConstructorParameterMetadata: combineFilter(
        filterClassConstructorParameterMetadata,
        c.filterClassConstructorParameterMetadata,
      ),
      mergeClassFieldWithConstructorParameter: c.mergeClassFieldWithConstructorParameter
          ? true
          : mergeClassFieldWithConstructorParameter,
      classMethods: c.classMethods ? true : classMethods,
      filterClassInstanceMethod: c.filterClassInstanceMethod ? true : filterClassInstanceMethod,
      filterClassStaticMethod: c.filterClassStaticMethod ? true : filterClassStaticMethod,
      filterMethods: combineFilter(filterMethods, c.filterMethods),
      filterClassMethodMetadata: combineFilter(filterClassMethodMetadata, c.filterClassMethodMetadata),
      collectClassSubTypes: c.collectClassSubTypes ? true : collectClassSubTypes,
      filterCollectSubTypes: combineFilter(filterCollectSubTypes, c.filterCollectSubTypes),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (classFields) 'cf': true,
      if (filterClassInstanceFields) 'fcif': true,
      if (filterClassIgnoreSetterOnly) 'fciso': true,
      if (filterClassStaticFields) 'fcsf': true,
      if (filterClassFieldMetadata.isNotEmpty) 'fcfm': filterClassFieldMetadata,
      if (classConstructors) 'cc': true,
      if (filterClassConstructorParameterMetadata.isNotEmpty) 'fccpm': filterClassConstructorParameterMetadata,
      if (mergeClassFieldWithConstructorParameter) 'mcfwcp': true,
      if (classMethods) 'cm': true,
      if (filterClassInstanceMethod) 'fcim': true,
      if (filterClassStaticMethod) 'fcsm': true,
      if (filterMethods.isNotEmpty) 'fm': filterMethods,
      if (filterClassMethodMetadata.isNotEmpty) 'fcmm': filterClassMethodMetadata,
      if (collectClassSubTypes) 'ccst': true,
      if (filterCollectSubTypes.isNotEmpty) 'fccst': filterCollectSubTypes,
    };
  }

  @override
  String toString() {
    return 'MacroCapability{classFields: $classFields, filterClassInstanceFields: $filterClassInstanceFields, filterClassStaticFields: $filterClassStaticFields, filterClassFieldMetadata: $filterClassFieldMetadata, classConstructors: $classConstructors, filterClassConstructorParameterMetadata: $filterClassConstructorParameterMetadata, mergeClassFieldWithConstructorParameter: $mergeClassFieldWithConstructorParameter, classMethods: $classMethods, filterClassInstanceMethod: $filterClassInstanceMethod, filterClassStaticMethod: $filterClassStaticMethod, filterMethods: $filterMethods, filterClassMethodMetadata: $filterClassMethodMetadata, collectClassSubTypes: $collectClassSubTypes, filterCollectSubTypes: $filterCollectSubTypes}';
  }
}

/// Represents the configuration for a macro applied to a specific declaration.
///
/// A `MacroConfig` contains:
///   * the macro's capability information [capability] describing what the
///     macro is allowed to read from the declaration, and
///   * a key [key] that holds the constant values provided in the metadata
///     where the macro was applied.
///
/// In other words, the key captures the user-defined configuration of the macro
/// (e.g., options passed through an annotation), while the capability describes
/// what structural information the generator may access.
///
/// This configuration is passed to the macro generator at runtime, allowing the
/// generator to behave according to the metadata applied in source code.
class MacroConfig {
  MacroConfig({
    required this.capability,
    required this.combine,
    required this.key,
  });

  static MacroConfig fromJson(Map<String, dynamic> json) {
    return MacroConfig(
      capability: MacroCapability.fromJson(json['c'] as Map<String, dynamic>),
      combine: json['cgc'] == true,
      key: MacroKey.fromJson(json['k'] as Map<String, dynamic>),
    );
  }

  /// The applied capability
  final MacroCapability capability;

  /// The generator configuration
  final MacroKey key;

  /// Whether to combine generated code for multiple macros applied to a single declaration
  final bool combine;

  @internal
  late final int? configHash = xxh32code(toString());

  Map<String, dynamic> toJson() {
    return {
      'c': capability.toJson(),
      'k': key.toJson(),
      if (combine) 'cgc': true,
    };
  }

  @override
  String toString() {
    return 'MacroConfig{capability: $capability, key: $key, combine: $combine}';
  }
}

/// Represents a single metadata annotation applied to a declaration,
/// such as `@JsonKey` or any custom macro configuration.
///
/// A `MacroKey` captures:
///   * the name of the metadata annotation, and
///   * the constant values of its constructor arguments as [properties].
///
/// This allows the macro system to reconstruct the original configuration
/// supplied by the user directly from the source code. It enables the
/// generator to understand how the macro was configured (e.g., user options,
/// flags, names, defaults, etc.) without re-parsing the annotation.
class MacroKey {
  const MacroKey({
    required this.name,
    required this.properties,
  });

  static MacroKey fromJson(Map<String, dynamic> json) {
    return MacroKey(
      name: json['n'] as String,
      properties:
          (json['p'] as List?)?.map((e) => MacroProperty.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
    );
  }

  /// The name of the metadata annotation.
  ///
  /// For example:
  ///   * `'JsonKey'`
  ///   * `'MyConfig'`
  ///
  /// This value identifies which annotation was applied.
  final String name;

  /// The list of constant properties provided to the annotation's constructor.
  ///
  /// Each [MacroProperty] represents a single named or positional argument
  /// passed to the metadata. These values together allow the macro generator
  /// to fully reconstruct how the annotation was used in the source code.
  ///
  /// Example for:
  ///   `@JsonKey(name: 'id', includeIfNull: false)`
  ///
  /// The list would contain two properties:
  ///   * name = 'name', value = 'id'
  ///   * name = 'includeIfNull', value = false
  final List<MacroProperty> properties;

  Map<String, dynamic> toJson() {
    return {
      'n': name,
      if (properties.isNotEmpty) 'p': properties.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'MacroKey{name: $name, properties: $properties}';
  }
}

class MacroClassConstructor {
  const MacroClassConstructor({
    required this.constructorName,
    this.modifier = const MacroModifier({}),
    this.redirectFactory,
    required this.positionalFields,
    required this.namedFields,
  });

  static MacroClassConstructor fromJson(Map<String, dynamic> json) {
    return MacroClassConstructor(
      constructorName: json['cn'] as String,
      modifier: json['m'] == null
          ? const MacroModifier({})
          : MacroModifier((json['m'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool))),
      redirectFactory: json['rf'] as String?,
      positionalFields: MacroProperty._decodeUpdatableList((json['pf'] as List?) ?? const []),
      namedFields: MacroProperty._decodeUpdatableList((json['nf'] as List?) ?? const []),
    );
  }

  final String constructorName;
  final MacroModifier modifier;
  final String? redirectFactory;
  final List<MacroProperty> positionalFields;
  final List<MacroProperty> namedFields;

  bool get hasFields => positionalFields.isNotEmpty || namedFields.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'cn': constructorName,
      if (modifier.value.isNotEmpty) 'm': modifier.value,
      if (redirectFactory?.isNotEmpty == true) 'rf': redirectFactory,
      if (positionalFields.isNotEmpty) 'pf': positionalFields.map((e) => e.toJson()).toList(),
      if (namedFields.isNotEmpty) 'nf': namedFields.map((e) => e.toJson()).toList(),
    };
  }
}

class MacroProperty {
  MacroProperty({
    required this.name,
    required this.type,
    required this.typeInfo,
    this.deepEquality,
    this.typeArguments,
    this.classInfo,
    this.functionTypeInfo,
    this.extraMetadata,
    this.modifier = const MacroModifier({}),
    this.keys,
    this.constantValue,
    this.requireConversionToLiteral,
  });

  static MacroProperty fromJson(Map<String, dynamic> json) {
    final typeInfo = TypeInfo.values.byIdOr((json['ti'] as num).toInt(), defaultValue: TypeInfo.dynamic);
    final constantValue = json['cv'] as Object?;

    return MacroProperty(
      name: (json['n'] as String?) ?? '',
      type: (json['t'] as String?) ?? '',
      typeInfo: typeInfo,
      deepEquality: json['dq'] as bool?,
      typeArguments: (json['ta'] as List?)?.map((e) => MacroProperty.fromJson(e as Map<String, dynamic>)).toList(),
      classInfo: json['ci'] == null ? null : MacroClassDeclaration.fromJson(json['ci'] as Map<String, dynamic>),
      functionTypeInfo: json['fti'] == null ? null : MacroMethod.fromJson(json['fti'] as Map<String, dynamic>),
      extraMetadata: json['em'] == null
          ? null
          : (json['em'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, MacroProperty.fromJson(v as Map<String, dynamic>)),
            ),
      modifier: json['m'] == null
          ? const MacroModifier({})
          : MacroModifier((json['m'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool))),
      keys: (json['k'] as List?)?.map((e) => MacroKey.fromJson(e as Map<String, dynamic>)).toList(),
      constantValue: switch (constantValue) {
        _ when json['cvType'] == 'set' && constantValue is List => constantValue.toSet(),
        _ when json['cvType'] == 'macro_property' && constantValue is Map => MacroProperty.fromJson(
          constantValue as Map<String, dynamic>,
        ),
        _ => constantValue,
      },
      requireConversionToLiteral: json['rcl'] as bool?,
    );
  }

  static List<MacroProperty> _decodeUpdatableList(List rawValues) {
    List<MacroProperty> results = [];

    for (int i = 0; i < rawValues.length; i++) {
      final res = MacroProperty.fromJson(rawValues[i] as Map<String, dynamic>);
      results.add(res);

      if (res.classInfo?.ready == false) {
        addPendingUpdate(() {
          final sharedDec = getZoneSharedClassDeclaration() ?? {};
          if (sharedDec[res.classInfo!.classId] case MacroClassDeclaration v) {
            results[i] = results[i].copyWith(classInfo: v);
          }
        });
      }
    }

    return results;
  }

  final String name;
  final String type;
  final TypeInfo typeInfo;
  final MacroClassDeclaration? classInfo;
  final bool? deepEquality;
  final List<MacroProperty>? typeArguments;
  final MacroMethod? functionTypeInfo;
  final Map<String, MacroProperty>? extraMetadata;
  final MacroModifier modifier;
  final List<MacroKey>? keys;
  final Object? constantValue;
  final bool? requireConversionToLiteral;

  String? get constantValueToDartLiteralIfNeeded {
    if (requireConversionToLiteral == true) {
      return jsonLiteralAsDart(constantValue);
    } else if (constantValue case String v) {
      return v;
    }
    return null;
  }

  bool get isNullable => modifier.isNullable || type.endsWith('?');

  static bool isDynamicIterable(String type) {
    return const [
      'Iterable<dynamic>',
      'Iterable',
      'Iterable<Object?>',
    ].contains(type.removedNullability);
  }

  static bool isDynamicList(String type) {
    return const [
      'List<dynamic>',
      'List',
      'List<Object?>',
    ].contains(type.removedNullability);
  }

  static bool isListEncodeDirectlyToJson(String type) {
    return const [
      'List<int>',
      'List<double>',
      'List<num>',
      'List<String>',
      'List<bool>',
      'List<Map<String, int>>',
      'List<Map<String, double>>',
      'List<Map<String, num>>',
      'List<Map<String, String>>',
      'List<Map<String, bool>>',
    ].contains(type.replaceAll('?', ''));
  }

  static bool isDynamicSet(String type) {
    return const [
      'Set<dynamic>',
      'Set',
      'Set<Object?>',
    ].contains(type.removedNullability);
  }

  static bool isDynamicMap(String type) {
    return const ['Map', 'Map<String, dynamic>'].contains(type.removedNullability);
  }

  static bool isMapEncodeDirectlyToJson(String type) {
    return const [
      'Map<String, int>',
      'Map<String, double>',
      'Map<String, num>',
      'Map<String, String>',
      'Map<String, bool>',
      'Map<String, List<String>',
      'Map<String, List<double>>',
      'Map<String, List<num>>',
      'Map<String, List<String>>',
      'Map<String, List<bool>>',
    ].contains(type.replaceAll('?', ''));
  }

  Map<String, Object?>? _cacheKeysByKeyName;

  bool get isMapStringDynamicType {
    if (typeInfo != TypeInfo.map) return false;
    if (typeArguments?.firstOrNull?.typeInfo != TypeInfo.string) return false;
    if (typeArguments?.elementAtOrNull(1)?.typeInfo != TypeInfo.dynamic) return false;
    return true;
  }

  /// Convert first key in [keys] into [T] and cache it for future use
  T? cacheFirstKeyTo<T>(String keyName, T Function(MacroKey key) convertFn, {bool disableCache = false}) {
    var key = disableCache ? null : _cacheKeysByKeyName?[keyName];
    if (key is T) return key;

    if (key == Null) return null;

    final macroKey = keys?.firstWhereOrNull((e) => e.name == keyName);
    if (macroKey == null) {
      if (!disableCache) {
        _cacheKeysByKeyName ??= {};
        _cacheKeysByKeyName![keyName] = Null;
      }
      return null;
    }

    final res = convertFn(macroKey);
    if (!disableCache) {
      _cacheKeysByKeyName ??= {};
      _cacheKeysByKeyName![keyName] = res;
    }
    return res;
  }

  T? keyOfTo<T>(T Function(MacroKey key) convertFn, {required int index}) {
    final key = keys?.elementAtOrNull(index);
    if (key == null) return null;

    return convertFn(key);
  }

  MacroProperty copyWith({MacroClassDeclaration? classInfo}) {
    return MacroProperty(
      name: name,
      type: type,
      typeInfo: typeInfo,
      modifier: modifier,
      typeArguments: typeArguments,
      constantValue: constantValue,
      functionTypeInfo: functionTypeInfo,
      requireConversionToLiteral: requireConversionToLiteral,
      keys: keys,
      extraMetadata: extraMetadata,
      classInfo: classInfo ?? this.classInfo,
      deepEquality: deepEquality,
    );
  }

  bool? asBoolConstantValue() {
    if (constantValue case bool v) return v;
    return null;
  }

  String? asStringConstantValue() {
    if (constantValue case String v) return v;
    return null;
  }

  int? asIntConstantValue() {
    if (constantValue case int v) return v;
    return null;
  }

  double? asDoubleConstantValue() {
    if (constantValue case double v) return v;
    return null;
  }

  num? asNumConstantValue() {
    if (constantValue case num v) return v;
    return null;
  }

  /// Represent a Dart Type from annotation
  MacroProperty? asTypeValue() {
    if (constantValue case MacroProperty v) return v;
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (name.isNotEmpty) 'n': name,
      if (type.isNotEmpty) 't': type,
      'ti': typeInfo.id,
      if (deepEquality == true) 'dq': true,
      if (typeArguments?.isNotEmpty == true) 'ta': typeArguments!.map((e) => e.toJson()).toList(),
      if (classInfo != null) 'ci': classInfo!.toJson(),
      if (functionTypeInfo != null) 'fti': functionTypeInfo!.toJson(),
      if (extraMetadata?.isNotEmpty == true) 'em': extraMetadata!.map((k, v) => MapEntry(k, v.toJson())),
      if (modifier.isNotEmpty) 'm': modifier,
      if (keys?.isNotEmpty == true) 'k': keys!.map((e) => e.toJson()).toList(),
      if (constantValue case Set val) ...{
        'cv': val.toList(),
        'cvType': 'set',
      } else if (constantValue case MacroProperty val) ...{
        'cv': val.toJson(),
        'cvType': 'macro_property',
      } else if (constantValue != null)
        'cv': constantValue,
      if (requireConversionToLiteral == true) 'rcl': true,
    };
  }

  @override
  String toString() {
    return 'MacroProperty{name: $name, type: $type, typeInfo: $typeInfo, classInfo: $classInfo, deepEquality: $deepEquality, typeArguments: $typeArguments, functionTypeInfo: $functionTypeInfo, extraMetadata: $extraMetadata, modifier: $modifier, keys: $keys, constantValue: $constantValue, requireConversionToLiteral: $requireConversionToLiteral, _cacheKeysByKeyName: $_cacheKeysByKeyName}';
  }
}

typedef IntType = int;

enum TypeInfo implements Identifiable<int> {
  clazz(1),
  clazzAugmentation(2),
  extension(3),
  extensionType(4),
  int(5),
  double(6),
  num(7),
  string(8),
  boolean(9),
  iterable(10),
  list(11),
  map(12),
  set(13),
  datetime(14),
  duration(15),
  bigInt(16),
  uri(17),
  enumData(18),
  record(19),
  symbol(20),
  function(21),
  future(22),
  stream(23),
  object(24),
  nullType(25),
  voidType(26),
  type(27),
  dynamic(28),
  generic(29);

  const TypeInfo(this.id);

  @override
  final IntType id;

  bool get isIntOrDouble => this == TypeInfo.int || this == TypeInfo.double;

  bool get isClassLike {
    return switch (this) {
      clazz || clazzAugmentation || extensionType => true,
      _ => false,
    };
  }
}

extension type const MacroModifier(Map<String, bool> value) implements Map<String, bool> {
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
    bool isSealed = false,
    bool isExhaustive = false,
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
    bool isRequiredNamed = false,
    bool isRequiredPositional = false,
    bool isGetProperty = false,
    bool isSetProperty = false,
    bool hasInitializer = false,
    bool hasDefaultValue = false,
    bool isInitializingFormal = false,
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
      if (isSealed) 'cs': true,
      if (isExhaustive) 'ce': true,
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
      if (isRequiredNamed) 'rn': true,
      if (isRequiredPositional) 'rp': true,
      if (isGetProperty) 'gp': true,
      if (isSetProperty) 'sp': true,
      if (hasInitializer) 'hi': true,
      if (hasDefaultValue) 'hd': true,
      if (isInitializingFormal) 'if': true,
    });
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

  bool get isSealed => value['sc'] == true;

  bool get isExhaustive => value['ce'] == true;

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

  bool get isRequireNamed => value['rn'] == true;

  bool get isRequirePositional => value['rp'] == true;

  bool get isGetProperty => value['gp'] == true;

  bool get isSetProperty => value['sp'] == true;

  /// Whether the variable has an initializer at declaration.
  bool get hasInitializer => value['hi'] == true;

  /// Whether the parameter has a default value
  bool get hasDefaultValue => value['hdv'] == true;

  ///  Whether the parameter is an initializing formal parameter.
  bool get isInitializingFormal => value['if'] == true;
}

class MacroMethod {
  const MacroMethod({
    required this.name,
    required this.typeParams,
    required this.params,
    required this.returns,
    required this.modifier,
    this.keys,
  });

  static MacroMethod fromJson(Map<String, dynamic> json) {
    return MacroMethod(
      name: json['n'] as String? ?? '',
      typeParams: (json['tp'] as List?)?.map((e) => e as String).toList() ?? const [],
      params: MacroProperty._decodeUpdatableList(json['p'] as List),
      returns: MacroProperty._decodeUpdatableList(json['r'] as List),
      modifier: json['m'] == null
          ? const MacroModifier({})
          : MacroModifier((json['m'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool))),
      keys: (json['k'] as List?)?.map((e) => MacroKey.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  final String name;
  final List<String> typeParams;
  final List<MacroProperty> params;
  final List<MacroProperty> returns;
  final MacroModifier modifier;
  final List<MacroKey>? keys;

  Map<String, dynamic> toJson() {
    return {
      if (name.isNotEmpty) 'n': name,
      if (typeParams.isNotEmpty) 'tp': typeParams,
      if (params.isNotEmpty) 'p': params.map((e) => e.toJson()).toList(),
      'r': returns.map((e) => e.toJson()).toList(),
      if (modifier.value.isNotEmpty) 'm': modifier,
      if (keys?.isNotEmpty == true) 'k': keys!.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'MacroFunction{name: $name, typeParams: $typeParams, params: $params, returns: $returns, modifier: $modifier, keys: $keys}';
  }
}

class MacroClassDeclaration {
  const MacroClassDeclaration({
    required this.classId,
    required this.configs,
    required this.className,
    required this.modifier,
    required this.classTypeParameters,
    required this.classFields,
    required this.constructors,
    required this.methods,
    required this.subTypes,
    this.ready = true,
  });

  factory MacroClassDeclaration.pendingDeclaration({
    required String classId,
    required String className,
    required List<MacroConfig> configs,
    required MacroModifier modifier,
    required List<String>? classTypeParameters,
    required List<MacroClassDeclaration>? subTypes,
  }) {
    return MacroClassDeclaration(
      classId: classId,
      configs: configs,
      className: className,
      modifier: modifier,
      classTypeParameters: classTypeParameters,
      classFields: null,
      constructors: null,
      methods: null,
      subTypes: null,
      ready: false,
    );
  }

  static MacroClassDeclaration fromJson(Map<String, dynamic> json) {
    final classId = json['cid'] as String;
    final configs = (json['cf'] as List).map((e) => MacroConfig.fromJson(e as Map<String, dynamic>)).toList();
    final ready = (json['rs'] as bool?) ?? true;

    final sharedDec = getZoneSharedClassDeclaration() ?? {};
    if (sharedDec[classId] case MacroClassDeclaration value) {
      return value.copyWith(configs: configs, ready: true);
    }

    final List<MacroProperty> classFields = [];
    final classFieldsRaw = (json['f'] as List?) ?? const [];
    for (int i = 0; i < classFieldsRaw.length; i++) {
      final res = MacroProperty.fromJson(classFieldsRaw[i] as Map<String, dynamic>);
      classFields.add(res);
      if (res.classInfo?.ready == false) {
        addPendingUpdate(() {
          if (sharedDec[res.classInfo!.classId] case MacroClassDeclaration v) {
            classFields[i] = classFields[i].copyWith(classInfo: v);
          }
        });
      }
    }

    return MacroClassDeclaration(
      classId: classId,
      configs: configs,
      className: json['cn'] as String,
      modifier: json['cm'] == null
          ? const MacroModifier({})
          : MacroModifier((json['cm'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool))),
      classTypeParameters: (json['tp'] as List?)?.map((e) => e as String).toList(),
      classFields: classFields,
      constructors: (json['c'] as List?)
          ?.map((e) => MacroClassConstructor.fromJson(e as Map<String, dynamic>))
          .toList(),
      methods: (json['m'] as List?)?.map((e) => MacroMethod.fromJson(e as Map<String, dynamic>)).toList(),
      subTypes: (json['st'] as List?)?.map((e) => MacroClassDeclaration.fromJson(e as Map<String, dynamic>)).toList(),
      ready: ready,
    );
  }

  final String classId;
  final List<MacroConfig> configs;
  final String className;
  final MacroModifier modifier;
  final List<String>? classTypeParameters;
  final List<MacroProperty>? classFields;
  final List<MacroClassConstructor>? constructors;
  final List<MacroMethod>? methods;
  final List<MacroClassDeclaration>? subTypes;
  final bool ready;

  MacroClassDeclaration copyWith({String? classId, List<MacroConfig>? configs, bool? ready}) {
    return MacroClassDeclaration(
      classId: classId ?? this.classId,
      configs: configs ?? this.configs,
      className: className,
      modifier: modifier,
      classTypeParameters: classTypeParameters,
      classFields: classFields,
      constructors: constructors,
      methods: methods,
      subTypes: subTypes,
      ready: ready ?? this.ready,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cid': classId,
      'cf': configs.map((e) => e.toJson()).toList(),
      'cn': className,
      if (ready == false) 'rs': false,
      if (ready) ...{
        if (modifier.value.isNotEmpty) 'cm': modifier.value,
        if (classTypeParameters?.isNotEmpty == true) 'tp': classTypeParameters,
        if (classFields?.isNotEmpty == true) 'f': classFields!.map((e) => e.toJson()).toList(),
        if (constructors?.isNotEmpty == true) 'c': constructors!.map((e) => e.toJson()).toList(),
        if (methods?.isNotEmpty == true) 'm': methods!.map((e) => e.toJson()).toList(),
        if (subTypes?.isNotEmpty == true) 'st': subTypes!.map((e) => e.toJson()).toList(),
      },
    };
  }

  @override
  String toString() {
    return 'MacroClassDeclaration{classId: $classId, configs: $configs, className: $className, modifier: $modifier, classTypeParameters: $classTypeParameters, classFields: $classFields, constructors: $constructors, methods: $methods, subTypes: $subTypes}';
  }
}

/// Represents an asset file change event for macro processing.
///
/// This class encapsulates information about an asset file that has been
/// created, modified, or deleted.
///
/// Asset macros use this information to determine which files need processing
/// and what type of change occurred.
class MacroAssetDeclaration {
  MacroAssetDeclaration({
    required this.path,
    required this.type,
  });

  static MacroAssetDeclaration fromJson(Map<String, dynamic> json) {
    return MacroAssetDeclaration(
      path: json['p'] as String,
      type: MacroExt.decodeEnum<AssetChangeType, String>(
        AssetChangeType.values,
        json['t'] as String,
        unknownValue: AssetChangeType.modify,
      ),
    );
  }

  /// Absolute path of the asset file.
  ///
  /// This is the full filesystem path to the asset file that triggered
  /// the macro execution.
  ///
  /// Example: `'/home/user/project/assets/data/config.json'`
  final String path;

  /// The type of change that occurred to the asset file.
  ///
  /// Indicates whether the file was added, modified, or removed,
  /// allowing macros to handle different change types appropriately.
  final AssetChangeType type;

  /// The basename of the asset file (filename with extension).
  ///
  /// Example: For path `'/project/assets/config.json'`, returns `'config.json'`
  String get name => p.basename(path);

  /// The file extension including the dot.
  ///
  /// Uses [p.extension] with level 2 to handle double extensions like `.tar.gz`.
  ///
  /// Example: For path `'/project/assets/archive.tar.gz'`, returns `'.tar.gz'`
  String get extension => p.extension(path, 2);

  Map<String, dynamic> toJson() {
    return {
      'p': path,
      't': type.name,
    };
  }

  @override
  String toString() {
    return 'MacroAssetDeclaration{path: $path, type: $type}';
  }
}

/// Configuration for asset-based macro generation.
///
/// This class defines which macro should process asset files and where
/// the generated output should be written. It's used to configure macros
/// that monitor asset directories and generate code or data based on
/// asset file changes.
///
/// Example:
/// ```dart
/// AssetMacroInfo(
///   macroName: 'ResizeImageMacro',
///   output: 'assets/images-generated',
/// )
/// ```
class AssetMacroInfo {
  AssetMacroInfo({
    required this.macroName,
    this.extension = '*',
    required this.output,
    this.config = const {},
  });

  static AssetMacroInfo fromJson(Map<String, dynamic> json) {
    return AssetMacroInfo(
      macroName: json['name'] as String,
      extension: json['ext'] as String,
      output: json['output'] as String,
      config: json['config'] as Map<String, dynamic>?,
    );
  }

  /// Names of macros that should respond to asset directory changes
  final String macroName;

  /// File extensions to monitor within the directory
  ///
  /// Only files with these extensions will trigger macro regeneration.
  ///
  /// Supports:
  ///   - `'*'` to monitor all file types
  ///   - Specific extensions ex. `'.png,.json'`
  ///
  /// Examples: `'.json',.yaml'`, `'*'`, `'.png,.jpg,.svg'`
  final String extension;

  /// Output directory path for generated assets.
  ///
  /// When asset macros generate data based on asset files, the generated
  /// files must be written to this directory to avoid recursive regeneration loops.
  ///
  /// If generated files were written back to [assetDirectories], they would trigger
  /// the file watcher again, causing infinite regeneration cycles.
  ///
  /// Path should be relative to your project root.
  ///
  /// Example: `'assets-gen'`, `'lib/generated/assets'`
  final String output;

  /// Custom configuration for provided macro
  final Map<String, dynamic>? config;

  late final List<String> allExtensions = extension == '*' ? const [] : extension.split(',');

  Map<String, dynamic> toJson() {
    return {
      'name': macroName,
      'ext': extension,
      'output': output,
      if (config != null) 'config': config,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetMacroInfo &&
          runtimeType == other.runtimeType &&
          macroName == other.macroName &&
          extension == other.extension &&
          output == other.output &&
          config == other.config;

  @override
  int get hashCode => macroName.hashCode ^ extension.hashCode ^ output.hashCode ^ config.hashCode;

  @override
  String toString() {
    return 'AssetMacroInfo{macroName: $macroName, extension: $extension, output: $output, config: $config}';
  }
}

enum AssetChangeType {
  add,
  modify,
  remove,
}

enum TargetType { clazz, asset }

class AssetState {
  AssetState({
    required this.relativeBasePath,
    required this.absoluteBasePath,
    required this.absoluteBaseOutputPath,
  });

  /// Relative path of the base asset directory in which macro triggered
  ///
  /// Example: `'assets'`
  final String relativeBasePath;

  /// Absolute path of the base asset directory.
  ///
  /// Example: `'/home/user/project/assets'`
  final String absoluteBasePath;

  /// The base output path for generated asset file
  ///
  /// its only has non null value when generating asset file
  final String absoluteBaseOutputPath;
}

class MacroState {
  MacroState({
    required this.macro,
    required this.remainingMacro,
    required this.targetType,
    required this.targetName,
    required this.modifier,
    required this.isCombingGenerator,
    required this.suffixName,
    required this.assetState,
    required Map<String, MacroClassDeclaration>? classesById,
  }) : _classesById = classesById;

  /// Represents a single metadata annotation applied to a declaration,
  /// such as `@JsonKey` or any custom macro configuration.
  final MacroKey macro;

  /// The list of remaining macros that will be executed after the current one
  final Iterable<MacroKey> remainingMacro;

  /// The type of target this macro is applied to (class, asset, variable,...)
  final TargetType targetType;

  /// The name of the target element (class, asset or variable name,...)
  final String targetName;

  /// The modifier flags containing information about target declaration
  final MacroModifier modifier;

  /// Whether this macro' combine generated code with other macros' output
  final bool isCombingGenerator;

  /// The suffix to append to generated code
  final String suffixName;

  /// The asset information in which triggered the macro generation
  final AssetState? assetState;

  /// Formatter for generated code produced by the asset macro.
  ///
  /// This formatter is specifically configured for code generated through the asset
  /// macro system.
  ///
  /// Note: Regular macros have automatic formatting applied by the Dart macro system.
  /// This formatter is only needed for custom code generation scenarios where the
  /// asset macro produces output that requires explicit formatting.
  static final dartFormatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
    trailingCommas: TrailingCommas.preserve,
    pageWidth: 120,
  );

  static String formatCode(String code) {
    try {
      return dartFormatter.format(code);
    } catch (_) {
      return code;
    }
  }

  final Map<String, Object?> _data = {};
  final Map<String, MacroClassDeclaration>? _classesById;
  List<String>? _generatedFilePath;

  /// The generated code that can be combined with other macros
  String get generated => _generated;
  String _generated = '';

  /// The generated code that cannot be combined with other macros
  String? get generatedNonCombinable => _generatedNonCombinable;
  String? _generatedNonCombinable;

  /// The generated asset file during execution
  List<String> get generatedFilePaths => _generatedFilePath ?? const [];

  /// Retrieves a class declaration by its unique class ID
  @pragma('vm:prefer-inline')
  MacroClassDeclaration? getClassById(String classId) {
    return _classesById?[classId];
  }

  /// Reports generated code to be written to output files
  ///
  /// If [canBeCombined] is true, the code will be combined with other macros' output
  /// in a single generated file. If false, it will be written not combined.
  void reportGenerated(String code, {bool canBeCombined = true}) {
    if (!canBeCombined) {
      _generatedNonCombinable = code;
    } else {
      _generated = code;
    }
  }

  /// Reports file paths that was generated during macro execution
  void reportGeneratedFile(List<String> paths) {
    _generatedFilePath ??= [];
    _generatedFilePath!.addAll(paths);
  }

  /// Stores a value in the macro state's temporary data storage
  ///
  /// This can be used to share data between different lifecycle methods
  /// (e.g., between onClassFields and onClassConstructors).
  void set(String key, Object? value) {
    _data[key] = value;
  }

  /// Retrieves a value from the macro state's temporary data storage
  ///
  /// Throws an assertion error if the value is not of type [T].
  T get<T>(String key) {
    assert(_data[key] is T);

    return _data[key] as T;
  }

  /// Retrieves a value from the macro state's temporary data storage, or null if not found
  ///
  /// Returns null if the key doesn't exist or the value is null.
  /// Throws an assertion error if the value exists but is not of type [T].
  T? getOrNull<T>(String key) {
    final value = _data[key];
    if (value == null) return null;

    assert(value is T);
    return value as T;
  }

  /// Retrieves a boolean value from the macro state's temporary data storage
  ///
  /// Returns [defaultVal] if the key doesn't exist or the value is not a boolean.
  bool getBool(String key, [bool defaultVal = false]) {
    final value = _data[key];
    return value is bool ? value : defaultVal;
  }

  /// Retrieves a nullable boolean value from the macro state's temporary data storage
  ///
  /// Returns [defaultVal] if the key doesn't exist or the value is not a boolean.
  bool? getBoolOrNull(String key, [bool? defaultVal]) {
    final value = _data[key];
    return value is bool ? value : defaultVal;
  }
}

abstract class BaseMacroGenerator {
  const BaseMacroGenerator();

  String get suffixName;

  /// called first time for each class with macro annotation
  Future<void> init(MacroState state);

  /// Called for a class target which have a type parameter(generic)
  Future<void> onClassTypeParameter(MacroState state, List<String> typeParameters);

  /// called when macro has class fields capability.
  /// you can use these fields and generate constructor, when augment feature released
  /// or use the [onClassConstructor] to know the field defined as positional or named.
  Future<void> onClassFields(MacroState state, List<MacroProperty> classFields);

  /// called with all available constructor of the class when macro has class constructor capability
  Future<void> onClassConstructors(MacroState state, List<MacroClassConstructor> classConstructor);

  /// called with all available method of the class when macro has class method capability
  Future<void> onClassMethods(MacroState state, List<MacroMethod> executable);

  /// called with all class declaration that's a subtype of target class
  Future<void> onClassSubTypes(MacroState state, List<MacroClassDeclaration> subTypes) async {}

  /// called when a monitored asset file is created, modified, or deleted in configured asset directories
  Future<void> onAsset(MacroState state, MacroAssetDeclaration asset);

  /// called at last step to generate the code
  Future<void> onGenerate(MacroState state);
}

abstract class MacroGenerator implements BaseMacroGenerator {
  const MacroGenerator({required this.capability});

  final MacroCapability capability;

  @override
  Future<void> init(MacroState state) async {}

  @override
  Future<void> onClassTypeParameter(MacroState state, List<String> typeParameters) async {}

  @override
  Future<void> onClassFields(MacroState state, List<MacroProperty> classFields) async {}

  @override
  Future<void> onClassConstructors(MacroState state, List<MacroClassConstructor> classConstructor) async {}

  @override
  Future<void> onClassMethods(MacroState state, List<MacroMethod> names) async {}

  @override
  Future<void> onClassSubTypes(MacroState state, List<MacroClassDeclaration> subTypes) async {}

  @override
  Future<void> onAsset(MacroState state, MacroAssetDeclaration asset) async {}

  /// Return whether a class have a method with specified [name] or in metadata support
  /// generating this capability to the class.
  ///
  /// the configuration for that feature must be boolean value and it consider
  /// to return true when the configuration value is not explicitly set false value
  (bool, MacroMethod?) hasMethodOf({
    required MacroClassDeclaration? declaration,
    required String macroName,
    required String name,
    required String configName,
    bool? staticFunction,
  }) {
    if (declaration == null) return (false, null);

    // fast path: check toJson method
    final method = declaration.methods?.firstWhereOrNull(
      (e) => e.name == name && (staticFunction == null || staticFunction == e.modifier.isStatic),
    );
    if (method != null) {
      return (true, method);
    }

    // slow path, check for config for all metadata
    for (final config in declaration.configs) {
      final macroKey = config.key;
      if (macroKey.name == macroName &&
          macroKey.properties.firstWhereOrNull((e) => e.name == configName)?.constantValue != false) {
        return (true, null);
      }
    }

    return (false, null);
  }

  String computeClassTypeParamWithBound(List<String> generics) {
    final value = generics
        .mapIndexed((i, e) {
          // final extend = genericsExtends![i];
          // return extend != '' ? '$e extends $extend' : e;
          return e;
        })
        .join(',');

    return '<$value>';
  }
}

@internal
extension MacroX on String {
  String get removedNullability {
    return replaceFirst('?', '');
  }
}
