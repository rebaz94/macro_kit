import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

part 'param_rewrite_test.g.dart';

@dataClassMacro
class A with AData {
  A(this.a, int? b, int c) : b = b ?? 0, _c = c;

  final int a;
  final int b;
  final int _c;
}

@dataClassMacro
class B with BData {
  const B(int a, int b) : a = b, b = a;

  final int a;
  final int b;
}

@dataClassMacro
class C with CData {
  const C(this.name);

  final String name;
}

void main() {
  group('param rewrite explicitly', () {
    test('from json succeeds', () {
      var a = AData.fromJson({'a': 1, 'c': 3});
      expect(a, equals(A(1, 0, 3)));
    });

    test('from json succeeds-2', () {
      var a = AData.fromJson({'a': 1, 'b': 1, 'c': 3});
      expect(a, equals(A(1, 1, 3)));
    });

    test('to json succeeds', () {
      var a = A(1, 2, 3);
      expect(a.toJson(), equals({'a': 1, 'b': 2, 'c': 3}));
    });

    test('swapped from json succeeds', () {
      var b = BData.fromJson({'a': 1, 'b': 2});
      expect(b.toString(), r"B{a: 1, b: 2}"); // rewrite param
      expect(b.copyWith(), equals(b));
      expect(b, equals(B(1, 2)));
    });

    test('swapped to json succeeds', () {
      var b = B(1, 2);
      expect(b.toString(), r"B{a: 1, b: 2}");
      expect(b.copyWith(), equals(b));
      expect(b.toJson(), equals({'a': 1, 'b': 2}));
    });
  });
}
