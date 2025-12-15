import 'package:example/models.dart';
import 'package:macro_kit/macro_kit.dart';

void main() async {
  await runMacro(
    package: PackageInfo('example'),
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
    },
    enabled: true,
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
