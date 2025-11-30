import 'package:change_case/change_case.dart';
import 'package:macro_kit/macro.dart';
import 'package:macro_kit/src/analyzer/types_ext.dart';
import 'package:meta/meta.dart';

/// An annotation used to specify how a field is serialized.
class JsonKey {
  /// Creates a new [JsonKey] instance.
  ///
  /// Only required when the default behavior is not desired.
  const JsonKey({
    this.defaultValue,
    this.fromJson,
    this.includeFromJson,
    this.includeIfNull,
    this.includeToJson,
    this.name,
    this.readValue,
    this.toJson,
    this.unknownEnumValue,
    this.asRequired,
  });

  /// The value to use if the source JSON does not contain this key or if the
  /// value is `null`.
  ///
  /// Also supported: a top-level or static [Function] or a constructor with no
  /// required parameters and a return type compatible with the field being
  /// assigned.
  final Object? defaultValue;

  /// A [Function] to use when decoding the associated JSON value to the
  /// annotated field.
  ///
  /// Must be a top-level or static [Function] or a constructor that accepts one
  /// positional argument mapping a JSON literal to a value compatible with the
  /// type of the annotated field.
  ///
  /// When creating a class that supports both `toJson` and `fromJson`
  /// (the default), you should also set [toJson] if you set [fromJson].
  /// Values returned by [toJson] should "round-trip" through [fromJson].
  final Function? fromJson;

  /// Used to force a field to be included (or excluded) when decoding a object
  /// from JSON.
  ///
  /// `null` (the default) means the field will be handled with the default
  /// semantics that take into account if it's private or if it can be cleanly
  /// round-tripped to-from JSON.
  ///
  /// `true` means the field should always be decoded, even if it's private.
  ///
  /// `false` means the field should never be decoded.
  final bool? includeFromJson;

  /// Whether the generator should include fields with `null` values in the
  /// serialized output.
  ///
  /// If `true`, the generator should include the field in the serialized
  /// output, even if the value is `null`.
  ///
  /// The default value, `null`, indicates that the behavior should be
  /// acquired from the [DataClassMacroConfig.includeIfNull] annotation on the
  /// enclosing class.
  final bool? includeIfNull;

  /// Used to force a field to be included (or excluded) when encoding a object
  /// to JSON.
  ///
  /// `null` (the default) means the field will be handled with the default
  /// semantics that take into account if it's private or if it can be cleanly
  /// round-tripped to-from JSON.
  ///
  /// `true` means the field should always be encoded, even if it's private.
  ///
  /// `false` means the field should never be encoded.
  final bool? includeToJson;

  /// The key in a JSON map to use when reading and writing values corresponding
  /// to the annotated fields.
  ///
  /// If `null`, the field name is used.
  final String? name;

  /// Specialize how a value is read from the source JSON map.
  ///
  /// Typically, the value corresponding to a given key is read directly from
  /// the JSON map using `map[key]`. At times it's convenient to customize this
  /// behavior to support alternative names or to support logic that requires
  /// accessing multiple values at once.
  ///
  /// The provided, the [Function] must be a top-level or static within the
  /// using class.
  ///
  /// Note: using this feature does not change any of the subsequent decoding
  /// logic for the field. For instance, if the field is of type [DateTime] we
  /// expect the function provided here to return a [String].
  final Object? Function(Map, String)? readValue;

  /// A [Function] to use when encoding the annotated field to JSON.
  ///
  /// Must be a top-level or static [Function] or a constructor that accepts one
  /// positional argument compatible with the field being serialized that
  /// returns a JSON-compatible value.
  ///
  /// When creating a class that supports both `toJson` and `fromJson`
  /// (the default), you should also set [fromJson] if you set [toJson].
  /// Values returned by [toJson] should "round-trip" through [fromJson].
  final Function? toJson;

  /// The value to use for an enum field when the value provided is not in the
  /// source enum.
  ///
  /// Valid only on enum fields with a compatible enum value.
  final Enum? unknownEnumValue;

  /// Determine an nullable field must have a `required` keyword when generating a constructor
  /// note: this field is not been used until augment became stable
  final bool? asRequired;
}

@internal
class JsonKeyConfig {
  const JsonKeyConfig({
    this.defaultValue,
    this.fromJson,
    this.fromJsonArgType,
    this.fromJsonReturnType,
    this.includeFromJson,
    this.includeIfNull,
    this.includeToJson,
    this.name,
    this.readValue,
    this.toJson,
    this.toJsonArgType,
    this.toJsonReturnNullable,
    this.unknownEnumValue,
    this.asRequired,
  });

  static const defaultKey = JsonKeyConfig();

  static String toLiteralValue(Object? prop, {Map<String, List<MacroClassConstructor>>? types}) {
    if (prop is MacroProperty) {
      if (prop.requireConversionToLiteral == true) {
        if (prop.typeInfo == TypeInfo.clazz) {
          return clazzToLiteral(prop, types);
        }
      }

      if (prop.typeInfo == TypeInfo.enumData) {
        return prop.asStringConstantValue() ?? '';
      }

      return jsonLiteralAsDart(prop.constantValue);
    }

    return jsonLiteralAsDart(prop);
  }

  static String clazzToLiteral(MacroProperty prop, Map<String, List<MacroClassConstructor>>? types) {
    final config = prop.constantValue;
    if (config is! Map<String, dynamic>) return '';

    types ??= {};
    final constructors = types[prop.type] ?? prop.classInfo?.constructors ?? const [];
    types[prop.type] = constructors;

    final constantConstructor = config['__constructor__'] as String? ?? '';
    var constructor = constructors.firstWhereOrNull((e) => e.constructorName == constantConstructor);
    // if no constructor fallback to the first one with const(maybe fails at compile time)
    constructor ??= constructors.firstWhereOrNull((e) => e.modifier.isGenerative || e.modifier.isConst);

    // still null, return raw data as literal
    if (constructor == null) {
      return jsonLiteralAsDart(config);
    }

    final str = StringBuffer('const ${prop.type}(');
    bool needComma = false;
    for (final field in constructor.positionalFields) {
      if (needComma) {
        str.write(', ');
      }
      final value = config[field.name];
      final literal = toLiteralValue(value, types: types);
      str.write(literal);
      needComma = true;
    }

    if (constructor.namedFields.isNotEmpty) {
      if (constructor.positionalFields.isEmpty) {
        str.write('{');
      } else {
        str.write(',{ ');
      }
    }

    needComma = false;
    for (final field in constructor.namedFields) {
      if (needComma) {
        str.write(', ');
      }
      final value = config[field.name];
      final literal = toLiteralValue(value, types: types);
      str.write('${field.name}: $literal');
      needComma = true;
    }

    if (constructor.namedFields.isNotEmpty) {
      str.write('}');
    }

    str.write(')');
    return str.toString();
  }

  static JsonKeyConfig fromMacroKey(MacroKey key) {
    final props = Map.fromEntries(key.properties.map((e) => MapEntry(e.name, e)));

    final fromJsonProp = props['fromJson'];
    String? fromJson, fromJsonArgType, fromJsonReturnType;

    if (fromJsonProp != null) {
      if (fromJsonProp.typeInfo != TypeInfo.function || !fromJsonProp.modifier.isStatic) {
        throw MacroException(
          'The provided JsonKey.fromJson must be a static function but got: ${fromJsonProp.constantValue}',
        );
      } else if (fromJsonProp.functionTypeInfo?.params.length != 1 ||
          fromJsonProp.functionTypeInfo!.returns.first.typeInfo == TypeInfo.voidType) {
        throw MacroException(
          'The provided JsonKey.fromJson must be a static function with one argument and return but got: ${fromJsonProp.constantValue}',
        );
      }
      fromJson = fromJsonProp.asStringConstantValue();
      fromJsonArgType = fromJsonProp.functionTypeInfo!.params.first.type;
      fromJsonReturnType = fromJsonProp.functionTypeInfo!.returns.first.type;
    }

    final toJsonProp = props['toJson'];
    String? toJson, toJsonArgType;
    bool? toJsonReturnNullable;

    if (toJsonProp != null) {
      if (toJsonProp.typeInfo != TypeInfo.function || !toJsonProp.modifier.isStatic) {
        throw MacroException(
          'The provided JsonKey.toJson must be a static function but got: ${toJsonProp.constantValue}',
        );
      } else if (toJsonProp.functionTypeInfo?.params.length != 1 ||
          toJsonProp.functionTypeInfo!.returns.first.typeInfo == TypeInfo.voidType) {
        throw MacroException(
          'The provided JsonKey.toJson must be a static function with one argument and return but got: ${toJsonProp.constantValue}',
        );
      }
      toJson = toJsonProp.asStringConstantValue();
      toJsonArgType = toJsonProp.functionTypeInfo!.params.first.type;
      toJsonReturnNullable = toJsonProp.functionTypeInfo!.returns.first.modifier.isNullable ? true : null;
    }

    final readValueProp = props['readValue'];
    String? readValue;

    if (readValueProp != null) {
      if (readValueProp.typeInfo != TypeInfo.function || !readValueProp.modifier.isStatic) {
        throw MacroException(
          'The provided JsonKey.readValue must be a static function but got: ${readValueProp.constantValue}',
        );
      } else if (readValueProp.functionTypeInfo?.params.length != 2 ||
          readValueProp.functionTypeInfo!.params.first.typeInfo != TypeInfo.map ||
          readValueProp.functionTypeInfo!.params.last.typeInfo != TypeInfo.string ||
          readValueProp.functionTypeInfo!.returns.first.typeInfo == TypeInfo.voidType) {
        throw MacroException(
          'The provided JsonKey.readValue must be a static function with two argument(Map obj, String key) and a return value but got: ${readValueProp.constantValue}',
        );
      }
      readValue = readValueProp.asStringConstantValue();
    }

    return JsonKeyConfig(
      defaultValue: props.containsKey('defaultValue') ? toLiteralValue(props['defaultValue']!) : null,
      fromJson: fromJson,
      fromJsonArgType: fromJsonArgType,
      fromJsonReturnType: fromJsonReturnType,
      includeFromJson: props['includeFromJson']?.asBoolConstantValue(),
      includeIfNull: props['includeIfNull']?.asBoolConstantValue(),
      includeToJson: props['includeToJson']?.asBoolConstantValue(),
      name: props['name']?.asStringConstantValue(),
      readValue: readValue,
      toJson: toJson,
      toJsonArgType: toJsonArgType,
      toJsonReturnNullable: toJsonReturnNullable,
      unknownEnumValue: props['unknownEnumValue']?.asStringConstantValue(),
      asRequired: props['asRequired']?.asBoolConstantValue(),
    );
  }

  final String? defaultValue;
  final String? fromJson;
  final String? fromJsonArgType;
  final String? fromJsonReturnType;
  final bool? includeFromJson;
  final bool? includeIfNull;
  final bool? includeToJson;
  final String? name;
  final String? readValue;
  final String? toJson;
  final String? toJsonArgType;
  final bool? toJsonReturnNullable;
  final String? unknownEnumValue;
  final bool? asRequired;
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

class DataClassMacroConfig {
  const DataClassMacroConfig({
    this.fieldRename,
    this.createFromJson,
    this.createToJson,
    this.createMapTo,
    this.createEqual,
    this.createCopyWith,
    this.createToStringOverride,
    this.includeIfNull,
  });

  static DataClassMacroConfig get defaultConfig {
    return DataClassMacroConfig();
  }

  static DataClassMacroConfig fromJson(Map<String, dynamic> json) {
    return DataClassMacroConfig(
      fieldRename: FieldRename.values.firstWhereOrNull((e) => e.name == json['field_rename']) ?? FieldRename.none,
      createFromJson: json['create_from_json'] as bool?,
      createToJson: json['create_to_json'] as bool?,
      createMapTo: json['createMapTo'] as bool?,
      createEqual: json['create_equal'] as bool?,
      createCopyWith: json['create_copy_with'] as bool?,
      createToStringOverride: json['create_to_string'] as bool?,
      includeIfNull: json['include_if_null'] as bool?,
    );
  }

  /// Defines the automatic naming strategy when converting class field names
  /// into JSON map keys.
  ///
  /// With a value [FieldRename.none] (the default), the name of the field is
  /// used without modification.
  ///
  /// See [FieldRename] for details on the other options.
  ///
  /// Note: the value for [JsonKey.name] takes precedence over this option for
  /// fields annotated with [JsonKey].
  final FieldRename? fieldRename;

  /// If `true` (the default), A static function is created in [ClassNameJson] that you can
  /// reference from your class. when argument became stable you can access it directly using [ClassName]
  ///
  /// ```dart
  /// @Macro(DataClassMacro())
  /// class Example {
  ///
  /// }
  ///
  /// mixin ExampleJson {
  ///   static Example fromJson(Map<String, dynamic> json) {..} // <- this is generated
  /// }
  /// ```
  final bool? createFromJson;

  /// If `true` (the default), A method is created that you can
  /// reference from your class.
  ///
  /// ```dart
  /// @Macro(DataClassMacro())
  /// class Example {
  ///   Map<String, dynamic> toJson() {..} // <- this is generated
  /// }
  /// ```
  final bool? createToJson;

  /// If `true` (the default), it implements map and mapOrNull method for sealed or abstract class
  final bool? createMapTo;

  /// If `true` (the default), it implements equality for all fields
  final bool? createEqual;

  /// If `true` (the default), it implements copyWith for all fields
  final bool? createCopyWith;

  /// If `true` (the default), it implements toString for all fields
  final bool? createToStringOverride;

  /// Whether the generator should include fields with `null` values in the
  /// serialized output.
  ///
  /// If `true`, all fields are written to JSON, even if they are `null`.
  /// default is false
  ///
  /// If a field is annotated with `JsonKey` with a non-`null` value for
  /// `includeIfNull`, that value takes precedent.
  final bool? includeIfNull;
}
