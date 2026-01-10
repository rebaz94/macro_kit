import 'package:macro_kit/macro_kit.dart';

part 'models.g.dart';

@dataClassMacro
class Person with PersonData {
  final String firstName;

  Person(this.firstName);
}

enum MyEnum { a, b, c }

typedef MyData = (int, int);
