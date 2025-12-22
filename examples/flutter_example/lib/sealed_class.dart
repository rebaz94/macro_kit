import 'package:flutter_example/example_macro/json_schema_macro.dart';
import 'package:macro_kit/macro_kit.dart';

part 'sealed_class.g.dart';

@Macro(DataClassMacro(discriminatorKey: 'type'), combine: true)
@jsonSchemaMacro
sealed class Animal with AnimalData {
  Animal({required this.name});

  final String name;
}

@Macro(DataClassMacro(includeDiscriminator: true), combine: true)
@jsonSchemaMacro
class Cat extends Animal with CatData {
  final String nickName;

  Cat({required super.name, required this.nickName});
}

@Macro(DataClassMacro(discriminatorValue: Dog.checkIsDog), combine: true)
@jsonSchemaMacro
class Dog extends Animal with DogData {
  final bool big;

  static bool checkIsDog(Map<String, dynamic> json) {
    return json.containsKey('big');
  }

  Dog({required super.name, required this.big});
}
