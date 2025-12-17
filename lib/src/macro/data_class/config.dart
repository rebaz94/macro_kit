import 'package:macro_kit/macro_kit.dart';
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
    this.asLiteral,
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

  /// The default value(s) to use when an enum value is not recognized during deserialization.
  ///
  /// Valid only on enum fields. Use [EnumValue(myEnum)] for a single enum type, or
  /// `[EnumValue.values([enum1, enum2])]` when working with complex generic types containing
  /// multiple different enum types (e.g., `Map<Enum1, Enum2>`). For multiple enums, the order
  /// in the list should match the order they appear in the type definition.
  final EnumValue? unknownEnumValue;

  /// Determine an nullable field must have a `required` keyword when generating a constructor
  /// note: this field is not been used until augment became stable
  final bool? asRequired;

  /// Whether this field should be treated as a literal, bypassing serialization/deserialization.
  ///
  /// When `true`, the field value is passed through directly without any transformation.
  /// This is useful for types that are already serializable or have custom serialization
  /// handled elsewhere, such as Firebase's `GeoPoint` or `Timestamp`.
  ///
  /// If `null`, the field will use the default serialization behavior or inherit from
  /// global `asLiteralTypes` configuration.
  final bool? asLiteral;
}

/// Represents a default enum value or multiple enum values for handling unknown cases.
///
/// Use the default constructor [EnumValue.new] for a single enum type.
/// Use [EnumValue.of] when working with complex generic types that contain
/// multiple different enum types (e.g., `Map<Enum1, Enum2>`), where the order
/// of enums in the list should match their order in the type definition.
class EnumValue {
  const EnumValue._(this.value) : values = null;

  const EnumValue.__(this.values) : value = null;

  /// Creates an enum value wrapper for a single enum.
  const factory EnumValue(Enum value) = EnumValue._;

  /// Creates an enum value wrapper for a single enum.
  const factory EnumValue.value(Enum value) = EnumValue._;

  /// Creates an enum value wrapper for multiple enums in complex generic types.
  ///
  /// The order of enums in the list should match the order they appear in the
  /// type definition. For example, with `Map<Enum1, Enum2>`, provide
  /// `[defaultEnum1, defaultEnum2]`.
  const factory EnumValue.of(List<Enum> value) = EnumValue.__;

  /// Single enum value for simple cases.
  final Enum? value;

  /// Multiple enum values for complex generic types with multiple enum parameters.
  final List<Enum>? values;
}

@internal
class JsonKeyConfig {
  const JsonKeyConfig({
    this.defaultValue,
    this.fromJsonProp,
    this.includeFromJson,
    this.includeIfNull,
    this.includeToJson,
    this.name,
    this.readValueProp,
    this.toJsonProp,
    this.toJsonReturnNullable,
    this.unknownEnumValue,
    this.asRequired,
    this.asLiteral,
  });

  static const defaultKey = JsonKeyConfig();

  static JsonKeyConfig fromMacroKey(MacroKey key) {
    final props = Map.fromEntries(key.properties.map((e) => MapEntry(e.name, e)));

    final fromJsonProp = props['fromJson'];

    if (fromJsonProp != null) {
      if (fromJsonProp.typeInfo != TypeInfo.function || !fromJsonProp.isStatic) {
        throw MacroException(
          'The provided JsonKey.fromJson must be a static function but got: ${fromJsonProp.constantValue}',
        );
      } else if (fromJsonProp.functionTypeInfo?.params.length != 1 ||
          fromJsonProp.functionTypeInfo!.returns.first.typeInfo == TypeInfo.voidType) {
        throw MacroException(
          'The provided JsonKey.fromJson must be a static function with one argument and return but got: ${fromJsonProp.constantValue}',
        );
      }
    }

    final toJsonProp = props['toJson'];
    bool? toJsonReturnNullable;

    if (toJsonProp != null) {
      if (toJsonProp.typeInfo != TypeInfo.function || !toJsonProp.isStatic) {
        throw MacroException(
          'The provided JsonKey.toJson must be a static function but got: ${toJsonProp.constantValue}',
        );
      } else if (toJsonProp.functionTypeInfo?.params.length != 1 ||
          toJsonProp.functionTypeInfo!.returns.first.typeInfo == TypeInfo.voidType) {
        throw MacroException(
          'The provided JsonKey.toJson must be a static function with one argument and return but got: ${toJsonProp.constantValue}',
        );
      }

      toJsonReturnNullable = toJsonProp.functionTypeInfo!.returns.first.modifier.isNullable ? true : null;
    }

    final readValueProp = props['readValue'];
    final unknownEnumValue = props['unknownEnumValue']?.constantValue;

    if (readValueProp != null) {
      if (readValueProp.typeInfo != TypeInfo.function || !readValueProp.isStatic) {
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
    }

    final defaultValue = props['defaultValue'];

    return JsonKeyConfig(
      defaultValue: defaultValue != null ? MacroProperty.toLiteralValue(defaultValue) : null,
      fromJsonProp: fromJsonProp,
      includeFromJson: props['includeFromJson']?.asBoolConstantValue(),
      includeIfNull: props['includeIfNull']?.asBoolConstantValue(),
      includeToJson: props['includeToJson']?.asBoolConstantValue(),
      name: props['name']?.asStringConstantValue(),
      readValueProp: readValueProp,
      toJsonProp: toJsonProp,
      toJsonReturnNullable: toJsonReturnNullable,
      unknownEnumValue: unknownEnumValue is Map
          ? unknownEnumValuesFromJson(unknownEnumValue as Map<String, dynamic>)
          : null,
      asRequired: props['asRequired']?.asBoolConstantValue(),
      asLiteral: props['asLiteral']?.asBoolConstantValue(),
    );
  }

  /// Parse encoded constant [EnumValue] type into a list
  static List<String>? unknownEnumValuesFromJson(Map<String, dynamic> json) {
    final value = json['value'] as String?;
    if (value != null) {
      return [value];
    }

    return (json['values'] as List?)?.map((e) => e as String).toList();
  }

  final String? defaultValue;
  final MacroProperty? fromJsonProp;
  final bool? includeFromJson;
  final bool? includeIfNull;
  final bool? includeToJson;
  final String? name;
  final MacroProperty? readValueProp;
  final MacroProperty? toJsonProp;
  final bool? toJsonReturnNullable;
  final List<String>? unknownEnumValue;
  final bool? asRequired;
  final bool? asLiteral;

  bool isLiteral(DataClassMacroConfig config, String type) {
    return switch (asLiteral) {
      false => false,
      true => true,
      _ => config.asLiteralTypes.contains(type),
    };
  }
}

@internal
class DataClassMacroConfig extends MacroGlobalConfig {
  const DataClassMacroConfig({
    this.fieldRename,
    this.createFromJson,
    this.createToJson,
    this.createMapTo,
    this.createAsCast,
    this.createEqual,
    this.createCopyWith,
    this.createToStringOverride,
    this.includeIfNull,
    this.asLiteralTypes = const [],
    this.useMapConvention = false,
  });

  static DataClassMacroConfig fromJson(Map<String, dynamic> json) {
    @pragma('vm:prefer-inline')
    T? parseField<T>(Object? value) {
      if (value is T) return value;
      return null;
    }

    return DataClassMacroConfig(
      fieldRename: MacroExt.decodeEnum(FieldRename.values, json['field_rename'] ?? '', unknownValue: FieldRename.none),
      createFromJson: parseField(json['create_from_json']),
      createToJson: parseField(json['create_to_json']),
      createMapTo: parseField(json['create_map_to']),
      createAsCast: parseField(json['create_as_cast']),
      createEqual: parseField(json['create_equal']),
      createCopyWith: parseField(json['create_copy_with']),
      createToStringOverride: parseField(json['create_to_string']),
      includeIfNull: parseField(json['include_if_null']),
      asLiteralTypes: parseField<List>(json['as_literal_types'])?.map((e) => e as String).toList() ?? const [],
      useMapConvention: parseField(json['use_map_convention']) ?? false,
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

  /// If `true` (the default), A static function is created in '{ClassName}Json' that you can
  /// reference from your class. when argument became stable you can access it directly using 'ClassName'
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

  /// If `true` (the default), it implements as cast method for sealed or abstract class
  final bool? createAsCast;

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

  /// Types that should be treated as literals, bypassing serialization/deserialization.
  ///
  /// These types are passed through directly without any transformation. This is
  /// useful for types that are already serializable or have custom serialization
  /// handled elsewhere, such as Firebase's `GeoPoint` or `Timestamp`.
  final List<String> asLiteralTypes;

  /// Whether to use fromMap/toMap over fromJson/toJson
  ///
  /// When `use_map_convention` is false or not specified, the following method names are generated:
  /// - fromJson - Static method to create instance from `Map<String, dynamic>`
  /// - toJson - Instance method to convert to `Map<String, dynamic>`
  ///
  /// When `use_map_convention` is true, the following method names are generated:
  /// - fromMap - Static method to create instance from `Map<String, dynamic>`
  /// - toMap - Instance method to convert to `Map<String, dynamic>`
  ///
  /// This setting is configured globally since data classes that depend on other
  /// data classes need to know which methods to call during nested serialization.
  ///
  /// Use case: Migration from tools like Dart Data Class Generator VS Code extension
  /// which uses toMap/fromMap convention by default.
  final bool useMapConvention;
}
