import 'package:logging/logging.dart';
import 'package:macro_kit/src/analyzer/logger.dart';
import 'package:macro_kit/src/client/client_manager.dart';

// copied from flutter
const bool _kReleaseMode = bool.fromEnvironment('dart.vm.product');
const bool _kProfileMode = bool.fromEnvironment('dart.vm.profile');
const bool _kDebugMode = !_kReleaseMode && !_kProfileMode;

Future<MacroManager?> runMacro({
  required Map<String, MacroInitFunction> macros,
  Level logLevel = Level.INFO,
  void Function(Object? value)? log,
  String serverAddress = 'http://localhost:3232',
  bool autoReconnect = true,
  Duration generateTimeout = const Duration(seconds: 30),
  bool enabled = _kDebugMode,
}) async {
  if (!enabled) return null;

  final logger = MacroLogger.createLogger(name: 'MacroGenerator', into: log, level: logLevel);
  final manager = MacroManager(
    logger: logger,
    serverAddress: serverAddress,
    macros: macros,
    autoReconnect: autoReconnect,
    generateTimeout: generateTimeout,
  );

  logger.info('MacroManager initializing');
  manager.connect();
  return manager;
}
