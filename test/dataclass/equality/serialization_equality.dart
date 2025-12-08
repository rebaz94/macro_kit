import 'package:test/test.dart';

import 'class_equality_test.dart';

typedef G = Generic<String>;
typedef GN = Generic<String?>;
typedef W = Wrapper<String>;
typedef WN = Wrapper<String?>;
typedef WO = Wrapper<Object>;
typedef WD = Wrapper<dynamic>;

void main() {
  group('serialization equality', () {
    test('of basic class', () {
      var a = A('abc', b: 2, c: 0.5, d: true, e: B.bB);

      expect(a, equals(AData.fromJson(a.toJson())));
      expect(a, equals(AData.fromJson(a.toJson())));
    });

    test('of subclass', () {
      var sub = Sub('abc');
      var sub2 = Sub2('abc', 'xyz');

      expect(sub, equals(SubData.fromJson(sub.toJson())));
      expect(sub2, equals(Sub2Data.fromJson(sub2.toJson())));

      expect(sub, equals(BaseData.fromJson(sub.toJson())));
      expect(sub2, equals(BaseData.fromJson(sub2.toJson())));
    });

    test('of discriminated subclass', () {
      var sub = SubType('SubType');
      var sub2 = SubType2('SubType');

      expect(sub, equals(SubTypeData.fromJson(sub.toJson())));
      expect(sub2, equals(SubType2Data.fromJson(sub2.toJson())));

      expect(sub, equals(BaseTypeData.fromJson(sub.toJson())));
      expect(sub2, equals(BaseTypeData.fromJson(sub2.toJson())));
    });

    test('of generic class', () {
      var g = Generic<String>('abc');
      var gNull = Generic<String?>('abc');

      expect(
        g,
        equals(
          GenericData.fromJson(
            g.toJson((v) => v),
            (v) => v as String,
          ),
        ),
      );
      expect(
        gNull,
        equals(
          GenericData.fromJson(
            gNull.toJson((v) => v),
            (v) => v as String?,
          ),
        ),
      );
    });

    test('of wrapper class', () {
      var w = Wrapper<String>(Generic<String>('abc'), Generic<String>('xyz'), 'swe');
      var wNull = Wrapper<String?>(Generic<String?>('abc'), Generic<String>('xyz'), 'swe');
      var wNullNotInner = Wrapper<String?>(Generic<String>('abc'), Generic<String>('xyz'), 'swe');
      var wObj = Wrapper<Object>(Generic<String>('abc'), Generic<String>('xyz'), 'swe');
      var wObj2 = Wrapper<Object>(Generic<Object>(Generic<String>('abc')), Generic<String>('xyz'), 'swe');
      var wDyn = Wrapper<dynamic>(Generic<dynamic>(Generic<String>('abc')), Generic<String>('xyz'), 'swe');

      expect(
        w,
        equals(
          WrapperData.fromJson<String>(
            w.toJson((v) => v, (v) => v),
            (v) => v as String,
            (v) => v as String,
          ),
        ),
      );
      expect(
        wNull,
        equals(
          WrapperData.fromJson<String?>(
            wNull.toJson((v) => v, (v) => v),
            (v) => v as String?,
            (v) => v as String,
          ),
        ),
      );
      expect(
        wNullNotInner,
        isNot(
          equals(
            WrapperData.fromJson<String?>(
              wNullNotInner.toJson((v) => v, (v) => v),
              (v) => v as String?,
              (v) => v as String,
            ),
          ),
        ),
      );
      expect(
        Wrapper<String?>(Generic<String?>('abc'), Generic<String>('xyz'), 'swe'),
        equals(
          WrapperData.fromJson<String?>(
            wNullNotInner.toJson((v) => v, (v) => v),
            (v) => v as String?,
            (v) => v as String,
          ),
        ),
      );

      expect(
        wObj,
        isNot(
          equals(
            WrapperData.fromJson<Object>(
              wObj.toJson((v) => v, (v) => v),
              (v) => v as Object,
              (v) => v as String,
            ),
          ),
        ),
      );
      expect(
        Wrapper<Object>(Generic<Object>('abc'), Generic<String>('xyz'), 'swe'),
        equals(
          WrapperData.fromJson<Object>(
            wObj.toJson((v) => v, (v) => v),
            (v) => v as Object,
            (v) => v as String,
          ),
        ),
      );

      expect(
        wObj2,
        equals(
          WrapperData.fromJson<Object>(
            wObj2.toJson((v) => v, (v) => v),
            (v) => v as Object,
            (v) => v as String,
          ),
        ),
      );
      expect(
        wDyn,
        equals(
          WrapperData.fromJson<dynamic>(
            wDyn.toJson((v) => v, (v) => v),
            (v) => v,
            (v) => v as String,
          ),
        ),
      );
    });
  });
}
