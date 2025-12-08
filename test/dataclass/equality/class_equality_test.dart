import 'package:macro_kit/macro.dart';
import 'package:test/test.dart';

part 'class_equality_test.g.dart';

@dataClassMacro
class A with AData {
  A(this.a, {this.b = 0, this.c, required this.d, this.e});

  final String a;
  final int b;
  final double? c;
  final bool d;
  final B? e;
}

enum B { a, bB, ccCc }

@dataClassMacro
abstract class Base with BaseData {
  final String data;

  Base(this.data);
}

@Macro(DataClassMacro(includeDiscriminator: true))
class Sub extends Base with SubData {
  Sub(super.data);
}

@Macro(DataClassMacro(includeDiscriminator: true))
class Sub2 extends Base with Sub2Data {
  Sub2(super.data, this.data2);

  final String data2;
}

@Macro(DataClassMacro(discriminatorKey: 'disType'))
sealed class BaseType with BaseTypeData {
  BaseType(this.type);

  final String type;
}

@Macro(DataClassMacro(includeDiscriminator: true, discriminatorValue: 'SubType1', discriminatorKey: 'disType'))
class SubType extends BaseType with SubTypeData {
  SubType(super.type);
}

@Macro(DataClassMacro(includeDiscriminator: true, discriminatorKey: 'disType'))
class SubType2 extends BaseType with SubType2Data {
  SubType2(super.type);
}

@dataClassMacro
class Generic<T> with GenericData<T> {
  Generic(this.data);

  final T data;
}

@dataClassMacro
class Wrapper<T> with WrapperData<T> {
  Wrapper(this.value1, this.value2, this.value3);

  final Generic<T> value1;
  final Generic<String> value2;
  final T value3;
}

@dataClassMacro
class Wrapper2<T, E> with Wrapper2Data<T, E> {
  Wrapper2(this.value1, this.value2, this.value3);

  final Generic<T> value1;
  final Generic<String> value2;
  final T value3;
}

@Macro(DataClassMacro(discriminatorKey: 'disType'))
sealed class BaseTypeGen<T> with BaseTypeGenData<T> {
  BaseTypeGen(this.base);

  final T base;
}

@Macro(DataClassMacro(includeDiscriminator: true, discriminatorValue: 'SubType1', discriminatorKey: 'disType'))
class SubTypeGen extends BaseTypeGen<String> with SubTypeGenData {
  SubTypeGen(super.base);
}

@Macro(DataClassMacro(includeDiscriminator: true, discriminatorKey: 'disType'))
class SubType2Gen extends BaseTypeGen<String> with SubType2GenData {
  SubType2Gen(super.base);
}

void main() {
  group('class equality', () {
    test('of basic class', () {
      var a = A('abc', b: 2, c: 0.5, d: true, e: B.bB);
      var a2 = A('abc', b: 2, c: 0.5, d: true, e: B.bB);

      expect(a, equals(a2));
      expect(a == a2, isTrue);
    });

    test('of subclass', () {
      var sub = Sub('abc');
      var subDupe = Sub('abc');
      var subDif = Sub('def');

      var sub2 = Sub2('abc', 'aa');
      var sub2Dupe = Sub2('abc', 'aa');
      var sub2Dif = Sub2('def', 'aa');

      expect(sub, equals(subDupe));
      expect(sub, isNot(equals(subDif)));

      expect(sub2, equals(sub2Dupe));
      expect(sub2, isNot(equals(sub2Dif)));

      expect(sub, isNot(equals(sub2)));

      expect(sub == subDupe, isTrue);
      expect(sub == sub2Dif, isFalse);
    });

    test('of discriminated subclass', () {
      var sub = SubType('abc');
      var subDupe = SubType('abc');
      var subDif = SubType('def');

      var sub2 = SubType2('abc');
      var subDupe2 = SubType2('abc');
      var subDif2 = SubType2('def');

      expect(sub, equals(subDupe));
      expect(sub, isNot(equals(subDif)));

      expect(sub == subDupe, isTrue);
      expect(sub == subDif, isFalse);

      expect(sub2, equals(subDupe2));
      expect(sub2, isNot(equals(subDif2)));

      expect(sub2 == subDupe2, isTrue);
      expect(sub2 == subDif2, isFalse);

      expect(sub, isNot(equals(sub2)));
      expect(sub == sub2, isFalse);
    });

    test('of generic class', () {
      var g = Generic<String>('abc');
      var gDupe = Generic<String>('abc');
      var gNull = Generic<String?>('abc');
      var gNullDupe = Generic<String?>('abc');
      var g2 = Generic<String>('def');

      expect(g, equals(gDupe));
      expect(g, isNot(equals(gNull)));

      expect(gNull, equals(gNullDupe));
      expect(gNull, isNot(equals(g)));
      expect(g, isNot(equals(g2)));

      expect(g == gDupe, isTrue);
      expect(g == gNull, isFalse);
      expect(gNull == gNullDupe, isTrue);
      expect(gNull == g, isFalse);
      expect(g == g2, isFalse);
    });

    test('of wrapper class-1', () {
      var w = Wrapper<String>(Generic<String>('abc'), Generic<String>('xyz'), 'swe');
      var wDupe = Wrapper<String>(Generic<String>('abc'), Generic<String>('xyz'), 'swe');
      var wNull = Wrapper<String?>(Generic<String?>('abc'), Generic<String>('xyz'), 'swe');
      var wNullDupe = Wrapper<String?>(Generic<String?>('abc'), Generic<String>('xyz'), 'swe');
      var wNullNotInner = Wrapper<String?>(Generic<String>('abc'), Generic<String>('xyz'), 'swe');
      var w2 = Wrapper<String>(Generic<String>('def'), Generic<String>('xyz'), 'swe');

      expect(w, equals(wDupe));
      expect(w, isNot(equals(wNull)));
      expect(w, isNot(equals(wNullDupe)));

      expect(wNull, isNot(equals(w)));
      expect(wNull, equals(wNullDupe));
      expect(wNullDupe, isNot(equals(w)));
      expect(wNullDupe, equals(wNull));
      expect(wNullNotInner, isNot(equals(wNull)));
      expect(wNullNotInner == wNull, isFalse);

      expect(w, isNot(equals(w2)));
      expect(wNull, isNot(equals(w2)));
      expect(wNullDupe, isNot(equals(w2)));
      expect(w2, isNot(equals(wNull)));
      expect(w2, isNot(equals(wNullDupe)));
    });

    test('of wrapper class-2', () {
      var w = Wrapper2<String, int>(Generic<String>('abc'), Generic<String>('xyz'), 'swe');
      var wDupe = Wrapper2<String, int>(Generic<String>('abc'), Generic<String>('xyz'), 'swe');
      var wNull = Wrapper2<String?, int>(Generic<String?>('abc'), Generic<String>('xyz'), 'swe');
      var wNullReal = Wrapper2<String?, int>(Generic<String?>('abc'), Generic<String>('xyz'), 'swe');
      var w2 = Wrapper2<String, int>(Generic<String>('def'), Generic<String>('xyz'), 'swe');

      expect(w, equals(wDupe));
      expect(w, isNot(equals(wNull)));
      expect(w, isNot(equals(wNullReal)));

      expect(wNull, isNot(equals(w)));
      expect(wNull, equals(wNullReal));
      expect(wNullReal, isNot(equals(w)));
      expect(wNullReal, equals(wNull));

      expect(w, isNot(equals(w2)));
      expect(wNull, isNot(equals(w2)));
      expect(wNullReal, isNot(equals(w2)));
      expect(w2, isNot(equals(wNull)));
      expect(w2, isNot(equals(wNullReal)));
    });

    test('of discriminated subclass - generic', () {
      var sub = SubTypeGen('abc');
      var subDupe = SubTypeGen('abc');
      var subDif = SubTypeGen('def');

      var sub2 = SubType2Gen('abc');
      var subDupe2 = SubType2Gen('abc');
      var subDif2 = SubType2Gen('def');

      expect(sub, equals(subDupe));
      expect(sub, isNot(equals(subDif)));

      expect(sub == subDupe, isTrue);
      expect(sub == subDif, isFalse);

      expect(sub2, equals(subDupe2));
      expect(sub2, isNot(equals(subDif2)));

      expect(sub2 == subDupe2, isTrue);
      expect(sub2 == subDif2, isFalse);

      expect(sub, isNot(equals(sub2)));
      expect(sub == sub2, isFalse);
    });
  });
}
