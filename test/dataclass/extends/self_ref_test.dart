import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

part 'self_ref_test.g.dart';

@dataClassMacro
class ProfileGen1<T> with ProfileGen1Data<T> {
  ProfileGen1({
    required this.value,
    this.data,
    this.data2,
    this.data3,
  });

  final T value;
  final ProfileGen1<T>? data;
  final ProfileGen1<int>? data2;
  final ProfileGen1<String>? data3;
}

@dataClassMacro
class ProfileGen2<T, V> with ProfileGen2Data<T, V> {
  ProfileGen2({
    required this.value,
    required this.value2,
    this.data,
    this.data2,
    this.data3,
    this.data4,
    this.data5,
    this.data6,
  });

  final T value;
  final V value2;
  final ProfileGen2<T, V>? data;
  final ProfileGen2<V, T>? data2;
  final ProfileGen2<String, T>? data3;
  final ProfileGen2<V, String>? data4;
  final ProfileGen2<String, String>? data5;
  final ProfileGen2<int, int>? data6;

  // not supported, two different type for single field with self reference
  // final ProfileGen2<String, int>? data7;
}

@dataClassMacro
class ProfileGen3<T, F, V> with ProfileGen3Data<T, F, V> {
  ProfileGen3({
    required this.value,
    required this.value2,
    required this.value3,
    this.data,
    this.data2,
    this.data3,
    this.data4,
    this.data5,
    this.data6,
    this.data7,
  });

  final T value;
  final F value2;
  final V value3;
  final ProfileGen3<T, F, V>? data;
  final ProfileGen3<V, F, T>? data2;
  final ProfileGen3<String, V, T>? data3;
  final ProfileGen3<V, T, String>? data4;
  final ProfileGen3<String, T, F>? data5;
  final ProfileGen3<String, String, F>? data6;
  final ProfileGen3<String, String, String>? data7;
  // not supported, two different type for single field with self reference
  // final ProfileGen3<String, String, int>? data7;
}

void main() {
  group('Self Generic Reuse', () {
    test('Should generate for generic and initiated type-1', () {
      var a = ProfileGen1<String>(
        value: 'Rebaz',
        data: ProfileGen1(value: 'Raouf'),
      );
      var aDupe = ProfileGen1<String>(
        value: 'Rebaz',
        data: ProfileGen1(value: 'Raouf'),
      );
      final json = {
        'value': 'Rebaz',
        'data': {'value': 'Raouf'},
      };

      expect(a, equals(aDupe));
      expect(a.toJson((v) => v, (v) => v, (v) => v), equals(json));
      expect(
        ProfileGen1Data.fromJson<String>(
          json,
          (v) => v as String,
          (v) => int.parse(v.toString()),
          (v) => v as String,
        ),
        equals(a),
      );
    });

    test('Should generate for generic and initiated type-2', () {
      var a = ProfileGen2<String, String>(
        value: 'Rebaz',
        value2: 'Rebaz',
        data: ProfileGen2(value: 'Raouf', value2: 'Raouf'),
      );
      var aDupe = ProfileGen2<String, String>(
        value: 'Rebaz',
        value2: 'Rebaz',
        data: ProfileGen2(value: 'Raouf', value2: 'Raouf'),
      );
      final json = {
        'value': 'Rebaz',
        'value2': 'Rebaz',
        'data': {'value': 'Raouf', 'value2': 'Raouf'},
      };

      expect(a, equals(aDupe));
      expect(
        a.toJson(
          (v) => v,
          (v) => v,
          (v) => v,
          (v) => v,
          (v) => v,
          (v) => v,
        ),
        equals(json),
      );
      expect(
        ProfileGen2Data.fromJson<String, String>(
          json,
          (v) => v as String,
          (v) => v as String,
          (v) => v as String,
          (v) => v as String,
          (v) => v as String,
          (v) => int.parse(v.toString()),
        ),
        equals(a),
      );
    });

    test('Should generate for generic and initiated type-3', () {
      var a = ProfileGen3<String, String, String>(
        value: 'Rebaz',
        value2: 'Rebaz',
        value3: 'Mh',
        data: ProfileGen3(value: 'Raouf', value2: 'Raouf', value3: 'Mh'),
      );
      var aDupe = ProfileGen3<String, String, String>(
        value: 'Rebaz',
        value2: 'Rebaz',
        value3: 'Mh',
        data: ProfileGen3(value: 'Raouf', value2: 'Raouf', value3: 'Mh'),
      );
      final json = {
        'value': 'Rebaz',
        'value2': 'Rebaz',
        'value3': 'Mh',
        'data': {'value': 'Raouf', 'value2': 'Raouf', 'value3': 'Mh'},
      };

      expect(a, equals(aDupe));
      expect(
        a.toJson(
          (v) => v,
          (v) => v,
          (v) => v,
          (v) => v,
          (v) => v,
          (v) => v,
          (v) => v,
          (v) => v,
        ),
        equals(json),
      );
      expect(
        ProfileGen3Data.fromJson<String, String, String>(
          json,
          (v) => v as String,
          (v) => v as String,
          (v) => v as String,
          (v) => v as String,
          (v) => v as String,
          (v) => v as String,
          (v) => v as String,
          (v) => v as String,
        ),
        equals(a),
      );
    });
  });
}
