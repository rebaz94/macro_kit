import 'dart:convert';
import 'dart:core' as $c;

import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

import 'other/models.dart' as m;

part 'import_complex.g.dart';

@dataClassMacro
class MyProfile with MyProfileData {
  MyProfile({
    required this.info,
    required this.age,
    required this.lives,
    required this.livesNum,
    required this.isDead,
    required this.bigInt,
    required this.uri,
    required this.symbol,
    required this.dynamicVal,
    required this.myEnum,
    required this.address,
    required this.date,
    required this.duration,
    required this.myIter,
    required this.myList,
    required this.mySet,
    required this.map1,
    required this.map2,
    required this.future,
  });

  static m.Person infoFromJson($c.Map<$c.String, $c.dynamic> json) {
    return m.PersonData.fromJson(json);
  }

  static $c.Future<$c.String> futureFromJson($c.Object? data) {
    return $c.Future.value('');
  }

  @JsonKey(fromJson: infoFromJson)
  final m.Person info;
  final $c.int age;
  final $c.double lives;
  final $c.num livesNum;
  final $c.bool isDead;
  final $c.BigInt bigInt;
  final $c.Uri uri;
  final $c.Symbol symbol;
  final $c.dynamic dynamicVal;
  final MyEnum myEnum;
  final $c.String address;
  final $c.DateTime date;
  final $c.Duration duration;
  final $c.Iterable<$c.String> myIter;
  final $c.List<$c.String> myList;
  final $c.Set<$c.int> mySet;
  final $c.Map<$c.String, $c.int> map1;
  final $c.Map<$c.String, m.Person> map2;

  @JsonKey(fromJson: futureFromJson, includeToJson: false)
  final $c.Future<$c.String> future;
}

enum MyEnum { a, b, c }

void main() {
  group('import types', () {
    test('DataClass are generated correctly', () {
      final value = MyProfile(
        info: m.Person('niki'),
        age: 10,
        lives: 3,
        livesNum: 2.2,
        isDead: true,
        bigInt: $c.BigInt.two,
        uri: $c.Uri.parse('http://hello.com'),
        symbol: #hello,
        dynamicVal: -1,
        myEnum: MyEnum.b,
        address: 'us',
        date: $c.DateTime(2025, 12, 7),
        duration: $c.Duration(seconds: 10),
        myIter: ['hello', 'data', 'class'],
        myList: ['1', '2'],
        mySet: {1, 2, 3},
        map1: {'aa': 11},
        map2: {'name1': m.Person('rebaz')},
        future: $c.Future.value('yep'),
      );

      expect(
        jsonEncode(value.toJson()),
        equals(
          r'{"info":{"firstName":"niki"},"age":10,"lives":3.0,"livesNum":2.2,"isDead":true,"bigInt":"2","uri":"http://hello.com","symbol":"Symbol(\"hello\")","dynamicVal":-1,"myEnum":"b","address":"us","date":"2025-12-07T00:00:00.000","duration":10000000,"myIter":["hello","data","class"],"myList":["1","2"],"mySet":[1,2,3],"map1":{"aa":11},"map2":{"name1":{"firstName":"rebaz"}}}',
        ),
      );

      final updatedAge = value.copyWith(age: 30);
      expect(updatedAge != value, true);

      expect(
        jsonEncode(updatedAge),
        equals(
          r'{"info":{"firstName":"niki"},"age":30,"lives":3.0,"livesNum":2.2,"isDead":true,"bigInt":"2","uri":"http://hello.com","symbol":"Symbol(\"hello\")","dynamicVal":-1,"myEnum":"b","address":"us","date":"2025-12-07T00:00:00.000","duration":10000000,"myIter":["hello","data","class"],"myList":["1","2"],"mySet":[1,2,3],"map1":{"aa":11},"map2":{"name1":{"firstName":"rebaz"}}}',
        ),
      );
    });
  });
}
