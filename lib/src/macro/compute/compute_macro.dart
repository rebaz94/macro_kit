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
}) => fn;

/// A macro that executes a compute function at compile time and generates
/// a const/final/var variable (or getter) with the result.
///
/// The generated declaration is controlled by [modifier]:
/// - default → `const variableName = ...;`
/// - `isFinal` → `final variableName = ...;`
/// - `isVar` → `var variableName = ...;`
/// - `isPrivate` → adds leading `_` to the generated name
///
/// ## Usage
///
/// ```dart
/// // Default: const
/// @Macro(ComputeMacro())
/// final _versionMacro = compute(() => '1.0.0');
/// // Generates: const version = '1.0.0';
///
/// // Explicit final
/// @Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true)))
/// final _dynamicMacro = compute(() => DateTime.now().toString());
/// // Generates: final dynamic = '...';
///
/// // Var
/// @Macro(ComputeMacro(modifier: ComputeModifier(isVar: true)))
/// final _mutableMacro = compute(() => 'rebuildable');
/// // Generates: var mutable = '...';
///
/// // Private + final
/// @Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true, isPrivate: true)))
/// final _secretMacro = compute(() => 'hidden');
/// // Generates: final _secret = 'hidden';
/// ```
class ComputeMacro extends MacroGenerator {
  const ComputeMacro({
    super.capability = computeMacroCapability,
    this.modifier = const ComputeModifier(),
  });

  /// Create a ComputeMacro instance from a MacroConfig
  static ComputeMacro initialize(MacroConfig config) {
    final key = config.key;
    final props = key.propertiesAsMap();

    return ComputeMacro(
      capability: config.capability,
      modifier: ComputeModifier.fromConstant(props['modifier']?.constantValue),
    );
  }

  /// Modifier controlling the generated variable/getter.
  ///
  /// - default → generates `const`
  /// - `isFinal` → generates `final`
  /// - `isVar` → generates `var`
  /// - `isPrivate` → adds leading underscore to generated name
  final ComputeModifier modifier;

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
    state.set('classFields', fields);
  }

  @override
  Future<void> onGenerate(MacroState state) async {
    final buff = StringBuffer();

    switch (state.targetType) {
      case TargetType.variable:
        await _generateVariable(state, modifier, buff);

      case TargetType.clazz:
        await _generateClass(state, modifier, buff);

      default:
        throw MacroException('ComputeMacro: unexpected target type: ${state.targetType}');
    }

    state.reportGenerated(buff.toString(), canBeCombined: false);
  }

  /// Generate code for a top-level variable.
  ///
  /// Produces one of:
  /// - `const name = value;` (default)
  /// - `final name = value;`
  /// - `var name = value;`
  Future<void> _generateVariable(
    MacroState state,
    ComputeModifier mod,
    StringBuffer buff,
  ) async {
    final computedResult = state.get('computedResult');

    if (computedResult == null) {
      throw MacroException('Compute body for ${state.targetName} returned empty result');
    }

    final variableName = _deriveName(state.targetName, mod);

    // Add hash constant for incremental caching
    final combinedHash = state.getOrNull<int>('combinedHash');
    if (combinedHash != null) {
      buff.write('const _${state.targetName}Hash = $combinedHash;\n');
    }

    // Variable case: determine keyword from modifier
    String keyword;
    if (mod.isFinal) {
      keyword = 'final';
    } else if (mod.isVar) {
      keyword = 'var';
    } else {
      // Default to const when no keyword is specified
      keyword = 'const';
    }

    buff.write('$keyword $variableName = $computedResult;\n');
  }

  /// Generate code for a class (abstract class with computed fields)
  Future<void> _generateClass(
    MacroState state,
    ComputeModifier mod,
    StringBuffer buff,
  ) async {
    final classFields = state.getOrNull<List<MacroProperty>>('classFields');
    if (classFields == null || classFields.isEmpty) {
      throw MacroException('No computed fields found in class ${state.targetName}');
    }

    buff.write('abstract class ${state.targetName}$suffixName {\n');

    final dartCorePrefix = state.imports[r"import dart:core"] ?? '';
    for (final entry in classFields) {
      final fieldName = entry.name;
      final fieldType =
          entry.functionTypeInfo?.returns.firstOrNull?.typeArguments?.firstOrNull?.getDartType(dartCorePrefix) ??
          entry.type;

      final derivedName = _deriveName(fieldName, mod);
      buff.write('  $fieldType get $derivedName;\n');
    }

    buff.write('}\n');
  }

  /// Derive the generated variable name from the raw name.
  ///
  /// Rules:
  /// - Strip leading underscore
  /// - Strip trailing 'Macro' suffix
  /// - If [mod] has `isPrivate`, add leading underscore
  String _deriveName(String rawName, ComputeModifier mod) {
    var name = rawName;

    // Strip leading underscore
    if (name.startsWith('_')) {
      name = name.substring(1);
    }

    // Strip trailing 'Macro' suffix
    if (name.endsWith('Macro')) {
      name = name.substring(0, name.length - 5);
    }

    // Apply private option from modifier
    if (mod.isPrivate && !name.startsWith('_')) {
      name = '_$name';
    }

    return name;
  }
}

/// User-friendly modifier for [ComputeMacro].
///
/// Controls what kind of declaration is generated: const, final, or var.
/// Unlike [MacroModifier], this uses clear named booleans and works in const contexts.
///
/// ## Examples
///
/// ```dart
/// // Default: const (omit modifier or use default)
/// @Macro(ComputeMacro())
/// final _versionMacro = compute(() => '1.0.0');
/// // Generates: const version = '1.0.0';
///
/// // Final variable
/// @Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true)))
/// final _dynamicMacro = compute(() => DateTime.now().toString());
/// // Generates: final dynamic = '...';
///
/// // Private + final
/// @Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true, isPrivate: true)))
/// final _secretMacro = compute(() => 'hidden');
/// // Generates: final _secret = 'hidden';
/// ```
class ComputeModifier {
  /// Creates a [ComputeModifier].
  ///
  /// - [isFinal]: generates `final name = value;`
  /// - [isVar]: generates `var name = value;`
  /// - [isPrivate]: prefixes the generated name with `_`
  ///
  /// When no keyword flag is set, `const` is generated.
  const ComputeModifier({
    this.isFinal = false,
    this.isVar = false,
    this.isPrivate = false,
  });

  /// Creates a [ComputeModifier] from the serialized constant annotation value.
  ///
  /// The analyzer serializes a const-constructed argument as a map with a
  /// `'__named_args__'` entry. Returns the default modifier (const) when
  /// [rawValue] is missing, null, or in an unexpected shape.
  static ComputeModifier fromConstant(Object? rawValue) {
    if (rawValue case Map m when m['__named_args__'] is Map) {
      final namedArgs = m['__named_args__'] as Map;
      return ComputeModifier(
        isFinal: namedArgs['isFinal'] == true,
        isVar: namedArgs['isVar'] == true,
        isPrivate: namedArgs['isPrivate'] == true,
      );
    }
    return const ComputeModifier();
  }

  /// Whether the generated declaration uses `final`.
  final bool isFinal;

  /// Whether the generated declaration uses `var`.
  final bool isVar;

  /// Whether the generated name is prefixed with `_`.
  final bool isPrivate;
}

/// Processes a raw compute result before transport across isolate/process boundaries.
///
/// This function is called in the temp file's `main()` entrypoint. It handles:
/// - **[DartCode]**: wraps the raw code as `{'__dartCode__': code}` for transport
/// - **No encode/decode**: returns the raw value as-is (primitives, collections)
/// - **With encode/decode**: applies encode to the raw value, then decode to the string
///
/// The result is sent back to the analyzer server which serializes it to a Dart literal.
///
/// [raw] is the runtime result of calling the compute function.
/// [enc] is the optional encode function (converts runtime value to string).
/// [dec] is the optional decode function (converts encoded string to Dart literal).
Object? processComputedResult<T>(T raw, [String Function(T)? enc, String Function(String)? dec]) {
  if (raw case DartCode raw) return {'__dartCode__': raw.code};
  if (enc == null && dec == null) return raw;
  final String encoded = enc != null ? enc(raw).toString() : raw.toString();
  return dec != null ? dec(encoded) : encoded;
}

const _computeOnce = 1;

/// Sentinel dependency list that marks a compute macro to build only once.
///
/// When used as `deps: macroBuildOnce`, the compute body is executed exactly once
/// and the result is cached permanently. The hash stored in the generated `.g.dart`
/// file will never trigger a rebuild since the hash value is constant.
///
/// ## Usage
///
/// ```dart
/// @Macro(ComputeMacro())
/// final _randomMacro = compute(
///   () => Random().nextInt(1000),
///   deps: macroBuildOnce,  // builds once, never rebuilds
/// );
/// ```
///
/// This is useful for values that are intentionally non-deterministic or
/// expensive to compute, where you want to freeze the result at build time.
const macroBuildOnce = [_computeOnce];

/// Shorthand annotation for the compute macro (default: const).
///
/// Usage:
/// ```dart
/// @computeMacro
/// final _versionMacro = compute(() => '1.0.0');
/// ```
const computeMacro = Macro(ComputeMacro(capability: computeMacroCapability));

/// Shorthand annotation for the compute macro with code combining.
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
