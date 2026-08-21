import 'dart:async';

import 'package:macro_kit/macro_kit.dart';

/// Marker function for compile-time computation.
///
/// At runtime, this function simply returns [fn] unchanged.
/// During macro generation, Macro Kit detects this call pattern in the AST,
/// executes [fn] in an isolate, and materializes the result into generated code.
///
/// ## Example (Top-level Variable)
///
/// ```dart
/// @Macro(ComputeMacro())
/// final _versionMacro = compute(() => '1.0.0');
/// ```
///
/// Generates:
/// ```dart
/// const version = '1.0.0';
/// ```
///
/// ## Example (with DartCode)
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
///
/// ## Example (with encode/decode)
///
/// ```dart
/// @Macro(ComputeMacro())
/// final _dateMacro = compute(
///   () => DateTime.now(),
///   encode: (v) => v.toIso8601String(),
///   decode: (v) => "DateTime.parse('$v')",
/// );
/// ```
///
/// ## Example (with deps)
///
/// ```dart
/// final _config = Config.parse('...');
/// final _helper = Helper();
///
/// @Macro(ComputeMacro())
/// final _resultMacro = compute(
///   () => _helper.process(_config),
///   deps: [_config, _helper],  // only rebuild when these change
/// );
/// ```
///
/// When [deps] is provided, only changes to the compute body or listed
/// dependencies trigger re-execution. When omitted, any change in the
/// source file triggers rebuild.
///
/// The [encode] function converts the runtime result to a string
/// before it's sent back from the temp file execution. If not provided, the result
/// is serialized using built-in rules (primitives, collections, DartCode).
///
/// The [decode] function converts the encoded string back to a Dart literal
/// for code generation. Both [encode] and [decode] are applied in the temp file;
/// the server receives the final Dart literal. If [decode] is not provided,
/// the encoded string is used as-is.
///
/// The [deps] parameter lists identifier dependencies that should be tracked
/// for incremental rebuilds. When provided, only changes to the compute body
/// or listed dependencies trigger re-execution. When omitted, the full file
/// content is used for hashing (any file change triggers rebuild).
FutureOr<T> Function() compute<T>(
  FutureOr<T> Function() fn, {
  String Function(T value)? encode,
  String Function(String value)? decode,
  List<Object>? deps,
}) =>
    fn;

/// A macro that executes a compute function at compile time and generates
/// a constant/final/var with the result.
///
/// This macro can be applied to:
/// - **Top-level variables**: generates a const/final/var variable
/// - **Classes**: generates an abstract class with computed fields
///
/// For class application, the macro declares `classFields: true` with
/// `filterClassFieldMetadata: 'Macro'` to collect only fields annotated
/// with `@Macro(...)`. The `onClassFields` callback processes these fields
/// and generates computed values in an abstract class.
class ComputeMacro extends MacroGenerator {
  const ComputeMacro({
    super.capability = computeMacroCapability,
    this.asConst = true,
    this.private,
  });

  /// Create a ComputeMacro instance from a MacroConfig
  static ComputeMacro initialize(MacroConfig config) {
    final key = config.key;
    final props = key.propertiesAsMap();

    return ComputeMacro(
      capability: config.capability,
      asConst: props['asConst']?.asBoolConstantValue() ?? true,
      private: props['private']?.asBoolConstantValue(),
    );
  }

  /// Whether to use `const` instead of `final` in generated code
  final bool asConst;

  /// Whether to make the generated variable private (add leading underscore)
  final bool? private;

  @override
  String get suffixName => 'Computed';

  @override
  GeneratedType get generatedType => GeneratedType.abstractClass;

  @override
  Future<void> init(MacroState state) async {
    if (state.targetType != TargetType.variable && state.targetType != TargetType.clazz) {
      throw MacroException('ComputeMacro can only be applied to variables or classes, but got: ${state.targetType}');
    }
  }

  @override
  Future<void> onClassFields(MacroState state, List<MacroProperty> fields) async {
    // Store field data for onGenerate to use
    // Note: compute body extraction from fields is done by the analyzer
    // and stored in the declaration's data map
    state.set('classFields', fields);
  }

  @override
  Future<void> onGenerate(MacroState state) async {
    final buff = StringBuffer();

    switch (state.targetType) {
      case TargetType.variable:
        await _generateVariable(state, asConst, private, buff);

      case TargetType.clazz:
        await _generateClass(state, asConst, private, buff);

      default:
        throw MacroException('ComputeMacro: unexpected target type: ${state.targetType}');
    }

    state.reportGenerated(buff.toString(), canBeCombined: false);
  }

  /// Generate code for a top-level variable
  Future<void> _generateVariable(
    MacroState state,
    bool useAsConst,
    bool? makePrivate,
    StringBuffer buff,
  ) async {
    final computedResult = state.get('computedResult');

    if (computedResult == null) {
      throw MacroException('Compute body for ${state.targetName} returned empty result');
    }

    final variableName = _deriveName(state.targetName, makePrivate);
    final modifier = useAsConst ? 'const' : 'final';

    // Add hash constant for incremental caching
    final combinedHash = state.getOrNull<int>('combinedHash');
    if (combinedHash != null) {
      buff.write('const _${state.targetName}_computeHash = $combinedHash;\n');
    }

    buff.write('$modifier $variableName = $computedResult;\n');
  }

  /// Generate code for a class (abstract class with computed fields)
  Future<void> _generateClass(
    MacroState state,
    bool useAsConst,
    bool? makePrivate,
    StringBuffer buff,
  ) async {
    final classFields = state.getOrNull<Map<String, dynamic>>('classFields');
    if (classFields == null || classFields.isEmpty) {
      throw MacroException('No computed fields found in class ${state.targetName}');
    }

    buff.write('abstract class ${state.targetName}$suffixName {\n');

    for (final entry in classFields.entries) {
      final fieldName = entry.key;
      final fieldInfo = entry.value as Map<String, dynamic>;
      final fieldType = fieldInfo['type'] as String? ?? 'dynamic';

      // Note: computedResult will be populated by the server after execute
      // For now, generate a placeholder that will be filled in
      final derivedName = _deriveName(fieldName, makePrivate);
      buff.write('  $fieldType get $derivedName;\n');
    }

    buff.write('}\n');
  }

  /// Derive the generated variable name from the raw name
  ///
  /// Rules:
  /// - Strip leading underscore
  /// - Strip trailing 'Macro' suffix
  /// - If [forcePrivate] is true, add leading underscore
  String _deriveName(String rawName, bool? forcePrivate) {
    var name = rawName;

    // Strip leading underscore
    if (name.startsWith('_')) {
      name = name.substring(1);
    }

    // Strip trailing 'Macro' suffix
    if (name.endsWith('Macro')) {
      name = name.substring(0, name.length - 5);
    }

    // Apply private option
    if (forcePrivate == true && !name.startsWith('_')) {
      name = '_$name';
    }

    return name;
  }
}

/// Shorthand annotation for the compute macro.
///
/// Usage:
/// ```dart
/// @computeMacro
/// final _versionMacro = compute(() => '1.0.0');
/// ```
const computeMacro = Macro(ComputeMacro(capability: computeMacroCapability));

/// see [computeMacro]
const computeMacroCombined = Macro(
  combine: true,
  ComputeMacro(
    capability: computeMacroCapability,
  ),
);

/// Default capability for the compute macro.
///
/// - [MacroCapability.topLevelVariables]: collect top-level variables
/// - [MacroCapability.classFields]: collect class fields
/// - [MacroCapability.filterClassFieldMetadata]: only fields with `@Macro(...)` annotation
const computeMacroCapability = MacroCapability(
  topLevelVariables: true,
  classFields: true,
  filterClassInstanceFields: true,
  filterClassStaticFields: true,
  filterClassFieldMetadata: 'Macro',
);