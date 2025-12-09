import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

import '../../utils/utils.dart';

part 'basic_serialization.g.dart';

@dataClassMacro
class A with AData {
  final String a;
  final int b;
  final double? c;
  final bool d;
  final B? e;
  final String? f;
  final Map<String, int> map;
  final Set<int> set1;
  final Set<int> set2;
  final SomeConst someConst;
  final SomeConst? someConst2;

  A(
    this.a, {
    this.b = 0,
    this.c,
    required this.d,
    this.e,
    this.f = "a \\' name",
    this.map = const {'a ^ \' name': 1},
    this.set1 = const {1, 2, 3},
    required this.set2,
    this.someConst = const SomeConst('hello', value: 3),
    this.someConst2 = const SomeConst('hello', value: 3),
  });
}

@dataClassMacro
class SomeConst with SomeConstData {
  const SomeConst(this.name, {required this.value});

  final String name;
  final int value;
}

enum B { a, bB, ccCc }

@Macro(DataClassMacro())
class ClassA with ClassAData {
  const ClassA(this.someVariable);

  @JsonKey(unknownEnumValue: EnumValue(EnumA.unknown))
  final Map<EnumA, bool> someVariable;
}

@Macro(DataClassMacro())
class ClassB with ClassBData {
  const ClassB(this.someVariable);

  @JsonKey(unknownEnumValue: EnumValue.of([EnumA.unknown, EnumB.unknown]))
  final Map<EnumA, EnumB?> someVariable;
}

enum EnumA { a, aa, unknown }

enum EnumB {
  a(0),
  aa(1),
  unknown(2);

  const EnumB(this.value);

  final int value;
}

void main() {
  group(
    'Basic Serialization',
    () {
      test('from json success-1', () {
        expect(
          AData.fromJson({
            'a': 'hi',
            'd': false,
            'set2': [3, 4],
          }),
          A('hi', d: false, set2: {3, 4}),
        );

        expect(
          AData.fromJson({
            'a': 'test',
            'b': 1,
            'c': 0.5,
            'd': true,
            'set2': [3, 4],
          }),
          equals(A('test', b: 1, c: 0.5, d: true, set2: {3, 4})),
        );
      });

      test('from json success-2', () {
        var a = ClassA({EnumA.a: true, EnumA.aa: false});
        var b = ClassA({EnumA.aa: false, EnumA.a: true});

        expect(ClassAData.fromJson({'someVariable': {'a': true, 'aa': false}}), a);
        expect(ClassAData.fromJson({'someVariable': {'aa': false, 'a': true}}), b);

        expect(
          ClassAData.fromJson({
            'someVariable': {'a': true, 'not_exist': false},
          }),
          ClassA({EnumA.a: true, EnumA.unknown: false}),
        );
      });

      test('from json success-3', () {
        var a = ClassB({EnumA.a: EnumB.a, EnumA.aa: EnumB.aa});
        var b = ClassB({EnumA.aa: EnumB.aa, EnumA.a: EnumB.a});

        expect(ClassBData.fromJson({'someVariable': {'a': 'a', 'aa': 'aa'}}), a);
        expect(ClassBData.fromJson({'someVariable': {'aa': 'aa', 'a': 'a'}}), b);

        expect(
          ClassBData.fromJson({
            'someVariable': {'a': 'not_exist', 'not_exist': 'not_exist'},
          }),
          ClassB({EnumA.a: EnumB.unknown, EnumA.unknown: EnumB.unknown}),
        );
      });

      test('from map throws', () {
        expect(
          () => AData.fromJson({
            'a': 'hi',
            'set2': [3, 4],
          }),
          throwsTypeError(r"type 'Null' is not a subtype of type 'bool' in type cast"),
        );

        expect(
          () => AData.fromJson({
            'a': 'ok',
            'b': 'fail',
            'd': false,
            'set2': [3, 4],
          }),
          throwsTypeError(r"type 'String' is not a subtype of type 'num?' in type cast"),
        );
      });

      test('to json succeeds-1', () {
        final a = A('hi', d: false, e: B.bB, set2: {3, 4});
        final json = {
          'a': 'hi',
          'b': 0,
          'd': false,
          'e': 'bB',
          'f': 'a \\\' name',
          'map': {'a ^ \' name': 1},
          'set1': [1, 2, 3],
          'set2': [3, 4],
          'someConst': {'name': 'hello', 'value': 3},
          'someConst2': {'name': 'hello', 'value': 3},
        };
        expect(a.toJson(), equals(json));
        expect(AData.fromJson(json), equals(a));

        expect(
          A('test', b: 1, c: 0.5, d: true, set2: {3, 4}).toJson(),
          equals({
            'a': 'test',
            'b': 1,
            'c': 0.5,
            'd': true,
            'f': 'a \\\' name',
            'map': {'a ^ \' name': 1},
            'set1': [1, 2, 3],
            'set2': [3, 4],
            'someConst': {'name': 'hello', 'value': 3},
            'someConst2': {'name': 'hello', 'value': 3},
          }),
        );
      });

      test('to json succeeds-2', () {
        var a = ClassA({EnumA.a: true, EnumA.aa: false});
        var b = ClassA({EnumA.aa: false, EnumA.a: true});

        expect(ClassAData.fromJson(a.toJson()), a);
        expect(ClassAData.fromJson(b.toJson()), b);
      });

      test('from json success-4', () {
        var a = ClassB({EnumA.a: EnumB.a, EnumA.aa: EnumB.aa});
        var b = ClassB({EnumA.aa: EnumB.aa, EnumA.a: EnumB.a});

        expect(ClassBData.fromJson(a.toJson()), a);
        expect(ClassBData.fromJson(b.toJson()), b);
      });

    },
  );
}
