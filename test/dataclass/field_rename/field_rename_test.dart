import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

part 'field_rename_test.g.dart';

/// The annotation-level `fieldRename` takes precedence over the global config
/// (which is not set in this test context and defaults to [FieldRename.none]),
/// so JSON keys are converted to snake_case.
@Macro(DataClassMacro(fieldRename: FieldRename.snake))
class SnakeUser with SnakeUserData {
  const SnakeUser({required this.userName, required this.friendName});

  final String userName;
  final String friendName;
}

/// No `fieldRename` anywhere in the chain (annotation -> global -> none), so
/// field names are used as-is.
@dataClassMacro
class PlainUser with PlainUserData {
  const PlainUser({required this.userName});

  final String userName;
}

/// [JsonKey.name] always wins over both the annotation-level and global
/// `fieldRename`.
@Macro(DataClassMacro(fieldRename: FieldRename.snake))
class NamedUser with NamedUserData {
  const NamedUser({required this.userName});

  @JsonKey(name: 'overridden')
  final String userName;
}

void main() {
  group('DataClassMacro fieldRename', () {
    test('annotation fieldRename applies to json keys', () {
      final user = SnakeUser(userName: 'rebo', friendName: 'max');
      expect(user.toJson(), equals({'user_name': 'rebo', 'friend_name': 'max'}));
      expect(
        SnakeUserData.fromJson({'user_name': 'rebo', 'friend_name': 'max'}),
        equals(user),
      );
    });

    test('falls back to unchanged names when nothing is set', () {
      final user = PlainUser(userName: 'rebo');
      expect(user.toJson(), equals({'userName': 'rebo'}));
      expect(PlainUserData.fromJson({'userName': 'rebo'}), equals(user));
    });

    test('annotation fieldRename also applies on fromJson', () {
      expect(
        SnakeUserData.fromJson({'user_name': 'rebo', 'friend_name': 'max'}),
        equals(const SnakeUser(userName: 'rebo', friendName: 'max')),
      );
    });

    test('JsonKey.name takes precedence over fieldRename', () {
      final user = NamedUser(userName: 'rebo');
      expect(user.toJson(), equals({'overridden': 'rebo'}));
      expect(NamedUserData.fromJson({'overridden': 'rebo'}), equals(user));
    });
  });
}
