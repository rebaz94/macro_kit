import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:macro_kit/macro_kit.dart';
import 'package:meta/meta.dart';

abstract class EmbedFileEntity {
  String get path;
}

class EmbedFile implements EmbedFileEntity {
  EmbedFile(this.path);

  @override
  final String path;

  @internal
  late final EmbedRegistry $registry;

  bool existsSync() => $registry.exists(path);

  Future<bool> exists() async => existsSync();

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

  Future<Uint8List> readAsBytes() async => readAsBytesSync();

  String readAsStringSync({Encoding encoding = utf8}) {
    return encoding.decode(readAsBytesSync());
  }

  Future<String> readAsString({Encoding encoding = utf8}) async {
    return readAsStringSync(encoding: encoding);
  }

  int lengthSync() => readAsBytesSync().length;

  Future<int> length() async => lengthSync();

  void dispose() {
    $registry.cache.remove(path);
  }

  EmbedDirectory get parent => EmbedDirectory(parentPathOf(path))..$registry = $registry;

  Uri get uri => Uri.file(path);

  bool get isAbsolute => path.startsWith('/');

  List<String> readAsLinesSync({Encoding encoding = utf8}) {
    return readAsStringSync(encoding: encoding).split('\\n');
  }

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

class EmbedDirectory implements EmbedFileEntity {
  EmbedDirectory(this.path);

  @override
  final String path;

  @internal
  late final EmbedRegistry $registry;

  bool existsSync() {
    final normalized = path == '/' ? '/' : (path.endsWith('/') ? path : '$path/');
    return $registry.allPaths.any((p) => p.startsWith(normalized));
  }

  Future<bool> exists() async => existsSync();

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

  Stream<EmbedFileEntity> list({bool recursive = false, bool followLinks = true}) {
    return Stream.fromIterable(listSync(recursive: recursive, followLinks: followLinks));
  }

  EmbedDirectory get parent => EmbedDirectory(parentPathOf(path))..$registry = $registry;

  EmbedDirectory get absolute => this;

  Uri get uri => Uri.directory(path);

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

abstract class EmbedRegistry {
  final cache = <String, Uint8List>{};

  void clearCache() => cache.clear();

  List<String> get allPaths;

  bool exists(String path);

  Uint8List? readBytes(String path);
}
