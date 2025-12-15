import 'package:macro_kit/macro_kit.dart';

part 'models.g.dart';

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
