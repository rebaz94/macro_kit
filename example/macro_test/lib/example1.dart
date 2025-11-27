import 'package:macro_kit/macro.dart';

part 'example1.g.dart';

@dataClassMacro
class UserProfile with UserProfileData {
  const UserProfile({required this.name, required this.age});

  @JsonKey(name: 'UserName')
  final String name;
  final int age;
}

@dataClassMacro
sealed class Animal with AnimalData {
  Animal({required this.name});

  final String name;
}

@Macro(DataClassMacro(includeDiscriminator: true))
class Cat extends Animal with CatData {
  final String nickName;

  Cat({required super.name, required this.nickName});
}

@Macro(DataClassMacro(discriminatorValue: Dog.checkIsDog))
class Dog extends Animal with DogData {
  final bool big;

  static bool checkIsDog(Map<String, dynamic> json) {
    return json.containsKey('big');
  }

  Dog({required super.name, required this.big});
}
