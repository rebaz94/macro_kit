part of 'embed_macro.dart';

class _EmbedMetadata {
  const _EmbedMetadata({
    required this.file,
    required this.rawData,
    required this.files,
  });

  static _EmbedMetadata load(File metadataFile) {
    if (!metadataFile.existsSync()) {
      return _EmbedMetadata(
        file: metadataFile,
        rawData: {'version': '1.0'},
        files: {},
      );
    }

    try {
      final content = metadataFile.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return _EmbedMetadata.fromJson(json, metadataFile);
    } catch (e) {
      return _EmbedMetadata(
        file: metadataFile,
        rawData: {'version': '1.0'},
        files: {},
      );
    }
  }

  static _EmbedMetadata fromJson(Map<String, dynamic> json, File file) {
    final files = json['files'];
    return _EmbedMetadata(
      file: file,
      rawData: json,
      files: files is Map ? files.map((k, v) => MapEntry(k as String, v as String)) : {},
    );
  }

  final File file;
  final Map<String, dynamic> rawData;
  final Map<String, String> files;

  void saveMetadata(Map<String, String> files) {
    final json = {
      'version': '1.0',
      'files': files,
    };

    file.writeAsStringSync(jsonEncode(json));
  }
}
