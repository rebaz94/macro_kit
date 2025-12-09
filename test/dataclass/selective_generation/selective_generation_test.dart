import 'dart:convert';

import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

part 'selective_generation_test.g.dart';

@Macro(DataClassMacro(fromJson: false, toJson: true, copyWith: true, toStringOverride: false, equal: false))
class A with AData {
  final String a;

  A(this.a);
}

@Macro(DataClassMacro(fromJson: false, toJson: false, copyWith: false, toStringOverride: true, equal: true))
class B with BData {
  final String b;

  B(this.b);
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
  });
}
