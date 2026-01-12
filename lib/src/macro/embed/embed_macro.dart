import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:macro_kit/macro_kit.dart';
import 'package:macro_kit/src/analyzer/utils/hash.dart';
import 'package:path/path.dart' as p;

export 'package:macro_kit/src/core/platform/platform.dart' show parentPathOf;

export 'embed_entity.dart';

part 'config.dart';
part 'metadata.dart';

/// A macro that embeds asset files directly into Dart code as byte arrays.
///
/// This macro scans a directory, generates Dart code containing the raw bytes of each file,
/// and provides a virtual file system interface similar to dart:io classes for seamless integration.
///
/// ## Features
///
/// - **Embedded Assets**: Converts files to [Uint8List] byte arrays in generated code
/// - **Change Detection**: Tracks file changes via `.embed_generated.json` and only regenerates modified files
///
/// ## Usage
///
/// Register the macro in your `main.dart`:
///
/// ```dart
/// await runMacro(
///   macros: {
///     'EmbedMacro': EmbedMacro.initialize,
///   },
///   assetMacros: {
///     'assets': [
///       AssetMacroInfo(
///         macroName: 'EmbedMacro',
///         extension: '*',
///         output: 'lib/embed',
///         config: const EmbedMacroConfig().toJson(),
///       ),
///     ],
///   },
/// );
/// ```
///
/// ## Usage in Code
///
/// ```dart
/// final fs = EmbedFS.current;
/// final file = fs.file('/images/logo.png');
/// final bytes = file.readAsBytesSync();
///
/// // Dispose when done to remove data from memory
/// file.dispose();
///
/// // List directory contents
/// final dir = fs.directory('/images');
/// final files = dir.listSync(recursive: true);
/// ```
class EmbedMacro extends MacroGenerator {
  const EmbedMacro({
    super.capability = const MacroCapability(),
    this.config = const EmbedMacroConfig(),
  });

  static EmbedMacro initialize(MacroConfig config) {
    final key = config.key;
    final props = key.propertiesAsMap();

    return EmbedMacro(
      capability: config.capability,
      config: Macro.parseMacroConfig(
        value: props['config']?.constantValue,
        fn: EmbedMacroConfig.fromJson,
        defaultValue: const EmbedMacroConfig(),
      ),
    );
  }

  final EmbedMacroConfig config;

  @override
  String get suffixName => '';

  @override
  GeneratedType get generatedType => GeneratedType.clazz;

  static const _metadataFileName = '.embed_generated.json';
  static const _maxFileSizeWarning = 5 * 1024 * 1024; // 5 MB

  @override
  Future<void> onAsset(MacroState state, MacroAssetDeclaration asset) async {
    final assetState = state.assetState;
    if (assetState == null) return;

    final relativeBasePath = assetState.relativeBasePath;
    final absoluteBasePath = assetState.absoluteBasePath;
    final absoluteBaseOutputPath = assetState.absoluteBaseOutputPath;

    final entity = FileSystemEntity.typeSync(absoluteBasePath, followLinks: false);
    if (entity != FileSystemEntityType.directory) return;

    final dir = Directory(absoluteBasePath);

    // Load existing metadata from output directory
    final metadataFile = File(p.join(absoluteBaseOutputPath, _metadataFileName));
    final metadata = _EmbedMetadata.load(metadataFile);

    // Scan current files
    final currentFiles = <String, String>{};
    final filesToGenerate = <String, File>{};

    bool Function(String path)? includeFile;
    if (config.extension != null && config.extension != '*') {
      final extensions = config.extension!.split(',');
      includeFile = (String path) => extensions.contains(p.extension(path));
    }

    final recursive = config.recursive ?? true;
    final entities = (config.syncList ?? true)
        ? dir.listSync(recursive: recursive, followLinks: false)
        : await dir.list(recursive: recursive, followLinks: false).toList();

    for (final entity in entities) {
      if (entity is File) {
        if (includeFile?.call(entity.path) == false) continue;

        final relativePath = p.relative(entity.path, from: absoluteBasePath);
        final fileHash = _calculateFileHash(entity);
        final size = entity.lengthSync();

        currentFiles[relativePath] = fileHash;

        // Check if file needs generation
        final existing = metadata.files[relativePath];
        if (existing == null || existing != fileHash) {
          filesToGenerate[relativePath] = entity;

          // Warn about large files
          if (size > _maxFileSizeWarning) {
            print('⚠️  WARNING: File "$relativePath" is ${(size / 1024 / 1024).toStringAsFixed(2)} MB (>5 MB)');
          }
        }
      }
    }

    // Find deleted files
    final deletedFiles = metadata.files.keys.where((path) => !currentFiles.containsKey(path)).toSet();

    state.set('metadata', metadata);
    state.set('absoluteBasePath', absoluteBasePath);
    state.set('relativeBasePath', relativeBasePath);
    state.set('currentFiles', currentFiles);
    state.set('filesToGenerate', filesToGenerate);
    state.set('deletedFiles', deletedFiles);
  }

  @override
  Future<void> onGenerate(MacroState state) async {
    final metadata = state.getOrNull<_EmbedMetadata>('metadata');
    final absoluteBasePath = state.getOrNull<String>('absoluteBasePath') ?? '';
    final relativeBasePath = state.getOrNull<String>('relativeBasePath') ?? '';
    final currentFiles = state.getOrNull<Map<String, String>>('currentFiles') ?? {};
    final filesToGenerate = state.getOrNull<Map<String, File>>('filesToGenerate') ?? {};
    final deletedFiles = state.getOrNull<Set<String>>('deletedFiles') ?? {};
    final outputPath = state.assetState!.absoluteBaseOutputPath;

    await _generatePerFile(
      state,
      outputPath,
      absoluteBasePath,
      relativeBasePath,
      filesToGenerate,
      deletedFiles,
    );

    // Generate registry
    await _generateRegistry(state, outputPath, currentFiles, relativeBasePath);

    // Save updated metadata
    metadata?.saveMetadata(currentFiles);
  }

  Future<void> _generatePerFile(
    MacroState state,
    String outputPath,
    String absoluteBasePath,
    String relativeBasePath,
    Map<String, File> filesToGenerate,
    Set<String> deletedFiles,
  ) async {
    final generatedFiles = <String>[];

    // Generate files that changed
    for (final entry in filesToGenerate.entries) {
      final relativePath = entry.key;
      final file = entry.value;

      final propertyName = _sanitizePropertyName(p.basenameWithoutExtension(relativePath));
      final virtualPath = '/${p.posix.join(relativeBasePath, relativePath)}';
      final bytes = file.readAsBytesSync();

      final content = _generateEmbedFileContent(propertyName, virtualPath, bytes);

      final outputFilePath = p.join(
        outputPath,
        p.dirname(relativePath),
        '${p.basenameWithoutExtension(relativePath)}.dart',
      );

      final outputFile = File(outputFilePath);
      outputFile.createSync(recursive: true);
      outputFile.writeAsStringSync(content);

      generatedFiles.add(outputFilePath);
    }

    // Delete files that no longer exist
    for (final relativePath in deletedFiles) {
      final outputFilePath = p.join(
        outputPath,
        p.dirname(relativePath),
        '${p.basenameWithoutExtension(relativePath)}.dart',
      );

      final outputFile = File(outputFilePath);
      if (outputFile.existsSync()) {
        outputFile.deleteSync();
      }
    }

    state.reportGeneratedFile(generatedFiles);
  }

  Future<void> _generateRegistry(
    MacroState state,
    String outputPath,
    Map<String, String> currentFiles,
    String relativeBasePath,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln('''// coverage:ignore-file
// GENERATED BY Macro: DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_internal_member, unused_element, unused_local_variable, unnecessary_overrides, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark
// dart format off
''');

    // Generate imports
    buffer.writeln("import 'dart:typed_data';\n");
    buffer.writeln("import 'package:macro_kit/macro_kit.dart';\n");

    // Create unique aliases that include the full path
    for (final relativePath in currentFiles.keys) {
      final importPath = p.posix.join(
        p.dirname(relativePath),
        '${p.basenameWithoutExtension(relativePath)}.dart',
      );
      // Create unique alias using full path with directory structure
      final importAlias = _createUniqueImportAlias(relativePath);
      buffer.writeln('import \'$importPath\' as $importAlias;');
    }

    final generatedClassName = config.generatedClassName ?? 'EmbedFS';

    buffer.writeln();
    buffer.writeln('''
final class $generatedClassName {
  $generatedClassName._();
  
  static final _EmbedRegistryImpl _registry = _EmbedRegistryImpl._();
  
  static EmbedFile file(String path) => EmbedFile(path)..\$registry = _registry;
  
  static EmbedDirectory directory(String path) => EmbedDirectory(path)..\$registry = _registry;
  
  static EmbedDirectory get current => directory('/');
}    
    
final class _EmbedRegistryImpl implements EmbedRegistry {   
  _EmbedRegistryImpl._();
   
  final cache = <String, Uint8List>{};

  void clearCache() => cache.clear();

  List<String> get allPaths => _files.keys.toList();

  bool exists(String path) => _files.containsKey(path);

  Uint8List? readBytes(String path) => _files[path]?.call();
''');

    buffer.writeln('  final Map<String, Uint8List Function()> _files = {');
    for (final relativePath in currentFiles.keys) {
      final propertyName = _sanitizePropertyName(p.basenameWithoutExtension(relativePath));
      final virtualPath = '/${p.posix.join(relativeBasePath, relativePath)}';
      final importAlias = _createUniqueImportAlias(relativePath);

      buffer.writeln('    \'$virtualPath\': () => $importAlias.${propertyName}Data,');
    }

    buffer.writeln('  };');
    buffer.writeln();
    buffer.writeln('}');

    final outputFilePath = p.join(outputPath, 'embed.dart');
    final outputFile = File(outputFilePath);
    outputFile.createSync(recursive: true);
    outputFile.writeAsStringSync(buffer.toString());

    state.reportGeneratedFile([outputFilePath]);
  }

  /// Creates a unique import alias by incorporating the full path
  String _createUniqueImportAlias(String relativePath) {
    return 'i${generateHash(relativePath)}';
  }

  String _generateEmbedFileContent(String propertyName, String virtualPath, List<int> bytes) {
    final buffer = StringBuffer();

    buffer.writeln('''// coverage:ignore-file
// GENERATED BY Macro: DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unused_local_variable, unnecessary_overrides, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark
// dart format off
''');

    buffer.writeln("import 'dart:typed_data';");
    buffer.writeln("import 'dart:convert';");
    buffer.writeln();
    buffer.writeln('/// $virtualPath');
    final encoded = base64Encode(bytes);
    buffer.write("Uint8List get ${propertyName}Data => base64Decode('$encoded');");
    return buffer.toString();

    // for (var i = 0; i < bytes.length; i++) {
    //   if (i > 0) buffer.write(',');
    //   if (i % 16 == 0) buffer.write('\n  ');
    //   // buffer.write('0x${bytes[i].toRadixString(16).padLeft(2, '0')}');
    //   buffer.write(bytes[i]); // using hex make file size bigger by 8kb
    // }
  }

  String _calculateFileHash(File file) {
    final stat = file.statSync();
    return generateHash('${file.path}_${stat.modified.millisecondsSinceEpoch}_${stat.size}').toString();
  }

  static final RegExp _invalidCharsPattern = RegExp(r'[^a-zA-Z0-9_$]');
  static final RegExp _leadingUnderscoresPattern = RegExp(r'^_+');
  static final RegExp _startsWithNumberPattern = RegExp(r'^[0-9]');

  String _sanitizePropertyName(String name) {
    var sanitized = name.replaceAll(_invalidCharsPattern, '_');
    sanitized = sanitized.replaceAll(_leadingUnderscoresPattern, '');

    if (sanitized.isEmpty || _startsWithNumberPattern.hasMatch(sanitized)) {
      sanitized = 'asset$sanitized';
    }

    if (AssetPathMacro.reservedWords.contains(sanitized)) {
      sanitized = '${sanitized}Asset';
    }

    return sanitized;
  }
}
