import 'package:macro_kit/macro_kit.dart';

enum TimeUnit {
  microseconds,
  milliseconds,
  seconds,
}

class TimedMacro extends MacroGenerator {
  const TimedMacro({
    super.capability = timedMacroCapability,
    this.unit = TimeUnit.microseconds,
  });

  static TimedMacro initialize(MacroConfig config) {
    final key = config.key;
    final props = Map.fromEntries(key.properties.map((e) => MapEntry(e.name, e)));

    return TimedMacro(
      capability: config.capability,
      unit: MacroExt.decodeEnum(
        TimeUnit.values,
        props['unit']?.asStringConstantValue()?.replaceAll('TimeUnit.', ''),
        unknownValue: TimeUnit.microseconds,
      ),
    );
  }

  final TimeUnit unit;

  @override
  GeneratedType get generatedType => GeneratedType.function;

  @override
  String get suffixName => '';

  @override
  Future<void> init(MacroState state) async {
    if (state.targetType != TargetType.function) {
      throw MacroException('TimedMacro can only be applied on function but applied on: ${state.targetType}');
    }
  }

  @override
  Future<void> onTopLevelFunctionTypeParameter(MacroState state, List<MacroProperty> typeParameters) async {
    state.set('typeParams', typeParameters);
  }

  @override
  Future<void> onTopLevelFunction(MacroState state, MacroMethod function) async {
    state.set('function', function);
  }

  @override
  Future<void> onGenerate(MacroState state) async {
    final typeParams = state.getOrNull<List<MacroProperty>>('typeParams') ?? const [];
    final function = state.get<MacroMethod>('function');

    final fnReturn = function.returns.firstOrNull;
    if (fnReturn == null) {
      throw MacroException('TimedMacro requires a function with a return type');
    }

    final buff = StringBuffer();
    final dcp = state.imports[r"import dart:core"] ?? '';

    // Determine return type and whether it's async
    final bool isAsync;
    final MacroProperty? returnType;
    final bool hasReturnValue;

    if (fnReturn.typeInfo == TypeInfo.future) {
      isAsync = true;
      final innerType = fnReturn.typeArguments?.firstOrNull;
      if (innerType == null || innerType.typeInfo == TypeInfo.voidType) {
        hasReturnValue = false;
        returnType = null;
      } else {
        hasReturnValue = true;
        returnType = innerType;
      }
    } else if (fnReturn.typeInfo == TypeInfo.voidType) {
      isAsync = false;
      hasReturnValue = false;
      returnType = null;
    } else {
      isAsync = false;
      hasReturnValue = true;
      returnType = fnReturn;
    }

    // Generate function name
    final originalName = state.targetName;
    final String generatedName;
    if (originalName.startsWith('_')) {
      // Private function - remove underscore
      generatedName = originalName.substring(1);
    } else {
      // Public function - add 'Timed' suffix
      generatedName = '${originalName}Timed';
    }

    // Build type parameters
    final typeParamsStr = typeParams.isNotEmpty ? MacroProperty.getTypeParameterWithBound(typeParams) : '';
    final typeParamsCall = typeParams.isNotEmpty ? MacroProperty.getTypeParameter(typeParams) : '';

    // Separate positional and named parameters
    final requiredPositionalParams = <String>[];
    final optionalPositionalParams = <String>[];
    final namedParams = <String>[];
    final positionalArgs = <String>[];
    final namedArgs = <String>[];

    String getLiteralValue(MacroProperty p) {
      if (p.typeInfo == TypeInfo.function && p.constantValue is String) {
        return p.constantValue as String;
      }

      return MacroProperty.toLiteralValue(p);
    }

    for (final p in function.params) {
      final prefix = p.importPrefix;
      final type = p.getDartType(dcp);
      final name = p.name;

      if (p.modifier.isRequiredPositional) {
        // Required positional parameter
        requiredPositionalParams.add('$prefix$type $name');
        positionalArgs.add(name);
      } else if (p.modifier.isNamed || p.modifier.isRequiredNamed) {
        // Named parameter (required or optional)
        final bool isRequire = p.modifier.isRequiredNamed || (!p.isNullable && p.constantValue == null);
        final require = isRequire ? 'required ' : '';
        final defaultVal = p.constantValue != null ? ' = ${getLiteralValue(p)}' : '';
        namedParams.add('$require$prefix$type $name$defaultVal');
        namedArgs.add('$name: $name');
      } else {
        // Optional positional parameter
        final defaultVal = p.constantValue != null ? ' = ${getLiteralValue(p)}' : '';
        optionalPositionalParams.add('$prefix$type $name$defaultVal');
        positionalArgs.add(name);
      }
    }

    // Build parameters string
    final paramsStr = StringBuffer();
    if (requiredPositionalParams.isNotEmpty) {
      paramsStr.write(requiredPositionalParams.join(', '));
    }
    if (optionalPositionalParams.isNotEmpty) {
      if (requiredPositionalParams.isNotEmpty) {
        paramsStr.write(', ');
      }
      paramsStr.write('[${optionalPositionalParams.join(', ')}]');
    }
    if (namedParams.isNotEmpty) {
      if (requiredPositionalParams.isNotEmpty || optionalPositionalParams.isNotEmpty) {
        paramsStr.write(', ');
      }
      paramsStr.write('{${namedParams.join(', ')}}');
    }

    // Build arguments string
    final argsStr = StringBuffer();
    if (positionalArgs.isNotEmpty) {
      argsStr.write(positionalArgs.join(', '));
    }
    if (namedArgs.isNotEmpty) {
      if (positionalArgs.isNotEmpty) {
        argsStr.write(', ');
      }
      argsStr.write(namedArgs.join(', '));
    }

    // Build return type
    final String finalReturnType;
    if (hasReturnValue && returnType != null) {
      final returnTypeStr = returnType.getDartType(dcp);
      finalReturnType = '($returnTypeStr, ${dcp}int)';
    } else {
      finalReturnType = '${dcp}int';
    }

    final timeUnitProp = switch (unit) {
      TimeUnit.microseconds => 'elapsedMicroseconds',
      TimeUnit.milliseconds => 'elapsedMilliseconds',
      TimeUnit.seconds => 'elapsed.inSeconds',
    };

    // Generate the function
    buff.write('${isAsync ? '${dcp}Future<' : ''}$finalReturnType${isAsync ? '>' : ''} ');
    buff.write('$generatedName$typeParamsStr($paramsStr)');
    buff.write(isAsync ? ' async ' : ' ');
    buff.write('{\n');
    buff.write('  final s = ${dcp}Stopwatch()..start();\n');
    buff.write('  try {\n');

    if (hasReturnValue) {
      buff.write('  final res = ${isAsync ? 'await ' : ''}$originalName$typeParamsCall($argsStr);\n');
      buff.write('  return (res, (s..stop()).$timeUnitProp);\n');
    } else {
      buff.write('  ${isAsync ? 'await ' : ''}$originalName$typeParamsCall($argsStr);\n');
      buff.write('  return (s..stop()).$timeUnitProp;\n');
    }

    buff.write('  }\n catch(_) { \n');
    buff.writeln('  s.stop();');
    buff.writeln('  rethrow;');
    buff.writeln('}\n');

    buff.write('}\n');

    state.reportGenerated(buff.toString());
  }
}

/// Shorthand annotation for [TimedMacro]
const timedMacro = Macro(
  TimedMacro(
    capability: timedMacroCapability,
  ),
);

/// Combined version
const timedMacroCombined = Macro(
  combine: true,
  TimedMacro(
    capability: timedMacroCapability,
  ),
);

const timedMacroCapability = MacroCapability(
  topLevelFunctions: true,
);
