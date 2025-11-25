import 'package:macro_kit/macro.dart';

part 'example1.g.dart';

typedef MyInt = int;

MyInt strFromJson2(Object? value) {
  return (value as num).toInt();

  ///nsmsmdsdfddmmknkdsnnfnn
}

class CustomB {
  Future<String> test2() async {
    throw '';
  }
}

class MyMetadata {
  const MyMetadata({required this.name});

  final String name;
}

const dataClassMacro = Macro(
  DataClassMacro(
    capability: MacroCapability(
      classFields: true,
      filterClassInstanceFields: true,
      filterClassStaticFields: true,
      filterClassFieldMetadata: '*',
      classConstructors: true,
      filterClassConstructorParameterMetadata: '*',
      classMethods: true,
      filterClassMethodMetadata: '*',
      filterClassInstanceMethod: true,
      filterClassStaticMethod: true,
    ),
  ),
);

const dataClassMacro2 = Macro(
  DataClassMacro(
    capability: MacroCapability(
      classMethods: true,
      filterClassMethodMetadata: '*',
      filterClassInstanceMethod: true,
      filterClassStaticMethod: true,
    ),
  ),
);

// @Macro(
//   DataClassMacro(
//     capability: MacroCapability(
//       classFields: true,
//       filterClassInstanceFields: true,
//       filterClassStaticFields: true,
//       filterClassFieldMetadata: '*',
//       classConstructors: true,
//       filterClassConstructorParameterMetadata: '*',
//       classMethods: true,
//       filterClassMethodMetadata: '*',
//       filterClassInstanceMethod: true,
//       filterClassStaticMethod: true,
//       inspectStaticFromJson: true,
//     ),
//   ),
// )
@dataClassMacro
@dataClassMacro2
class A<T> implements CustomB {
  factory A.aaa({
    @MyMetadata(name: 'its data3 factory field metadata ')
    @JsonKey(name: 'its data3 factory field metadata')
    required List<String> data3,
    required MyInt data,
    required B b,
    required B c,
    required MyEnumData customEnum,
  }) = A; //dddfmkddffndkccssfsd

  A({
    @MyMetadata(name: 'its data constructor field metadata') required this.data,
    required this.b,
    @MyMetadata(name: 'its c constructor field metadata') required this.c,
    required this.data3,
    required this.customEnum,
  });

  final List<String> data3;

  @JsonKey(name: 'data', fromJson: A.strFromJson, toJson: A.strToJson)
  final MyInt data;

  @JsonKey(name: 'data2', defaultValue: B())
  final B b;
  @JsonKey(name: 'data3', defaultValue: B.new)
  final B c;

  ///sff/d//dnsdsdsdfkfdsssdsssdssd

  final MyEnumData customEnum;

  String? nnn;

  @MyMetadata(name: 'its hello with metadata')
  void hello<C>(
    void Function(String name) fn1,
    C data,
    String? aa,
  ) {}

  @override
  Future<String> test2() async {
    throw 'sfsdss';
  }

  @MyMetadata(name: 'its asyncRet with metadata')
  Stream<int> asyncRet() {
    throw 'sfsdss';
  }

  Stream<int> asyncGen() async* {
    throw 'sfsdss';
  }

  Iterable<int> syncRet() {
    throw 'sfsdss';
  }

  Iterable<int> syncGen() sync* {
    throw 'sfsdsss';
  }

  @MyMetadata(name: 'its test3 with metadata')
  static Future<String> test3() {
    throw 'sfsdss';
  }

  static Stream<int> asyncRet1() {
    throw 'sfsdss';
  }

  static Stream<int> asyncGen1() async* {
    throw 'sfsdss';
  }

  static Iterable<int> syncRet1() {
    throw 'sfsdss';
  }

  static Iterable<int> syncGen1() sync* {
    throw 'sfsdsss';
  }

  void aabb() {
    // hello(data);
  }

  @MyMetadata(name: 'its field naa with metadata')
  static String naaaa = '';

  @MyMetadata(name: 'its _myName with metadata')
  String _myName = '';

  String get aa => _myName;

  @MyMetadata(name: 'its var133 with metadata')
  var var133 = 'dddd';

  // String get myName => _myName;////ss

  // set myName(String value) {
  //   _myName = value;
  // }

  static B bFact() => B();

  static MyInt strFromJson(Object? value) {
    return (value as num).toInt();
  }

  static String strToJson(MyInt value) {
    return value.toString();
  }
}

class B {
  const B();
}

class Test<T1, T2, T3, T4> {}

// @Macro(DataClassMacro())
class Profile1<T extends num> with Profile1Json<T> {
  const Profile1({
    required this.genericData,
    required this.genericData2,
    this.customGeneric,
    required this.someGeneric,
    required this.name,
    required this.age,
    required this.someInt,
    this.point,
    this.address,
    this.address2,
    this.address3,
    this.address4,
    this.intVal,
    required this.codable,
    required this.codable2,
    required this.codable3,
    required this.codable4,
    required this.list,
    required this.list2,
    required this.list3,
    required this.map,
    required this.map1,
    required this.map2,
    required this.map3,
    required this.map4,
    required this.map5,
    required this.map6,
    required this.map7,
    required this.map8,
    required this.map9,
    required this.map10,
    required this.map11,
    required this.map12,
    required this.dateTime,
    required this.dateTime2,
    required this.dateTime3,
    required this.duration,
    required this.duration2,
    required this.bigInt,
    required this.bigInt2,
    required this.uri,
    required this.uri2,
    required this.enumData,
    required this.enumData2,
    required this.enumData3,
    required this.obj,
    required this.obj2,
    required this.dynamicVal,
  });

  final T genericData;
  final T? genericData2;
  final CustomGeneric<String, bool, int>? customGeneric;
  final SomeGeneric<int> someGeneric;
  final String name;
  final int age;
  final int? someInt;
  final double? point;
  final String? address;
  final String? address2;
  final String? address3;
  final String? address4;
  final int? intVal;

  final SomeData codable;
  final SomeData? codable2;
  final SomeData2 codable3;
  final SomeData3 codable4;

  final List<String> list;
  final List<String>? list2;
  final List<int?>? list3;

  final Map<String, dynamic> map;
  final Map<String, double> map1;
  final Map<Object, double> map2;
  final Map<dynamic, double> map3;
  final Map<dynamic, double> map4;
  final Map<MyEnumData, int> map5;
  final Map<BigInt, double> map6;
  final Map<DateTime, String> map7;
  final Map<int, int> map8;
  final Map<Uri, int> map9;
  final Map<int, double>? map10;
  final Map<String, List<String>> map11;
  final Map<T, String> map12;

  final DateTime dateTime;
  final DateTime? dateTime2;
  final List<DateTime?> dateTime3;

  final Duration duration;
  final Duration? duration2;

  final BigInt bigInt;
  final BigInt? bigInt2;

  final Uri uri;
  final Uri? uri2;

  final MyEnumData enumData;
  final MyEnumData? enumData2;
  final MyEnumData? enumData3;

  final Object obj;
  final Object? obj2;

  final dynamic dynamicVal;

  static String getDefaultAddress() => 'Goizha';

  static String? address2FromJson(String? value) => value;

  static int intValueToJson(int? value) => value ?? 0;

  static Object? readStr(Map map, String key) {
    final v = map[key];
    if (v is String?) return v;
    if (v is num) return v.toString();
    return null;
  }

  static int? intFromStr(String? key) {
    return int.tryParse(key ?? '');
  }

  static SomeGeneric<int> someGenericFromJson(Map<String, dynamic> json) {
    return SomeGeneric<int>.fromJson(
      json,
      (data) => int.tryParse(data as String) ?? -1,
    );
  }

  static Map<String, dynamic> someGenericToJson(SomeGeneric<int> data) {
    return data.toJson((v) => v.toString());
  }
}

class CustomGeneric<T1, T2, T3 extends num> {
  CustomGeneric._();

  factory CustomGeneric.fromJson(Map<String, dynamic> json) {
    return CustomGeneric._();
  }

  Map<String, dynamic> toJson() {
    return {};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CustomGeneric && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

enum MyEnumData { a, b, c }

class SomeData {
  static SomeData fromJson(Map<String, dynamic> value) => SomeData();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) => identical(this, other) || other is SomeData && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  @override
  String toString() {
    return 'SomeData{}';
  }
}

extension type SomeData2(int value) {
  static SomeData2 fromJson(int value) => SomeData2(value);

  int toJson() => value;
}

enum SomeData3 {
  a,
  b,
  c;

  static SomeData3 fromJson(String value) => SomeData3.values.byName(value);

  String toJson() => a.name; //
}

class SomeGeneric<T> {
  SomeGeneric({required this.data});

  factory SomeGeneric.fromJson(Map<String, dynamic> json, T Function(Object? data) fromJsonT) {
    return SomeGeneric(data: fromJsonT(json['data']));
  }

  final T data;

  Map<String, dynamic> toJson(Object? Function(T v) toJsonT) {
    return {
      'data': toJsonT(data),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SomeGeneric && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;
}

void profile1Example() async {
  // step 1 - prepare class info based on analyzer
  final classFields = [
    MacroProperty(name: 'genericData', type: 'T', typeInfo: TypeInfo.generic), //
    MacroProperty(name: 'genericData2', type: 'T?', typeInfo: TypeInfo.generic), //
    MacroProperty(
      name: 'customGeneric',
      type: 'CustomGeneric<String, bool, int>?',
      typeInfo: TypeInfo.clazz,
      typeArguments: [
        MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
        MacroProperty(name: '', type: 'bool', typeInfo: TypeInfo.boolean),
        MacroProperty(name: '', type: 'int', typeInfo: TypeInfo.int),
      ],
      extraMetadata: {
        'fromJsonType': MacroProperty(
          name: '',
          type: 'Map<String, dynamic>',
          typeInfo: TypeInfo.map,
          typeArguments: [
            MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
            MacroProperty(name: '', type: 'dynamic', typeInfo: TypeInfo.dynamic),
          ],
        ),
      },
    ),
    MacroProperty(
      name: 'someGeneric',
      type: 'SomeGeneric<int>',
      typeInfo: TypeInfo.clazz,
      typeArguments: [
        MacroProperty(
          name: '',
          type: 'int',
          typeInfo: TypeInfo.int,
        ),
      ],
      keys: [
        MacroKey(
          name: 'JsonKey',
          properties: [
            MacroProperty(
              name: 'fromJson',
              type: 'Profile1 Function(Object)',
              typeInfo: TypeInfo.function,
              functionTypeInfo: MacroMethod(
                name: '',
                typeParams: [],
                params: [
                  MacroProperty(
                    name: 'json',
                    type: 'Map<String, dynamic>',
                    typeInfo: TypeInfo.map,
                    typeArguments: [
                      MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
                      MacroProperty(name: '', type: 'dynamic', typeInfo: TypeInfo.dynamic),
                    ],
                  ),
                ],
                returns: [MacroProperty(name: '', type: 'Profile1', typeInfo: TypeInfo.clazz)],
                modifier: MacroModifier.create(isStatic: true),
                keys: null,
              ),
              constantValue: 'Profile1.someGenericFromJson',
            ),
            MacroProperty(
              name: 'toJson',
              type: 'Map<String, dynamic> Function()',
              typeInfo: TypeInfo.function,
              functionTypeInfo: MacroMethod(
                name: '',
                typeParams: [],
                params: [
                  MacroProperty(name: 'value', type: 'Profile1', typeInfo: TypeInfo.clazz),
                ],
                returns: [
                  MacroProperty(
                    name: '',
                    type: 'Map<String, dynamic>',
                    typeInfo: TypeInfo.map,
                    typeArguments: [
                      MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
                      MacroProperty(name: '', type: 'dynamic', typeInfo: TypeInfo.dynamic),
                    ],
                  ),
                ],
                modifier: MacroModifier.create(isStatic: true),
                keys: null,
              ),
              constantValue: 'Profile1.someGenericToJson',
            ),
          ],
        ),
      ],
      extraMetadata: {
        'fromJsonType': MacroProperty(
          name: '',
          type: 'Map<String, dynamic>',
          typeInfo: TypeInfo.map,
          typeArguments: [
            MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
            MacroProperty(name: '', type: 'dynamic', typeInfo: TypeInfo.dynamic),
          ],
        ),
      },
    ),
    MacroProperty(
      name: 'name',
      type: 'String',
      typeInfo: TypeInfo.string,
      keys: [
        MacroKey(
          name: 'JsonKey',
          properties: [
            MacroProperty(name: 'name', type: 'String', typeInfo: TypeInfo.string, constantValue: 'Name'),
          ],
        ),
      ],
    ),
    MacroProperty(name: 'age', type: 'int', typeInfo: TypeInfo.int),
    MacroProperty(
      name: 'someInt',
      type: 'int?',
      typeInfo: TypeInfo.int,
      keys: [
        MacroKey(
          name: 'JsonKey',
          properties: [
            MacroProperty(
              name: 'fromJson',
              type: 'Profile1 Function(Object)',
              typeInfo: TypeInfo.function,
              functionTypeInfo: MacroMethod(
                name: '',
                typeParams: [],
                params: [
                  MacroProperty(
                    name: 'json',
                    type: 'String?',
                    typeInfo: TypeInfo.string,
                    modifier: MacroModifier.create(isNullable: true),
                  ),
                ],
                returns: [
                  MacroProperty(
                    name: '',
                    type: 'int',
                    typeInfo: TypeInfo.int,
                    modifier: MacroModifier.create(isNullable: true),
                  ),
                ],
                modifier: MacroModifier.create(isStatic: true),
                keys: null,
              ),
              constantValue: 'Profile1.intFromStr',
            ),
            MacroProperty(
              name: 'read',
              type: 'Object? Function(Map map, String key)',
              typeInfo: TypeInfo.function,
              functionTypeInfo: MacroMethod(
                name: '',
                typeParams: [],
                params: [
                  MacroProperty(
                    name: 'map',
                    type: 'Map<String, dynamic>',
                    typeInfo: TypeInfo.map,
                    typeArguments: [
                      MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
                      MacroProperty(name: '', type: 'dynamic', typeInfo: TypeInfo.dynamic),
                    ],
                  ),
                  MacroProperty(name: 'key', type: 'String', typeInfo: TypeInfo.string),
                ],
                returns: [
                  MacroProperty(
                    name: '',
                    type: 'Object?',
                    typeInfo: TypeInfo.object,
                    modifier: MacroModifier.create(isNullable: true),
                  ),
                ],
                modifier: MacroModifier.create(isStatic: true),
                keys: null,
              ),
              constantValue: 'Profile1.readStr',
            ),
          ],
        ),
      ],
    ),
    MacroProperty(
      name: 'point',
      type: 'double?',
      typeInfo: TypeInfo.double,
      keys: [
        MacroKey(
          name: 'JsonKey',
          properties: [
            MacroProperty(
              name: 'defaultValue',
              type: 'double?',
              typeInfo: TypeInfo.double,
              modifier: MacroModifier.create(isNullable: true, isConst: true),
            ),
          ],
        ),
      ],
    ),
    MacroProperty(
      name: 'address',
      type: 'String?',
      typeInfo: TypeInfo.string,
      keys: [
        MacroKey(
          name: 'JsonKey',
          properties: [
            MacroProperty(
              name: 'defaultValue',
              type: 'String',
              typeInfo: TypeInfo.function,
              functionTypeInfo: MacroMethod(
                name: 'getDefaultAddress',
                typeParams: [],
                params: [],
                returns: [
                  MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
                ],
                modifier: MacroModifier.create(isConst: true),
                keys: null,
              ),
              modifier: MacroModifier.create(isNullable: true, isConst: true),
            ),
          ],
        ),
      ],
    ),
    MacroProperty(
      name: 'address2',
      type: 'String?',
      typeInfo: TypeInfo.string,
      keys: [
        MacroKey(
          name: 'JsonKey',
          properties: [
            MacroProperty(
              name: 'fromJson',
              type: 'String? Function(String?)',
              typeInfo: TypeInfo.function,
              functionTypeInfo: MacroMethod(
                name: '',
                typeParams: [],
                params: [
                  MacroProperty(
                    name: 'json',
                    type: 'String?',
                    typeInfo: TypeInfo.string,
                    modifier: MacroModifier.create(isNullable: true),
                  ),
                ],
                returns: [
                  MacroProperty(
                    name: '',
                    type: 'String?',
                    typeInfo: TypeInfo.string,
                    modifier: MacroModifier.create(isNullable: true),
                  ),
                ],
                modifier: MacroModifier.create(isStatic: true),
                keys: null,
              ),
              constantValue: 'Profile1.address2FromJson',
            ),
            MacroProperty(
              name: 'defaultValue',
              type: 'Profile1.getDefaultAddress()',
              typeInfo: TypeInfo.function,
              functionTypeInfo: MacroMethod(
                name: '',
                typeParams: [],
                params: [],
                returns: [
                  MacroProperty(
                    name: '',
                    type: 'String',
                    typeInfo: TypeInfo.string,
                    modifier: MacroModifier.create(),
                  ),
                ],
                modifier: MacroModifier.create(isStatic: true),
                keys: null,
              ),
              constantValue: 'Profile1.address2FromJson',
            ),
          ],
        ),
      ],
    ),
    MacroProperty(
      name: 'address3',
      type: 'String?',
      typeInfo: TypeInfo.string,
      keys: [
        MacroKey(
          name: 'JsonKey',
          properties: [
            MacroProperty(name: 'includeFromJson', type: 'bool', typeInfo: TypeInfo.boolean, constantValue: false),
            MacroProperty(name: 'defaultValue', type: 'String', typeInfo: TypeInfo.string, constantValue: "'rebaz'"),
            MacroProperty(name: 'includeToJson', type: 'bool', typeInfo: TypeInfo.boolean, constantValue: false),
          ],
        ),
      ],
    ),
    MacroProperty(
      name: 'address4',
      type: 'String?',
      typeInfo: TypeInfo.string,
      keys: [
        MacroKey(
          name: 'JsonKey',
          properties: [
            MacroProperty(
              name: 'includeFromJson',
              type: 'bool',
              typeInfo: TypeInfo.boolean,
              constantValue: false,
              modifier: MacroModifier.create(isNullable: true),
            ),
            MacroProperty(
              name: 'includeToJson',
              type: 'bool',
              typeInfo: TypeInfo.boolean,
              constantValue: false,
              modifier: MacroModifier.create(isNullable: true),
            ),
          ],
        ),
      ],
    ),
    MacroProperty(
      name: 'intVal',
      type: 'int?',
      typeInfo: TypeInfo.int,
      keys: [
        MacroKey(
          name: 'JsonKey',
          properties: [
            MacroProperty(
              name: 'toJson',
              type: 'Object Function(Object?)',
              typeInfo: TypeInfo.function,
              functionTypeInfo: MacroMethod(
                name: '',
                typeParams: [],
                params: [
                  MacroProperty(
                    name: 'value',
                    type: 'Object?',
                    typeInfo: TypeInfo.object,
                    modifier: MacroModifier.create(isNullable: true),
                  ),
                ],
                returns: [
                  MacroProperty(
                    name: '',
                    type: 'Object',
                    typeInfo: TypeInfo.object,
                    modifier: MacroModifier.create(),
                  ),
                ],
                modifier: MacroModifier.create(isStatic: true),
              ),
              constantValue: 'Profile1.intValueToJson',
            ),
            MacroProperty(
              name: 'includeIfNull',
              type: 'bool',
              typeInfo: TypeInfo.boolean,
              constantValue: false,
              modifier: MacroModifier.create(isNullable: true),
            ),
          ],
        ),
      ],
    ),
    MacroProperty(
      name: 'codable',
      type: 'SomeData',
      typeInfo: TypeInfo.clazz,
      extraMetadata: {
        // the fromJson of SomeData
        'fromJsonType': MacroProperty(
          name: '',
          type: 'Map<String, dynamic>',
          typeInfo: TypeInfo.map,
          typeArguments: [
            MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
            MacroProperty(name: '', type: 'dynamic', typeInfo: TypeInfo.dynamic),
          ],
        ),
      },
    ),
    MacroProperty(
      name: 'codable2',
      type: 'SomeData?',
      typeInfo: TypeInfo.clazz,
      extraMetadata: {
        // the fromJson of SomeData
        'fromJsonType': MacroProperty(
          name: '',
          type: 'Map<String, dynamic>',
          typeInfo: TypeInfo.map,
          typeArguments: [
            MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
            MacroProperty(name: '', type: 'dynamic', typeInfo: TypeInfo.dynamic),
          ],
        ),
      },
    ),
    MacroProperty(
      name: 'codable3',
      type: 'SomeData2',
      typeInfo: TypeInfo.extensionType,
      extraMetadata: {
        // the fromJson of SomeData2
        'fromJsonType': MacroProperty(name: '', type: 'int', typeInfo: TypeInfo.int),
      },
    ),
    MacroProperty(
      name: 'codable4',
      type: 'SomeData3',
      typeInfo: TypeInfo.enumData,
      extraMetadata: {
        // the fromJson of SomeData3
        'fromJsonType': MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
      },
    ),
    MacroProperty(
      name: 'list',
      type: 'List<String>',
      typeInfo: TypeInfo.list,
      deepEquality: true,
      typeArguments: [MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string)],
    ),
    MacroProperty(
      name: 'list2',
      type: 'List<String>?',
      typeInfo: TypeInfo.list,
      deepEquality: true,
      typeArguments: [MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string)],
    ),
    MacroProperty(
      name: 'list3',
      type: 'List<int?>?',
      typeInfo: TypeInfo.list,
      deepEquality: true,
      typeArguments: [MacroProperty(name: '', type: 'int?', typeInfo: TypeInfo.int)],
    ),
    MacroProperty(
      name: 'map',
      type: 'Map<String, dynamic>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
        MacroProperty(name: '', type: 'dynamic', typeInfo: TypeInfo.dynamic),
      ],
    ),
    MacroProperty(
      name: 'map1',
      type: 'Map<String, double>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
        MacroProperty(name: '', type: 'double', typeInfo: TypeInfo.double),
      ],
    ),
    MacroProperty(
      name: 'map2',
      type: 'Map<Object, double>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'Object', typeInfo: TypeInfo.object),
        MacroProperty(name: '', type: 'double', typeInfo: TypeInfo.double),
      ],
    ),
    MacroProperty(
      name: 'map3',
      type: 'Map<dynamic, double>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'dynamic', typeInfo: TypeInfo.dynamic),
        MacroProperty(name: '', type: 'double', typeInfo: TypeInfo.double),
      ],
    ),
    MacroProperty(
      name: 'map4',
      type: 'Map<dynamic, double>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'dynamic', typeInfo: TypeInfo.dynamic),
        MacroProperty(name: '', type: 'double', typeInfo: TypeInfo.double),
      ],
    ),
    MacroProperty(
      name: 'map5',
      type: 'Map<MyEnumData, int>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'MyEnumData', typeInfo: TypeInfo.enumData),
        MacroProperty(name: '', type: 'int', typeInfo: TypeInfo.int),
      ],
    ),
    MacroProperty(
      name: 'map6',
      type: 'Map<BigInt, double>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'BigInt', typeInfo: TypeInfo.bigInt),
        MacroProperty(name: '', type: 'double', typeInfo: TypeInfo.double),
      ],
    ),
    MacroProperty(
      name: 'map7',
      type: 'Map<DateTime, String>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'DateTime', typeInfo: TypeInfo.datetime),
        MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
      ],
    ),
    MacroProperty(
      name: 'map8',
      type: 'Map<int, int>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'int', typeInfo: TypeInfo.int),
        MacroProperty(name: '', type: 'int', typeInfo: TypeInfo.int),
      ],
    ),
    MacroProperty(
      name: 'map9',
      type: 'Map<Uri, int>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'Uri', typeInfo: TypeInfo.uri),
        MacroProperty(name: '', type: 'int', typeInfo: TypeInfo.int),
      ],
    ),
    MacroProperty(
      name: 'map10',
      type: 'Map<int, double>?',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'int', typeInfo: TypeInfo.int),
        MacroProperty(name: '', type: 'double', typeInfo: TypeInfo.double),
      ],
    ),
    MacroProperty(
      name: 'map11',
      type: 'Map<String, List<String>>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
        MacroProperty(
          name: '',
          type: 'List<String>',
          typeInfo: TypeInfo.list,
          typeArguments: [
            MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
          ],
        ),
      ],
    ),
    MacroProperty(
      name: 'map12',
      type: 'Map<T, String>',
      typeInfo: TypeInfo.map,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'T', typeInfo: TypeInfo.generic),
        MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
      ],
    ),
    MacroProperty(name: 'dateTime', type: 'DateTime', typeInfo: TypeInfo.datetime),
    MacroProperty(name: 'dateTime2', type: 'DateTime?', typeInfo: TypeInfo.datetime),
    MacroProperty(
      name: 'dateTime3',
      type: 'List<DateTime?>',
      typeInfo: TypeInfo.list,
      deepEquality: true,
      typeArguments: [
        MacroProperty(name: '', type: 'DateTime?', typeInfo: TypeInfo.datetime),
      ],
    ),
    MacroProperty(name: 'duration', type: 'Duration', typeInfo: TypeInfo.duration),
    MacroProperty(name: 'duration2', type: 'Duration?', typeInfo: TypeInfo.duration),
    MacroProperty(name: 'bigInt', type: 'BigInt', typeInfo: TypeInfo.bigInt),
    MacroProperty(name: 'bigInt2', type: 'BigInt?', typeInfo: TypeInfo.bigInt),
    MacroProperty(name: 'uri', type: 'Uri', typeInfo: TypeInfo.uri),
    MacroProperty(name: 'uri2', type: 'Uri?', typeInfo: TypeInfo.uri),
    MacroProperty(name: 'enumData', type: 'MyEnumData', typeInfo: TypeInfo.enumData),
    MacroProperty(name: 'enumData2', type: 'MyEnumData?', typeInfo: TypeInfo.enumData),
    MacroProperty(
      name: 'enumData3',
      type: 'MyEnumData?',
      typeInfo: TypeInfo.enumData,
      keys: [
        MacroKey(
          name: 'JsonKey',
          properties: [MacroProperty(name: 'unknownEnumValue', type: 'MyEnumData.c', typeInfo: TypeInfo.enumData)],
        ),
      ],
    ),
    MacroProperty(name: 'obj', type: 'Object', typeInfo: TypeInfo.object),
    MacroProperty(name: 'obj2', type: 'Object?', typeInfo: TypeInfo.object),
    MacroProperty(name: 'dynamicVal', type: 'dynamic', typeInfo: TypeInfo.dynamic),
  ];
  final classConstructors = [
    MacroClassConstructor(
      constructorName: 'new',
      positionalFields: const [],
      namedFields: classFields, // here its same, that's why reused the fields
    ),
  ];

  // step 2 - init and generate
  final macroState = MacroState(
    macro: MacroKey(name: 'DataClassMacro', properties: []),
    remainingMacro: [],
    targetType: TargetType.clazz,
    targetName: 'Profile1',
    modifier: MacroModifier({}),
    isCombingGenerator: false,
    suffixName: 'Data',
    classesById: null,
  );

  final gen = DataClassMacro();
  await gen.onClassFields(macroState, classFields);
  await gen.onClassConstructors(macroState, classConstructors);
  await gen.onGenerate(macroState);

  print(macroState.generated);

  final ex = Profile1(
    genericData: 0,
    genericData2: 0,
    someGeneric: SomeGeneric(data: 1),
    name: 'rebaz',
    age: 30,
    someInt: 10,
    point: 33,
    address: 'a',
    address2: 'a1',
    address3: 'rebaz',
    address4: null,
    intVal: 20,
    codable: SomeData(),
    codable2: SomeData(),
    codable3: SomeData2(1),
    codable4: SomeData3.a,
    list: ['l1', 'l2'],
    list2: null,
    list3: [],
    map: {'a': 1, 'b': true},
    map1: {'a': 1.2},
    map2: {'a': 1, 1: 2.2},
    map3: {'a': 2, 33: 44},
    map4: {'a': 2, 33: 44},
    map5: {MyEnumData.a: 2},
    map6: {BigInt.one: 2},
    map7: {DateTime.now(): 'hello'},
    map8: {1: 222},
    map9: {Uri.parse('http://aa'): 3},
    map10: {22: 33.3},
    map11: {
      'aa': ['1', '2', '3'],
    },
    map12: {1: '22'},
    dateTime: DateTime.now(),
    dateTime2: DateTime.now(),
    dateTime3: [DateTime.now(), null],
    duration: Duration(seconds: 60),
    duration2: null,
    bigInt: BigInt.two,
    bigInt2: null,
    uri: Uri.parse('http://aa'),
    uri2: null,
    enumData: MyEnumData.b,
    enumData2: MyEnumData.c,
    enumData3: null,
    obj: 'obj',
    obj2: 3333.3,
    dynamicVal: '3',
  );
  final json = ex.toJson((v) => v);
  print('main: $json');

  final ex2 = Profile1Json.fromJson(json, (v) => (v as num).toInt());
  print(ex);
  print(ex2);
  print('should be true: ${ex == ex2}');

  final ex3 = ex2.copyWith(name: 'its me', age: 33);
  print('should be false: ${ex3 == ex2}');

  final ex4 = Profile1Json.fromJson(ex3.toJson((v) => v), (v) => (v as num).toInt());
  print('should be true: ${ex4 == ex3}');

  final a = Profile1Json as dynamic;
  a.call(<String, dynamic>{});
}
