import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

part 'record_test.g.dart';

typedef TypeDefTuple = (String, {int year});
typedef TypeDefTupleGen<T> = (String, {T year, bool active});

@dataClassMacro
class TupleModel with TupleModelData {
  TupleModel({
    required this.value1,
    required this.value2,
    required this.value3,
    required this.value4,
    required this.value5,
    required this.value6,
    this.value7,
    required this.value8,
  });

  final (String, int) value1;
  final (String, int, {bool flag, String? name}) value2;
  final TypeDefTuple value3;
  final TypeDefTupleGen<int> value4;
  final (String, {String year, bool active}) value5;
  final (String, {int year, bool active}) value6;
  final (String, int)? value7;
  final TypeDefTupleGen<String> value8;
}

@dataClassMacro
class TupleModel2<T> with TupleModel2Data<T> {
  TupleModel2({
    required this.value1,
    required this.value2,
    required this.value3,
    required this.value4,
    required this.value5,
    required this.value6,
    this.value7,
    required this.value8,
  });

  final (String, T) value1;
  final (String, T, {bool flag, String? name}) value2;
  final TypeDefTuple value3;
  final TypeDefTupleGen<int> value4;
  final (String, {String year, bool active}) value5;
  final (String, {int year, bool active}) value6;
  final (String, int)? value7;
  final TypeDefTupleGen<String> value8;
}

void main() {
  group(
    'Record Serialization',
    () {
      test('from json success-1', () {
        expect(
          TupleModelData.fromJson({
            'value1': {r'$1': 'hi', r'$2': 100},
            'value2': {r'$1': 'hi', r'$2': 100, 'flag': true},
            'value3': {r'$1': 'hi', 'year': 2026},
            'value4': {r'$1': 'hi', 'year': 2026, 'active': true},
            'value5': {r'$1': 'hi', 'year': '2025', 'active': false},
            'value6': {r'$1': 'hi', 'year': 2025, 'active': false},
            'value8': {r'$1': 'hi', 'year': '2026', 'active': true},
          }),
          TupleModel(
            value1: ('hi', 100),
            value2: ('hi', 100, flag: true, name: null),
            value3: ('hi', year: 2026),
            value4: ('hi', year: 2026, active: true),
            value5: ('hi', year: '2025', active: false),
            value6: ('hi', year: 2025, active: false),
            value8: ('hi', year: '2026', active: true),
          ),
        );
      });

      test('to json succeeds-1', () {
        final a = TupleModelData.fromJson({
          'value1': {r'$1': 'hi', r'$2': 100},
          'value2': {r'$1': 'hi', r'$2': 100, 'flag': true},
          'value3': {r'$1': 'hi', 'year': 2026},
          'value4': {r'$1': 'hi', 'year': 2026, 'active': true},
          'value5': {r'$1': 'hi', 'year': '2025', 'active': false},
          'value6': {r'$1': 'hi', 'year': 2025, 'active': false},
          'value8': {r'$1': 'hi', 'year': '2026', 'active': true},
        });

        final json = {
          'value1': {r'$1': 'hi', r'$2': 100},
          'value2': {r'$1': 'hi', r'$2': 100, 'flag': true},
          'value3': {r'$1': 'hi', 'year': 2026},
          'value4': {r'$1': 'hi', 'year': 2026, 'active': true},
          'value5': {r'$1': 'hi', 'year': '2025', 'active': false},
          'value6': {r'$1': 'hi', 'year': 2025, 'active': false},
          'value8': {r'$1': 'hi', 'year': '2026', 'active': true},
        };
        expect(a.toJson(), equals(json));
        expect(TupleModelData.fromJson(json), equals(a));
      });

      test('from json success-2', () {
        expect(
          TupleModel2Data.fromJson<int>(
            {
              'value1': {r'$1': 'hi', r'$2': 100},
              'value2': {r'$1': 'hi', r'$2': 100, 'flag': true, 'name': 'rebaz'},
              'value3': {r'$1': 'hi', 'year': 2026},
              'value4': {r'$1': 'hi', 'year': 2026, 'active': true},
              'value5': {r'$1': 'hi', 'year': '2025', 'active': false},
              'value6': {r'$1': 'hi', 'year': 2025, 'active': false},
              'value8': {r'$1': 'hi', 'year': '2026', 'active': true},
            },
            (v) => v as int,
          ),
          TupleModel2(
            value1: ('hi', 100),
            value2: ('hi', 100, flag: true, name: 'rebaz'),
            value3: ('hi', year: 2026),
            value4: ('hi', year: 2026, active: true),
            value5: ('hi', year: '2025', active: false),
            value6: ('hi', year: 2025, active: false),
            value8: ('hi', year: '2026', active: true),
          ),
        );
      });

      test('to json succeeds-2', () {
        final a = TupleModel2Data.fromJson(
          {
            'value1': {r'$1': 'hi', r'$2': 100},
            'value2': {r'$1': 'hi', r'$2': 100, 'flag': true, 'name': 'rebaz'},
            'value3': {r'$1': 'hi', 'year': 2026},
            'value4': {r'$1': 'hi', 'year': 2026, 'active': true},
            'value5': {r'$1': 'hi', 'year': '2025', 'active': false},
            'value6': {r'$1': 'hi', 'year': 2025, 'active': false},
            'value8': {r'$1': 'hi', 'year': '2026', 'active': true},
          },
          (v) => v as int,
        );

        final json = {
          'value1': {r'$1': 'hi', r'$2': 100},
          'value2': {r'$1': 'hi', r'$2': 100, 'flag': true, 'name': 'rebaz'},
          'value3': {r'$1': 'hi', 'year': 2026},
          'value4': {r'$1': 'hi', 'year': 2026, 'active': true},
          'value5': {r'$1': 'hi', 'year': '2025', 'active': false},
          'value6': {r'$1': 'hi', 'year': 2025, 'active': false},
          'value8': {r'$1': 'hi', 'year': '2026', 'active': true},
        };
        expect(a.toJson((v) => v), equals(json));
        expect(
          TupleModel2Data.fromJson(
            json,
            (v) => v as int,
          ),
          equals(a),
        );
      });
    },
  );
}
