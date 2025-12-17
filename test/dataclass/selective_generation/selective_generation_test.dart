import 'dart:convert';

import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

part 'selective_generation_test.g.dart';

@Macro(DataClassMacro(fromJson: false, toJson: true, copyWith: true, toStringOverride: false, equal: false))
class A with AData {
  A(this.a);

  final String a;
}

@Macro(DataClassMacro(fromJson: false, toJson: false, copyWith: false, toStringOverride: true, equal: true))
class B with BData {
  B(this.b);

  final String b;
}

@Macro(DataClassMacro(copyWithAsOption: true))
class C with CData {
  C(this.c, this.c2);

  final String? c;

  @JsonKey(copyWithAsOption: false)
  final String? c2;
}

@dataClassMacro
class E with EData {
  E(this.e, this.e2);

  @JsonKey(copyWithAsOption: true)
  final String? e;

  @JsonKey(copyWithAsOption: false)
  final String? e2;
}

void main() {
  group('Selective generation', () {
    test('Should only generate encode and copy methods', () {
      var a = A('test');

      // should work
      expect(a.toJson(), equals({'a': 'test'}));
      expect(jsonEncode(a.toJson()), equals('{"a":"test"}'));
      expect(a.copyWith(a: 'test2').a, equals('test2'));

      // should not work
      expect(a, isNot(equals(A('test'))));
      expect(a.toString(), equals("Instance of 'A'"));
    });

    test('Should only generate equals and stringify', () {
      var b = B('hi');

      // should work
      expect(b, equals(B('hi')));
      expect(b.toString(), equals('B{b: hi}'));

      // should not work
      expect(() => (b as dynamic).toJson, throwsNoSuchMethodError);
      expect(() => (b as dynamic).copyWith, throwsNoSuchMethodError);
    });

    test('Should generate copyWith with dataclass option', () {
      var c = C('hi', null);

      // should work
      expect(c, equals(C('hi', null)));
      expect(c.toString(), equals('C{c: hi, c2: null}'));
      expect(c.copyWith(c: Option.value('test2')).c, equals('test2'));
      expect(c.copyWith(c2: null).c, equals('hi'));
    });

    test('Should generate copyWith with key option', () {
      var e = E('hi', null);

      // should work
      expect(e, equals(E('hi', null)));
      expect(e.toString(), equals('E{e: hi, e2: null}'));
      expect(e.copyWith(e: Option.value('test2')).e, equals('test2'));
      expect(e.copyWith(e2: null).e, equals('hi'));
    });
  });
}
