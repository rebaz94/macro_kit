import 'dart:core' as $c;

import 'package:macro_kit/macro.dart';
import 'package:test/test.dart';

import 'other/food.dart' as f;
import 'other/models.dart' as m;

part 'import.g.dart';

@dataClassMacro
class MyProfile with MyProfileData {
  MyProfile({
    required this.info,
    required this.age,
    required this.address,
    required this.apple,
    required this.bread,
    required this.cake,
    required this.myEnum,
  });

  final m.Person info;
  final $c.int age;
  final $c.String address;
  final f.Apple apple;
  final f.Bread bread;
  final f.Cake cake;
  final m.MyEnum myEnum;
}

@dataClassMacro
sealed class Animal with AnimalData {
  Animal({required this.name});

  final $c.String name;
}

@Macro(DataClassMacro(includeDiscriminator: true))
class Dog extends Animal with DogData {
  Dog({required super.name, required this.breed});

  final $c.String breed;
}

@Macro(DataClassMacro(includeDiscriminator: true))
class Cat extends Animal with CatData {
  Cat({
    required super.name,
    required this.lives,
  });

  final $c.int lives;
}

@Macro(DataClassMacro(includeDiscriminator: true, discriminatorValue: 'BigCow'))
class Cow<CowDataType> extends Animal with CowData<CowDataType> {
  Cow({
    required super.name,
    required this.data,
  });

  final CowDataType data;
}

@dataClassMacro
class Generic<T> with GenericData<T> {
  Generic({required this.data});

  final T data;
}

void main() {
  group('import types', () {
    test('DataClass are generated correctly', () {
      expect(m.Person('Tom').toJson(), equals({'firstName': 'Tom'}));
      expect(f.Cake('Lemon').toJson(), equals({'type': 'Lemon'}));
      expect(m.Person('Anna').toJson(), equals({'firstName': 'Anna'}));

      expect(
        AnimalData.fromJson<$c.String>(
          {
            'type': 'Cat',
            'name': 'niki',
            'lives': 10,
          },
          fromJsonCowDataType: (v) => v as $c.String,
        ),
        equals(Cat(name: 'niki', lives: 10)),
      );

      final cowBoy = AnimalData.fromJson<$c.String>(
        {
          'type': 'BigCow',
          'name': 'Mooww',
          'data': 'custom milky data',
        },
        fromJsonCowDataType: (v) => v as $c.String,
      );

      expect(cowBoy, equals(Cow(name: 'Mooww', data: 'custom milky data')));

      expect(
        cowBoy.copyWithBy<$c.String>(
          cow: (value) => value.copyWith(data: 'I have a new milk'),
        ),
        equals(Cow(name: 'Mooww', data: 'I have a new milk')),
      );

      expect(
        Generic<$c.String>(data: 'data'),
        equals(Generic<$c.String>(data: 'data')),
      );

      expect(
        Generic<$c.String>(data: 'hello data').toJson((v) => v),
        equals({'data': 'hello data'}),
      );

      expect(
        Generic<$c.String>(data: 'hello data').toString(),
        equals('Generic<String>{data: hello data}'),
      );
    });
  });
}
