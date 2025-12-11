import 'dart:async' as async;

import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:meta/meta.dart';
import 'package:web_socket_channel/web_socket_channel.dart' show WebSocketChannel;

@internal
class ContextInfo {
  ContextInfo({
    required this.path,
    required this.packageName,
    required this.isDynamic,
    required this.config,
  });

  final String path;
  final String packageName;
  final bool isDynamic;
  final MacroClientConfiguration config;

  /// Whether this context has executed auto-rebuild on connection
  bool autoRebuildExecuted = false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContextInfo &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          packageName == other.packageName;

  @override
  int get hashCode => path.hashCode ^ packageName.hashCode;

  @override
  String toString() {
    return 'ContextInfo{path: $path, packageName: $packageName, isDynamic: $isDynamic}';
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
    required this.package,
    required this.macros,
    required this.assetMacros,
    required this.timeout,
    required this.sub,
  });

  final int id;
  final WebSocketChannel channel;
  final PackageInfo package;
  final List<String> macros;
  final Map<String, List<AssetMacroInfo>> assetMacros;
  final Duration timeout;
  final async.StreamSubscription? sub;
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
          userMacrosConfig == other.userMacrosConfig;

  @override
  int get hashCode =>
      id.hashCode ^
      context.hashCode ^
      packageName.hashCode ^
      remapGeneratedFileTo.hashCode ^
      autoRebuildOnConnect.hashCode ^
      alwaysRebuildOnConnect.hashCode ^
      userMacrosConfig.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (remapGeneratedFileTo.isNotEmpty) 'remap_generated_file_to': remapGeneratedFileTo,
      if (autoRebuildOnConnect) 'auto_rebuild_on_connect': autoRebuildOnConnect,
      if (alwaysRebuildOnConnect) 'always_rebuild_on_connect': alwaysRebuildOnConnect,
      'macros': userMacrosConfig,
    };
  }

  @override
  String toString() {
    return 'MacroClientConfiguration{id: $id, context: $context, packageName: $packageName, remapGeneratedFileTo: $remapGeneratedFileTo, autoRebuildOnConnect: $autoRebuildOnConnect, alwaysRebuildOnConnect: $alwaysRebuildOnConnect, userMacrosConfig: $userMacrosConfig}';
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
