## DataClassMacro

`DataClassMacro` is a powerful macro that automatically generates common data class boilerplate code
for your Dart classes. It eliminates the need to manually write repetitive code for JSON
serialization, equality comparison, copying, and string representation.

## Features

The DataClassMacro automatically generates:

* ✅ `fromJson(Map<String, dynamic> json)` static constructor
* ✅ `toJson()` method
* ✅ Equality operators (`==`, `hashCode`)
* ✅ `copyWith()` method
* ✅ `toString()` method
* ✅ `map()` and `mapOrNull()` methods for sealed/abstract classes

## Basic Usage

To use the DataClassMacro, annotate your class with `@Macro(DataClassMacro())` or the shorthand
`@dataClassMacro`, then apply a `with` clause to include the generated mixin:

```dart
@dataClassMacro
class User with UserData {
  final String id;
  final String name;
  final int age;

  User({
    required this.id,
    required this.name,
    required this.age,
  });
}
```

The macro will generate a mixin named `{ClassName}Data` that provides all the functionality.

## Configuration Options

### Per-Class Configuration

You can customize the macro behavior for individual classes by passing parameters to the macro
annotation:

```dart
@Macro(DataClassMacro(
  fromJson: true,
  toJson: true,
  equal: true,
  copyWith: true,
  toStringOverride: true,
  includeDiscriminator: false,
))
class User with UserDataClass {
  // ...
}
```

#### Available Parameters

- **`primaryConstructor`** (String?): Specifies a custom constructor name. If it contains `.`, it's
  treated as a named constructor.
    - Example: `'Example.test'` or `'.test'` for a named constructor

- **`fromJson`** (bool?): If `true`, generates a static `fromJson` method. Defaults to global
  config.

- **`toJson`** (bool?): If `true`, generates a `toJson` method. Defaults to global config.

- **`mapTo`** (bool?): If `true`, generates `map` and `mapOrNull` methods for sealed or abstract
  classes. Defaults to global config.

- **`asCast`** (bool?): If `true`, generates casting methods for sealed or abstract
  classes. Defaults to global config.

- **`equal`** (bool?): If `true`, generates equality operators. Defaults to global config.

- **`copyWith`** (bool?): If `true`, generates a `copyWith` method. Defaults to global config.

- **`toStringOverride`** (bool?): If `true`, generates a `toString` method. Defaults to global
  config.

### Polymorphic Classes

For sealed classes or abstract class hierarchies, the macro supports discriminator-based
polymorphism:

- **`discriminatorKey`** (String?): The JSON key used to identify the subtype (e.g., `"type"`,
  `"kind"`).

- **`discriminatorValue`** (Object?): The value that identifies this specific class. Supports:
    - Primitive types: `int`, `double`, `bool`, `String`
    - Custom matcher function: `bool Function(Map<String, dynamic> json)`

- **`includeDiscriminator`** (bool?): Whether to automatically include the discriminator in
  serialization. Only use when `discriminatorKey` and `discriminatorValue` are not provided.

- **`defaultDiscriminator`** (bool?): If `true`, this class becomes the default choice when no
  discriminator matches.

#### Polymorphic Example

```dart
@Macro(DataClassMacro(
  discriminatorKey: 'type',
))
sealed class Animal with AnimalDataClass {}

@Macro(DataClassMacro(
  discriminatorValue: 'dog',
))
class Dog extends Animal with DogDataClass {
  final String breed;

  Dog({required this.breed});
}

@Macro(DataClassMacro(
  discriminatorValue: 'cat',
))
class Cat extends Animal with CatDataClass {
  final bool isIndoor;

  Cat({required this.isIndoor});
}
```

## Global Configuration

You can set default behaviors for all classes using the `.macro.json` configuration file. This
allows you to customize the macro's behavior project-wide without annotating every class
individually.

### Configuration File Structure

Create or modify `.macro.json` in your project root:

```json
{
  "config": {
    "remap_generated_file_to": "",
    "auto_rebuild_on_connect": true,
    "always_rebuild_on_connect": false
  },
  "macros": {
    "DataClassMacro": {
      "field_rename": "none",
      "create_from_json": true,
      "create_to_json": true,
      "create_map_to": true,
      "create_as_cast": true,
      "create_equal": true,
      "create_copy_with": true,
      "create_to_string": true,
      "include_if_null": false,
      "as_literal_types": []
    }
  }
}
```

### Global Configuration Options

#### `field_rename`

Defines the automatic naming strategy when converting class field names into JSON map keys.

- **`"none"`** (default): Uses field names without modification
- **`"snake_case"`**: Converts `camelCase` to `snake_case`
- **`"kebab_case"`**: Converts `camelCase` to `kebab-case`
- **`"pascal_case"`**: Converts to `PascalCase`

Example:

```json
{
  "field_rename": "snake_case"
}
```

This converts `userName` → `"user_name"` in JSON.

#### `create_from_json`

- **Type**: `bool`
- **Default**: `true`
- **Description**: Generates a static `fromJson` constructor in the generated mixin.

```dart
mixin ExampleData {
// Generated code
  static Example fromJson(Map<String, dynamic> json) {}
}
```

#### `create_to_json`

- **Type**: `bool`
- **Default**: `true`
- **Description**: Generates a `toJson` method.

```dart
mixin ExampleData {
  // Generated code
  Map<String, dynamic> toJson() {}
}
```

#### `create_map_to`

- **Type**: `bool`
- **Default**: `true`
- **Description**: Generates `map` and `mapOrNull` methods for sealed or abstract classes.

#### `create_as_cast`

- **Type**: `bool`
- **Default**: `true`
- **Description**: Generates casting methods (like `asDog()`, `asCat()`) for sealed or abstract
  classes.

#### `create_equal`

- **Type**: `bool`
- **Default**: `true`
- **Description**: Generates `==` operator and `hashCode` for all fields.

#### `create_copy_with`

- **Type**: `bool`
- **Default**: `true`
- **Description**: Generates a `copyWith` method for immutable updates.

#### `create_to_string`

- **Type**: `bool`
- **Default**: `true`
- **Description**: Generates a `toString` method that prints all field values.

#### `include_if_null`

- **Type**: `bool`
- **Default**: `false`
- **Description**: Whether to include fields with `null` values in `toJson` output. If `false`, null
  fields are omitted from the JSON.

Example:

```json
{
  "include_if_null": true
}
```

#### `as_literal_types`

- **Type**: `List<String>`
- **Default**: `[]`
- **Description**: Types that should bypass serialization/deserialization and be passed through
  directly. Useful for types that are already serializable or have custom serialization.

Example:

```json
{
  "as_literal_types": [
    "GeoPoint",
    "Timestamp",
    "Duration"
  ]
}
```

This treats Firebase's `GeoPoint` and `Timestamp`, and Dart's `Duration` as literal types that don't
need conversion.

#### `use_map_convention`

- **Type**: `bool`
- **Default**: `false`
- **Description**: Control the naming convention for serialization methods in generated data classes

When `use_map_convention` is false or not specified, the following method names are generated:

- fromJson - Static method to create instance from Map<String, dynamic>
- toJson - Instance method to convert to Map<String, dynamic>

When `use_map_convention` is true, the following method names are generated:

- fromMap - Static method to create instance from Map<String, dynamic>
- toMap - Instance method to convert to Map<String, dynamic>

### Complete Example

Here's a fully configured `.macro.json`:

```json
{
  "config": {
    "remap_generated_file_to": "lib/generated",
    "auto_rebuild_on_connect": true,
    "always_rebuild_on_connect": false
  },
  "macros": {
    "DataClassMacro": {
      "field_rename": "snake_case",
      "create_from_json": true,
      "create_to_json": true,
      "create_map_to": true,
      "create_as_cast": true,
      "create_equal": true,
      "create_copy_with": true,
      "create_to_string": true,
      "include_if_null": false,
      "as_literal_types": [
        "GeoPoint",
        "Timestamp"
      ],
      "use_map_convention": false
    }
  }
}
```

**Note**: To customize the DataClassMacro behavior globally, you need to add these configuration
options under `"macros"` → `"DataClassMacro"` in your `.macro.json` file as shown above.

---

<p align="right"><a href="../topics/Asset Path Macro-topic.html">Next: Asset Path Macro</a></p>