// ignore_for_file: unused_element

import 'dart:math';

import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

part 'compute_all_test.g.dart';

// ============================================================
// Stub types for non-Flutter tests
// ============================================================

class Color {
  final int _value;

  const Color(this._value);

  int toARGB32() => _value;
  static const green = Color(0xFF00FF00);
}

// ============================================================
// Same-file dependencies (used by deps: [...] tests)
// ============================================================

final data = 32;
final appVersion = '2.1.0';
final appName = 'MyApp';
final maxRetries = 3;
final timeoutMs = 5000;
final List<String> _tagList = ['alpha', 'beta', 'gamma'];

// ============================================================
// 1. Primitive literals (no encode/decode) — auto-serialization
// ============================================================

@Macro(ComputeMacro())
final _stringValMacro = compute(() => 'hello world');

@Macro(ComputeMacro())
final _intValMacro = compute(() => 42);

@Macro(ComputeMacro())
final _doubleValMacro = compute(() => 3.14);

@Macro(ComputeMacro())
final _boolValMacro = compute(() => true);

@Macro(ComputeMacro())
final _nullValMacro = compute(() => null);

@Macro(ComputeMacro())
final _negativeIntMacro = compute(() => -100);

@Macro(ComputeMacro())
final _zeroValMacro = compute(() => 0);

@Macro(ComputeMacro())
final _emptyStringMacro = compute(() => '');

// ============================================================
// 2. String interpolation / concatenation — auto-serialization
// ============================================================

@Macro(ComputeMacro())
final _interpolationMacro = compute(() => 'year=${2026}');

@Macro(ComputeMacro())
// ignore: prefer_adjacent_string_concatenation
final _concatMacro = compute(() => 'foo' + 'bar');

// ============================================================
// 3. Block body (not arrow) — auto-serialization
// ============================================================

@Macro(ComputeMacro())
final _blockBodyMacro = compute(() {
  final x = 10;
  final y = 20;
  return x + y;
});

@Macro(ComputeMacro())
final _blockBodyStringMacro = compute(() {
  final parts = ['a', 'b', 'c'];
  return parts.join('-');
});

// ============================================================
// 4. Collections (List, Map) — auto-serialization
// ============================================================

@Macro(ComputeMacro())
final _listValMacro = compute(() => [1, 2, 3]);

@Macro(ComputeMacro())
final _mapValMacro = compute(() => {'a': 1, 'b': 2});

@Macro(ComputeMacro())
final _nestedListMacro = compute(
  () => [
    [1, 2],
    [3, 4],
  ],
);

@Macro(ComputeMacro())
final _nestedMapMacro = compute(
  () => {
    'users': {'alice': 1, 'bob': 2},
  },
);

@Macro(ComputeMacro())
final _emptyListMacro = compute(() => <String>[]);

@Macro(ComputeMacro())
final _emptyMapMacro = compute(() => <String, int>{});

// ============================================================
// 5. DartCode — raw Dart source embedding
// ============================================================

@Macro(ComputeMacro())
final _dartCodeSimpleMacro = compute<DartCode>(() => DartCode('2 | 10'));

@Macro(ComputeMacro())
final _dartCodeExprMacro = compute<DartCode>(
  () => DartCode('Duration(seconds: ${5 * 60})'),
);

@Macro(ComputeMacro())
final _dartCodeBypassMacro = compute<DartCode>(
  () => DartCode('Color(0xFF${123.toRadixString(16).padLeft(6, '0')})'),
);

// ============================================================
// 6. Custom serialization (encode/decode)
// ============================================================

@Macro(ComputeMacro())
final _encodeStringMacro = compute(
  () => 'hello',
  encode: (v) => v.toUpperCase(),
  decode: (v) => "'$v'",
);

@Macro(ComputeMacro())
final _encodeIntMacro = compute(
  () => 42,
  encode: (v) => (v * 2).toString(),
  decode: (v) => v,
);

@Macro(ComputeMacro())
final _myFavColorMacro = compute(
  () => Color.green,
  encode: (value) => value.toARGB32().toString(),
  decode: (value) => 'Color($value)',
);

// ============================================================
// 7. toString() in compute body — auto-serialization
// ============================================================

@Macro(ComputeMacro())
final _versionMacro = compute(() => 1.toString());

// ============================================================
// 8. deps: same-file variables (list literal)
// ============================================================

@Macro(ComputeMacro())
final _myAgeMacro = compute(
  () => 'MyAge: $data',
  deps: [data],
);

@Macro(ComputeMacro())
final _depsSameFileMacro = compute(
  () => '$appName v$appVersion',
  deps: [appVersion, appName],
);

// ============================================================
// 9. deps: function from same file
// ============================================================

String buildLabel(String name, String version) => '$name-$version';

@Macro(ComputeMacro())
final _depsFuncMacro = compute(
  () => buildLabel('App', '1.0'),
  deps: [buildLabel],
);

// ============================================================
// 10. deps: multiple same-file values
// ============================================================

@Macro(ComputeMacro())
final _depsMultiMacro = compute(
  () => 'retries=$maxRetries, timeout=$timeoutMs',
  deps: [maxRetries, timeoutMs],
);

// ============================================================
// 11. deps: bare identifier (macroBuildOnce)
// ============================================================

@Macro(ComputeMacro())
final _randomNumberMacro = compute(
  () => Random().nextInt(1000),
  deps: macroBuildOnce,
);

// ============================================================
// 12. deps: list access
// ============================================================

@Macro(ComputeMacro())
final _tagCountMacro = compute(
  () => _tagList.length,
  deps: [_tagList],
);

// ============================================================
// 13. Non-deterministic (no deps → full file hash)
// ============================================================

@Macro(ComputeMacro())
final _randomMacro = compute(() => Random().nextInt(99999));

// ============================================================
// 14. Ternary / conditional — auto-serialization
// ============================================================

@Macro(ComputeMacro())
// ignore: dead_code
final _ternaryMacro = compute(() => true ? 'yes' : 'no');

// ============================================================
// 15. Large literal — auto-serialization
// ============================================================

@Macro(ComputeMacro())
final _largeStringMacro = compute(
  () =>
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
      'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
);

// ============================================================
// 16. Math expressions — auto-serialization
// ============================================================

@Macro(ComputeMacro())
final _mathMacro = compute(() => 2 * 3 + 7 - 1);

@Macro(ComputeMacro())
final _stringOpsMacro = compute(() => 'hello'.toUpperCase().length);

// ============================================================
// 17. Modifier: final (not const)
// ============================================================

@Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true)))
final _finalIntMacro = compute(() => 42 + 8);

@Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true)))
final _finalDartCodeMacro = compute(
  () => DartCode('() { return 99 / 33; } ()'),
);

// ============================================================
// 18. Modifier: var (not const, not final)
// ============================================================

@Macro(ComputeMacro(modifier: ComputeModifier(isVar: true)))
final _mutableMacro = compute(() => 'mutable with initial value computed');

// ============================================================
// 20. Modifier: private (isPrivate)
// ============================================================

@Macro(ComputeMacro(modifier: ComputeModifier(isPrivate: true)))
final _privateMacro = compute(() => 'secret');

// ============================================================
// 21. Modifier: final + private
// ============================================================

@Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true, isPrivate: true)))
final _finalPrivateMacro = compute(() => 'final-private');

// ============================================================
// 22. Nested DartCode
// ============================================================

@Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true)))
final _nestedDartCodeMacro = compute<DartCode>(
  () => DartCode("List<int>.generate(3, (i) => i * ${10})"),
);

// ============================================================
// Tests
// ============================================================

void main() {
  group('Primitive auto-serialization', () {
    test('string', () => expect(stringVal, 'hello world'));
    test('int', () => expect(intVal, 42));
    test('double', () => expect(doubleVal, 3.14));
    test('bool', () => expect(boolVal, isTrue));
    test('null', () => expect(nullVal, isNull));
    test('negative int', () => expect(negativeInt, -100));
    test('zero', () => expect(zeroVal, 0));
    test('empty string', () => expect(emptyString, ''));
  });

  group('String interpolation / concatenation', () {
    test('interpolation', () => expect(interpolation, 'year=2026'));
    test('concat', () => expect(concat, 'foobar'));
  });

  group('Block body', () {
    test('arithmetic', () => expect(blockBody, 30));
    test('join', () => expect(blockBodyString, 'a-b-c'));
  });

  group('Collections', () {
    test('list', () => expect(listVal, [1, 2, 3]));
    test('map', () => expect(mapVal, {'a': 1, 'b': 2}));
    test(
      'nested list',
      () => expect(nestedList, [
        [1, 2],
        [3, 4],
      ]),
    );
    test(
      'nested map',
      () => expect(nestedMap, {
        'users': {'alice': 1, 'bob': 2},
      }),
    );
    test('empty list', () => expect(emptyList, <String>[]));
    test('empty map', () => expect(emptyMap, <String, int>{}));
  });

  group('DartCode', () {
    test('simple expression', () => expect(dartCodeSimple, isNotNull));
    test('duration expression', () => expect(dartCodeExpr, isNotNull));
    test('color hex expression', () => expect(dartCodeBypass, isNotNull));
  });

  group('Custom serialization (encode/decode)', () {
    test('encode string uppercase', () => expect(encodeString, 'HELLO'));
    test('encode int doubled', () => expect(encodeInt, 84));
    test('color encode/decode', () => expect(myFavColor.toString(), contains('Color')));
  });

  group('toString() in body', () {
    test('version from toString', () => expect(version, '1'));
  });

  group('Deps: same-file variables', () {
    test('single variable dep', () => expect(myAge, 'MyAge: 32'));
    test('multi variable deps', () => expect(depsSameFile, 'MyApp v2.1.0'));
  });

  group('Deps: function', () {
    test('function dep', () => expect(depsFunc, 'App-1.0'));
  });

  group('Deps: multiple values', () {
    test('multiple deps', () => expect(depsMulti, 'retries=3, timeout=5000'));
  });

  group('Deps: bare identifier', () {
    test('macroBuildOnce as bare identifier', () => expect(randomNumber, isA<int>()));
    test('macroBuildOnce value is within range', () {
      expect(randomNumber, greaterThanOrEqualTo(0));
      expect(randomNumber, lessThan(1000));
    });
  });

  group('Deps: list access', () {
    test('list length dep', () => expect(tagCount, 3));
  });

  group('Non-deterministic', () {
    test('random produces int', () => expect(random, isA<int>()));
    test('random is in range', () {
      expect(random, greaterThanOrEqualTo(0));
      expect(random, lessThan(99999));
    });
  });

  group('Ternary / conditional', () {
    test('ternary', () => expect(ternary, 'yes'));
  });

  group('Large literal', () {
    test('large string', () => expect(largeString, contains('Lorem ipsum')));
  });

  group('Math expressions', () {
    test('arithmetic', () => expect(math, 12));
    test('string ops', () => expect(stringOps, 5));
  });

  group('Modifier: final', () {
    test('final int', () => expect(finalInt, 50));
    test('final dart code', () => expect(finalDartCode, isNotNull));
  });

  group('Modifier: var', () {
    test('var produces value', () => expect(mutable, isA<String>()));
  });

  group('Modifier: private', () {
    test('private generates private name', () => expect(_private, 'secret'));
  });

  group('Modifier: final + private', () {
    test('final private', () => expect(_finalPrivate, 'final-private'));
  });

  group('Nested DartCode', () {
    test('nested dart code produces result', () => expect(nestedDartCode, isNotNull));
  });
}
