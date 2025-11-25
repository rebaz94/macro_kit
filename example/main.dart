import 'package:macro_kit/macro.dart';

part 'main.g.dart';

void main() async {
  await runMacro(
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
    },
  );

  final b = B(name: 'name', base: 1);
  final c = C<int>(name2: 'name', val: 11111, base: 1);
  final c2 = C2<int>(name2: 'name', base: 1);
  final e = E(name2: 'name', base: 1);

  final test = c;
  final aJson = test.toJson((v) => v); //ssssddddsfffdddmdd
  // final aJson = test.toJson();
  print(test);
  final t = AData.fromJson<int, int, int>(
    aJson,
    fromJsonCT: (v) => (v as num).toInt(),
    fromJsonC2T: (v) => (v as num?)?.toInt() ?? -1,
  );
  print(t == test);

  print(
    t.toJsonBy<int, int>(
      toJsonCT: (value) => value,
      toJsonC2T: (value) => value,
    ),
  );

  final r = t as C<int>;
  r.toJson((e) => e);

  final res = r.copyWithBy(
    c: (value) => value,
  );
  print(res);

  final Animal cat = Cat(nickName: 'niki', name: 'myaw');
  final catJson = cat.toJsonBy();
  final cat2 = AnimalData.fromJson(catJson);
  print(cat == cat2);
  final cat3 = cat2.copyWithBy(
    cat: (value) => value.copyWith(nickName: 'asas'),
  );
  print(cat2 == cat3);
}

//.ddssssssaj

@dataClassMacro
class Data {
  final String a;
  final B b;

  Data({required this.a, required this.b});
}

// sffdddssdsdsffdskksa

@Macro(DataClassMacro(discriminatorKey: 'type'))
sealed class A<T> with AData<T> {
  const A({required this.base});

  static A<T> fromJson<T, CT, C2T>(
    Map<String, dynamic> json, {
    required CT Function(Object? v) fromJsonCT,
    required C2T Function(Object? v) fromJsonC2T,
  }) {
    final type = json['type'];
    return switch (type) {
          'B' => BData.fromJson(json),
          'its_c' => CData.fromJson<CT>(json, fromJsonCT),
          'its_c2' => C2Data.fromJson<C2T>(json, fromJsonC2T),
          _ when E.filter(json) => EData.fromJson(json),
          _ => CData.fromJson<CT>(json, fromJsonCT),
        }
        as A<T>;
  }

  Res map2<Res, CT, C2T>({
    required Res Function(B value) b,
    required Res Function(C<CT> value) c,
    required Res Function(C2<C2T> value) c2,
    Res Function(A<T> value)? fallback,
  }) {
    return switch (this) {
      B v => b(v),
      C<CT> v => c(v),
      C2<C2T> v => c2(v),
      _ when fallback != null => fallback(this),
      _ => throw 'Invalid subtype provided',
    };
  }

  final T base;
}

@Macro(DataClassMacro(includeDiscriminator: true, defaultDiscriminator: false))
class B extends A<int> with BData {
  B({required this.name, required super.base});

  final String name;
}

@Macro(DataClassMacro(discriminatorValue: 'its_c', defaultDiscriminator: false))
class C<T> extends A<int> with CData<T> {
  C({required this.name2, required this.val, required super.base});

  final String name2;
  final T val;
}

@Macro(DataClassMacro(discriminatorValue: E.filter))
class E extends A<int> with EData {
  E({required this.name2, required super.base});

  static bool filter(Map<String, dynamic> json) => true;

  final String name2;
}

@Macro(DataClassMacro(discriminatorValue: 'its_c2'))
class C2<T> extends A<T> with C2Data<T> {
  C2({required this.name2, required super.base});

  final String name2;
}

@Macro(DataClassMacro())
sealed class Animal with AnimalData {
  Animal({required this.name});

  final String name;
}

@Macro(DataClassMacro(includeDiscriminator: true))
class Cat extends Animal with CatData {
  Cat({required this.nickName, required super.name});

  final String nickName;
}

@Macro(DataClassMacro(discriminatorValue: 'its_dog'))
class Dog extends Animal with DogData {
  Dog({required this.big, required super.name});

  final bool big;
}

@Macro(DataClassMacro())
class Cow extends Animal with DogData {
  Cow({required this.big, required super.name});

  final bool big;
}

typedef MyInt = int;

MyInt strFromJson2(Object? value) {
  return (value as num).toInt();

  ///nsmsmdsdhfddmmknksdsssnnfdddsssk;;nmknnjssjsdss
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

@Macro(DataClassMacro(primaryConstructor: null))
class Aaa<T> with AaaData<T> implements CustomB {
  factory Aaa.aaa({
    required List<List<T>> genericData,
    @MyMetadata(name: 'its data3 factory field metadatkddd')
    @JsonKey(name: 'its data3 factory field metadata')
    required List<String> data3,
    required MyInt data,
    required Bb b,
    required Bb c,
    required MyEnumData customEnum,
    required Ccc d,
    required String name,
  }) = Aaa;

  Aaa({
    @JsonKey(name: 'genData') required this.genericData,
    @MyMetadata(name: 'its data constructor field metadata') required this.data,
    required this.b,
    @MyMetadata(name: 'its c constructor field metadata ') required this.c,
    required this.data3,
    required this.customEnum,
    required this.d,
    required this.name,
  });

  final List<List<T>> genericData;

  @JsonKey(
    name: 'dataD',
    defaultValue: Ccc('a1', 'a2', e: 'eee'),
  )
  final Ccc d;

  final List<String> data3;

  @JsonKey(name: 'data', fromJson: Aaa.strFromJson, toJson: Aaa.strToJson)
  final MyInt data;

  @JsonKey(name: 'data2', defaultValue: Bb())
  final Bb b;
  @JsonKey(name: 'dataC', defaultValue: Bb.new)
  final Bb c;

  final String name;

  ///sff/d//dnsdsdsdfkfdsssdsssdxddafsdssddd

  final MyEnumData customEnum;

  String? nnn;

  @MyMetadata(name: 'its hello with metadata')
  void hello<Ccc>(
    void Function(String name) fn1,
    Ccc data,
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
    throw 'sfsdssss';
  }

  void aabb() {
    // hello(data);
  }

  @MyMetadata(name: 'its field naa with metadata n')
  static String naaaa = '';

  @MyMetadata(name: 'its _myName with metadata')
  String _myName = 'dd';

  String get aa => _myName;

  @MyMetadata(name: 'its var133 with metadata')
  var var133 = 'dddd';

  // String get myName => _myName;////ss

  // set myName(String value) {
  //   _myName = value;
  // }

  static Bb bFact() => Bb();

  static MyInt strFromJson(Object? value) {
    return (value as num).toInt();
  }

  static String strToJson(MyInt value) {
    return value.toString();
  }
}

@dataClassMacro
class Bb with BbData {
  const Bb();

  ///kdsaskksssssdsdjskdds/sssss
}

@dataClassMacro
class Ccc with CccData{
  const Ccc(this.a, this.b, {this.d, required this.e, this.aaaaa});

  final String a;
  final String b;
  final String? d;
  final String? e;

  @JsonKey(name: 'cccusjtokkhjjmdd', fromJson: aFromJson, toJson: aToJson)
  final Aaa<int>? aaaaa;

  static Aaa<int> aFromJson(Map<String, dynamic> json) {
    return AaaData.fromJson(json, (v) => v as int);
  }

  static Map<String, dynamic>? aToJson(Aaa<int>? obj) {
    return obj?.toJson((v) => v);
  }
}

@Macro(DataClassMacro())
class Test<T1, T2, T3, T4> with TestData {
  final String name;

  Test({required this.name});
}

enum MyEnumData { a, b, c }

