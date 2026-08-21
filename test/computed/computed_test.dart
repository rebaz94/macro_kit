import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

part 'computed_test.g.dart';

@dataClassMacro
class Test with TestData  {
  Test({required this.id, required this.name});

  final String id;
  final String name;
}


@Macro(ComputeMacro())
final versionMacro = compute(() => 2.toString());

void main() {
  group('Primitive value', () {
    test('version', () => expect(version, '2'));
    test('test class', () => expect(Test(id: '1', name: 'aa'), Test(id: '1', name: 'aa')));
  });
}