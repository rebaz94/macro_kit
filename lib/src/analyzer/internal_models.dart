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
    required this.context,
    required this.remapGeneratedFileTo,
    required this.autoRebuildOnConnect,
  });

  factory MacroClientConfiguration.withDefault(String context) {
    return MacroClientConfiguration(context: context, remapGeneratedFileTo: '', autoRebuildOnConnect: false);
  }

  static MacroClientConfiguration fromYaml(String context, YamlMap map) {
    final rewrite = (map['remap_generated_file_to'] as String?) ?? '';

    return MacroClientConfiguration(
      context: context,
      remapGeneratedFileTo: switch (rewrite) {
        _ when rewrite.startsWith('./') => rewrite.substring(2),
        _ when rewrite.startsWith('.') => rewrite.substring(1),
        _ when rewrite.startsWith('/') => rewrite.substring(1),
        _ => rewrite,
      },
      autoRebuildOnConnect: (map['auto_rebuild_on_connect'] as bool?) ?? false,
    );
  }

  static MacroClientConfiguration defaultConfig = MacroClientConfiguration(
    context: '',
    remapGeneratedFileTo: '',
    autoRebuildOnConnect: false,
  );

  /// The associated project context
  final String context;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacroClientConfiguration &&
          runtimeType == other.runtimeType &&
          context == other.context &&
          remapGeneratedFileTo == other.remapGeneratedFileTo &&
          autoRebuildOnConnect == other.autoRebuildOnConnect;

  @override
  int get hashCode => context.hashCode ^ remapGeneratedFileTo.hashCode ^ autoRebuildOnConnect.hashCode;

  Map<String, dynamic> toJson() {
    return {
      if (remapGeneratedFileTo.isNotEmpty) 'remap_generated_file_to': remapGeneratedFileTo,
      if (autoRebuildOnConnect) 'auto_rebuild_on_connect': autoRebuildOnConnect,
    };
  }

  @override
  String toString() {
    return 'MacroClientConfiguration{context: $context, remapGeneratedFileTo: $remapGeneratedFileTo, autoRebuildOnConnect: $autoRebuildOnConnect}';
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
