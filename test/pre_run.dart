import 'dart:io';

import 'package:macro_kit/macro.dart';
import 'package:macro_kit/src/analyzer/regenerate.dart';
import 'package:path/path.dart' as p;

void main() async {
  final clientId = await runMacro(
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

  // wait macro manager initialize
  await Future.delayed(const Duration(seconds: 2));

  final testDir = p.join(Directory.current.path);
  final s = Stopwatch()..start();
  await forceRegenerateFor(
    clientId: clientId!,
    contextPath: testDir,
    addToContext: true,
    removeInContext: false,
  );

  print('regenerated all files in ${s.elapsedMilliseconds} ms');
}
