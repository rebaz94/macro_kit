import 'dart:io';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:macro_kit/macro.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:source_helper/source_helper.dart' show escapeDartString;

extension ExecutableElementExtension on ExecutableElement {
  /// Returns the name of `this` qualified with the class name if it's a [MethodElement].
  String get qualifiedName {
    if (this is TopLevelFunctionElement) {
      return displayName;
    }

    if (this is MethodElement) {
      return '${enclosingElement!.displayName}.$displayName';
    }

    if (this is ConstructorElement) {
      // The default constructor.
      if (name == 'new') {
        return enclosingElement!.name!;
      }
      return '${enclosingElement!.name}.$displayName';
    }

    throw MacroException('$runtimeType is not supported');
  }
}

/// ------------------------------------------------------------------------------------
/// COPIED & added as extension FROM source_gen package: ./lib/src/constants/util.dart
/// ------------------------------------------------------------------------------------
extension DartObjectExt on DartObject {
  /// Returns whether or not [object] is or represents a `null` value.
  static bool isNullLike(DartObject? object) => object?.isNull != false;

  /// Similar to [DartObject.getField], but traverses super classes.
  ///
  /// Returns `null` if ultimately [field] is never found.
  static DartObject? getFieldRecursive(DartObject? object, String field) {
    if (isNullLike(object)) {
      return null;
    }
    final result = object!.getField(field);
    if (isNullLike(result)) {
      return getFieldRecursive(object.getField('(super)'), field);
    }
    return result;
  }

  @pragma('vm:prefer-inline')
  DartObject? peek(String field) {
    return getFieldRecursive(this, field);
  }

  Object? literalValueOrNull() {
    final type = this.type;
    if (type == null) return null;

    if (type.isDartCoreDouble) {
      return toDoubleValue();
    } else if (type.isDartCoreInt) {
      return toIntValue();
    } else if (type.isDartCoreString) {
      return toStringValue();
    } else if (type.isDartCoreBool) {
      return toBoolValue();
    } else if (type.isDartCoreSymbol) {
      return toSymbolValue();
    }
    return null;
  }

  Object? literalForObject(
    String fieldName,
    Iterable<String> typeInformation,
  ) {
    if (isNull || this.type == null) {
      return null;
    }

    String? badType;
    final type = this.type!;
    if (type.isDartCoreType) {
      badType = 'Type';
    } else if (type is FunctionType) {
      badType = 'Function';
    }

    if (badType != null) {
      badType = typeInformation.followedBy([badType]).join(' > ');
      throw MacroException('`$fieldName` is `$badType`, it must be a literal.');
    }

    if (type.isDartCoreDouble) {
      return toDoubleValue();
    } else if (type.isDartCoreInt) {
      return toIntValue();
    } else if (type.isDartCoreString) {
      return toStringValue();
    } else if (type.isDartCoreBool) {
      return toBoolValue();
    } else if (type.isDartCoreSymbol) {
      return toSymbolValue();
    } else if (type.isDartCoreList) {
      return [
        for (var e in toListValue() ?? const <DartObject>[])
          e.literalForObject(fieldName, [...typeInformation, 'List']),
      ];
    } else if (type.isDartCoreSet) {
      return {
        for (var e in toSetValue() ?? const <DartObject>{}) e.literalForObject(fieldName, [...typeInformation, 'Set']),
      };
    } else if (type.isDartCoreMap) {
      final mapTypeInformation = [...typeInformation, 'Map'];
      return toMapValue()?.map(
        (k, v) => MapEntry(
          k!.literalForObject(fieldName, mapTypeInformation),
          v!.literalForObject(fieldName, mapTypeInformation),
        ),
      );
    } else if (type.element?.kind == ElementKind.CLASS) {
      final classElement = type.element! as ClassElement;
      final imports = getZoneAnalysisImports();
      final classConfig = <String, dynamic>{
        '__type__': classElement.firstFragment.element.name?.removedNullability ?? '',
        '__import__': imports?[classElement] ?? '',
      };

      // use constant constructor to reconstruct the type
      if (constructorInvocation != null) {
        final positionalArgs = <Object?>[];
        final namedArgs = <String, Object?>{};
        for (final (i, arg) in constructorInvocation!.positionalArguments.indexed) {
          positionalArgs.add(arg.literalForObject('argPos$i', typeInformation));
        }

        for (final entry in constructorInvocation!.namedArguments.entries) {
          namedArgs[entry.key] = entry.value.literalForObject(entry.key, typeInformation);
        }

        classConfig['__use_ctor__'] = constructorInvocation!.constructor.name;
        classConfig['__pos_args__'] = positionalArgs;
        classConfig['__named_args__'] = namedArgs;
        return classConfig;
      }

      // fallback to get all value from class
      classConfig['__ctor__'] = classElement.constructors
          .where((e) => e.isGenerative || e.isConst)
          .map((e) => '${e.name}:${e.formalParameters.length}')
          .toList();

      for (final field in classElement.fields) {
        if (field.isPrivate || field.isStatic || field.isExternal) continue;

        final fieldName = field.name ?? '';
        final obj = peek(fieldName);
        classConfig[fieldName] = obj?.literalForObject(fieldName, [
          ...typeInformation,
          classElement.displayName,
        ]);
      }

      return classConfig;
    } else if (type.element case EnumElement v) {
      return '${v.name}.${variable!.name}';
    }

    badType = typeInformation.followedBy(['$this']).join(' > ');

    throw UnsupportedError(
      'The provided value is not supported: $badType. '
      'This may be an error in package:macro. ',
    );
  }
}

/// Returns a [String] representing a valid Dart literal for [value].
String jsonLiteralAsDart(Object? value) {
  if (value == null) return 'null';

  if (value is String) return escapeDartString(value);

  if (value is double) {
    if (value.isNaN) {
      return 'double.nan';
    }

    if (value.isInfinite) {
      if (value.isNegative) {
        return 'double.negativeInfinity';
      }
      return 'double.infinity';
    }
  }

  if (value is bool || value is num) return value.toString();

  if (value is List) {
    final listItems = value.map(jsonLiteralAsDart).join(', ');
    return '[$listItems]';
  }

  if (value is Set) {
    final listItems = value.map(jsonLiteralAsDart).join(', ');
    return '{$listItems}';
  }

  if (value is Map) return _jsonMapAsDart(value);

  throw StateError(
    'Should never get here – with ${value.runtimeType} - `$value`.',
  );
}

String _jsonMapAsDart(Map value) {
  final buffer = StringBuffer()..write('{');

  var first = true;
  value.forEach((k, v) {
    if (first) {
      first = false;
    } else {
      buffer.writeln(',');
    }
    buffer
      ..write(jsonLiteralAsDart(k))
      ..write(': ')
      ..write(jsonLiteralAsDart(v));
  });

  buffer.write('}');

  return buffer.toString();
}

/// Returns a [String] representing a valid Dart literal for [value].
Object? encodeDartObject(Object? value) {
  if (value == null) return null;

  if (value is String) return value;

  if (value is double) {
    if (value.isNaN) {
      return double.nan;
    }

    if (value.isInfinite) {
      if (value.isNegative) {
        return double.negativeInfinity;
      }
      return double.infinity;
    }
  }

  if (value is bool || value is num) return value;

  if (value is List) {
    return value.map(encodeDartObject).toList();
  }

  if (value is Set) {
    return value.map(encodeDartObject).toList();
  }

  if (value is Map) {
    return value.map((k, v) => MapEntry(encodeDartObject(k), encodeDartObject(v)));
  }

  throw StateError(
    'Should never get here – with ${value.runtimeType} - `$value`.',
  );
}

extension FileExt on File {
  /// Write data to a file directly or retry when [createFile] is true and file not exist.
  Object? writeDataSyncOrErr(String contents, {required bool createFile, bool recursive = false}) {
    try {
      writeAsStringSync(contents);
      return null;
    } on PathNotFoundException catch (e) {
      if (!createFile) {
        return e;
      }

      try {
        createSync(recursive: recursive);
        writeAsStringSync(contents);
        return null;
      } catch (e) {
        return e;
      }
    }
  }
}

extension UniqueList<T> on List<T> {
  List<T> unique() {
    return toSet().toList();
  }

  List<T> uniqueBy<K>(K Function(T) keyExtractor) {
    final seen = <K>{};
    return where((item) => seen.add(keyExtractor(item))).toList();
  }
}
