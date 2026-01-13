## EmbedMacro Documentation

`EmbedMacro` is a macro that embeds asset files directly into Dart code as byte arrays. It scans a
specified directory, converts matching files into `Uint8List` data, and generates a virtual file
system API—similar to `dart:io`—for seamless and efficient access to embedded assets at runtime.

Unlike path-based solutions, `EmbedMacro` fully embeds asset contents into the generated Dart code,
making it ideal for environments where file system access is limited or unavailable.

## Features

* ✅ **Embedded Assets**: Converts asset files into `Uint8List` byte arrays in generated Dart code
* ✅ **Virtual File System**: Provides `file` and `directory` APIs modeled after `dart:io`
* ✅ **Change Detection**: Tracks asset changes using `.embed_generated.json` and regenerates only
  modified files
* ✅ **Recursive Scanning**: Optionally embeds files from nested directories
* ✅ **Extension Filtering**: Supports embedding specific file types or all files
* ✅ **Memory Management**: Allows explicit disposal of embedded file data when no longer needed

## Setup

Register the macro in your `main.dart` file (or wherever you initialize macros):

```dart
void main() async {
  await runMacro(
    macros: {
      'EmbedMacro': EmbedMacro.initialize,
    },
    assetMacros: {
      'assets': [
        AssetMacroInfo(
          macroName: 'EmbedMacro',
          extension: '*',
          output: 'lib/embed',
          config: const EmbedMacroConfig().toJson(),
        ),
      ],
    },
  );
}
```

## Usage in Code

```dart

final fs = EmbedFs.current;

// Read a file as bytes
final file = fs.file('/images/logo.png');
final bytes = file.readAsBytesSync();

// Dispose when done to free memory
file.dispose
();

// List directory contents
final dir = fs.directory('/images');
final files = dir.listSync(recursive: true);
```

## Configuration Parameters

### `config`

* **Type**: `Map<String, dynamic>?`
* **Required**: No
* **Description**: Configuration object for `EmbedMacro`. Must be converted to JSON using
  `.toJson()`.

## EmbedMacroConfig Options

The `EmbedMacroConfig` class allows fine-grained control over how assets are embedded and accessed:

```dart

const config = EmbedMacroConfig(
  generatedClassName: 'EmbedFs',
  syncList: true,
  recursive: true,
  extension: '*',
);
```

### `generatedClassName`

* **Type**: `String?`
* **Default**: `'EmbedFs'`
* **Description**: The name of the generated virtual file system class.

### `syncList`

* **Type**: `bool?`
* **Default**: `true`
* **Description**: Whether to expose synchronous directory listing APIs (e.g. `listSync`).

### `recursive`

* **Type**: `bool?`
* **Default**: `true`
* **Description**: Whether to recursively include files from subdirectories when embedding assets.

### `extension`

* **Type**: `String?`
* **Default**: `'*'`
* **Description**: File extensions to include during embedding.

Supported formats:

* `'*'` — include all file types
* Specific extensions such as `'.png,.json,.yaml'`

## How It Works

1. **Directory Scan**: The macro scans the configured asset directory
2. **Filtering**: Files are filtered based on the configured extensions
3. **Embedding**: Each file is converted into a `Uint8List` in generated Dart code
4. **Change Tracking**: A `.embed_generated.json` file records file hashes to detect changes
5. **Regeneration**: Only changed or new files are regenerated on subsequent runs
6. **Runtime Access**: Assets are accessed via the generated virtual file system API

---

<p align="right"><a href="../topics/Global Configuration-topic.html">Next: Global Configuration</a></p>
