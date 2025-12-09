import 'dart:io';

import 'package:macro_kit/macro_kit.dart';

void main() async {
  await runMacro(
    package: PackageInfo('${Directory.current.path}/test'),
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

  await waitUntilRebuildCompleted();
}
