import 'package:macro_kit/src/analyzer/log_cli.dart';
import 'package:macro_kit/src/analyzer/server_routes.dart';

void main(List<String> args) async {
  if (args.isNotEmpty) {
    return await startLogHandler(args);
  }

  startMacroServer();
}
