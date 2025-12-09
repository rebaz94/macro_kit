import 'dart:async' as async;

import 'package:analyzer/dart/element/element.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:meta/meta.dart';
// ignore: depend_on_referenced_packages
import 'package:yaml/yaml.dart';

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
    required this.packageName,
    required this.context,
    required this.remapGeneratedFileTo,
    required this.autoRebuildOnConnect,
    required this.alwaysRebuildOnConnect,
  });

  factory MacroClientConfiguration.withDefault(String context, String packageName) {
    return MacroClientConfiguration(
      context: context,
      packageName: packageName,
      remapGeneratedFileTo: '',
      autoRebuildOnConnect: false,
      alwaysRebuildOnConnect: false,
    );
  }

  static MacroClientConfiguration fromYaml(String context, String packageName, YamlMap map) {
    final rewrite = (map['remap_generated_file_to'] as String?) ?? '';

    return MacroClientConfiguration(
      context: context,
      packageName: packageName,
      remapGeneratedFileTo: switch (rewrite) {
        _ when rewrite.startsWith('./') => rewrite.substring(2),
        _ when rewrite.startsWith('.') => rewrite.substring(1),
        _ when rewrite.startsWith('/') => rewrite.substring(1),
        _ => rewrite,
      },
      autoRebuildOnConnect: (map['auto_rebuild_on_connect'] as bool?) ?? false,
      alwaysRebuildOnConnect: (map['always_rebuild_on_connect'] as bool?) ?? false,
    );
  }

  static MacroClientConfiguration defaultConfig = MacroClientConfiguration(
    packageName: '',
    context: '',
    remapGeneratedFileTo: '',
    autoRebuildOnConnect: false,
    alwaysRebuildOnConnect: false,
  );

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacroClientConfiguration &&
          runtimeType == other.runtimeType &&
          context == other.context &&
          packageName == other.packageName &&
          remapGeneratedFileTo == other.remapGeneratedFileTo &&
          autoRebuildOnConnect == other.autoRebuildOnConnect &&
          alwaysRebuildOnConnect == other.alwaysRebuildOnConnect;

  @override
  int get hashCode =>
      context.hashCode ^
      packageName.hashCode ^
      remapGeneratedFileTo.hashCode ^
      autoRebuildOnConnect.hashCode ^
      alwaysRebuildOnConnect.hashCode;

  Map<String, dynamic> toJson() {
    return {
      if (remapGeneratedFileTo.isNotEmpty) 'remap_generated_file_to': remapGeneratedFileTo,
      if (autoRebuildOnConnect) 'auto_rebuild_on_connect': autoRebuildOnConnect,
      if (alwaysRebuildOnConnect) 'always_rebuild_on_connect': alwaysRebuildOnConnect,
    };
  }

  @override
  String toString() {
    return 'MacroClientConfiguration{context: $context, packageName: $packageName, remapGeneratedFileTo: $remapGeneratedFileTo, autoRebuildOnConnect: $autoRebuildOnConnect, alwaysRebuildOnConnect: $alwaysRebuildOnConnect}';
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
