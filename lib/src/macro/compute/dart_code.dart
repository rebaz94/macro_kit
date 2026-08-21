/// A wrapper that lets compute macros return raw Dart source code
/// instead of a runtime value.
///
/// Use this when the computed result can't be expressed as a simple
/// Dart literal (e.g., `Color(0xFF...)`, `DateTime.now()`, constructor calls).
///
/// ## Example
///
/// ```dart
/// @Macro(ComputeMacro())
/// final _colorMacro = compute<DartCode>(
///   () => DartCode("Color(0xFF${generateHex()})"),
/// );
/// ```
///
/// Generates:
/// ```dart
/// const color = Color(0xFFA1B2C3);
/// ```
class DartCode {
  /// Creates a [DartCode] from raw Dart source.
  ///
  /// [code] is the raw Dart expression to embed in generated code.
  const DartCode(this.code);

  /// Creates a [DartCode] that wraps a value as a string literal.
  ///
  /// Convenience factory that quotes [value] as a Dart string literal.
  factory DartCode.value(String value) {
    final escaped = value
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
    return DartCode("'$escaped'");
  }

  /// The raw Dart source code to embed.
  final String code;

  /// Whether this instance represents raw code (true) or a value literal (false).
  bool get isRawCode => true;

  @override
  String toString() => 'DartCode($code)';
}

/// Sentinel type used by the compute executor to distinguish
/// [DartCode] results from regular values across isolate/process boundaries.
///
/// This is not meant to be used directly by users.
class DartCodeResult {
  const DartCodeResult(this.code);

  factory DartCodeResult.fromJson(Map<String, dynamic> json) {
    return DartCodeResult(json['code'] as String);
  }

  final String code;

  Map<String, dynamic> toJson() => {'code': code};
}

/// Encodes a compute result for transport across isolate/process boundaries.
///
/// - Regular values are encoded as-is (JSON-safe types survive).
/// - [DartCode] instances are encoded as `{'__dartCode__': code}`.
Object? encodeComputeResult(Object? value) {
  if (value is DartCode) {
    return {'__dartCode__': value.code};
  }
  if (value is List) {
    return value.map(encodeComputeResult).toList();
  }
  if (value is Map) {
    return value.map((k, v) => MapEntry(k, encodeComputeResult(v)));
  }
  return value;
}

/// Decodes a compute result received from an isolate/process.
///
/// Reverses [encodeComputeResult]: `{'__dartCode__': code}` becomes [DartCodeResult].
Object? decodeComputeResult(Object? value) {
  if (value is Map && value.containsKey('__dartCode__')) {
    return DartCodeResult(value['__dartCode__'] as String);
  }
  if (value is List) {
    return value.map(decodeComputeResult).toList();
  }
  if (value is Map) {
    return value.map((k, v) => MapEntry(k, decodeComputeResult(v)));
  }
  return value;
}

/// Serializes a compute result to a Dart literal string for code generation.
///
/// Handles [DartCodeResult] (raw code), primitives, collections, and
/// falls back to `toString()` for unknown types.
String serializeComputeResult(Object? value) {
  if (value == null) return 'null';
  if (value is DartCodeResult) return value.code;
  if (value is String) {
    final escaped = value
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
    return "'$escaped'";
  }
  if (value is bool || value is num) return value.toString();
  if (value is List) {
    final items = value.map(serializeComputeResult).join(', ');
    return '[$items]';
  }
  if (value is Set) {
    final items = value.map(serializeComputeResult).join(', ');
    return '{$items}';
  }
  if (value is Map) {
    final entries = value.entries
        .map((e) => '${serializeComputeResult(e.key)}: ${serializeComputeResult(e.value)}')
        .join(', ');
    return '{$entries}';
  }
  // Fallback: wrap toString() as string literal
  final escaped = value.toString()
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'");
  return "'$escaped'";
}
