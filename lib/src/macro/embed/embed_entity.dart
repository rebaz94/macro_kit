import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:macro_kit/macro_kit.dart';
import 'package:meta/meta.dart';

/// Base interface for embedded file system entities (files and directories).
///
/// This abstract class defines the common contract for both [EmbedFile] and
/// [EmbedDirectory], requiring implementers to provide a [path] property.
abstract class EmbedFileEntity {
  /// The absolute path of this file system entity.
  String get path;
}

/// Represents an embedded file with methods to read its contents.
///
/// Provides a synchronous and asynchronous API similar to dart:io's [File] class,
/// but operates on files that have been embedded directly into the Dart code as
/// byte arrays at compile time.
///
/// ## Example
///
/// ```dart
/// final file = EmbedFile('/config/settings.json');
/// final content = file.readAsStringSync();
/// print(content);
///
/// // Clean up cached data when done
/// file.dispose();
/// ```
class EmbedFile implements EmbedFileEntity {
  /// Creates an [EmbedFile] with the given [path].
  ///
  /// The [path] should match a file that was embedded during the macro generation phase.
  EmbedFile(this.path);

  @override
  final String path;

  @internal
  late final EmbedRegistry $registry;

  /// Synchronously checks if this file exists in the embedded file system.
  ///
  /// Returns `true` if the file was embedded, `false` otherwise.
  bool existsSync() => $registry.exists(path);

  /// Asynchronously checks if this file exists in the embedded file system.
  ///
  /// Returns a [Future] that completes with `true` if the file was embedded,
  /// `false` otherwise.
  Future<bool> exists() async => existsSync();

  /// Synchronously reads the file contents as bytes.
  ///
  /// The result is cached in memory after the first read. Subsequent calls
  /// return the cached data without re-reading.
  ///
  /// Throws an [Exception] if the file is not found in the embedded file system.
  ///
  /// Returns the file contents as a [Uint8List].
  Uint8List readAsBytesSync() {
    final cached = $registry.cache[path];
    if (cached != null) {
      return cached;
    }

    final data = $registry.readBytes(path);
    if (data != null) {
      $registry.cache[path] = data;
      return data;
    }

    throw Exception('File not found: $path');
  }

  /// Asynchronously reads the file contents as bytes.
  ///
  /// Returns a [Future] that completes with the file contents as a [Uint8List].
  ///
  /// See [readAsBytesSync] for more details.
  Future<Uint8List> readAsBytes() async => readAsBytesSync();

  /// Synchronously reads the file contents as a string.
  ///
  /// The [encoding] parameter specifies how to decode the bytes. Defaults to [utf8].
  ///
  /// Returns the decoded file contents as a [String].
  String readAsStringSync({Encoding encoding = utf8}) {
    return encoding.decode(readAsBytesSync());
  }

  /// Asynchronously reads the file contents as a string.
  ///
  /// The [encoding] parameter specifies how to decode the bytes. Defaults to [utf8].
  ///
  /// Returns a [Future] that completes with the decoded file contents as a [String].
  Future<String> readAsString({Encoding encoding = utf8}) async {
    return readAsStringSync(encoding: encoding);
  }

  /// Synchronously gets the length of the file in bytes.
  ///
  /// Returns the number of bytes in the file.
  int lengthSync() => readAsBytesSync().length;

  /// Asynchronously gets the length of the file in bytes.
  ///
  /// Returns a [Future] that completes with the number of bytes in the file.
  Future<int> length() async => lengthSync();

  /// Removes this file's cached data from memory.
  ///
  /// Call this method when you're done with the file to free up memory.
  /// Subsequent reads will reload the data from the embedded bytes.
  void dispose() {
    $registry.cache.remove(path);
  }

  /// Returns the parent directory of this file.
  EmbedDirectory get parent => EmbedDirectory(parentPathOf(path))..$registry = $registry;

  /// Returns a [Uri] representing this file's path.
  Uri get uri => Uri.file(path);

  /// Returns `true` if this file's path is absolute (starts with '/').
  bool get isAbsolute => path.startsWith('/');

  /// Synchronously reads the file contents as lines of text.
  ///
  /// The file is decoded using the specified [encoding] (defaults to [utf8])
  /// and split on newline characters.
  ///
  /// Returns a [List] of strings, one for each line in the file.
  List<String> readAsLinesSync({Encoding encoding = utf8}) {
    return readAsStringSync(encoding: encoding).split('\\n');
  }

  /// Asynchronously reads the file contents as lines of text.
  ///
  /// The file is decoded using the specified [encoding] (defaults to [utf8])
  /// and split on newline characters.
  ///
  /// Returns a [Future] that completes with a [List] of strings, one for each line.
  Future<List<String>> readAsLines({Encoding encoding = utf8}) async {
    return readAsLinesSync(encoding: encoding);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmbedFile && runtimeType == other.runtimeType && path == other.path && $registry == other.$registry;

  @override
  int get hashCode => path.hashCode ^ $registry.hashCode;

  @override
  String toString() {
    return 'EmbedFile{path: $path}';
  }
}

/// Represents an embedded directory that can list its contents.
///
/// Provides methods to list files and subdirectories similar to dart:io's
/// [Directory] class, but operates on the embedded file system.
///
/// ## Example
///
/// ```dart
/// final dir = EmbedDirectory('/assets');
///
/// // List immediate children
/// final children = dir.listSync();
///
/// // List all files recursively
/// final allFiles = dir.listSync(recursive: true);
/// ```
class EmbedDirectory implements EmbedFileEntity {
  /// Creates an [EmbedDirectory] with the given [path].
  EmbedDirectory(this.path);

  @override
  final String path;

  @internal
  late final EmbedRegistry $registry;

  /// Synchronously checks if this directory exists in the embedded file system.
  ///
  /// A directory is considered to exist if any embedded file path starts with
  /// this directory's path.
  ///
  /// Returns `true` if the directory exists, `false` otherwise.
  bool existsSync() {
    final normalized = path == '/' ? '/' : (path.endsWith('/') ? path : '$path/');
    return $registry.allPaths.any((p) => p.startsWith(normalized));
  }

  /// Asynchronously checks if this directory exists in the embedded file system.
  ///
  /// Returns a [Future] that completes with `true` if the directory exists,
  /// `false` otherwise.
  Future<bool> exists() async => existsSync();

  /// Synchronously lists the contents of this directory.
  ///
  /// Parameters:
  /// - [recursive]: If `true`, lists all descendants. If `false` (default),
  ///   only lists immediate children.
  /// - [followLinks]: Included for API compatibility but has no effect as
  ///   the embedded file system doesn't support symbolic links.
  ///
  /// Returns a [List] of [EmbedFileEntity] objects ([EmbedFile] or [EmbedDirectory]).
  ///
  /// ## Example
  ///
  /// ```dart
  /// final dir = EmbedDirectory('/assets');
  ///
  /// // List only immediate children
  /// for (final entity in dir.listSync()) {
  ///   print(entity.path);
  /// }
  ///
  /// // List all files recursively
  /// for (final entity in dir.listSync(recursive: true)) {
  ///   if (entity is EmbedFile) {
  ///     print('File: ${entity.path}');
  ///   }
  /// }
  /// ```
  List<EmbedFileEntity> listSync({bool recursive = false, bool followLinks = true}) {
    final entities = <EmbedFileEntity>[];
    final normalized = path == '/' ? '' : (path.endsWith('/') ? path : '$path/');
    final seenDirs = <String>{};

    for (final filePath in $registry.allPaths) {
      if (!filePath.startsWith(normalized)) continue;

      final relative = filePath.substring(normalized.length);
      if (relative.isEmpty) continue;

      final parts = relative.split('/');

      if (!recursive) {
        // Direct file
        if (parts.length == 1) {
          entities.add(EmbedFile(filePath)..$registry = $registry);
        } else {
          // Direct child directory
          final dirPath = '$normalized${parts.first}';
          if (seenDirs.add(dirPath)) {
            entities.add(EmbedDirectory(dirPath)..$registry = $registry);
          }
        }
      } else {
        // Recursive: emit all dirs + files
        String current = normalized;
        for (int i = 0; i < parts.length - 1; i++) {
          current += parts[i];
          if (seenDirs.add(current)) {
            entities.add(EmbedDirectory(current)..$registry = $registry);
          }
          current += '/';
        }

        entities.add(EmbedFile(filePath)..$registry = $registry);
      }
    }

    return entities;
  }

  /// Lists the contents of this directory as a stream.
  ///
  /// Parameters are the same as [listSync]. This is currently implemented
  /// by converting the synchronous list result into a stream.
  ///
  /// Returns a [Stream] of [EmbedFileEntity] objects.
  Stream<EmbedFileEntity> list({bool recursive = false, bool followLinks = true}) {
    return Stream.fromIterable(listSync(recursive: recursive, followLinks: followLinks));
  }

  /// Returns the parent directory of this directory.
  EmbedDirectory get parent => EmbedDirectory(parentPathOf(path))..$registry = $registry;

  /// Returns this directory itself (already absolute).
  EmbedDirectory get absolute => this;

  /// Returns a [Uri] representing this directory's path.
  Uri get uri => Uri.directory(path);

  /// Returns `true` if this directory's path is absolute (starts with '/').
  bool get isAbsolute => path.startsWith('/');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmbedDirectory && runtimeType == other.runtimeType && path == other.path && $registry == other.$registry;

  @override
  int get hashCode => path.hashCode ^ $registry.hashCode;

  @override
  String toString() {
    return 'EmbedDirectory{path: $path}';
  }
}

/// Abstract registry that manages embedded file data and caching.
///
/// This class is implemented by the macro-generated code to provide access
/// to the embedded file system. Users should not typically interact with
/// this class directly, but instead use [EmbedFile] and [EmbedDirectory].
abstract class EmbedRegistry {
  /// In-memory cache of file contents to avoid repeated byte array lookups.
  ///
  /// Maps file paths to their byte data. Populated automatically when files
  /// are read, and can be managed via [clearCache] or individual file's [dispose].
  final cache = <String, Uint8List>{};

  /// Clears all cached file data from memory.
  ///
  /// Call this to free up memory when you're done working with embedded files.
  void clearCache() => cache.clear();

  /// Returns a list of all file paths in the embedded file system.
  ///
  /// This is used internally to implement directory listing and existence checks.
  List<String> get allPaths;

  /// Checks if a file at the given [path] exists in the embedded file system.
  ///
  /// Returns `true` if the file was embedded, `false` otherwise.
  bool exists(String path);

  /// Reads the raw bytes of the file at the given [path].
  ///
  /// Returns the file contents as a [Uint8List], or `null` if the file doesn't exist.
  Uint8List? readBytes(String path);
}
