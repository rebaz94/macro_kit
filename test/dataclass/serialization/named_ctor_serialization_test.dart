import 'dart:convert';

import 'package:macro_kit/macro.dart';
import 'package:test/test.dart';

part 'named_ctor_serialization_test.g.dart';

@dataClassMacro
class A with AData {
  const A(this.a, this.b, this.c);

  const A.filled(this.a) : b = 1, c = const C(2);

  final int a;
  final int b;
  final C c;
}

@Macro(DataClassMacro(primaryConstructor: '.filled'))
class A2 with A2Data {
  A2(this.a, this.b, this.c);

  const A2.filled(this.a) : b = 1, c = const C(2);

  final int a;
  final int b;
  final C c;
}

@dataClassMacro
class B extends A with BData {
  B(super.a, super.b, this.d, super.c);

  final int d;
}

@dataClassMacro
class C with CData {
  const C(this.x);

  final int x;
}

void main() {
  group('named serialization', () {
    test('primary constructor', () {
      var b = A(1, 2, C(3));
      expect(jsonEncode(b.toJson()), equals('{"a":1,"b":2,"c":{"x":3}}'));
    });

    test('named constructor', () {
      var b = A2.filled(99);
      expect(jsonEncode(b.toJson()), equals('{"a":99}'));
    });

    test('to json succeeds', () {
      var b = B(3, 5, 0, C(2));
      expect(jsonEncode(b.toJson()), equals('{"a":3,"b":5,"d":0,"c":{"x":2}}'));
    });
  });
}
