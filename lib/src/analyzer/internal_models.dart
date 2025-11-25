import 'dart:async' as async;

import 'package:macro_kit/src/core/core.dart';
import 'package:meta/meta.dart';

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
