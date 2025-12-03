import 'package:macro_kit/macro.dart';
import 'package:test/test.dart';

part 'encoding_params_test.g.dart';

@dataClassMacro
class A with AData {
  final String a;
  final B? b;

  A(this.a, {this.b});
}

enum B { a, bB, ccCc }

void main() {
  group('encoding params serialization', () {
    test('encodes', () {
      expect(A('hi', b: B.bB).toJson(), equals({'a': 'hi', 'b': 'bB'}));
    });
  });
}
