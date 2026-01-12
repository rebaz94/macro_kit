part of 'embed_macro.dart';

/// Configuration for the Embed macro.
class EmbedMacroConfig {
  const EmbedMacroConfig({
    this.generatedClassName,
    this.syncList,
    this.recursive,
    this.extension,
  });

  static EmbedMacroConfig fromJson(Map<String, dynamic> json) {
    return EmbedMacroConfig(
      generatedClassName: json['generatedClassName'] as String?,
      syncList: json['syncList'] as bool?,
      recursive: json['recursive'] as bool?,
      extension: json['extension'] as String?,
    );
  }

  /// The name of the generated EmbedFs.
  ///
  /// Default to `EmbedFs`
  final String? generatedClassName;

  /// Whether to use sync list API to fetch all files in the directory.
  ///
  /// Default is `true`
  final bool? syncList;

  /// Whether to recursively fetch all files inside the directory.
  ///
  /// Default is `true`
  final bool? recursive;

  /// File extensions to be included in the embedding.
  ///
  /// Only files with these extensions will be embedded.
  ///
  /// Supports:
  ///   - `'*'` for any file types
  ///   - Specific extensions ex. `'.png,.json'`
  ///
  /// Examples: `'.json,.yaml'`, `'*'`, `'.png,.jpg,.svg'`
  ///
  /// Default to `*`
  final String? extension;

  Map<String, dynamic> toJson() {
    return {
      if (generatedClassName?.isNotEmpty == true) 'generatedClassName': generatedClassName,
      if (syncList != null) 'syncList': syncList,
      if (recursive != null) 'recursive': recursive,
      if (extension?.isNotEmpty == true) 'extension': extension,
    };
  }

  @override
  String toString() {
    return 'EmbedMacroConfig{generatedClassName: $generatedClassName, syncList: $syncList, recursive: $recursive, extension: $extension}';
  }
}
