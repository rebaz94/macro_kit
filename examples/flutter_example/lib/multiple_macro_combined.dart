import 'package:flutter_example/example_macro/json_schema_macro.dart';
import 'package:macro_kit/macro_kit.dart';

part 'multiple_macro_combined.g.dart';

@dataClassMacroCombined
@jsonSchemaMacro
class UserProfile with UserProfileData {
  const UserProfile({required this.username, required this.email, required this.age, required this.roles});

  @JsonField(
    description: 'Must be 3-20 characters, lowercase letters and numbers only.',
    minLength: 3,
    maxLength: 20,
    pattern: r'^[a-z0-9]+$',
  )
  final String username;

  @JsonField(format: 'email', description: 'A valid email address.')
  final String email;

  @JsonField(minimum: 18, description: 'Optional age, must be 18 or older.')
  final int? age;

  @JsonField(uniqueItems: true, description: 'Optional list of user roles, must be unique.')
  final List<String>? roles;
}

@dataClassMacroCombined
@jsonSchemaMacro
class UserProfile2 extends UserProfile with UserProfile2Data {
  const UserProfile2({
    required super.username,
    required super.email,
    required super.age,
    required super.roles,
    required this.customData,
  });

  @JsonKey(name: 'CustomData')
  final int customData;
}
