// ignore_for_file: non_constant_identifier_names, library_private_types_in_public_api

import 'package:macro_kit/src/core/core.dart';

extension MacroKeyListExt on List<MacroKey> {
  MacroKey? firstMacroKeyOf(String name) {
    for (final key in this) {
      if (key.name == name) return key;
    }
    return null;
  }
}

abstract class Identifiable<T> {
  T get id;
}

extension EnumByIdExt<T extends Identifiable> on Iterable<T> {
  T byId<V>(V value) {
    for (var enumType in this) {
      if (enumType.id == value) return enumType;
    }
    throw StateError('enum with value of ($value) not found');
  }

  T byIdOr<V>(V value, {required T defaultValue}) {
    for (var enumType in this) {
      if (enumType.id == value) return enumType;
    }
    return defaultValue;
  }

  T? byIdOrNull<V>(V value) {
    for (var enumType in this) {
      if (enumType.id == value) return enumType;
    }
    return null;
  }

  V? validByIdOrNull<V>(V value) {
    for (var enumType in this) {
      if (enumType.id == value) return value;
    }
    return null;
  }
}

extension FutureTExt<T> on Future<T> {
  @pragma('vm:prefer-inline')
  Future<(T?, Object? error)> awaitValue() {
    return then<(T?, Object?)>(
      (value) => (value, null),
      onError: (err) => (null, err),
    );
  }

  @pragma('vm:prefer-inline')
  Future<(T?, Object? error, StackTrace?)> awaitValueTraced() {
    return then<(T?, Object?, StackTrace?)>(
      (value) => (value, null, null),
      onError: (err, trace) => (null, err, trace),
    );
  }

  @pragma('vm:prefer-inline')
  Future<Object?> awaitErr() {
    return then<Object?>(
      (_) => null,
      onError: (err) => err,
    );
  }

  @pragma('vm:prefer-inline')
  Future<(Object?, StackTrace?)> awaitErrTraced() {
    return then<(Object?, StackTrace?)>(
      (_) => (null, null),
      onError: (err, trace) => (err, trace),
    );
  }

  @pragma('vm:prefer-inline')
  Future<void> awaitIgnoreErr() async {
    return then<void>((_) {}, onError: (_) {});
  }
}
