import 'dart:convert';
import 'dart:io';

import 'package:macro_kit/src/common/common.dart';

Future<(bool, String?)> upgradedMacroServer(String toVersion) async {
  try {
    final path = getSystemVariableWithDartIncluded();
    final args = [dartBinary, 'pub', 'global', 'activate', 'macro_kit', toVersion];
    final process = await Process.start(
      args.first,
      args.sublist(1),
      environment: {
        ...Platform.environment,
        'PATH': path,
      },
      runInShell: Platform.isWindows,
    );
    final output = await process.stdout.transform(utf8.decoder).toList();

    if (output.contains('Activated macro_kit $toVersion.')) {
      return (true, null);
    }

    // wait until macro server initialize itself
    await Future.delayed(const Duration(seconds: 3));
    return (true, null);
  } catch (e) {
    return (false, e.toString());
  }
}
