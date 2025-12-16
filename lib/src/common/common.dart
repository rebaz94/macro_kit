import 'dart:io';

import 'package:path/path.dart' as p;

const macroPluginRequestFileName = 'macro_plugin_request';
const macroClientRequestFileName = 'macro_client_request';

enum ConnectionStatus { connecting, connected, disconnected }

/// The dart binary from the current sdk.
final dartBinary = p.join(sdkBin, 'dart');

/// The path to the sdk bin directory on the current platform.
final sdkBin = p.join(sdkPath, 'bin');

/// The path to the sdk on the current platform.
final sdkPath = p.dirname(p.dirname(Platform.resolvedExecutable));

String get homeDir {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '~';
    if (!home.contains('Library/Containers')) {
      return home;
    }

    final user = Platform.environment['USER'];
    return user != null ? '/Users/$user' : home;
  } else if (Platform.isWindows) {
    return Platform.environment['LOCALAPPDATA'] ?? Platform.environment['APPDATA'] ?? '~';
  } else {
    return Platform.environment['HOME'] ?? '~';
  }
}

String get macroDirectory {
  return p.join(homeDir, '.dartServer/.plugin_manager/macro');
}

String getSystemVariableWithDartIncluded() {
  final home = homeDir;
  var path = Platform.environment['PATH'] ?? '';
  if (Platform.isWindows) {
    final addToPath = [
      r'fvm\default\bin',
      r'fvm\default\.pub-cache\bin',
      r'fvm\default\Pub\Cache\bin',
      r'.pub-cache\bin',
      r'Pub\Cache\bin',
    ].map((e) => p.join(home, e)).join(';');
    path += ';$sdkBin;$addToPath';
  } else {
    final addToPath = [
      'fvm/default/bin',
      'fvm/default/.pub-cache/bin',
      '.pub-cache/bin',
    ].map((e) => p.join(home, e)).join(':');
    path += ':$sdkBin:$addToPath';
  }

  return path;
}

List<String> get excludedDirectory {
  if (Platform.isWindows) {
    return const [
      '.dart_tool', '.pub-cache', r'Pub\Cache', '.idea', '.vscode', r'build\intermediates', //
      r'.symlinks\plugins', 'Intermediates.noindex', r'build\macos', //
    ];
  }

  return const [
    '.dart_tool', '.pub-cache', '.idea', '.vscode', 'build/intermediates', //
    '.symlinks/plugins', 'Intermediates.noindex', 'build/macos', //
  ];
}

bool isFileOpen(String filePath) {
  try {
    // Try to open the file in write mode with exclusive access
    final file = File(filePath);
    final raf = file.openSync(mode: FileMode.append);
    raf.closeSync();
    return false; // File is not open by another program
  } catch (e) {
    // If we can't open it, it's likely open by another program
    return true;
  }
}
