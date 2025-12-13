import 'dart:io';

import 'package:yaml/yaml.dart';

void main() async {
  print('🔄 Updating Analyzer Plugin Pubspec\n');

  try {
    // Read main pubspec.yaml
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw Exception('pubspec.yaml not found in current directory');
    }

    final pubspecContent = pubspecFile.readAsStringSync();
    final pubspec = loadYaml(pubspecContent);

    final versionName = pubspec['version'] as String?;
    final packageName = pubspec['name'] as String;

    if (versionName == null) {
      throw Exception('version not found in pubspec.yaml');
    }

    print('📦 Package: $packageName');
    print('📦 Version: $versionName\n');

    // Update tools/analyzer_plugin/pubspec.yaml
    print('📝 Updating tools/analyzer_plugin/pubspec.yaml...');
    final pluginPubspecFile = File('tools/analyzer_plugin/pubspec.yaml');
    if (!pluginPubspecFile.existsSync()) {
      throw Exception('tools/analyzer_plugin/pubspec.yaml not found');
    }

    final newVersion =
        '''name: macro_analyzer_plugin

environment:
  sdk: ">=3.9.0 <4.0.0"

dependencies:
  macro_kit: ^$versionName
#  macro_kit:
#    path: /Volumes/Projects/Server/swiftybase/macro

dev_dependencies:
  lints: ^6.0.0
''';

    pluginPubspecFile.writeAsStringSync(newVersion);
    print('✅ Analyzer plugin pubspec updated to use $packageName: ^$versionName');
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}
