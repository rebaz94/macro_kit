// macro-runner: flutter
// ignore_for_file: unused_element
import 'dart:io';
import 'package:macro_kit/macro_kit.dart';

// ignore: depend_on_referenced_packages
import 'package:yaml/yaml.dart';

part 'version.g.dart';

// To change how the value is computed, update the top comment to: flutter | dart | isolate

@Macro(ComputeMacro())
final _appVersion = compute(() {
  final yaml = loadYaml(File('pubspec.yaml').readAsStringSync());
  return yaml['version'] as String;
});

// @Macro(ComputeMacro())
// final _buildTime = compute(() => DateTime.now().toIso8601String());
//
// @Macro(ComputeMacro())
// final _gitCommit = compute(() {
//   final result = Process.runSync('git', ['rev-parse', '--short', 'HEAD']);
//   return (result.stdout as String).trim();
// });
