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