import 'package:macro_kit/macro.dart';

part 'main.g.dart';

void main() async {
  await runMacro(
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
    },
  );

  final profile = UserProfile(name: 'Rebaz', age: 30);
  print(
    [
      profile.toJson(),
      profile.toString(),
      profile.copyWith(name: 'Rebe'),
    ].join('\n'),
  );

  print('-----');

  Animal animal = Cat(nickName: 'Niki', name: 'Lala');
  print(
    [
      animal.toJsonBy(),
      animal.copyWithBy(cat: (value) => value.copyWith(name: 'Nik')),
    ].join('\n'),
  );

  print('-----');

  Cat cat = CatData.fromJson(animal.toJsonBy());
  print(
    [
      cat.toJson(),
      cat.copyWith(name: 'Myaw'),
    ].join('\n'),
  );

  print('-----');

  final dog = Dog(big: true, name: 'Iby');
  final dog2 = AnimalData.fromJson(dog.toJson());
  print(dog2 == dog);
}

@dataClassMacro
class UserProfile with UserProfileData {
  UserProfile({required this.name, required this.age});

  final String name;
  final int age;
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

@Macro(DataClassMacro(discriminatorValue: 'bow'))
class Cow extends Animal with DogData {
  Cow({required this.big, required super.name});

  final bool big;
}
