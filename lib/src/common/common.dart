import 'dart:io';

import 'package:path/path.dart' as p;

const macroPluginRequestFileName = 'macro_plugin_request';
const macroClientRequestFileName = 'macro_client_request';

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

/// The dart binary from the current sdk.
final dartBinary = p.join(sdkBin, 'dart');

/// The path to the sdk bin directory on the current platform.
final sdkBin = p.join(sdkPath, 'bin');

/// The path to the sdk on the current platform.
final sdkPath = p.dirname(p.dirname(Platform.resolvedExecutable));

enum ConnectionStatus { connecting, connected, disconnected }
