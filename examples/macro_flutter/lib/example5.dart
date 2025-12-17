import 'package:macro_kit/macro_kit.dart';

part 'example5.g.dart';

@Macro(DataClassMacro(copyWithAsOption: true))
class UserProfile5 with UserProfile5Data {
  const UserProfile5({
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

@dataClassMacro
class UserProfile6 with UserProfile6Data {
  const UserProfile6({
    required this.name,
    this.age,
    this.address,
  });

  @JsonKey(name: 'UserName')
  final String name;

  @JsonKey(copyWithAsOption: true)
  final int? age;

  final String? address;
}