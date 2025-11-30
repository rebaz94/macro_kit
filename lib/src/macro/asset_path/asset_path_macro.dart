import 'dart:io';

import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/macro/data_class/config.dart';
import 'package:macro_kit/src/macro/data_class/helpers.dart';
import 'package:path/path.dart' as p;

/// A macro generator that automatically creates type-safe asset path constants from a directory structure.
///
/// This macro watches a specified directory for file changes and generates Dart code containing
/// constant string fields for each asset file found. The generated code maintains the folder
/// hierarchy as nested classes, making it easy to reference assets in a type-safe manner.
///
/// ## Features
///
/// - **Automatic Code Generation**: Generates constants for all files in the specified directory
/// - **Folder Hierarchy**: Maintains directory structure as nested classes for organized access
/// - **Field Name Sanitization**: Converts file names to valid Dart identifiers with customizable naming conventions
/// - **Custom Replacements**: Applies character replacements before sanitization for better control
/// - **Flutter-Ready Paths**: Generates paths relative to project root (e.g., `assets/images/img.png`)
///
/// ## Usage
///
/// Register the macro in your `main.dart` file:
///
/// ```dart
/// await runMacro(
///   macros: {
///     'AssetPathMacro': AssetPathMacro.initialize,
///   },
///   assetMacros: {
///     'assets': [
///       AssetMacroInfo(
///         macroName: 'AssetPathMacro',
///         extension: '*',
///         output: 'lib',
///         config: const AssetPathConfig(
///           extension: '*',
///           rename: FieldRename.camelCase,
///         ).toJson(),
///       ),
///     ],
///   },
/// );
/// ```
///
/// ## Usage in Code
///
/// ```dart
/// Image.asset(AssetPaths.logo);
/// Image.asset(AssetPaths.icons.home);
/// SvgPicture.asset(AssetPaths.icons.settings);
/// ```
///
/// ## Configuration
///
/// File names are automatically sanitized to create valid Dart identifiers:
/// - Special characters are replaced according to [AssetPathConfig.replacements]
/// - Remaining invalid characters are converted to underscores
/// - Leading underscores are removed (to keep fields public)
/// - Names starting with numbers are prefixed with `asset`
/// - Dart reserved keywords are suffixed with `Asset`
/// - Naming convention is applied based on [AssetPathConfig.rename]
///
/// Examples:
/// - `my-image.png` → `myImage` (with camelCase)
/// - `icon_2.svg` → `icon2` (with camelCase)
/// - `class.png` → `classAsset` (reserved keyword)
/// - `2d_map.png` → `asset2dMap` (starts with number)
class AssetPathMacro extends MacroGenerator {
  const AssetPathMacro({
    super.capability = const MacroCapability(),
    this.config = const AssetPathConfig(),
  });

  /// Initialize macro for execution
  static AssetPathMacro initialize(MacroConfig config) {
    final key = config.key;
    final props = Map.fromEntries(key.properties.map((e) => MapEntry(e.name, e)));

    return AssetPathMacro(
      capability: config.capability,
      config: Macro.parseMacroConfig(
        value: props['config']?.constantValue,
        fn: AssetPathConfig.fromJson,
        defaultValue: const AssetPathConfig(),
      ),
    );
  }

  /// The asset path configuration
  final AssetPathConfig config;

  @override
  String get suffixName => '';

  @override
  Future<void> onAsset(MacroState state, MacroAssetDeclaration asset) async {
    final assetState = state.assetState;
    if (assetState == null) return;

    final relativeBasePath = assetState.relativeBasePath;
    final absoluteBasePath = assetState.absoluteBasePath;

    final entity = FileSystemEntity.typeSync(absoluteBasePath, followLinks: false);
    if (entity != FileSystemEntityType.directory) return;

    final dir = Directory(absoluteBasePath);
    var rename = config.rename;
    if (rename == FieldRename.kebab) {
      rename = FieldRename.camelCase;
    }

    // Map structure: folder path -> list of (fieldName, filePath)
    final folderStructure = <String, List<(String, String)>>{};

    // Track subdirectories for each folder
    final subfolders = <String, Set<String>>{};

    if (config.syncList) {
      final entities = dir.listSync(recursive: config.recursive, followLinks: false);
      _processEntities(entities, absoluteBasePath, rename, folderStructure, subfolders);
    } else {
      final entities = await dir.list(recursive: config.recursive, followLinks: false).toList();
      _processEntities(entities, absoluteBasePath, rename, folderStructure, subfolders);
    }

    state.set('absoluteBasePath', absoluteBasePath);
    state.set('relativeBasePath', relativeBasePath);
    state.set('folderStructure', folderStructure);
    state.set('subfolders', subfolders);
  }

  void _processEntities(
    List<FileSystemEntity> entities,
    String absoluteBasePath,
    FieldRename rename,
    Map<String, List<(String, String)>> folderStructure,
    Map<String, Set<String>> subfolders,
  ) {
    bool Function(String path)? includeFile;
    if (config.extension != '*') {
      final extensions = config.extension.split(',');
      includeFile = (String path) => extensions.contains(p.extension(path));
    }

    for (final entity in entities) {
      if (entity is File) {
        if (includeFile?.call(entity.path) == false) {
          continue;
        }

        final relativePath = p.relative(entity.path, from: absoluteBasePath);
        final parentDir = p.dirname(relativePath);

        // if parentDir equal to '.', its root dir
        final folderKey = parentDir == '.' ? '' : parentDir;

        // Sanitize field name
        var rawFieldName = p.basenameWithoutExtension(entity.path);
        for (final entry in config.replacements.entries) {
          rawFieldName = rawFieldName.replaceAll(entry.key, entry.value);
        }

        final fieldName = _sanitizeFieldName(rename.renameOf(rawFieldName));

        folderStructure.putIfAbsent(folderKey, () => []).add((fieldName, entity.path));

        // Track parent-child folder relationships
        if (folderKey.isNotEmpty) {
          final parts = p.split(folderKey);
          for (var i = 0; i < parts.length; i++) {
            final parentPath = i == 0 ? '' : p.joinAll(parts.sublist(0, i));

            subfolders.putIfAbsent(parentPath, () => {}).add(parts[i]);
          }
        }
      }
    }
  }

  @override
  Future<void> onGenerate(MacroState state) async {
    final buff = StringBuffer();

    final absoluteBasePath = state.getOrNull<String>('absoluteBasePath') ?? '';
    final relativeBasePath = state.getOrNull<String>('relativeBasePath') ?? '';
    final folderStructure = state.getOrNull<Map<String, List<(String, String)>>>('folderStructure') ?? const {};
    final subfolders = state.getOrNull<Map<String, Set<String>>>('subfolders') ?? const {};

    // Generate main AssetPaths class first
    buff.writeln('// ignore_for_file: library_private_types_in_public_api');
    buff.writeln('// Generated by AssetPathMacro: DO NOT MODIFY BY HAND\n');
    buff.writeln('final class AssetPaths {');
    buff.writeln('  const AssetPaths._();\n');

    // Add root level files
    final rootFiles = folderStructure[''] ?? const [];
    for (final (fieldName, filePath) in rootFiles) {
      final assetPath = _getAssetPath(filePath, absoluteBasePath, relativeBasePath);
      buff.writeln('  static const $fieldName = \'$assetPath\';');
    }

    if (rootFiles.isNotEmpty && subfolders['']?.isNotEmpty == true) {
      buff.writeln();
    }

    // Add root level folder references
    final rootSubfolders = subfolders[''] ?? {};
    for (final folderName in rootSubfolders) {
      final className = _getFolderClassName(FieldRename.pascal.renameOf(folderName));
      buff.writeln('  static const $className $folderName = $className._();');
    }

    buff.writeln('}');
    buff.writeln();

    // Generate nested folder classes (private)
    final processedFolders = <String>{};
    _generateFolderClasses(buff, folderStructure, subfolders, processedFolders, absoluteBasePath, relativeBasePath);

    final file = File(p.join(state.assetState!.absoluteBaseOutputPath, 'assets.dart'));
    file.createSync(recursive: true);
    file.writeAsStringSync(MacroState.formatCode(buff.toString()));

    state.reportGeneratedFile([file.path]);
  }

  String _getAssetPath(String filePath, String absoluteBasePath, String relativeBasePath) {
    // Get the file path relative to the absolute base directory
    final relativeToBase = p.relative(filePath, from: absoluteBasePath);

    // Combine with the relative base path to get the full asset path
    return p.join(relativeBasePath, relativeToBase);
  }

  void _generateFolderClasses(
    StringBuffer buff,
    Map<String, List<(String, String)>> folderStructure,
    Map<String, Set<String>> subfolders,
    Set<String> processedFolders,
    String absoluteBasePath,
    String relativeBasePath,
  ) {
    // Sort folders by depth (deepest first) to ensure nested classes are generated first
    final sortedFolders = folderStructure.keys.where((k) => k.isNotEmpty).toList()
      ..sort((a, b) => p.split(a).length.compareTo(p.split(b).length));

    for (final folderPath in sortedFolders) {
      if (processedFolders.contains(folderPath)) continue;
      processedFolders.add(folderPath);

      final className = _getFolderClassName(FieldRename.pascal.renameOf(folderPath));

      buff.writeln('final class $className {');
      buff.writeln('  const $className._();');
      buff.writeln();

      // Add files in this folder
      final files = folderStructure[folderPath] ?? [];
      for (final (fieldName, filePath) in files) {
        final assetPath = _getAssetPath(filePath, absoluteBasePath, relativeBasePath);
        buff.writeln('  static const ${fieldName}Val = \'$assetPath\';\n');
        buff.writeln('  String get $fieldName => ${fieldName}Val;');
      }

      if (files.isNotEmpty && subfolders[folderPath]?.isNotEmpty == true) {
        buff.writeln();
      }

      // Add subfolder references
      final currentSubfolders = subfolders[folderPath] ?? {};
      for (final subfolderName in currentSubfolders) {
        final subfolderClassName = _getFolderClassName(FieldRename.pascal.renameOf('$folderPath/$subfolderName'));
        buff.writeln('  static const $subfolderClassName ${subfolderName}Val = $subfolderClassName._();\n');
        buff.writeln('  $subfolderClassName get $subfolderName => ${subfolderName}Val;\n');
      }

      buff.writeln('}');
      buff.writeln();
    }
  }

  static final RegExp _invalidCharsPattern = RegExp(r'[^a-zA-Z0-9_$]');
  static final RegExp _leadingUnderscoresPattern = RegExp(r'^_+');
  static final RegExp _startsWithNumberPattern = RegExp(r'^[0-9]');
  static const _reservedWords = {
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch', //
    'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do', //
    'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external', //
    'factory', 'false', 'final', 'finally', 'for', 'function', 'get', 'hide', //
    'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library', //
    'mixin', 'new', 'null', 'of', 'on', 'operator', 'part', 'required', //
    'rethrow', 'return', 'set', 'show', 'static', 'super', 'switch', 'sync', //
    'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'while', 'with', //
    'yield', //
  };

  String _sanitizeFieldName(String name) {
    // Replace invalid characters with underscores
    var sanitized = name.replaceAll(_invalidCharsPattern, '_');

    // Remove leading underscores to prevent making it private
    sanitized = sanitized.replaceAll(_leadingUnderscoresPattern, '');

    // Ensure it doesn't start with a number (after removing underscores)
    if (sanitized.isEmpty || _startsWithNumberPattern.hasMatch(sanitized)) {
      sanitized = 'asset$sanitized';
    }

    // Handle Dart reserved keywords
    if (_reservedWords.contains(sanitized)) {
      sanitized = '${sanitized}Asset';
    }

    return sanitized;
  }

  String _getFolderClassName(String folderName) {
    var cleaned = folderName.replaceAll(_invalidCharsPattern, '_');

    // Remove leading underscores before PascalCase conversion
    cleaned = cleaned.replaceAll(_leadingUnderscoresPattern, '');

    var className = FieldRename.pascal.renameOf(cleaned);

    // Ensure it doesn't start with a number or is empty
    if (className.isEmpty || _startsWithNumberPattern.hasMatch(className)) {
      className = 'Folder$className';
    }

    // Prefix with underscore to make the CLASS private (this is intentional)
    return '_$className';
  }
}

/// Configuration for the AssetPath macro that controls how asset path fields are generated.
class AssetPathConfig {
  const AssetPathConfig({
    this.syncList = true,
    this.recursive = true,
    this.extension = '*',
    this.rename = FieldRename.camelCase,
    this.replacements = defaultReplacements,
  });

  static const Map<String, String> defaultReplacements = {
    '"': '',
    "'": '',
    "{": '_',
    '}': '_',
    ' ': '',
    '!': '',
  };

  static AssetPathConfig fromJson(Map<String, dynamic> json) {
    return AssetPathConfig(
      syncList: json['syncList'] as bool,
      recursive: json['recursive'] as bool,
      extension: json['extension'] as String,
      rename: MacroExt.decodeEnum(FieldRename.values, json['rename'] as String?, unknownValue: FieldRename.camelCase),
      replacements: (json['replacements'] as Map).map((k, v) => MapEntry(k as String, v as String)),
    );
  }

  /// Whether to use sync list api to fetch all files in the directory.
  final bool syncList;

  /// Whether to recursively fetch all files inside the directory.
  final bool recursive;

  /// File extensions to be included in the asset path generation
  ///
  /// Only files with these extensions will be included in the generated asset path
  ///
  /// Supports:
  ///   - `'*'` for any file types
  ///   - Specific extensions ex. `'.png,.json'`
  ///
  /// Examples: `'.json',.yaml'`, `'*'`, `'.png,.jpg,.svg'`
  final String extension;

  /// The naming convention to apply to generated asset path field names.
  ///
  /// Determines how asset file names are transformed into valid Dart field names:
  /// - [FieldRename.none]: Uses the field name without changes, but replacing any (dash or .) with underscore.
  /// - [FieldRename.snake]: Converts to snake_case (e.g., `my_asset`)
  /// - [FieldRename.pascal]: Converts to PascalCase (e.g., `MyAsset`)
  /// - [FieldRename.screamingSnake]: Converts to SCREAMING_SNAKE_CASE (e.g., `MY_ASSET`)
  final FieldRename rename;

  /// The key value pair values to be applied and remove any invalid character in file or directory name.
  final Map<String, String> replacements;

  Map<String, dynamic> toJson() {
    return {
      'syncList': syncList,
      'recursive': recursive,
      'extension': extension,
      'rename': rename.name,
      'replacements': replacements,
    };
  }

  @override
  String toString() {
    return 'AssetPathConfig{syncList: $syncList, recursive: $recursive, extension: $extension, rename: $rename, replacements: $replacements}';
  }
}
