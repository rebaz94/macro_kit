import 'package:macro_kit/macro.dart';
import 'package:test/test.dart';

import '../../utils/utils.dart';

part 'nested_serialization_test.g.dart';

@dataClassMacro
class Person with PersonData {
  final String name;
  final int age;
  final Car? car;

  Person(this.name, {this.age = 18, this.car});
}

// ignore: constant_identifier_names
enum Brand { Toyota, Audi, BMW }

@dataClassMacro
class Car with CarData {
  final double miles;

  @JsonKey(unknownEnumValue: EnumValue(Brand.Audi))
  final Brand brand;

  const Car(int drivenKm, this.brand) : miles = drivenKm * 0.62;

  int get drivenKm => (miles / 0.62).round();
}

void main() {
  group('nested serialization', () {
    test('from map succeeds', () {
      expect(
        PersonData.fromJson({
          'name': 'Max',
          'age': 18,
          'car': {'drivenKm': 1000, 'brand': 'audi'},
        }),
        equals(Person('Max', car: const Car(1000, Brand.Audi))),
      );
      expect(
        PersonData.fromJson({'name': 'Eva', 'age': 21}),
        equals(Person('Eva', age: 21)),
      );
    });

    test('from map throws', () {
      expect(
        () => PersonData.fromJson({'name': 'Andi', 'car': 'None'}),
        throwsTypeError(r"type 'String' is not a subtype of type 'Map<String, dynamic>' in type cast"),
      );
    });

    test('to map succeeds', () {
      expect(
        Person('Max', car: const Car(1000, Brand.Audi)).toJson(),
        equals({
          'name': 'Max',
          'age': 18,
          'car': {'drivenKm': 1000, 'brand': 'Audi'},
        }),
      );

      expect(
        Person('Eva', age: 21).toJson(),
        equals({'name': 'Eva', 'age': 21}),
      );
    });
  });
}
