import 'package:macro_kit/macro.dart';
import 'package:test/test.dart';

import '../../utils/utils.dart';

part 'basic_serialization.g.dart';

@dataClassMacro
class A with AData {
  final String a;
  final int b;
  final double? c;
  final bool d;
  final B? e;

  A(this.a, {this.b = 0, this.c, required this.d, this.e});
}

enum B { a, bB, ccCc }

void main() {
  group(
    'Basic Serialization',
    () {
      test('from json success', () {
        expect(
          AData.fromJson({'a': 'hi', 'd': false}),
          A('hi', d: false),
        );

        expect(
          AData.fromJson({'a': 'test', 'b': 1, 'c': 0.5, 'd': true}),
          equals(A('test', b: 1, c: 0.5, d: true)),
        );
      });

      test('from map throws', () {
        expect(
          () => AData.fromJson({'a': 'hi'}),
          throwsTypeError(r"type 'Null' is not a subtype of type 'bool' in type cast"),
        );

        expect(
          () => AData.fromJson({'a': 'ok', 'b': 'fail', 'd': false}),
          throwsTypeError(r"type 'String' is not a subtype of type 'num?' in type cast"),
        );
      });

      test('to json succeeds', () {
        expect(
          A('hi', d: false, e: B.bB).toJson(),
          equals({'a': 'hi', 'b': 0, 'd': false, 'e': 'bB'}),
        );
        expect(
          A('test', b: 1, c: 0.5, d: true).toJson(),
          equals({'a': 'test', 'b': 1, 'c': 0.5, 'd': true}),
        );
      });
    },
  );
}
