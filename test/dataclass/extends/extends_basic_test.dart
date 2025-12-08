import 'package:macro_kit/macro.dart';
import 'package:test/test.dart';

part 'extends_basic_test.g.dart';

@dataClassMacro
class A with AData {
  A(this.data);

  final String data;
}

@dataClassMacro
class B extends A with BData {
  B(super.data);
}

@dataClassMacro
class A1 with A1Data {
  A1(this.data);

  final String? data;
}

@dataClassMacro
class B1 extends A1 with B1Data {
  B1(@JsonKey(name: 'custom') super.data);
}

@dataClassMacro
class A2 with A2Data {
  A2(String? data) : dataVar = data ?? 'default';
  final String dataVar;
}

@dataClassMacro
class B2 extends A2 with B2Data {
  B2(super.data);
}

@dataClassMacro
class A3 with A3Data {
  A3(String? data) : _dataVar = data ?? 'default';
  final String _dataVar;
}

@dataClassMacro
class B3 extends A3 with B3Data {
  B3(super.data);
}

@Macro(DataClassMacro(primaryConstructor: '.aa'))
class A4 with A4Data {
  A4.aa(String? data) : _dataVar = data ?? 'default';
  final String _dataVar;
}

@Macro(DataClassMacro(primaryConstructor: '.bb'))
class B4 extends A4 with B4Data {
  B4.bb(super.data) : super.aa();
}

@Macro(DataClassMacro(primaryConstructor: '.aa'))
class A5 with A5Data {
  A5.aa(String? data) : _dataVar = data ?? 'default';
  final String _dataVar;
}

@dataClassMacro
class B5 extends A5 with B5Data {
  B5(super.data) : super.aa();
}

@Macro(DataClassMacro(primaryConstructor: '.aa'))
class A6 with A6Data {
  @JsonKey(name: 'data')
  final String dataVar;

  A6.aa(String? data) : dataVar = data ?? 'default';
}

@dataClassMacro
class B6 extends A6 with B6Data {
  // ignore: use_super_parameters
  B6(String? dataValue, this.a2) : super.aa(dataValue);

  final String a2;
}

@Macro(DataClassMacro())
class ANormal<T> with ANormalData<T> {
  ANormal(this.name, this.data);

  final String name;
  final T data;
}

@Macro(DataClassMacro())
class BNormal<T> extends ANormal<T> with BNormalData<T> {
  BNormal(super.name, super.data);
}

@Macro(DataClassMacro())
class ANormal1<T> with ANormal1Data<T> {
  ANormal1({required this.name, required this.data});

  final String name;
  final T data;
}

@Macro(DataClassMacro())
class BNormal1<T> extends ANormal1<T> with BNormal1Data<T> {
  BNormal1({required super.data, super.name = 'Rebaz'});
}

@dataClassMacro
class A7<T> with A7Data<T> {
  A7(this.data, this.gen);

  final String data;
  final T gen;
}

@dataClassMacro
class B7<T> extends A7<T> with B7Data<T> {
  B7(super.data, super.gen);
}

@Macro(DataClassMacro(primaryConstructor: '.aa'))
class A8<T> with A8Data<T> {
  A8.aa(T data2) : _dataVar = data2;
  final T _dataVar;
}

@Macro(DataClassMacro(primaryConstructor: '.bb'))
class B8<T> extends A8<T> with B8Data<T> {
  B8.bb(super.data2) : super.aa();
}

@Macro(DataClassMacro())
class Complex<T> with ComplexData<T> {
  Complex(
    this.data, {
    this.name,
    int? age,
    required this.data2,
    T? data3,
  }) : age = age ?? 0,
       age2 = 10,
       _data3 = data3;

  final T data;
  final String? name;
  final int age;
  final int age2;
  final T data2;
  final T? _data3;
}

@Macro(DataClassMacro())
class ComplexSub<T> extends Complex<T> with ComplexSubData<T> {
  ComplexSub(super.data, {super.name, required super.data2, super.data3, super.age});
}

void main() {
  group('Class with extends', () {
    test('Should generate super parameter', () {
      var a = A('Rebaz');
      var aDupe = A('Rebaz');

      var b = B('Rebaz');
      var bDupe = B('Rebaz');

      final A bb = b;

      expect(a.toJson(), equals({'data': 'Rebaz'}));
      expect(a.copyWith(data: 'Tom').data, equals('Tom'));
      expect(a, equals(aDupe));

      expect(b.toJson(), equals({'data': 'Rebaz'}));
      expect(b.copyWith(data: 'Tom').data, equals('Tom'));
      expect(b, equals(bDupe));

      expect(bb.toJson(), equals({'data': 'Rebaz'}));

      expect(b, isA<B>());
      expect(b, isA<A>());
    });

    test('Should generate super parameter with customized key', () {
      var a = A1('Rebaz');
      var aDupe = A1('Rebaz');

      var b = B1('Rebaz');
      var bDupe = B1('Rebaz');

      final A1 bb = b;

      expect(a.toJson(), equals({'data': 'Rebaz'}));
      expect(a.copyWith(data: 'Tom').data, equals('Tom'));
      expect(a, equals(aDupe));

      expect(b.toJson(), equals({'custom': 'Rebaz'}));
      expect(b.copyWith(data: 'Tom').data, equals('Tom'));
      expect(b, equals(bDupe));

      expect(bb.toJson(), equals({'custom': 'Rebaz'}));

      expect(b, isA<B1>());
      expect(b, isA<A1>());
    });

    test('Should generate super parameter with initializer', () {
      var a = A2('Rebaz');
      var aDupe = A2('Rebaz');

      var b = B2('Rebaz');
      var bDupe = B2('Rebaz');

      final A2 bb = b;

      expect(a.toJson(), equals({'data': 'Rebaz'}));
      expect(a.copyWith(dataVar: 'Tom').dataVar, equals('Tom'));
      expect(a, equals(aDupe));

      expect(b.toJson(), equals({'data': 'Rebaz'}));
      expect(b.copyWith(dataVar: 'Tom').dataVar, equals('Tom'));
      expect(b, equals(bDupe));

      expect(bb.toJson(), equals({'data': 'Rebaz'}));

      expect(b, isA<B2>());
      expect(b, isA<A2>());
    });

    test('Should generate super parameter with private initializer', () {
      var a = A3('Rebaz');
      var aDupe = A3('Rebaz');

      var b = B3('Rebaz');
      var bDupe = B3('Rebaz');

      final A3 bb = b;

      expect(a.toJson(), equals({'data': 'Rebaz'}));
      expect(a.copyWith(data: 'Tom')._dataVar, equals('Tom'));
      expect(a, equals(aDupe));

      expect(b.toJson(), equals({'data': 'Rebaz'}));
      expect(b.copyWith(data: 'Tom')._dataVar, equals('Tom'));
      expect(b, equals(bDupe));

      expect(bb.toJson(), equals({'data': 'Rebaz'}));

      expect(b, isA<B3>());
      expect(b, isA<A3>());
    });

    test('Should generate super parameter with private initializer and custom constructor', () {
      var a = A4.aa('Rebaz');
      var aDupe = A4.aa('Rebaz');

      var b = B4.bb('Rebaz');
      var bDupe = B4.bb('Rebaz');

      final A4 bb = b;

      expect(a.toJson(), equals({'data': 'Rebaz'}));
      expect(a.copyWith(data: 'Tom')._dataVar, equals('Tom'));
      expect(a, equals(aDupe));

      expect(b.toJson(), equals({'data': 'Rebaz'}));
      expect(b.copyWith(data: 'Tom')._dataVar, equals('Tom'));
      expect(b, equals(bDupe));

      expect(bb.toJson(), equals({'data': 'Rebaz'}));

      expect(b, isA<B4>());
      expect(b, isA<A4>());
    });

    test('Should generate super parameter with private initializer and same constructor name', () {
      var a = A5.aa('Rebaz');
      var aDupe = A5.aa('Rebaz');

      var b = B5('Rebaz');
      var bDupe = B5('Rebaz');

      final A5 bb = b;

      expect(a.toJson(), equals({'data': 'Rebaz'}));
      expect(a.copyWith(data: 'Tom')._dataVar, equals('Tom'));
      expect(a, equals(aDupe));

      expect(b.toJson(), equals({'data': 'Rebaz'}));
      expect(b.copyWith(data: 'Tom')._dataVar, equals('Tom'));
      expect(b, equals(bDupe));

      expect(bb.toJson(), equals({'data': 'Rebaz'}));

      expect(b, isA<B5>());
      expect(b, isA<A5>());
    });

    test('Should generate super parameter with private initializer and passing super manually', () {
      var a = A6.aa('Rebaz');
      var aDupe = A6.aa('Rebaz');

      var b = B6('Rebaz', 'Rauf');
      var bDupe = B6('Rebaz', 'Rauf');

      final A6 bb = b;

      expect(a.toJson(), equals({'data': 'Rebaz'}));
      expect(a.copyWith(dataVar: 'Tom').dataVar, equals('Tom'));
      expect(a, equals(aDupe));

      expect(b.toJson(), equals({'dataValue': 'Rebaz', 'a2': 'Rauf'}));
      expect(b.copyWith(dataVar: 'Tom').dataVar, equals('Tom'));
      expect(b, equals(bDupe));

      expect(bb.toJson(), equals({'dataValue': 'Rebaz', 'a2': 'Rauf'}));

      expect(b, isA<B6>());
      expect(b, isA<A6>());
    });

    test('Should generate super parameter with generic', () {
      var a = ANormal('Rebaz', 30);
      var aDupe = ANormal('Rebaz', 30);

      var b = BNormal('Rebaz', 30);
      var bDupe = BNormal('Rebaz', 30);

      final ANormal<int> bb = b;

      expect(a.toJson((v) => v), equals({'name': 'Rebaz', 'data': 30}));
      expect(a.copyWith(name: 'Tom').name, equals('Tom'));
      expect(a.copyWith(data: 10).data, equals(10));
      expect(a, equals(aDupe));

      expect(b.toJson((v) => v), equals({'name': 'Rebaz', 'data': 30}));
      expect(b.copyWith(name: 'Tom').name, equals('Tom'));
      expect(b.copyWith(data: 10).data, equals(10));
      expect(b, equals(bDupe));

      expect(bb.toJson((v) => v), equals({'name': 'Rebaz', 'data': 30}));

      expect(b, isA<BNormal>());
      expect(b, isA<ANormal>());
    });

    test('Should generate super parameter with generic + default', () {
      var a = ANormal1(name: 'Rebaz', data: 30);
      var aDupe = ANormal1(name: 'Rebaz', data: 30);

      var b = BNormal1(data: 30);
      var bDupe = BNormal1(data: 30);

      final ANormal1<int> bb = b;

      expect(a.toJson((v) => v), equals({'name': 'Rebaz', 'data': 30}));
      expect(a.copyWith(name: 'Tom').name, equals('Tom'));
      expect(a.copyWith(data: 10).data, equals(10));
      expect(a, equals(aDupe));

      expect(b.toJson((v) => v), equals({'name': 'Rebaz', 'data': 30}));
      expect(b.copyWith(name: 'Tom').name, equals('Tom'));
      expect(b.copyWith(data: 10).data, equals(10));
      expect(b, equals(bDupe));

      expect(bb.toJson((v) => v), equals({'name': 'Rebaz', 'data': 30}));

      expect(b, isA<BNormal1>());
      expect(b, isA<ANormal1>());
    });

    test('Should generate super parameter with initializer + generic', () {
      var a = A7('Rebaz', 1);
      var aDupe = A7('Rebaz', 1);

      var b = B7('Rebaz', 1);
      var bDupe = B7('Rebaz', 1);

      final A7<int> bb = b;

      expect(a.toJson((v) => v), equals({'data': 'Rebaz', 'gen': 1}));
      expect(a.copyWith(data: 'Tom').data, equals('Tom'));
      expect(a.copyWith(gen: 2).gen, equals(2));
      expect(a, equals(aDupe));

      expect(b.toJson((v) => v), equals({'data': 'Rebaz', 'gen': 1}));
      expect(b.copyWith(data: 'Tom').data, equals('Tom'));
      expect(b.copyWith(gen: 2).gen, equals(2));
      expect(b, equals(bDupe));

      expect(bb.toJson((v) => v), equals({'data': 'Rebaz', 'gen': 1}));

      expect(b, isA<B7>());
      expect(b, isA<A7>());
    });

    test('Should generate super parameter with private initializer + generic', () {
      var a = A8.aa('Rebaz');
      var aDupe = A8.aa('Rebaz');

      var b = B8.bb('Rebaz');
      var bDupe = B8.bb('Rebaz');

      final A8<String> bb = b;

      expect(a.toJson((v) => v), equals({'data2': 'Rebaz'}));
      expect(a.copyWith(data2: 'Tom')._dataVar, equals('Tom'));
      expect(a, equals(aDupe));

      expect(b.toJson((v) => v), equals({'data2': 'Rebaz'}));
      expect(b.copyWith(data2: 'Tom')._dataVar, equals('Tom'));
      expect(b, equals(bDupe));

      expect(bb.toJson((v) => v), equals({'data2': 'Rebaz'}));

      expect(b, isA<B8>());
      expect(b, isA<A8>());
    });

    test('Should generate super parameter with initializer + generic and default', () {
      var a = Complex(99, name: 'Rebaz', age: 30, data2: 10, data3: 30);
      var aDupe = Complex(99, name: 'Rebaz', age: 30, data2: 10, data3: 30);

      var b = ComplexSub(99, name: 'Rebaz', age: 30, data2: 10, data3: 30);
      var bDupe = ComplexSub(99, name: 'Rebaz', age: 30, data2: 10, data3: 30);

      final Complex<int> bb = b;

      expect(a.toJson((v) => v), equals({'data': 99, 'name': 'Rebaz', 'age': 30, 'data2': 10, 'data3': 30}));
      expect(a.copyWith(data: 10).data, equals(10));
      expect(a.copyWith(age: 33).age, equals(33));
      expect(a.copyWith(data3: 33)._data3, equals(33));
      expect(a, equals(aDupe));

      expect(b.toJson((v) => v), equals({'data': 99, 'name': 'Rebaz', 'age': 30, 'data2': 10, 'data3': 30}));
      expect(b.copyWith(data: 10).data, equals(10));
      expect(b.copyWith(age: 33).age, equals(33));
      expect(b.copyWith(data3: 33)._data3, equals(33));
      expect(b, equals(bDupe));


      expect(bb.toJson((v) => v), equals({'data': 99, 'name': 'Rebaz', 'age': 30, 'data2': 10, 'data3': 30}));

      expect(b, isA<ComplexSub<int>>());
      expect(b, isA<ComplexSub<int>>());
    });
  });
}
