import 'dart:io';

import 'package:yaml/yaml.dart';

void main() async {
  // Read main pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    throw Exception('pubspec.yaml not found in current directory');
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final pubspec = loadYaml(pubspecContent);

  final packageName = pubspec['name'] as String;
  final versionName = pubspec['version'] as String;
  final versionCode = pubspec['version_code'] as int;

  print('📦 Package: $packageName');
  print('📦 Version: $versionName');
  print('📦 Code: $versionCode\n');

  _updateAnalyzerPluginVersion(packageName, versionName);
  _updateConstantVersion(versionName, versionCode);
}

void _updateAnalyzerPluginVersion(String packageName, String versionName) {
  try {
    print('🔄 Updating Analyzer Plugin Pubspec\n');

    print('📝 Updating tools/analyzer_plugin/pubspec.yaml...');
    final pluginPubspecFile = File('tools/analyzer_plugin/pubspec.yaml');
    if (!pluginPubspecFile.existsSync()) {
      throw Exception('${pluginPubspecFile.path} not found');
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

void _updateConstantVersion(String versionName, int versionCode) {
  try {
    print('🔄 Updating Constant Version\n');

    print('📝 Updating lib/src/version/version.dart...');
    final versionFile = File('lib/src/version/version.dart');
    if (!versionFile.existsSync()) {
      throw Exception('${versionFile.path} not found');
    }

    final newVersion =
        '''
const pluginVersionCode = $versionCode;
const pluginVersionName = '$versionName';
    '''
            .trim();

    versionFile.writeAsStringSync(newVersion);
    print('✅ Constant version updated to use ^$versionName');
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}
