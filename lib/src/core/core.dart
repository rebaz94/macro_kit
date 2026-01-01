import 'dart:core';

import 'package:change_case/change_case.dart';
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:macro_kit/src/analyzer/base_macro.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/types_ext.dart';
import 'package:macro_kit/src/analyzer/utils/hash.dart';
import 'package:macro_kit/src/core/constant.dart';
import 'package:macro_kit/src/core/extension.dart';
import 'package:macro_kit/src/core/modifier.dart';
import 'package:macro_kit/src/macro/data_class/helpers.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

export 'package:macro_kit/src/analyzer/base_macro.dart';

/// Macro used to attach metadata to a Dart declaration.
///
/// A `Macro` defines:
///   * which code generator should run, and
///   * whether its output should be merged with other macros applied
///     to the same declaration.
///
/// {@category Get started}
/// {@category Installation}
/// {@category Models}
/// {@category Data Class Macro}
/// {@category Asset Path Macro}
/// {@category Global Configuration}
/// {@category Write New Macro}
/// {@category Capability}
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

  static T parseMacroConfig<T>({
    required Object? value,
    required T Function(Map<String, dynamic> json) fn,
    required T defaultValue,
  }) {
    if (value is! Map) return defaultValue;

    try {
      return fn(value as Map<String, dynamic>);
    } catch (e) {
      return defaultValue;
    }
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
  late final int? configHash = generateHash(toString());

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

  /// The name of the constructor
  final String constructorName;

  /// A constructor modifier information
  final MacroModifier modifier;

  /// Redirect factory name
  final String? redirectFactory;

  /// Positional field of the constructor
  final List<MacroProperty> positionalFields;

  /// Named field of the constructor
  final List<MacroProperty> namedFields;

  /// Return true if has positional or named field
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

  @override
  String toString() {
    return 'MacroClassConstructor{constructorName: $constructorName, modifier: $modifier, redirectFactory: $redirectFactory, positionalFields: $positionalFields, namedFields: $namedFields}';
  }
}

/// Represents a property or type declaration with comprehensive metadata.
///
/// This is a generic container class that holds different information depending on the
/// [typeInfo]. For example:
/// - For classes or enums: [classInfo] contains the declaration details
/// - For functions: [functionTypeInfo] contains the function signature
/// - For generics: [typeArguments] contains the type parameters
/// - For constants: [constantValue] and [constantModifier] contain the value and its modifiers
///
/// This class is used to represent fields, parameters, return types, and type references
/// throughout the macro system.
class MacroProperty {
  MacroProperty({
    required this.name,
    required this.importPrefix,
    required this.type,
    required this.typeInfo,
    this.typeArguments,
    this.classInfo,
    this.functionTypeInfo,
    this.typeRefType,
    this.extraMetadata,
    this.modifier = const MacroModifier({}),
    this.keys,
    this.fieldInitializer,
    this.constantValue,
    this.constantModifier,
    this.requireConversionToLiteral,
  });

  static MacroProperty fromJson(Map<String, dynamic> json) {
    final typeInfo = TypeInfo.values.byIdOr((json['ti'] as num).toInt(), defaultValue: TypeInfo.dynamic);

    return MacroProperty(
      name: (json['n'] as String?) ?? '',
      importPrefix: (json['ip'] as String?) ?? '',
      type: (json['t'] as String?) ?? '',
      typeInfo: typeInfo,
      typeRefType: json['trt'] != null ? MacroProperty.fromJson(json['trt'] as Map<String, dynamic>) : null,
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
      fieldInitializer: json['fi'] == null ? null : MacroProperty.fromJson(json['fi'] as Map<String, dynamic>),
      constantValue: decodeConstantPropertyType(json['cvType'] as String? ?? '', json['cv'] as Object?),
      constantModifier: json['cm'] == null
          ? null
          : MacroModifier((json['cm'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool))),
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

  static String toLiteralValue(
    Object? prop, {
    Map<String, List<MacroClassConstructor>>? types,
    bool insideConstant = false,
  }) {
    if (prop is! MacroProperty) {
      if (prop is Map && prop.containsKey('__use_ctor__')) {
        return clazzToLiteral(prop as Map<String, dynamic>, insideConstant: insideConstant);
      }

      return jsonLiteralAsDart(prop);
    }

    if (prop.requireConversionToLiteral == true) {
      if (prop.constantValue is Map && (prop.constantValue as Map).containsKey('__use_ctor__')) {
        return clazzToLiteral(prop.constantValue as Map<String, dynamic>, insideConstant: insideConstant);
      }
    }

    if (prop.typeInfo == TypeInfo.enumData) {
      return prop.asStringConstantValue() ?? '';
    }

    return jsonLiteralAsDart(prop.constantValue);
  }

  static String clazzToLiteral(Map<String, dynamic> config, {bool insideConstant = false}) {
    final classTypeName = config['__type__'] as String;
    final importPrefix = config['__import__'] as String;
    final positionalArgs = config['__pos_args__'] as List<Object?>;
    final namedArgs = config['__named_args__'] as Map<String, Object?>;

    final str = StringBuffer('${insideConstant ? '' : 'const '}$importPrefix$classTypeName(');
    insideConstant = true;

    for (int i = 0; i < positionalArgs.length; i++) {
      final argumentVal = positionalArgs[i];
      if (i > 0) str.write(', ');

      final literal = toLiteralValue(argumentVal, insideConstant: insideConstant);
      str.write(literal);
    }

    if (positionalArgs.isNotEmpty) {
      str.write(', ');
    }

    for (final (i, entry) in namedArgs.entries.indexed) {
      final name = entry.key;
      final value = entry.value;

      if (i > 0) str.write(', ');

      if (value == null) {
        str.write('$name: null');
        continue;
      }

      final literal = toLiteralValue(value, insideConstant: insideConstant);
      str.write('$name: $literal');
    }

    str.write(')');
    return str.toString();
  }

  /// Checks if the type is a dynamic Iterable (`Iterable`, `Iterable<dynamic>`, or `Iterable<Object?>`).
  static bool isDynamicIterable(String type) {
    return const [
      'Iterable<dynamic>',
      'Iterable',
      'Iterable<Object?>',
    ].contains(type.removedNullability);
  }

  /// Checks if the type is a dynamic List (`List`, `List<dynamic>`, or `List<Object?>`).
  static bool isDynamicList(String type) {
    return const [
      'List<dynamic>',
      'List',
      'List<Object?>',
    ].contains(type.removedNullability);
  }

  /// Checks if the List type can be encoded directly to JSON without transformation.
  ///
  /// Returns true for Lists of primitives and Maps with primitive values.
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

  /// Checks if the type is a dynamic Set (`Set`, `Set<dynamic>`, or `Set<Object?>`).
  static bool isDynamicSet(String type) {
    return const [
      'Set<dynamic>',
      'Set',
      'Set<Object?>',
    ].contains(type.removedNullability);
  }

  /// Checks if the type is a dynamic Map (`Map` or `Map<String, dynamic>`).
  static bool isDynamicMap(String type) {
    return const ['Map', 'Map<String, dynamic>'].contains(type.removedNullability);
  }

  /// Checks if the Map type can be encoded directly to JSON without transformation.
  ///
  /// Returns true for Maps with String keys and primitive or List values.
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

  /// Extracts the base type and type parameters from a generic type string.
  ///
  /// For example, `List<int>` returns type = 'List' and typeParams = a list with 'int' as value.
  ///
  /// Non-generic types return empty type parameters.
  static ({String type, List<String> typeParams}) extractTypeArguments(String type) {
    final t = type.removedNullability;

    final start = t.indexOf('<');
    if (start == -1) {
      return (type: t, typeParams: const <String>[]);
    }

    final end = t.lastIndexOf('>');
    if (end == -1) {
      return (type: t, typeParams: const <String>[]);
    }

    return (
      type: t.substring(0, start),
      typeParams: (t.substring(start + 1, end)).split(',').map((e) => e.trim()).toList(),
    );
  }

  /// Replaces type parameter names in type strings
  /// Handles simple types, generic types, bounds, and complex nested generics
  static String replaceTypeParameter(String typeString, Map<String, String> replacements) {
    if (replacements.isEmpty) return typeString;

    // Sort keys by length (descending) to handle longer names first
    // This prevents "T1" from matching "T" prematurely
    final sortedKeys = replacements.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

    String result = typeString;

    for (final oldType in sortedKeys) {
      final newType = replacements[oldType]!;

      // Use word boundary pattern to match complete type names only
      // (?!\w) ensures we don't match "Type" in "TypeParam" or "T" in "T1"
      final pattern = RegExp(
        r'(?<=^|<|\(|\[|,\s*|\s)' + // After start or delimiter
            RegExp.escape(oldType) +
            r'(?![\w])' + // NOT followed by word character (letter, digit, underscore)
            r'(?=>|\)|\?|\]|,|\s|$)?', // Optionally followed by delimiter
      );

      result = result.replaceAll(pattern, newType);
    }

    return result;
  }

  static String getTypeParameter(List<MacroProperty> generics) {
    if (generics.isEmpty) return '';

    final s = StringBuffer('<');

    for (int i = 0; i < generics.length; i++) {
      final generic = generics[i];
      if (i > 0) {
        s.write(', ');
      }

      s.write(generic.name);
    }

    s.write('>');
    return s.toString();
  }

  static String getTypeParameterWithBound(List<MacroProperty> generics) {
    if (generics.isEmpty) return '';

    final s = StringBuffer('<');
    for (int i = 0; i < generics.length; i++) {
      final generic = generics[i];
      if (i > 0) {
        s.write(', ');
      }

      s.write(generic.name);
      if (generic.type.isNotEmpty) {
        s.write(' extends ${generic.type}');
      }
    }

    s.write('>');
    return s.toString();
  }

  static String getTypeParameterWithPrioritizedBound(List<MacroProperty> generics) {
    if (generics.isEmpty) return '';

    // Group by name, keeping the one with bound if duplicates exist
    final uniqueGenerics = <String, MacroProperty>{};

    for (final currGeneric in generics) {
      final existing = uniqueGenerics[currGeneric.name];
      if (existing == null) {
        uniqueGenerics[currGeneric.name] = currGeneric;
      } else if (existing.constantValue == null && currGeneric.constantValue != null) {
        // Replace unbounded with bounded version
        uniqueGenerics[currGeneric.name] = currGeneric;
      }
      // If existing has bound, keep it (don't replace)
    }

    final s = StringBuffer('<');
    for (final (i, generic) in uniqueGenerics.values.indexed) {
      if (i > 0) {
        s.write(', ');
      }

      s.write(generic.name);
      if (generic.type.isNotEmpty) {
        s.write(' extends ${generic.type}');
      }
    }

    s.write('>');
    return s.toString();
  }

  /// The name of the property or parameter.
  final String name;

  /// The import prefix used for this type (empty string if none).
  final String importPrefix;

  /// The dart type as a string (e.g., `String`, `List<int>`).
  final String type;

  /// Category of the type (e.g., class, enum, function, primitive).
  final TypeInfo typeInfo;

  /// Class declaration details when [typeInfo] is a class or enum type.
  final MacroClassDeclaration? classInfo;

  /// Type arguments for generic types (e.g., `T` in `List<T>`).
  final List<MacroProperty>? typeArguments;

  /// Function signature details when [typeInfo] is a function type.
  final MacroMethod? functionTypeInfo;

  /// The actual type information for the type assigned to [Type]
  ///
  /// The [typeInfo] will be [TypeInfo.type], and the referenced value is the actual type.
  ///
  /// For example, if you have a property like the one below and assign UserProfile to it:
  /// ```dart
  ///  final Type DataType
  /// ```
  ///
  final MacroProperty? typeRefType;

  /// Additional metadata annotations applied to this property.
  final Map<String, MacroProperty>? extraMetadata;

  /// Modifiers applied to this property (e.g., final, late, nullable).
  final MacroModifier modifier;

  /// Macro keys associated with this property.
  final List<MacroKey>? keys;

  /// Field initializer information for constructor parameters.
  ///
  /// Used when a constructor parameter initializes a different field name.
  /// For example, when a constructor has parameter `x` but initializes a private field `_x`.
  /// Contains the target field name, any constant value assigned, and the Dart code
  /// representation of the initializer expression if present.
  final MacroProperty? fieldInitializer;

  /// The constant value if this property is a compile-time constant.
  final Object? constantValue;

  /// Modifiers specific to the constant value (e.g., static const).
  final MacroModifier? constantModifier;

  /// Whether the constant value requires conversion to Dart literal syntax.
  final bool? requireConversionToLiteral;

  MacroProperty copyWith({
    String? name,
    String? type,
    MacroClassDeclaration? classInfo,
    Object? constantValue,
    MacroModifier? constantModifier,
    bool? requireConversionToLiteral,
  }) {
    return MacroProperty(
      name: name ?? this.name,
      importPrefix: classInfo != null && importPrefix.isEmpty ? classInfo.importPrefix : importPrefix,
      type: type ?? this.type,
      typeInfo: typeInfo,
      modifier: modifier,
      typeArguments: typeArguments,
      functionTypeInfo: functionTypeInfo,
      classInfo: classInfo ?? this.classInfo,
      typeRefType: typeRefType,
      keys: keys,
      fieldInitializer: fieldInitializer,
      constantValue: constantValue ?? this.constantValue,
      constantModifier: constantModifier ?? this.constantModifier,
      requireConversionToLiteral: requireConversionToLiteral ?? this.requireConversionToLiteral,
      extraMetadata: extraMetadata,
    );
  }

  /// Update class type parameter
  ///
  /// this is only update name and type without deep update
  MacroProperty updateClassTypeParameter(Map<String, String> replacements) {
    return copyWith(
      name: replaceTypeParameter(name, replacements),
      type: replaceTypeParameter(type, replacements),
    );
  }

  /// Converts the constant value to Dart literal syntax if needed, or returns it directly if it's a string.
  ///
  /// Returns the Dart code representation when [requireConversionToLiteral] is true,
  /// returns the value directly if it's already a string, or null otherwise.
  String? get constantValueToDartLiteralIfNeeded {
    if (requireConversionToLiteral == true) {
      return jsonLiteralAsDart(constantValue);
    } else if (constantValue case String v) {
      return v;
    }
    return null;
  }

  /// Return true if declaration is nullable
  bool get isNullable => modifier.isNullable || type.endsWith('?');

  /// Returns true if the declaration is static (based on either the modifier or constant modifier)
  bool get isStatic => modifier.isStatic || constantModifier?.isStatic == true;

  /// Returns true if the declaration is factory (based on either the modifier or constant modifier)
  bool get isFactory => modifier.isFactory || constantModifier?.isFactory == true;

  Map<String, Object?>? _cacheKeysByKeyName;

  /// Checks if this property is a `Map<String, dynamic>` type.
  bool get isMapStringDynamicType {
    if (typeInfo != TypeInfo.map) return false;
    if (typeArguments?.firstOrNull?.typeInfo != TypeInfo.string) return false;
    if (typeArguments?.elementAtOrNull(1)?.typeInfo != TypeInfo.dynamic) {
      return false;
    }
    return true;
  }

  /// Finds the first key with [keyName], converts it using [convertFn], and caches the result.
  ///
  /// Returns the cached value if available, or null if the key doesn't exist.
  /// Set [disableCache] to true to bypass caching.
  T cacheFirstKeyInto<T>({
    required String keyName,
    required T Function(MacroKey key) convertFn,
    required T defaultValue,
    bool disableCache = false,
  }) {
    var key = disableCache ? null : _cacheKeysByKeyName?[keyName];
    if (key is T) return key;

    if (key == Null) return defaultValue;

    final macroKey = keys?.firstWhereOrNull((e) => e.name == keyName);
    if (macroKey == null) {
      if (!disableCache) {
        _cacheKeysByKeyName ??= {};
        _cacheKeysByKeyName![keyName] = Null;
      }
      return defaultValue;
    }

    final res = convertFn(macroKey);
    if (!disableCache) {
      _cacheKeysByKeyName ??= {};
      _cacheKeysByKeyName![keyName] = res;
    }
    return res;
  }

  /// Converts the key at the specified [index] using [convertFn].
  ///
  /// Returns null if no key exists at the given index.
  T? keyOfTo<T>(T Function(MacroKey key) convertFn, {required int index}) {
    final key = keys?.elementAtOrNull(index);
    if (key == null) return null;

    return convertFn(key);
  }

  /// Returns a nullable version of this property.
  ///
  /// If already nullable, returns this instance unchanged.
  /// Otherwise, creates a new instance with nullable type and modifier.
  MacroProperty toNullability({bool intoNullable = true}) {
    if (intoNullable == isNullable) {
      return this;
    }

    final newType = switch ((intoNullable, type.endsWith('?'))) {
      (true, false) => '$type?',
      (false, true) => type.substring(0, type.length - 1),
      _ => type,
    };

    return MacroProperty(
      name: name,
      importPrefix: importPrefix,
      type: newType,
      typeInfo: typeInfo,
      modifier: MacroModifier({...modifier})..setIsNullable(intoNullable),
      typeArguments: typeArguments,
      functionTypeInfo: functionTypeInfo,
      classInfo: classInfo,
      typeRefType: typeRefType,
      keys: keys,
      fieldInitializer: fieldInitializer,
      constantValue: constantValue,
      constantModifier: constantModifier,
      requireConversionToLiteral: requireConversionToLiteral,
      extraMetadata: extraMetadata,
    );
  }

  /// Returns the constant value as a bool, or null if not a bool.
  bool? asBoolConstantValue() {
    if (constantValue case bool v) return v;
    return null;
  }

  /// Returns the constant value as a String, or null if not a String.
  String? asStringConstantValue() {
    if (constantValue case String v) return v;
    return null;
  }

  /// Returns the constant value as an int, or null if not an int.
  int? asIntConstantValue() {
    if (constantValue case int v) return v;
    return null;
  }

  /// Returns the constant value as a double, or null if not a double.
  double? asDoubleConstantValue() {
    if (constantValue case double v) return v;
    return null;
  }

  /// Returns the constant value as a num, or null if not a num.
  num? asNumConstantValue() {
    if (constantValue case num v) return v;
    return null;
  }

  /// Returns the constant value as a MacroProperty representing a Dart Type from an annotation.
  MacroProperty? asTypeValue() {
    if (typeInfo == TypeInfo.type && typeRefType != null) return typeRefType!;
    if (constantValue case MacroProperty v) return v; // todo: remove it
    return null;
  }

  /// Generates the full Dart type string with proper import prefix.
  ///
  /// The [dartCorePrefix] is prepended to dart:core types when no import prefix exists.
  /// Handles generic types, collections, and function types appropriately.
  String getDartType(String dartCorePrefix) {
    switch (typeInfo) {
      case TypeInfo.int:
      case TypeInfo.double:
      case TypeInfo.num:
      case TypeInfo.string:
      case TypeInfo.boolean:
      case TypeInfo.datetime:
      case TypeInfo.duration:
      case TypeInfo.bigInt:
      case TypeInfo.uri:
      case TypeInfo.symbol:
      case TypeInfo.nullType:
      case TypeInfo.dynamic:
      case TypeInfo.voidType:
      case TypeInfo.type:
        return importPrefix.isNotEmpty ? '$importPrefix$type' : '$dartCorePrefix$type';
      case TypeInfo.object:
        if (type == 'Enum') {
          return importPrefix.isNotEmpty ? '$importPrefix$type' : '$dartCorePrefix$type';
        }

        return '$importPrefix$type';
      case TypeInfo.clazz:
      case TypeInfo.clazzAugmentation:
      case TypeInfo.extension:
      case TypeInfo.extensionType:
      case TypeInfo.record:
        return '$importPrefix$type';
      case TypeInfo.enumData:
        if (type == 'Enum') {
          return importPrefix.isNotEmpty ? '$importPrefix$type' : '$dartCorePrefix$type';
        }
        return '$importPrefix$type';
      case TypeInfo.iterable:
      case TypeInfo.list:
      case TypeInfo.set:
      case TypeInfo.future:
      case TypeInfo.stream:
        final elemType = typeArguments?.firstOrNull;
        final String elemTypeStr;
        if (elemType != null) {
          elemTypeStr = elemType.getDartType(dartCorePrefix);
        } else {
          elemTypeStr = '${dartCorePrefix}dynamic';
        }

        final classType = switch (typeInfo) {
          TypeInfo.iterable => 'Iterable',
          TypeInfo.set => 'Set',
          TypeInfo.future => 'Future',
          TypeInfo.stream => 'Stream',
          _ => 'List',
        };

        final nullable = isNullable ? '?' : '';
        return importPrefix.isNotEmpty
            ? '$importPrefix$classType<$elemTypeStr>$nullable'
            : '$dartCorePrefix$classType<$elemTypeStr>$nullable';
      case TypeInfo.map:
        final elemType = typeArguments?.firstOrNull;
        final String elemTypeStr;
        if (elemType != null) {
          elemTypeStr = elemType.getDartType(dartCorePrefix);
        } else {
          elemTypeStr = '${dartCorePrefix}dynamic';
        }

        final elemValType = typeArguments?.elementAtOrNull(1);
        final String elemValTypeStr;
        if (elemValType != null) {
          elemValTypeStr = elemValType.getDartType(dartCorePrefix);
        } else {
          elemValTypeStr = '${dartCorePrefix}dynamic';
        }

        const classType = 'Map';
        final nullable = isNullable ? '?' : '';
        return importPrefix.isNotEmpty
            ? '$importPrefix$classType<$elemTypeStr, $elemValTypeStr>$nullable'
            : '$dartCorePrefix$classType<$elemTypeStr, $elemValTypeStr>$nullable';
      case TypeInfo.function:
        // returning prefix import with Function like $c.Function(param..)
        // will fails to compile when used in function argument
        final fnInfo = functionTypeInfo;
        if (fnInfo == null) {
          // try to get from constant
          final fnRef = asStringConstantValue() ?? '';
          return importPrefix.isNotEmpty ? '$importPrefix$fnRef' : fnRef;
        }

        return '${fnInfo.getFunctionType(dartCorePrefix)}${isNullable ? '?' : ''}';
      case TypeInfo.generic:
        // TODO: ensure just returning directly is correct
        return type;
    }
  }

  /// Return the name of function with proper import
  String getFunctionCallName() {
    if (asStringConstantValue() case final fnNameRef?) {
      return '$importPrefix$fnNameRef';
    }
    return '$importPrefix$name';
  }

  MacroProperty? getTopFieldInitializer() {
    if (fieldInitializer == null) return null;

    MacroProperty? currentInitializer = fieldInitializer;
    while (true) {
      if (currentInitializer?.fieldInitializer case final v?) {
        currentInitializer = v;
        continue;
      }

      return currentInitializer;
    }
  }

  Map<String, dynamic> toJson() {
    final (typeId, constantValueEncoded) = encodeConstantPropertyType(typeInfo, constantValue);

    return {
      if (name.isNotEmpty) 'n': name,
      if (importPrefix.isNotEmpty) 'ip': importPrefix,
      if (type.isNotEmpty) 't': type,
      'ti': typeInfo.id,
      if (typeArguments?.isNotEmpty == true) 'ta': typeArguments!.map((e) => e.toJson()).toList(),
      if (classInfo != null) 'ci': classInfo!.toJson(),
      if (functionTypeInfo != null) 'fti': functionTypeInfo!.toJson(),
      if (typeRefType != null) 'trt': typeRefType!.toJson(),
      if (extraMetadata?.isNotEmpty == true) 'em': extraMetadata!.map((k, v) => MapEntry(k, v.toJson())),
      if (modifier.isNotEmpty) 'm': modifier,
      if (keys?.isNotEmpty == true) 'k': keys!.map((e) => e.toJson()).toList(),
      if (fieldInitializer != null) 'fi': fieldInitializer!.toJson(),
      if (typeId != '') 'cvType': typeId,
      if (constantValueEncoded != null) 'cv': constantValueEncoded,
      if (constantModifier?.isNotEmpty == true) 'cm': constantModifier!,
      if (requireConversionToLiteral == true) 'rcl': true,
    };
  }

  @override
  String toString() {
    return 'MacroProperty{name: $name, importPrefix: $importPrefix, type: $type, typeInfo: $typeInfo, classInfo: $classInfo, typeArguments: $typeArguments, functionTypeInfo: $functionTypeInfo, typeRefType: $typeRefType, extraMetadata: $extraMetadata, modifier: $modifier, keys: $keys, fieldInitializer: $fieldInitializer, constantValue: $constantValue, constantModifier: $constantModifier, requireConversionToLiteral: $requireConversionToLiteral}';
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
      clazz || clazzAugmentation || extension || extensionType => true,
      _ => false,
    };
  }
}

/// Represents a method declaration
///
/// This class contains information about a method including its name, type parameters,
/// parameters, return types, and any applied modifiers or macro keys.
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
      typeParams:
          (json['tp'] as List?)?.map((e) => MacroProperty.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      params: MacroProperty._decodeUpdatableList(json['p'] as List? ?? const []),
      returns: MacroProperty._decodeUpdatableList(json['r'] as List? ?? const []),
      modifier: json['m'] == null
          ? const MacroModifier({})
          : MacroModifier((json['m'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool))),
      keys: (json['k'] as List?)?.map((e) => MacroKey.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// The name of the method.
  final String name;

  /// Type parameters (generics) of the method, if any.
  final List<MacroProperty> typeParams;

  /// The parameters accepted by this method.
  final List<MacroProperty> params;

  /// The return types of this method
  final List<MacroProperty> returns;

  /// Modifiers applied to this method (e.g., static, async, abstract).
  final MacroModifier modifier;

  /// Optional macro keys associated with this method.
  final List<MacroKey>? keys;

  String getFunctionType(String dartCorePrefix) {
    final str = StringBuffer();
    if (returns.firstOrNull case final v?) {
      str.write(v.getDartType(dartCorePrefix));
      str.write(' ');
    }

    str.write('Function${MacroProperty.getTypeParameterWithBound(typeParams)}(');

    final posParams = <MacroProperty>[];
    final namedParams = <MacroProperty>[];
    for (final param in params) {
      (param.modifier.isNamed ? namedParams : posParams).add(param);
    }

    // Positional parameters
    for (int i = 0; i < posParams.length; i++) {
      if (i > 0) str.write(', ');
      final p = posParams[i];
      str.write('${p.getDartType(dartCorePrefix)} ${p.name}');
    }

    // Named parameters
    if (namedParams.isNotEmpty) {
      if (posParams.isNotEmpty) str.write(', ');
      str.write('{');
      for (int i = 0; i < namedParams.length; i++) {
        if (i > 0) str.write(', ');
        final p = namedParams[i];
        if (p.modifier.isRequiredNamed) str.write('required ');
        str.write('${p.getDartType(dartCorePrefix)} ${p.name}');
      }
      str.write('}');
    }

    str.write(')');
    return str.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      if (name.isNotEmpty) 'n': name,
      if (typeParams.isNotEmpty) 'tp': typeParams.map((e) => e.toJson()).toList(),
      if (params.isNotEmpty) 'p': params.map((e) => e.toJson()).toList(),
      'r': returns.map((e) => e.toJson()).toList(),
      if (modifier.value.isNotEmpty) 'm': modifier,
      if (keys?.isNotEmpty == true) 'k': keys!.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'MacroMethod{name: $name, typeParams: $typeParams, params: $params, returns: $returns, modifier: $modifier, keys: $keys}';
  }
}

/// Represents a class declaration with its metadata, members, and macro configurations.
///
/// This class contains comprehensive information about a Dart class including its
/// modifiers, fields, constructors, methods, and any applied macro configurations.
class MacroClassDeclaration {
  const MacroClassDeclaration({
    required this.libraryId,
    required this.classId,
    required this.configs,
    required this.importPrefix,
    required this.className,
    required this.modifier,
    required this.classTypeParameters,
    required this.classFields,
    required this.constructors,
    required this.methods,
    required this.subTypes,
    this.ready = true,
  });

  /// Creates a pending declaration with unresolved members.
  ///
  /// Used during the initial analysis phase when the full class structure
  /// is not yet available or being resolved.
  factory MacroClassDeclaration.pendingDeclaration({
    required int libraryId,
    required String classId,
    required String importPrefix,
    required String className,
    required List<MacroConfig> configs,
    required MacroModifier modifier,
    required List<MacroProperty>? classTypeParameters,
    required List<MacroClassDeclaration>? subTypes,
  }) {
    return MacroClassDeclaration(
      libraryId: libraryId,
      classId: classId,
      importPrefix: importPrefix,
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
    final libraryId = (json['lid'] as num).toInt();
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
      libraryId: libraryId,
      classId: classId,
      configs: configs,
      importPrefix: (json['ip'] as String?) ?? '',
      className: json['cn'] as String,
      modifier: json['cm'] == null
          ? const MacroModifier({})
          : MacroModifier((json['cm'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool))),
      classTypeParameters: (json['tp'] as List?)
          ?.map((e) => MacroProperty.fromJson(e as Map<String, dynamic>))
          .toList(),
      classFields: classFields,
      constructors: (json['c'] as List?)
          ?.map((e) => MacroClassConstructor.fromJson(e as Map<String, dynamic>))
          .toList(),
      methods: (json['m'] as List?)?.map((e) => MacroMethod.fromJson(e as Map<String, dynamic>)).toList(),
      subTypes: (json['st'] as List?)?.map((e) => MacroClassDeclaration.fromJson(e as Map<String, dynamic>)).toList(),
      ready: ready,
    );
  }

  /// The ID of the library where this class is declared.
  ///
  /// Use this ID to retrieve the full path of the declaration's source file.
  final int libraryId;

  /// Unique identifier for this class declaration.
  final String classId;

  /// List of macro configurations applied to this class.
  final List<MacroConfig> configs;

  /// The import prefix used when importing this class (empty string if none).
  final String importPrefix;

  /// The name of the class.
  final String className;

  /// Modifiers applied to this class (e.g., abstract, sealed, static).
  final MacroModifier modifier;

  /// Type parameters (generics) of the class, if any.
  final List<MacroProperty>? classTypeParameters;

  /// Fields declared in this class.
  final List<MacroProperty>? classFields;

  /// Constructors defined in this class.
  final List<MacroClassConstructor>? constructors;

  /// Methods defined in this class.
  final List<MacroMethod>? methods;

  /// Subtypes that extend or implement this class (for sealed classes).
  final List<MacroClassDeclaration>? subTypes;

  /// Indicates whether all types referenced by this class have been resolved.
  ///
  /// When `false`, the class has unresolved type references that are still being processed.
  final bool ready;

  MacroClassDeclaration copyWith({int? libraryId, String? classId, List<MacroConfig>? configs, bool? ready}) {
    return MacroClassDeclaration(
      libraryId: libraryId ?? this.libraryId,
      classId: classId ?? this.classId,
      configs: configs ?? this.configs,
      importPrefix: importPrefix,
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
      'lid': libraryId,
      'cid': classId,
      'cf': configs.map((e) => e.toJson()).toList(),
      if (importPrefix.isNotEmpty) 'ip': importPrefix,
      'cn': className,
      if (ready == false) 'rs': false,
      if (ready) ...{
        if (modifier.value.isNotEmpty) 'cm': modifier.value,
        if (classTypeParameters?.isNotEmpty == true) 'tp': classTypeParameters!.map((e) => e.toJson()).toList(),
        if (classFields?.isNotEmpty == true) 'f': classFields!.map((e) => e.toJson()).toList(),
        if (constructors?.isNotEmpty == true) 'c': constructors!.map((e) => e.toJson()).toList(),
        if (methods?.isNotEmpty == true) 'm': methods!.map((e) => e.toJson()).toList(),
        if (subTypes?.isNotEmpty == true) 'st': subTypes!.map((e) => e.toJson()).toList(),
      },
    };
  }

  @override
  String toString() {
    return 'MacroClassDeclaration{libraryId: $libraryId, classId: $classId, configs: $configs, importPrefix: $importPrefix, className: $className, modifier: $modifier, classTypeParameters: $classTypeParameters, classFields: $classFields, constructors: $constructors, methods: $methods, subTypes: $subTypes, ready: $ready}';
  }
}

/// Represents a top level function declaration with its metadata, and macro configurations.
class MacroFunctionDeclaration {
  const MacroFunctionDeclaration({
    required this.libraryId,
    required this.functionId,
    required this.configs,
    required this.importPrefix,
    required this.info,
    required this.typeParameters,
  });

  static MacroFunctionDeclaration fromJson(Map<String, dynamic> json) {
    final libraryId = (json['lid'] as num).toInt();
    final functionId = json['fid'] as String;
    final configs = (json['cf'] as List).map((e) => MacroConfig.fromJson(e as Map<String, dynamic>)).toList();

    return MacroFunctionDeclaration(
      libraryId: libraryId,
      functionId: functionId,
      configs: configs,
      importPrefix: (json['ip'] as String?) ?? '',
      info: MacroMethod.fromJson(json['fi'] as Map<String, dynamic>),
      typeParameters: (json['tp'] as List?)?.map((e) => MacroProperty.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// The ID of the library where this function is declared.
  ///
  /// Use this ID to retrieve the full path of the declaration's source file.
  final int libraryId;

  /// Unique identifier for this function declaration.
  final String functionId;

  /// List of macro configurations applied to this function.
  final List<MacroConfig> configs;

  /// The import prefix used when importing this class (empty string if none).
  final String importPrefix;

  /// Type parameters (generics) of the function, if any.
  final List<MacroProperty>? typeParameters;

  /// The top level Function information
  final MacroMethod info;

  MacroFunctionDeclaration copyWith({int? libraryId, String? functionId, List<MacroConfig>? configs}) {
    return MacroFunctionDeclaration(
      libraryId: libraryId ?? this.libraryId,
      functionId: functionId ?? this.functionId,
      configs: configs ?? this.configs,
      importPrefix: importPrefix,
      info: info,
      typeParameters: typeParameters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lid': libraryId,
      'fid': functionId,
      'cf': configs.map((e) => e.toJson()).toList(),
      if (importPrefix.isNotEmpty) 'ip': importPrefix,
      'fi': info.toJson(),
      if (typeParameters?.isNotEmpty == true) 'tp': typeParameters!.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'MacroFunctionDeclaration{libraryId: $libraryId, functionId: $functionId, configs: $configs, importPrefix: $importPrefix, typeParameters: $typeParameters, info: $info}';
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

/// Defines naming conventions for transforming field names.
///
/// Used to specify how field names should be transformed when generating
/// code, particularly useful for converting between different naming conventions
/// like snake_case, camelCase, PascalCase, etc.
enum FieldRename {
  /// Use the field name without changes.
  ///
  /// Example: `myFieldName` → `myFieldName`
  none,

  /// Converts a field name to camelCase.
  ///
  /// The first letter is lowercase, and subsequent words start with uppercase.
  /// Example: `my_field_name` → `myFieldName`
  camelCase,

  /// Converts a field name to kebab-case.
  ///
  /// Words are separated by hyphens and all letters are lowercase.
  /// Example: `myFieldName` → `my-field-name`
  kebab,

  /// Converts a field name to snake_case.
  ///
  /// Words are separated by underscores and all letters are lowercase.
  /// Example: `myFieldName` → `my_field_name`
  snake,

  /// Converts a field name to PascalCase.
  ///
  /// The first letter and the first letter of each subsequent word are uppercase.
  /// Example: `my_field_name` → `MyFieldName`
  pascal,

  /// Converts a field name to SCREAMING_SNAKE_CASE.
  ///
  /// Words are separated by underscores and all letters are uppercase.
  /// Example: `myFieldName` → `MY_FIELD_NAME`
  screamingSnake;

  /// Transforms the given [name] according to this naming convention.
  ///
  /// Returns a new string with the [name] transformed based on the selected
  /// [FieldRename] option.
  ///
  /// Example:
  /// ```dart
  /// FieldRename.snake.renameOf('myFieldName'); // Returns 'my_field_name'
  /// FieldRename.pascal.renameOf('my_field_name'); // Returns 'MyFieldName'
  /// ```
  String renameOf(String name) {
    return switch (this) {
      FieldRename.none => name,
      FieldRename.camelCase => name.toCamelCase(),
      FieldRename.kebab => name.toKebabCase(),
      FieldRename.snake => name.toSnakeCase(),
      FieldRename.pascal => name.toPascalCase(),
      FieldRename.screamingSnake => name.toSnakeCase().toUpperCase(),
    };
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
    this.config,
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
  /// If generated files were written back to same asset directories, they would trigger
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

/// The target type that the macro has been applied to
enum TargetType { clazz, function, enumType, asset }

/// State information about the asset directory when processing asset-related macros.
///
/// This class contains path information about the asset directory being processed,
/// including both relative and absolute paths for input assets and output generation.
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

/// Provides contextual information and utilities for macro code generation.
///
/// [MacroState] is passed to all macro lifecycle methods, providing access to the
/// annotated class's structure, metadata, imports, and code generation utilities.
/// Use it to inspect the target declaration, share data between lifecycle methods,
/// and report generated code back to the build system.
///
/// ## Target Information
///
/// Access information about the annotated declaration:
/// - [targetName] - Name of the annotated element (class name, variable name, etc.)
/// - [targetType] - Type of target ([TargetType.clazz], [TargetType.asset], etc.)
/// - [modifier] - Declaration modifiers (abstract, sealed, final, const, etc.)
/// - [importPrefix] - Import prefix for the target (e.g., `'my_lib.'`)
/// - [macro] - The macro annotation configuration as [MacroKey]
/// - [remainingMacro] - Other macros that will execute after the current one
///
/// ## Import Management
///
/// The [imports] map contains all imports from the analyzed file, mapping import
/// paths to their prefixes. Use this to generate properly prefixed type references:
///
/// ```dart
/// final dartCorePrefix = state.imports["import dart:core"] ?? '';
/// buff.write('${dartCorePrefix}List<${dartCorePrefix}String>');
/// ```
///
/// The [libraryPaths] map provides file paths for library IDs, useful for resolving
/// declaration locations.
///
/// ## State Storage
///
/// Share data between lifecycle methods using the internal storage:
///
/// - [set] - Store any value by string key
/// - [get] - Retrieve required value (asserts type, fails if missing)
/// - [getOrNull] - Retrieve optional value (returns null if missing)
/// - [getBool] - Retrieve boolean with default fallback
/// - [getBoolOrNull] - Retrieve nullable boolean with default fallback
///
/// Example:
/// ```dart
/// // In onClassFields
/// state.set('fields', fields);
///
/// // In onGenerate
/// final fields = state.get<List<MacroProperty>>('fields');
/// ```
///
/// ## Class Declaration Lookup
///
/// Use [getClassById] to retrieve class declarations by their unique ID. This is
/// useful for resolving type information and analyzing related classes.
///
/// ## Code Generation and Reporting
///
/// ### Generated Code
///
/// Report generated code using [reportGenerated]:
/// ```dart
/// state.reportGenerated(
///   generatedCode,
///   canBeCombined: true, // Default: allow combining with other macros
/// );
/// ```
///
/// **Combinable Code** (`canBeCombined: true`): Multiple macros can merge their
/// output into a single mixin/class. Access via [generated].
///
/// **Non-Combinable Code** (`canBeCombined: false`): Code that must be written
/// separately (e.g., multiple class declarations, conflicting implementations).
/// Access via [generatedNonCombinable].
///
/// Check [isCombingGenerator] before generating class/mixin wrappers. When `true`,
/// only output method bodies without class/mixin declarations.
///
/// ### Generated Files
///
/// For asset macros that produce separate files, use [reportGeneratedFile] to
/// register output file paths. Access via [generatedFilePaths].
///
/// ### Code Formatting
///
/// For asset macros, use [formatCode] to format generated Dart code:
/// ```dart
/// final formatted = MacroState.formatCode(generatedCode);
/// ```
///
/// Note: Regular macros have automatic formatting applied by the Dart macro system.
/// Only use [dartFormatter] for asset macro if you generate dart code.
///
/// ## Asset Macro Support
///
/// ## Error Handling
///
/// Throw [MacroException] with descriptive messages for invalid configurations:
/// ```dart
/// if (state.targetType != TargetType.clazz) {
///   throw MacroException('This macro can only be applied to classes');
/// }
/// ```
class MacroState {
  MacroState({
    required this.macro,
    required this.remainingMacro,
    required this.globalConfig,
    required this.contentPath,
    required this.remapGeneratedFileTo,
    required this.targetPath,
    required this.targetType,
    required this.targetName,
    required this.importPrefix,
    required this.imports,
    required this.libraryPaths,
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

  /// The global configuration for this macro based on the file's context path.
  ///
  /// This config is determined by matching the file's path against configured
  /// context paths.
  ///
  /// Returns `null` unless [MacroGenerator.globalConfigParser] is configured
  /// to parse and return a global config.
  final MacroGlobalConfig? globalConfig;

  /// The root context of the target path.
  ///
  /// This value is expected to be non-empty, except when the client and server
  /// are not yet synchronized.
  final String? contentPath;

  /// The relative path to which the generated file will be rewritten.
  ///
  /// Defaults to an empty string.
  final String remapGeneratedFileTo;

  /// The absolute path of the file
  final String targetPath;

  /// The type of target this macro is applied to (class, asset, variable,...)
  final TargetType targetType;

  /// The name of the target element (class, asset or variable name,...)
  final String targetName;

  /// The prefixed import for specified target.
  ///
  /// for example it `my_lib.`
  final String importPrefix;

  /// Map of imports from the analyzed file, where the key is the import path
  /// and the value is the import prefix (if any)
  final Map<String, String> imports;

  /// Map of library IDs to their full file paths for target declarations
  final Map<int, String> libraryPaths;

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

/// The type of code this macro generates.
///
/// Used to determine compatibility when multiple macros are applied to the same class.
/// The macro system uses this information to ensure that generated code structures
/// can coexist without conflicts.
///
/// Choose the appropriate type based on your generated code structure:
/// - [mixin] - Generates `mixin ClassNameSuffixName`
/// - [clazz] - Generates `class ClassNameSuffixName`
/// - [abstractClass] - Generates `abstract class ClassNameSuffixName`
/// - [extendsClass] - Generates `class ClassNameSuffixName extends Base`
/// - [function] - Generates `function implementation`
enum GeneratedType {
  mixin,
  clazz,
  abstractClass,
  extendsClass,
  function,
}

/// Base class for implementing macro code generation.
///
/// A macro is a development-only code generator that analyzes annotated classes in real-time
/// and produces additional Dart code instantly. Macros run during development (with hot-reload
/// support) but are excluded from production builds.
///
/// ## How Macros Work
///
/// When a class is annotated with `@Macro(YourMacro())`, the build system:
/// 1. Instantiates your macro generator
/// 2. Invokes lifecycle methods with information about the annotated class
/// 3. Calls [onGenerate] to produce the final code
/// 4. Integrates generated code with the original class
///
/// ## Macro Types
///
/// **Regular Macros**: Analyze class structure (fields, methods, constructors) to
/// generate code. Used for serialization, equality, immutability patterns, and
/// other class-based code generation.
///
/// **Asset Macros**: Monitor file system paths and regenerate code when assets
/// change. Used for generating code from external resources like JSON schemas,
/// OpenAPI specs, or configuration files.
///
/// ## Capability Declaration
///
/// Declare required capabilities via the [capability] parameter. The macro receives
/// callbacks only for requested capabilities, optimizing performance by avoiding
/// unnecessary analysis:
///
/// - [MacroCapability.classFields] → [onClassFields] invoked with field declarations
/// - [MacroCapability.classConstructors] → [onClassConstructors] invoked with constructors
/// - [MacroCapability.classMethods] → [onClassMethods] invoked with methods
/// - [MacroCapability.topLevelFunctions] → [onTopLevelFunction] invoked with function
/// - [MacroCapability.collectClassSubTypes] → [onClassSubTypes] invoked with subtypes
///
/// Use capability filters (e.g., [MacroCapability.filterClassInstanceFields],
/// [MacroCapability.filterClassFieldMetadata]) to narrow the collected data to
/// only what your macro needs.
///
/// ## Metadata and Configuration
///
/// Macros read configuration from annotation classes applied to the target class
/// and its members. Define annotation classes with configuration properties, then
/// access them through [MacroProperty] instances in lifecycle callbacks. Use
/// [MacroProperty.cacheFirstKeyInto] to parse annotation data into typed
/// configuration objects.
///
/// Example: A field annotated with `@JsonKey(name: 'user_id')` provides metadata
/// that the macro can use to customize JSON serialization field names.
///
/// ## Code Combination
///
/// Multiple macros targeting the same class can combine their output into a single
/// generated file. When [MacroState.isCombingGenerator] is `true`, generate only
/// method bodies without class/mixin wrappers. If your macro cannot combine with
/// others, call [MacroState.reportGenerated] with `canBeCombined: false`.
///
/// When multiple macros are applied, their capabilities merge and each macro
/// receives only the data matching its declared capability.
///
/// ## Execution Lifecycle
///
/// Lifecycle methods execute in this order:
///
/// 1. [init] - Initialize macro state for the annotated class
/// 2. [onClassTypeParameter] - Process generic type parameters
/// 3. [onClassFields] - Process field declarations
/// 4. [onClassConstructors] - Process constructors
/// 5. [onClassMethods] - Process methods
/// 6. [onTopLevelFunctionTypeParameter] - Process top level function declarations type parameter
/// 7. [onTopLevelFunction] - Process top level function declarations
/// 8. [onClassSubTypes] - Process subtype declarations
/// 9. [onAsset] - Handle monitored asset changes (asset macros only)
/// 10.[onGenerate] - Generate final code output and report via [MacroState.reportGenerated]
///
///
/// ## Implementation Requirements
///
/// - Override [suffixName] with a unique suffix for generated class names
/// - Implement [onGenerate] to produce code output
/// - Override lifecycle methods corresponding to declared capabilities
/// - Use [MacroState] to access class information, manage imports, and report output
/// - Handle errors by throwing [MacroException] with descriptive messages
///
/// See [DataClassMacro] for a comprehensive implementation example demonstrating
/// serialization, equality, and polymorphic type handling.
abstract class MacroGenerator implements BaseMacroGenerator {
  const MacroGenerator({required this.capability});

  /// The capability describes which elements of a class (constructors,
  /// fields, methods, metadata, and subtypes) should be collected and made
  /// available to the macro during generation.
  ///
  /// see [MacroCapability] for more information.
  final MacroCapability capability;

  /// Suffix to be appended to generated class names (e.g., `User` → `User$suffixName`).
  ///
  /// Required when multiple macros generate code for the same class. Use a unique
  /// suffix to avoid conflicts. If combining with other macros isn't supported,
  /// call [MacroState.reportGenerated] with canBeCombined as false.
  @override
  String get suffixName;

  /// The type of code this macro generates.
  ///
  /// Used to determine compatibility when multiple macros are applied to the same class.
  ///
  /// Choose based on your generated code structure:
  /// - [GeneratedType.mixin] if generating `mixin ClassNameSuffixName`
  /// - [GeneratedType.clazz] if generating `class ClassNameSuffixName`
  /// - [GeneratedType.abstractClass] if generating `abstract class ClassNameSuffixName`
  /// - [GeneratedType.extendsClass] if generating `class ClassNameSuffixName extends Base`
  @override
  GeneratedType get generatedType;

  /// A function type for parsing global macro configuration from JSON.
  @override
  MacroGlobalConfigParser? get globalConfigParser => null;

  /// Called once per annotated class to initialize the macro state.
  @override
  Future<void> init(MacroState state) async {}

  /// Called when the target class has type parameters.
  @override
  Future<void> onClassTypeParameter(MacroState state, List<MacroProperty> typeParameters) async {}

  /// Called with all fields of the target class.
  ///
  /// Use to generate constructors or analyze field metadata. See [onClassConstructors]
  /// to determine whether fields are positional or named parameters.
  @override
  Future<void> onClassFields(MacroState state, List<MacroProperty> fields) async {}

  /// Called with all constructors of the target class.
  @override
  Future<void> onClassConstructors(MacroState state, List<MacroClassConstructor> constructors) async {}

  /// Called with all methods of the target class.
  @override
  Future<void> onClassMethods(MacroState state, List<MacroMethod> methods) async {}

  /// Called when the target function has type parameters.
  @override
  Future<void> onTopLevelFunctionTypeParameter(MacroState state, List<MacroProperty> typeParameters) async {}

  /// Called when the target function is a top level function.
  @override
  Future<void> onTopLevelFunction(MacroState state, MacroMethod function) async {}

  /// Called with all subtypes of the target class in the library
  @override
  Future<void> onClassSubTypes(MacroState state, List<MacroClassDeclaration> subTypes) async {}

  /// Called when a monitored asset file changes in configured directories.
  ///
  /// Triggers on create, modify, or delete events.
  @override
  Future<void> onAsset(MacroState state, MacroAssetDeclaration asset) async {}

  /// Called last to generate the final code output.
  @override
  Future<void> onGenerate(MacroState state);

  /// Return whether a class have a method with specified [methodName] or in metadata support
  /// generating this capability to the class.
  ///
  /// the configuration for that feature must be boolean value and it consider
  /// to return true when the configuration value is not explicitly set false value
  (bool, MacroMethod?) hasMethodOf({
    required MacroClassDeclaration? declaration,
    required String macroName,
    required String methodName,
    required String configName,
    bool? staticFunction,
  }) {
    if (declaration == null) return (false, null);

    // fast path: check toJson method
    final method = declaration.methods?.firstWhereOrNull(
      (e) => e.name == methodName && (staticFunction == null || staticFunction == e.modifier.isStatic),
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
}

/// Provides package identification for connecting macros to the Macro server.
///
/// This class specifies which package(s) the macro should analyze, enabling
/// the macro to establish a connection with the server and access
/// the analysis context.
///
/// ## Development vs CI/CD Environments
///
/// **In Development (IDE/Editor):**
/// The analyzer plugin automatically provides package information to the macro
/// server, so you typically only need to specify the package name:
/// ```dart
/// final packageInfo = PackageInfo('my_app');
/// ```
///
/// **In CI/CD or Without Plugin:**
/// When the analyzer plugin isn't running (e.g., in CI pipelines, automated tests,
/// or standalone builds), you must provide the absolute path to the package root
/// so the macro server can initialize its analysis context:
/// ```dart
/// final packageInfo = PackageInfo.path('/workspace/my_app');
/// ```
///
/// ## Package Identification Methods
///
/// You can identify packages in two ways:
/// 1. **By name** - Works when the analyzer plugin is active (development)
/// 2. **By path** - Required when the plugin isn't available (CI/CD, standalone)
///
/// ## Usage Examples
///
/// **Single Package:**
/// ```dart
/// // Development: by package name (plugin provides context)
/// final packageInfo = PackageInfo('my_app');
///
/// // CI/CD: by absolute path (no plugin available)
/// final packageInfo = PackageInfo.path('/workspace/my_app');
///
/// // For test directory specifically
/// final packageInfo = PackageInfo.path('/workspace/my_app/test');
/// ```
///
/// **Multiple Packages (Mono-repos):**
/// ```dart
/// final packageInfo = PackageInfo.mixed([
///   'my_app',                           // By name (dev)
///   '/workspace/shared_models',         // By path (CI)
///   '/workspace/core_lib',              // By path (CI)
/// ]);
/// ```
///
/// ## Auto-Rebuild & Regeneration
///
/// Providing the correct package path is crucial for auto-rebuild functionality.
/// When enabled, the macro server monitors the specified package(s) and automatically
/// regenerates code based on your `macro.json` configuration.
///
/// **Auto-Rebuild Behavior:**
/// - When you call `runMacro()` in your `main.dart` and have `auto_rebuild_on_connect: true`
///   in `macro.json`, any macro within the specified package/directory will automatically
///   rebuild upon connection.
/// - If `always_rebuild_on_connect: true`, macros will rebuild on every client connection,
///   including when you restart your Flutter app multiple times.
///
/// **Example for CI with auto-rebuild:**
/// ```dart
/// final packageInfo = PackageInfo.path(
///   Platform.environment['CI_PROJECT_DIR'] ?? '/workspace/my_app'
/// );
/// ```
///
/// ## Important Notes
///
/// - Package names must **exactly match** the `name` in `pubspec.yaml`
/// - Paths must be **absolute** and point to a directory containing `pubspec.yaml`
///   (or a valid subdirectory like `test/`)
/// - In CI/CD environments, **always use absolute paths** since the plugin isn't available
/// - All specified packages must be valid and accessible for initialization to succeed
/// - If you need code regeneration in CI, ensure you run the macro server before executing your code or tests:
/// ```bash
/// dart pub global activate macro_kit
/// macro  # Start the server before runMacro()
/// ```
class PackageInfo {
  const PackageInfo._(this.values);

  /// Creates a [PackageInfo] for a single package by name.
  ///
  /// **Best for:** Development environments where the analyzer plugin is active.
  ///
  /// The [name] must exactly match the `name` field in the package's `pubspec.yaml`.
  /// The analyzer plugin will automatically provide the package path and context.
  ///
  /// **Example:**
  /// ```dart
  /// // For a pubspec.yaml with: name: my_app
  /// final info = PackageInfo('my_app');
  /// ```
  ///
  /// **Note:** This won't work in CI/CD environments without the analyzer plugin.
  /// Use [PackageInfo.path] instead for those scenarios.
  ///
  /// **Parameters:**
  /// - [name]: The package name from `pubspec.yaml`
  factory PackageInfo(String name) {
    if (name.contains('/') || name.contains('\\')) {
      throw ArgumentError.value(
        name,
        'name',
        'Must be a package name, not a path. Use PackageInfo.path() for paths, '
            'e.g., PackageInfo.path("/workspace/my_app") for CI/CD environments.',
      );
    }
    return PackageInfo._([name]);
  }

  /// Creates a [PackageInfo] for a single package by absolute path.
  ///
  /// **Best for:** CI/CD pipelines, automated tests, or any environment where
  /// the analyzer plugin isn't running.
  ///
  /// The [absolutePath] must be the absolute path to:
  /// - The package root directory (containing `pubspec.yaml`), or
  /// - A valid subdirectory like `test/` for focused analysis
  ///
  /// This allows the macro server to initialize its analysis context without
  /// relying on the analyzer plugin, which is essential for auto-rebuild and
  /// code regeneration in automated environments.
  ///
  /// **Examples:**
  /// ```dart
  /// // Package root
  /// final info = PackageInfo.path('/workspace/my_app');
  ///
  /// // Test directory specifically
  /// final info = PackageInfo.path('/workspace/my_app/test');
  ///
  /// // Using environment variable (CI)
  /// final info = PackageInfo.path(Platform.environment['CI_PROJECT_DIR']!);
  /// ```
  ///
  /// **Parameters:**
  /// - [absolutePath]: Absolute path to the package root or subdirectory
  ///
  /// **Throws:**
  /// - [ArgumentError] if the path is not absolute (doesn't contain `/` or `\`)
  factory PackageInfo.path(String absolutePath) {
    if (!absolutePath.contains('/') && !absolutePath.contains('\\')) {
      throw ArgumentError.value(
        absolutePath,
        'absolutePath',
        'Must be an absolute path. Use PackageInfo(name) for package names, '
            'or provide a full path like "/workspace/my_app" for CI/CD environments.',
      );
    }
    return PackageInfo._([absolutePath]);
  }

  /// Creates a [PackageInfo] for multiple packages using names and/or paths.
  ///
  /// **Best for:** Mono-repo setups, multi-package projects, or mixed environments
  /// where some packages use the analyzer plugin and others need explicit paths.
  ///
  /// Each value in [nameOrAbsolutePath] can be either:
  /// - A package name (works with analyzer plugin in development)
  /// - An absolute path (works without plugin in CI/CD)
  ///
  /// This flexibility allows you to:
  /// - Use names for packages with active plugin support
  /// - Use paths for packages in CI/CD or for auto-rebuild
  /// - Mix both approaches as needed
  ///
  /// **Examples:**
  /// ```dart
  /// // Mixed: development packages by name, CI paths for auto-rebuild
  /// final info = PackageInfo.mixed([
  ///   'my_app',                          // Plugin provides context
  ///   '/workspace/shared_utils',         // Explicit path for CI
  ///   '/workspace/core/test',            // Test directory for focused analysis
  /// ]);
  ///
  /// // All paths for CI/CD environment
  /// final info = PackageInfo.mixed([
  ///   '/workspace/app',
  ///   '/workspace/shared',
  ///   '/workspace/core',
  /// ]);
  /// ```
  ///
  /// **Parameters:**
  /// - [nameOrAbsolutePath]: Collection of package names or absolute paths
  factory PackageInfo.mixed(Iterable<String> nameOrAbsolutePath) {
    return PackageInfo._(nameOrAbsolutePath.toList());
  }

  static PackageInfo fromJson(Map<String, dynamic> json) {
    return PackageInfo._(
      (json['values'] as List).map((e) => e as String).toList(),
    );
  }

  /// The list of package names that can connect to the MacroPlugin server.
  final List<String> values;

  /// Return a list of tuple for each package with extracted id
  List<({String name, String id})> parsedPackageWithId() {
    return values.map((p) {
      final index = p.indexOf('::');
      return index == -1 ? (name: p, id: '') : (name: p.substring(0, index), id: p.substring(index + 2));
    }).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'values': values,
    };
  }

  @override
  String toString() {
    return 'PackageInfo{values: $values}';
  }
}

@internal
extension MacroX on String {
  String get removedNullability {
    return replaceFirst('?', '');
  }
}
