import 'package:macro_kit/macro.dart';

part 'food.g.dart';

@dataClassMacro
class Apple with AppleData {
  final bool isRed;

  Apple(this.isRed);
}

@dataClassMacro
class Bread with BreadData {
  final int slices;

  Bread(this.slices);
}

@dataClassMacro
class Cake with CakeData {
  final String type;

  Cake(this.type);
}
