import 'dart:async' as async;

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
    required this.rewriteGeneratedFileTo,
  });

  static MacroClientConfiguration fromYaml(String context, YamlMap map) {
    final rewrite = (map['rewriteGeneratedFileTo'] as String?) ?? '';
    return MacroClientConfiguration(
      context: context,
      rewriteGeneratedFileTo: switch (rewrite) {
        _ when rewrite.startsWith('./') => rewrite.substring(2),
        _ when rewrite.startsWith('.') => rewrite.substring(1),
        _ when rewrite.startsWith('/') => rewrite.substring(1),
        _ => rewrite,
      },
    );
  }

  static MacroClientConfiguration defaultConfig = MacroClientConfiguration(
    context: '',
    rewriteGeneratedFileTo: '',
  );

  final String context;
  final String rewriteGeneratedFileTo;

  Map<String, dynamic> toJson() {
    return {
      if (rewriteGeneratedFileTo.isNotEmpty) 'rewriteGeneratedFileTo': rewriteGeneratedFileTo,
    };
  }

  @override
  String toString() {
    return 'MacroClientConfiguration{context: $context, rewriteGeneratedFileTo: $rewriteGeneratedFileTo}';
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
