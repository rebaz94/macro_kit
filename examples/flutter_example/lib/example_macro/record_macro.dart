import 'package:macro_kit/macro_kit.dart';

class RecordMacro extends MacroGenerator {
  const RecordMacro({
    super.capability = const MacroCapability(
      typeDefRecords: true,
    ),
  });

  static RecordMacro initialize(MacroConfig config) {
    final key = config.key;
    final _ = key.propertiesAsMap();

    return RecordMacro(
      capability: config.capability,
    );
  }

  @override
  GeneratedType get generatedType => GeneratedType.clazz;

  @override
  String get suffixName => '';

  @override
  Future<void> init(MacroState state) async {
    if (state.targetType != TargetType.typeDefRecord) {
      throw MacroException('Only record supported for this macro: $this');
    }
  }

  @override
  Future<void> onClassFields(MacroState state, List<MacroProperty> fields) async {
    state.set('fields', fields);
  }

  @override
  Future<void> onClassTypeParameter(MacroState state, List<MacroProperty> typeParameters) async {
    state.set('typeParams', typeParameters);
  }

  @override
  Future<void> onGenerate(MacroState state) async {
    final buff = StringBuffer();

    final fields = state.get<List<MacroProperty>>('fields');
    final typeParams = state.getOrNull<List<MacroProperty>>('typeParams');
    final className = FieldRename.pascal.renameOf('Cls ${state.targetName}');
    final posFields = fields.where((f) => f.modifier.isRequiredPositional).toList();
    final namedFields = fields.where((f) => f.modifier.isNamed).toList();
    final preparedTypeParams = MacroProperty.buildTypeParameterWithBound(typeParams ?? const []);
    final dartCorePrefix = ''; // TODO: get dart import prefix

    buff.writeln('/// An example of Record macro that convert record definition into a class');
    buff.writeln('class $className$preparedTypeParams {\n');

    // constructor
    buff.writeln('$className(');
    buff.write(posFields.map((f) => 'this.${f.name}').join(', '));
    if (posFields.isNotEmpty && namedFields.isNotEmpty) {
      buff.write(',');
    }

    if (namedFields.isNotEmpty) {
      buff
        ..write('{')
        ..write(
          namedFields.map((f) => '${f.isNullable ? '' : 'required'} this.${f.name}').join(', '),
        )
        ..write('}');
    }

    // end constructor
    buff.writeln(');\n');

    for (final field in fields) {
      buff.writeln('final ${field.getDartType(dartCorePrefix)} ${field.name};');
    }

    buff.writeln('}\n');
    state.reportGenerated(buff.toString(), canBeCombined: false);
  }
}

class A {
  A(this.$1);

  final int $1;
}
