import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

import 'dart_type_param_macro.dart';

part 'dart_type_test.g.dart';

@dataClassMacro
class UserProfile with UserProfileData {
  UserProfile({required this.name, required this.age});

  final String name;
  final int age;
}

const allKeyOpt = MyKey(
  type: String,
  set2: {String},
  list1: [String, int],
  list2: [
    [int],
  ],
  list3: [
    {int, double},
  ],
  map1: {'A': Future<String>},
  map2: {
    'A2': [bool],
  },
  map3: {
    'A3': [
      [double],
    ],
  },
);

@Macro(CustomMacro(type: UserProfile, types: [UserProfile, int, String]))
class Test {
  Test({
    required this.f1,
    required this.f2,
    required this.f3,
    required this.f4,
    required this.f5,
    required this.f6,
  });

  @allKeyOpt
  final String f1;

  @MyKey(type: int)
  final int f2;

  @MyKey(type: UserProfile)
  final UserProfile f3;

  @MyKey(type: List<int>)
  final List<int> f4;

  @MyKey(type: List<UserProfile>)
  final List<UserProfile> f5;

  @MyKey(type: List<Type>)
  final List<Type> f6;
}

void main() {
  final types = TestCustom().types;
  Object? get(String name) => types[name];

  group('get dart:Type info at runtime from macro', () {
    test('type from macro generator success', () {
      expect(get('singleType') == UserProfile, isTrue);
      expect(get('list0Type') == UserProfile, isTrue);
      expect(get('list1Type') == int, isTrue);
      expect(get('list2Type') == String, isTrue);
    });

    test('type from custom key success', () {
      expect(get('f1Type') == String, isTrue);
      expect(get('f2Type') == int, isTrue);
      expect(get('f3Type') == UserProfile, isTrue);
      expect(get('f4Type') == List<int>, isTrue);
      expect(get('f5Type') == List<UserProfile>, isTrue);
      expect(get('f6Type') == List<Type>, isTrue);
    });

    test('supported key type', () {
      expect(get('f1Set2Type0') == String, isTrue);
      expect(get('f1List1Type0') == String, isTrue);
      expect(get('f1List1Type1') == int, isTrue);
      expect(get('f1List2Type00') == int, isTrue);
      expect(get('f1List3Type00') == int, isTrue);
      expect(get('f1List3Type01') == double, isTrue);
      expect(get('f1Map1TypeA0') == Future<String>, isTrue);
      expect(get('f1Map2TypeA200') == bool, isTrue);
      expect(get('f1Map3TypeA3000') == double, isTrue);
    });
  });
}
