import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

part 'enum_map_test.g.dart';

enum EnumA { a, aa, unknown }

enum EnumB {
  a(0),
  aa(1),
  unknown(2);

  const EnumB(this.value);

  final int value;
}

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

void main() {
  group('enum map', () {
    test('equality-1', () {
      var a = ClassA({EnumA.a: true, EnumA.aa: false});
      var b = ClassA({EnumA.aa: false, EnumA.a: true});
      expect(a == b, isTrue);
    });

    test('equality-2', () {
      var a = ClassB({EnumA.a: EnumB.a, EnumA.aa: EnumB.aa});
      var b = ClassB({EnumA.a: EnumB.a, EnumA.aa: EnumB.aa});
      expect(a == b, isTrue);
    });

    test('toString-1', () {
      var a = ClassA({EnumA.a: true, EnumA.aa: false});
      expect(
        a.toString(),
        equals('ClassA{someVariable: {EnumA.a: true, EnumA.aa: false}}'),
      );
    });

    test('toString-2', () {
      var a = ClassB({EnumA.a: EnumB.a, EnumA.aa: EnumB.aa});
      expect(
        a.toString(),
        equals('ClassB{someVariable: {EnumA.a: EnumB.a, EnumA.aa: EnumB.aa}}'),
      );
    });
  });
}
