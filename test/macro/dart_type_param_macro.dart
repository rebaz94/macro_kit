import 'package:macro_kit/macro_kit.dart';

class MyKey {
  const MyKey({
    required this.type,
    this.set2,
    this.list1,
    this.list2,
    this.list3,
    this.map1,
    this.map2,
    this.map3,
  });

  static MyKeyConfig fromMacroKey(MacroKey key) {
    final props = Map.fromEntries(key.properties.map((e) => MapEntry(e.name, e)));
    return MyKeyConfig(
      expected: props['name']?.asStringConstantValue() ?? '',
      type: props['type']!,
    );
  }

  final Type type;
  final Set<Type>? set2;
  final List<Type>? list1;
  final List<List<Type>>? list2;
  final List<Set<Type>>? list3;
  final Map<String, Type>? map1;
  final Map<String, List<Type>>? map2;
  final Map<String, List<List<Type>>>? map3;
}

class MyKeyConfig {
  final String expected;
  final MacroProperty type;

  static MyKeyConfig defaultKey = MyKeyConfig(
    expected: '',
    type: MacroProperty(name: '', importPrefix: '', type: '', typeInfo: TypeInfo.object),
  );

  MyKeyConfig({
    required this.expected,
    required this.type,
  });
}

class CustomMacro extends MacroGenerator {
  const CustomMacro({
    super.capability = const MacroCapability(
      classFields: true,
      filterClassInstanceFields: true,
      filterClassFieldMetadata: 'MyKey',
    ),
    required this.type,
    this.types = const [],
  });

  static CustomMacro initialize(MacroConfig config) {
    /// here we can't re-initiate a type by name when running macro
    /// but we have all info of the passed type, so in [init] get all info.
    return CustomMacro(type: null);
  }

  final Type? type;
  final List<Type> types;

  @override
  GeneratedType get generatedType => GeneratedType.clazz;

  @override
  String get suffixName => 'Custom';

  @override
  Future<void> init(MacroState state) async {
    final key = state.macro;
    final props = Map.fromEntries(key.properties.map((e) => MapEntry(e.name, e)));
    {
      final type = props['type'];
      if (type?.typeInfo != TypeInfo.type) {
        print('expected type to be `Type` but got: ${type?.type}');
      } else if (type?.typeRefType == null) {
        print('expected type to have `TypeRefType` but got null');
      }
    }

    {
      final type = props['types'];
      if (type?.typeInfo != TypeInfo.list) {
        print('expected type to be `List` but got: ${type?.type}');
      } else if (type?.typeArguments?.firstOrNull?.typeInfo != TypeInfo.type) {
        print('expected List type to be `Type` but got: ${type?.typeArguments?.firstOrNull?.type}');
      }
    }
  }

  @override
  Future<void> onClassFields(MacroState state, List<MacroProperty> classFields) async {
    state.set('fields', classFields);
  }

  @override
  Future<void> onGenerate(MacroState state) async {
    final fields = state.getOrNull<List<MacroProperty>>('fields') ?? [];
    final macroProps = Map.fromEntries(state.macro.properties.map((e) => MapEntry(e.name, e)));
    final type = macroProps['type'];
    final types = macroProps['types'];

    final buff = StringBuffer();
    buff.write('class ${state.targetName}${state.suffixName} {\n');
    buff.write('final types = <String, Object>{\n');

    if (type != null) {
      buff.write("'singleType': ${type.typeRefType?.type.isNotEmpty == true ? type.typeRefType?.type : 'Null'}\n,");
    }

    if (types != null && types.constantValue is List) {
      for (final (i, v) in (types.constantValue as List).indexed) {
        if (v is MacroProperty) {
          buff.write("'list${i}Type': ${v.type.isNotEmpty ? v.type : 'Null'}\n,");
        }
      }
    }

    // for each field add a static property with only type of the field
    // gotten from the MyKey
    for (final field in fields) {
      final cfg = field.cacheFirstKeyInto(
        keyName: 'MyKey',
        convertFn: MyKey.fromMacroKey,
        defaultValue: MyKeyConfig.defaultKey,
      );

      final String type;
      if (cfg.type.typeInfo != TypeInfo.type) {
        print('expected type to be `Type` but got: ${cfg.type.type}');
        type = '';
      } else if (cfg.type.typeRefType == null) {
        print('expected to have typeRefType but got null');
        type = '';
      } else {
        type = cfg.type.typeRefType?.type ?? '';
      }

      buff.write("'${field.name}Type': ${type.isNotEmpty ? type : 'Null'}\n,");

      // write field keys type
      final key = field.keys?.firstOrNull;
      if (key == null) continue;

      final keyProps = Map.fromEntries(key.properties.map((e) => MapEntry(e.name, e)));
      {
        final set2 = keyProps['set2'];
        if (set2?.constantValue case Set set) {
          for (final (i, v) in set.indexed) {
            final type = v as MacroProperty?;
            buff.write("'${field.name}Set2Type$i': ${type?.type.isNotEmpty == true ? type!.type : 'Null'}\n,");
          }
        }
      }

      {
        final list1 = keyProps['list1'];
        if (list1?.constantValue case List list) {
          for (final (i, v) in list.indexed) {
            final type = v as MacroProperty?;
            buff.write("'${field.name}List1Type$i': ${type?.type.isNotEmpty == true ? type!.type : 'Null'}\n,");
          }
        }
      }

      {
        final list2 = keyProps['list2'];
        if (list2?.constantValue case List list) {
          for (final (i, v) in list.indexed) {
            if (v is List) {
              for (final (k, v2) in v.indexed) {
                final type = v2 as MacroProperty?;
                buff.write("'${field.name}List2Type$i$k': ${type?.type.isNotEmpty == true ? type!.type : 'Null'}\n,");
              }
            }
          }
        }
      }

      {
        final list3 = keyProps['list3'];
        if (list3?.constantValue case List list) {
          for (final (i, v) in list.indexed) {
            if (v is Set) {
              for (final (k, v2) in v.indexed) {
                final type = v2 as MacroProperty?;
                buff.write("'${field.name}List3Type$i$k': ${type?.type.isNotEmpty == true ? type!.type : 'Null'}\n,");
              }
            }
          }
        }
      }

      {
        final map1 = keyProps['map1'];
        if (map1?.constantValue case Map map) {
          for (final (i, v) in map.entries.indexed) {
            final type = v.value as MacroProperty?;
            buff.write("'${field.name}Map1Type${v.key}$i': ${type?.type.isNotEmpty == true ? type!.type : 'Null'}\n,");
          }
        }
      }

      {
        final map2 = keyProps['map2'];
        if (map2?.constantValue case Map map) {
          for (final (i, v) in map.entries.indexed) {
            if (v.value is List) {
              for (final (k, v2) in (v.value as List).indexed) {
                final type = v2 as MacroProperty?;

                buff.write(
                  "'${field.name}Map2Type${v.key}$i$k': ${type?.type.isNotEmpty == true ? type!.type : 'Null'}\n,",
                );
              }
            }
          }
        }
      }

      {
        final map2 = keyProps['map3'];
        if (map2?.constantValue case Map map) {
          for (final (i, v) in map.entries.indexed) {
            if (v.value is List) {
              for (final (k, v2) in (v.value as List).indexed) {
                if (v2 is List) {
                  for (final (k2, v3) in v2.indexed) {
                    final type = v3 as MacroProperty?;

                    buff.write(
                      "'${field.name}Map3Type${v.key}$i$k$k2': ${type?.type.isNotEmpty == true ? type!.type : 'Null'}\n,",
                    );
                  }
                }
              }
            }
          }
        }
      }
    }

    buff.write('};\n');
    buff.write('}\n');

    return state.reportGenerated(buff.toString());
  }
}
