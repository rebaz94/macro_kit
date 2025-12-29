import 'dart:async' as async;
import 'dart:io';
import 'dart:math' as m;

import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:macro_kit/src/analyzer/channel.dart';
import 'package:macro_kit/src/analyzer/utils/spawner.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:web_socket_channel/web_socket_channel.dart' show WebSocketChannel;

final m.Random random = m.Random();

int newId() => random.nextInt(100000);

@internal
class ContextInfo {
  ContextInfo({
    required this.path,
    required this.packageId,
    required this.packageName,
    required this.isDynamic,
    required this.config,
    required this.sourceContext,
  });

  final String path;
  final String packageId;
  final String packageName;
  final bool isDynamic;
  final MacroClientConfiguration config;
  final MacroContextSourceCodeInfo sourceContext;

  /// Whether this context has executed auto-rebuild on connection
  bool autoRebuildExecuted = false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContextInfo &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          packageId == other.packageId &&
          packageName == other.packageName;

  @override
  int get hashCode => path.hashCode ^ packageId.hashCode ^ packageName.hashCode;

  @override
  String toString() {
    return 'ContextInfo{path: $path, packageId: $packageId, packageName: $packageName, isDynamic: $isDynamic, config: $config, sourceContext: $sourceContext, autoRebuildExecuted: $autoRebuildExecuted}';
  }
}

@internal
class PluginChannelInfo {
  PluginChannelInfo({
    required this.channel,
    required this.contextPaths,
  });

  final WebSocketChannel? channel;

  /// List of context paths managed by this plugin
  /// These are raw paths that need to be resolved to ContextInfo
  final List<String> contextPaths;

  PluginChannelInfo copyWith({
    WebSocketChannel? channel,
    List<String>? contextPaths,
  }) {
    return PluginChannelInfo(
      channel: channel ?? this.channel,
      contextPaths: contextPaths ?? this.contextPaths,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginChannelInfo &&
          runtimeType == other.runtimeType &&
          channel == other.channel &&
          const DeepCollectionEquality().equals(contextPaths, other.contextPaths);

  @override
  int get hashCode => channel.hashCode ^ const DeepCollectionEquality().hash(contextPaths);

  @override
  String toString() {
    return 'PluginChannelInfo{channel: $channel, contextPaths: $contextPaths}';
  }
}

@internal
class ClientChannelInfo {
  ClientChannelInfo({
    required this.id,
    required this.channel,
    required this.packages,
    required this.macros,
    required this.assetMacros,
    required this.timeout,
    required this.autoRunMacro,
    required this.managedByMacroServer,
    required this.sub,
  });

  final int id;
  final WsChannel channel;
  final List<({String name, String id})> packages;
  final List<String> macros;
  final Map<String, List<AssetMacroInfo>> assetMacros;
  final Duration timeout;
  final bool autoRunMacro;
  final bool managedByMacroServer;
  final async.StreamSubscription? sub;

  bool containsPackageOf(String pkgName, String pkgId) {
    for (final pkg in packages) {
      if (pkg.name == pkgName && pkg.id == pkgId) {
        return true;
      }
    }

    return false;
  }

  bool containsPackagePathOf(String pkgPath) {
    for (final pkg in packages) {
      if (pkg.name == pkgPath) {
        return true;
      }
    }

    return false;
  }
}

extension type CountedCache._((int, Object) _v) {
  factory CountedCache(Object value, {int count = 1}) {
    return CountedCache._((count, value));
  }

  int get count => _v.$1;

  Object get value => _v.$2;

  CountedCache increaseCount() {
    return CountedCache(_v.$2, count: _v.$1 + 1);
  }
}

@internal
class AnalyzeResult {
  List<MacroClassDeclaration> classes = [];
  List<MacroFunctionDeclaration> topLevelFunctions = [];
}

@internal
class MacroClientConfiguration {
  MacroClientConfiguration({
    required this.id,
    required this.packageName,
    required this.context,
    required this.remapGeneratedFileTo,
    required this.autoRebuildOnConnect,
    required this.alwaysRebuildOnConnect,
    required this.skipConnectRebuildWithAutoRun,
    required this.userMacrosConfig,
  });

  factory MacroClientConfiguration.withDefault(int id, String context, String packageName) {
    return MacroClientConfiguration(
      id: id,
      context: context,
      packageName: packageName,
      remapGeneratedFileTo: '',
      autoRebuildOnConnect: false,
      alwaysRebuildOnConnect: false,
      skipConnectRebuildWithAutoRun: true,
      userMacrosConfig: const {},
    );
  }

  static MacroClientConfiguration fromJson(int id, String context, String packageName, Map<String, dynamic> json) {
    @pragma('vm:prefer-inline')
    T? parseField<T>(Object? value) {
      if (value is T) return value;
      return null;
    }

    final config = parseField<Map<String, dynamic>>(json['config']) ?? <String, dynamic>{};
    final rewrite = parseField<String>(config['remap_generated_file_to']) ?? '';

    return MacroClientConfiguration(
      id: id,
      context: context,
      packageName: packageName,
      remapGeneratedFileTo: switch (rewrite) {
        _ when rewrite.startsWith('./') => rewrite.substring(2),
        _ when rewrite.startsWith('.') => rewrite.substring(1),
        _ when rewrite.startsWith('/') => rewrite.substring(1),
        _ => rewrite,
      },
      autoRebuildOnConnect: parseField(config['auto_rebuild_on_connect']) ?? false,
      alwaysRebuildOnConnect: parseField(config['always_rebuild_on_connect']) ?? false,
      skipConnectRebuildWithAutoRun: parseField(config['skip_connect_rebuild_with_auto_run_macro']) ?? true,
      userMacrosConfig: parseField(json['macros']) ?? const {},
    );
  }

  static MacroClientConfiguration defaultConfig = MacroClientConfiguration(
    id: 0,
    packageName: '',
    context: '',
    remapGeneratedFileTo: '',
    autoRebuildOnConnect: false,
    alwaysRebuildOnConnect: false,
    skipConnectRebuildWithAutoRun: true,
    userMacrosConfig: const {},
  );

  /// A unique id for the configuration
  final int id;

  /// The associated project context
  final String context;

  /// The name of the package from pubspec.yaml
  final String packageName;

  /// Remap the generated file location to a custom directory
  ///
  /// Transforms the default generated file path to the specified directory.
  /// The path should be relative to the project root.
  ///
  /// Example: `lib/gen` will place all generated files in the lib/gen directory
  /// instead of their default locations.
  final String remapGeneratedFileTo;

  /// Automatically rebuild generated files when the plugin connects
  ///
  /// When enabled, forces a complete regeneration of all macro-generated
  /// files whenever the macro plugin establishes a connection.
  ///
  /// Defaults to `false`.
  final bool autoRebuildOnConnect;

  /// Whether to ignore cache for current plugin session and always re-run generation
  /// when new client connect to macro server
  final bool alwaysRebuildOnConnect;

  /// Skip connect-triggered rebuilds when external auto-run process is active
  ///
  /// When enabled, disables [autoRebuildOnConnect] and [alwaysRebuildOnConnect]
  /// if macro generation is being handled by a separate auto-run process.
  /// This prevents the Flutter app from triggering redundant generation
  /// when connecting to a server that's already running automatic generation.
  ///
  /// Set to `true` when `autoRunMacro` from your macro_context.dart is true.
  ///
  /// Defaults to `true` (skip connect-triggered rebuilds when auto-run is active).
  final bool skipConnectRebuildWithAutoRun;

  /// The user macros configuration keyed by macro name
  final Map<String, dynamic> userMacrosConfig;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacroClientConfiguration &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          context == other.context &&
          packageName == other.packageName &&
          remapGeneratedFileTo == other.remapGeneratedFileTo &&
          autoRebuildOnConnect == other.autoRebuildOnConnect &&
          alwaysRebuildOnConnect == other.alwaysRebuildOnConnect &&
          skipConnectRebuildWithAutoRun == other.skipConnectRebuildWithAutoRun &&
          userMacrosConfig == other.userMacrosConfig;

  @override
  int get hashCode =>
      id.hashCode ^
      context.hashCode ^
      packageName.hashCode ^
      remapGeneratedFileTo.hashCode ^
      autoRebuildOnConnect.hashCode ^
      alwaysRebuildOnConnect.hashCode ^
      skipConnectRebuildWithAutoRun.hashCode ^
      userMacrosConfig.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (remapGeneratedFileTo.isNotEmpty) 'remap_generated_file_to': remapGeneratedFileTo,
      if (autoRebuildOnConnect) 'auto_rebuild_on_connect': autoRebuildOnConnect,
      if (alwaysRebuildOnConnect) 'always_rebuild_on_connect': alwaysRebuildOnConnect,
      if (skipConnectRebuildWithAutoRun) 'skip_connect_rebuild_with_auto_run_macro': skipConnectRebuildWithAutoRun,
      'macros': userMacrosConfig,
    };
  }

  @override
  String toString() {
    return 'MacroClientConfiguration{id: $id, context: $context, packageName: $packageName, remapGeneratedFileTo: $remapGeneratedFileTo, autoRebuildOnConnect: $autoRebuildOnConnect, alwaysRebuildOnConnect: $alwaysRebuildOnConnect, skipConnectRebuildWithAutoRun: $skipConnectRebuildWithAutoRun, userMacrosConfig: $userMacrosConfig}';
  }
}

class MacroContextSourceCodeInfo {
  const MacroContextSourceCodeInfo({
    required this.hashId,
    this.fromTest = false,
    required this.autoRun,
    required this.runCommand,
  });

  static MacroContextSourceCodeInfo testContext() => const MacroContextSourceCodeInfo(
    hashId: -1,
    fromTest: true,
    autoRun: false,
    runCommand: [],
  );

  static Future<SpawnResult<MacroContextSourceCodeInfo>> fromSource(int hashId, String source) async {
    final (generatedCode, err) = _generateIsolateCode(source);
    if (err != null) {
      return SpawnError(err, StackTrace.empty);
    }

    final genFile = File(p.join(Directory.systemTemp.path, 'macro', 'macro_context_${newId()}.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(generatedCode);

    return Spawner.evaluateCode(
      codeUri: genFile.uri,
      onData: (data) {
        if (data is! Map) {
          throw 'Expected to get execution result but got: ${data.runtimeType}';
        }

        return MacroContextSourceCodeInfo(
          hashId: hashId,
          autoRun: data['autoRunMacro'] as bool,
          runCommand: (data['autoRunMacroCommand'] as List).map((e) => e as String).toList(),
        );
      },
    );
  }

  static (String, String?) _generateIsolateCode(String source) {
    source = _removeComments(source);

    String autoRunGetter = '';
    String commandGetter = '';
    try {
      autoRunGetter = _extractGetter(source, 'autoRunMacro') ?? 'bool get autoRunMacro => true;';
      commandGetter =
          _extractGetter(source, 'autoRunMacroCommand') ??
          'List<String> get autoRunMacroCommand => macroDartRunnerCommand;';
    } on StateError catch (e) {
      return ('', e.toString());
    }

    return (
      '''
import 'package:macro_kit/macro_kit.dart';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:math';

$autoRunGetter
  
$commandGetter

void main(List<String> _, SendPort port) async {
  port.send({
    'autoRunMacro': autoRunMacro,
    'autoRunMacroCommand': autoRunMacroCommand,
  });
}
''',
      null,
    );
  }

  static String? _extractGetter(String source, String getterName) {
    final getPattern = RegExp(
      r'\bget\s+' + RegExp.escape(getterName) + r'\b',
    );

    final match = getPattern.firstMatch(source);
    if (match == null) {
      return null;
    }

    // Walk backwards to line start (this preserves the return type)
    int start = match.start;
    while (start > 0 && source[start - 1] != '\n') {
      start--;
    }

    final arrowIndex = source.indexOf('=>', match.end);
    final braceIndex = source.indexOf('{', match.end);

    // Arrow getter
    if (arrowIndex != -1 && (braceIndex == -1 || arrowIndex < braceIndex)) {
      final end = source.indexOf(';', arrowIndex);
      if (end == -1) {
        throw StateError('Invalid arrow getter for $getterName');
      }
      return source.substring(start, end + 1);
    }

    // Block getter
    if (braceIndex == -1) {
      throw StateError('Invalid block getter for $getterName');
    }

    int braceCount = 0;
    for (int i = braceIndex; i < source.length; i++) {
      if (source[i] == '{') braceCount++;
      if (source[i] == '}') {
        braceCount--;
        if (braceCount == 0) {
          return source.substring(start, i + 1);
        }
      }
    }

    throw StateError('Unterminated getter body for $getterName');
  }

  static String _removeComments(String source) {
    final lines = source.split('\n');
    final buffer = StringBuffer();

    bool inBlockComment = false;

    for (final line in lines) {
      final trimmed = line.trimLeft();

      if (inBlockComment) {
        if (trimmed.contains('*/')) {
          inBlockComment = false;
        }
        continue;
      }

      if (trimmed.startsWith('/*')) {
        if (!trimmed.contains('*/')) {
          inBlockComment = true;
        }
        continue;
      }

      if (trimmed.startsWith('//')) {
        continue;
      }

      buffer.writeln(line);
    }

    return buffer.toString();
  }

  final int hashId;
  final bool fromTest;
  final bool autoRun;
  final List<String> runCommand;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacroContextSourceCodeInfo && runtimeType == other.runtimeType && hashId == other.hashId;

  @override
  int get hashCode => hashId.hashCode;

  @override
  String toString() {
    return 'MacroContextSourceCodeInfo{hashId: $hashId, fromTest: $fromTest, autoRun: $autoRun, runCommand: $runCommand}';
  }
}

R runZoneGuarded<R>({required R Function() fn, required Map<Object?, Object?> values}) {
  try {
    final res = async.runZonedGuarded(
      fn,
      (e, stack) => throw (e, stack),
      zoneValues: values,
    );
    return res as R;
  } catch (_) {
    rethrow;
  }
}

@pragma('vm:prefer-inline')
Map<String, MacroClassDeclaration>? getZoneSharedClassDeclaration() {
  return async.Zone.current[#sharedClasses] as Map<String, MacroClassDeclaration>?;
}

@pragma('vm:prefer-inline')
void addPendingUpdate(void Function() fn) {
  (async.Zone.current[#pendingUpdates] as List<void Function()>?)?.add(fn);
}

@pragma('vm:prefer-inline')
Map<Element, String>? getZoneAnalysisImports() {
  return async.Zone.current[#imports] as Map<Element, String>?;
}
