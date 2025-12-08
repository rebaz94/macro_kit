import 'dart:io';

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
  }

  final envKey = Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
  final envValue = Platform.environment[envKey];
  return envValue ?? '~';
}

String get macroDirectory {
  return '$homeDir/.dartServer/.plugin_manager/macro';
}

enum ConnectionStatus { connecting, connected, disconnected }
