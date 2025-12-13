import 'dart:io';

import 'package:macro_kit/macro_kit.dart';
import 'package:path/path.dart' as p;

void main() async {
  // in ci you need to:
  // 1. install macro_kit -> dart pub global activate macro_kit
  // 2. run macro server in separate process(normally this done by plugin but in ci you need initiate first) -> macro
  //    also can import the internal stuff like startMacroServer without doing separability :)
  // 3. add the absolute path(s) for the directory you want to regenerate: context added
  //    dynamically without needing analyzer plugin

  final rootProject = Directory.current.path;
  final testDir = p.join(rootProject, 'test');

  await runMacro(
    package: PackageInfo.path(testDir),
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
      'AssetPathMacro': AssetPathMacro.initialize,
    },
    assetMacros: {
      'assets': [
        AssetMacroInfo(
          macroName: 'AssetPathMacro',
          extension: '*',
          output: 'lib',
          config: const AssetPathConfig(extension: '*', rename: FieldRename.camelCase).toJson(),
        ),
      ],
    },
  );

  final s = Stopwatch()..start();
  final result = await waitUntilRebuildCompleted();
  print('full rebuild completed in: ${s.elapsed.inSeconds}s');

  for (final ctx in result.results) {
    if (!ctx.isSuccess) {
      print('context: ${ctx.context}, has error: ${ctx.error}');
    }
  }
}
