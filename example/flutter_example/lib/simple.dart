import 'package:flutter_example/example_macro/record_macro.dart';
import 'package:macro_kit/macro_kit.dart';

part 'simple.g.dart';

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

@Macro(DataClassMacro(copyWithAsOption: true))
class UserProfile2 with UserProfile2Data {
  const UserProfile2({
    required this.name,
    this.age,
    this.address,
  });

  @JsonKey(name: 'UserName')
  final String name;
  final int? age;

  @JsonKey(copyWithAsOption: false)
  final String? address;
}

@Macro(RecordMacro())
typedef AddressInfo<T> = ({T data, String? country, String building});

@dataClassMacro
class UserProfile3 with UserProfile3Data {
  const UserProfile3({
    required this.name,
    this.age,
    this.address,
    required this.address2,
  });

  @JsonKey(name: 'UserName')
  final String name;

  @JsonKey(copyWithAsOption: true)
  final int? age;

  @JsonKey(copyWithAsOption: true)
  final (String, {String? country, String building})? address;

  @JsonKey(copyWithAsOption: true)
  final AddressInfo<String>? address2;
}

void test() {
  var profile = UserProfile(name: 'Rebaz', age: 20);
  print(profile.copyWith(age: 30));

  final cat = Cat(name: 'Niki', nickName: 'niko');
  print(cat);

  var profile2 = UserProfile2(name: 'Rebaz', age: 30, address: null);
  profile2 = profile2.copyWith(age: Option.nil());
  // profile2 = profile2.copyWith(age: .nil()); // required dot shorthand feature
  // profile2 = profile2.copyWith(age: .value(33)); // required dot shorthand feature
  print(profile2);

  final recordToMacroClass = ClsAddressInfo(building: 'building', data: 'data');
  print(recordToMacroClass);
}
