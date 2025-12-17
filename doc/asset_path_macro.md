## AssetPathMacro Documentation

`AssetPathMacro` is a powerful macro that automatically generates type-safe asset path constants
from your project's directory structure. It watches a specified directory for file changes and
creates Dart code with constant string fields for each asset file, maintaining the folder hierarchy
as nested classes for organized and type-safe asset access.

## Features

* ✅ **Automatic Code Generation**: Generates constants for all files in the specified directory
* ✅ **Folder Hierarchy**: Maintains directory structure as nested classes for organized access
* ✅ **Field Name Sanitization**: Converts file names to valid Dart identifiers with customizable
  naming conventions
* ✅ **Custom Replacements**: Applies character replacements before sanitization for better control
* ✅ **Flutter-Ready Paths**: Generates paths relative to project root (e.g.,
  `assets/images/img.png`)
* ✅ **File Watching**: Automatically regenerates when asset files are added, removed, or renamed

## Setup

Register the macro in your `main.dart` file (or wherever you initialize macros):

```dart
void main() async {
  await runMacro(
    macros: {
      'AssetPathMacro': AssetPathMacro.initialize,
    },
    assetMacros: {
      'assets': [
        AssetMacroInfo(
          macroName: 'AssetPathMacro',
          extension: '*',
          output: 'lib',
          config: const AssetPathConfig(
            extension: '*',
            rename: FieldRename.camelCase,
          ).toJson(),
        ),
      ],
    },
  );
}
```

### Configuration Parameters

#### `macroName`

- **Type**: `String`
- **Required**: Yes
- **Description**: The name of the macro to use. Must be `'AssetPathMacro'`.

#### `extension`

- **Type**: `String`
- **Required**: Yes
- **Description**: File extension filter. Use `'*'` to include all files, or specify a particular
  extension like `'.png'`, `'.svg'`, `'.jpg'`, etc.

#### `output`

- **Type**: `String`
- **Required**: Yes
- **Description**: The output directory where the generated Dart file will be placed (e.g., `'lib'`,
  `'lib/generated'`).

#### `config`

- **Type**: `Map<String, dynamic>?`
- **Required**: false
- **Description**: Configuration object for the AssetPathMacro. Must be converted to JSON using
  `.toJson()`.

## AssetPathConfig Options

The `AssetPathConfig` class allows you to customize how asset paths are generated:

```dart

final config = const AssetPathConfig(
  extension: '*',
  rename: FieldRename.camelCase,
  replacements: {'-': '_', '.': '_'},
);
```

### `extension`

- **Type**: `String`
- **Default**: `'*'`
- **Description**: Filter files by extension. Use `'*'` for all files.

### `rename`

- **Type**: `FieldRename`
- **Default**: `FieldRename.camelCase`
- **Description**: Naming convention for generated field names.

Available options:

- **`FieldRename.none`**: Uses field names without modification
- **`FieldRename.camelCase`**: Converts to camelCase (e.g., `myImage`)
- **`FieldRename.pascalCase`**: Converts to PascalCase (e.g., `MyImage`)
- **`FieldRename.snakeCase`**: Converts to snake_case (e.g., `my_image`)
- **`FieldRename.kebabCase`**: Converts to kebab-case (e.g., `my-image`)

### `replacements`

- **Type**: `Map<String, String>`
- **Default**: `{}`
- **Description**: Custom character replacements applied before sanitization. Useful for handling
  special characters in file names.

## File Name Sanitization

Asset file names are automatically sanitized to create valid Dart identifiers following these rules:

1. **Custom Replacements**: Characters specified in `AssetPathConfig.replacements` are replaced
   first
2. **Invalid Characters**: Remaining invalid characters are converted to underscores
3. **Leading Underscores**: Removed to keep fields public
4. **Numbers at Start**: Names starting with numbers are prefixed with `asset`
5. **Reserved Keywords**: Dart reserved keywords are suffixed with `Asset`
6. **Naming Convention**: Applied based on `AssetPathConfig.rename`

### Sanitization Examples

With `FieldRename.camelCase`:

| Original File Name | Generated Field Name | Reason                                          |
|--------------------|----------------------|-------------------------------------------------|
| `my-image.png`     | `myImage`            | Hyphen removed, camelCase applied               |
| `icon_2.svg`       | `icon2`              | Underscore removed, camelCase applied           |
| `class.png`        | `classAsset`         | Reserved keyword, suffix added                  |
| `2d_map.png`       | `asset2dMap`         | Starts with number, prefix added                |
| `user@avatar.jpg`  | `userAvatar`         | Special char replaced (with custom replacement) |
| `_private.png`     | `private`            | Leading underscore removed                      |

---

<p align="right"><a href="../topics/Write New Macro-topic.html">Next: Write New Macro</a></p>