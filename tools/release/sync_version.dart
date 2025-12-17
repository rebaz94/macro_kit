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

  _updateConstantVersion(versionName, versionCode);
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
''';

    versionFile.writeAsStringSync(newVersion);
    print('✅ Constant version updated to use ^$versionName');
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}
