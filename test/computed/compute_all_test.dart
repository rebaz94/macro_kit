// ignore_for_file: unused_element

import 'dart:math';
import 'package:macro_kit/macro_kit.dart';

part 'compute_all_test.g.dart';

// ============================================================
// 1. Primitive literals (no encode/decode)
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
// 2. String interpolation / concatenation
// ============================================================

@Macro(ComputeMacro())
final _interpolationMacro = compute(() => 'year=${2026}');

@Macro(ComputeMacro())
final _concatMacro = compute(() => 'foo' + 'bar');

// ============================================================
// 3. Block body (not arrow)
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
// 4. Collections (List, Map)
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

// ============================================================
// 5. DartCode
// ============================================================

@Macro(ComputeMacro())
final _dartCodeSimpleMacro = compute<DartCode>(() => DartCode('2 | 10'));

@Macro(ComputeMacro())
final _dartCodeExprMacro = compute<DartCode>(
  () => DartCode('Duration(seconds: ${5 * 60})'),
);

// ============================================================
// 6. Encode/Decode
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

// ============================================================
// 7. deps: same-file identifier
// ============================================================

final appVersion = '2.1.0';
final appName = 'MyApp';

@Macro(ComputeMacro())
final _depsSameFileMacro = compute(
  () => '$appName v$appVersion',
  deps: [appVersion, appName],
);

// ============================================================
// 8. deps: function from same file
// ============================================================

String buildLabel(String name, String version) => '$name-$version';

@Macro(ComputeMacro())
final _depsFuncMacro = compute(
  () => buildLabel('App', '1.0'),
  deps: [buildLabel],
);

// ============================================================
// 9. deps: complex same-file values
// ============================================================

final maxRetries = 3;
final timeoutMs = 5000;

@Macro(ComputeMacro())
final _depsMultiMacro = compute(
  () => 'retries=$maxRetries, timeout=$timeoutMs',
  deps: [maxRetries, timeoutMs],
);

// ============================================================
// 10. DartCode (bypasses encode)
// ============================================================

@Macro(ComputeMacro())
final _dartCodeBypassMacro = compute<DartCode>(
  () => DartCode('Color(0xFF${123.toRadixString(16).padLeft(6, '0')})'),
);

class Color {
  final int value;

  const Color(this.value);
}

// ============================================================
// 11. Random / non-deterministic (no deps → full file hash)
// ============================================================

@Macro(ComputeMacro())
final _randomMacro = compute(() => Random().nextInt(99999));

// ============================================================
// 12. deps: list access
// ============================================================

final List<String> _tagList = ['alpha', 'beta', 'gamma'];

@Macro(ComputeMacro())
final _tagCountMacro = compute(
  () => _tagList.length,
  deps: [_tagList],
);

// ============================================================
// 13. Ternary / conditional
// ============================================================

@Macro(ComputeMacro())
final _ternaryMacro = compute(() => true ? 'yes' : 'no');

// ============================================================
// 14. Large literal
// ============================================================

@Macro(ComputeMacro())
final _largeStringMacro = compute(
  () =>
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
      'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
);

// ============================================================
// 15. Math expressions
// ============================================================

@Macro(ComputeMacro())
final _mathMacro = compute(() => 2 * 3 + 7 - 1);

@Macro(ComputeMacro())
final _stringOpsMacro = compute(() => 'hello'.toUpperCase().length);

// ============================================================
// Run
// ============================================================

void main() {
  print('--- compute_all_test ---');
  print('stringVal: $stringVal');
  print('intVal: $intVal');
  print('doubleVal: $doubleVal');
  print('boolVal: $boolVal');
  print('nullVal: $nullVal');
  print('negativeInt: $negativeInt');
  print('zeroVal: $zeroVal');
  print('emptyString: $emptyString');
  print('interpolation: $interpolation');
  print('concat: $concat');
  print('blockBody: $blockBody');
  print('blockBodyString: $blockBodyString');
  print('listVal: $listVal');
  print('mapVal: $mapVal');
  print('nestedList: $nestedList');
  print('nestedMap: $nestedMap');
  print('dartCodeSimple: $dartCodeSimple');
  print('dartCodeExpr: $dartCodeExpr');
  print('encodeString: $encodeString');
  print('encodeInt: $encodeInt');
  print('depsSameFile: $depsSameFile');
  print('depsFunc: $depsFunc');
  print('depsMulti: $depsMulti');
  print('dartCodeBypass: $dartCodeBypass');
  print('random: $random');
  print('tagCount: $tagCount');
  print('ternary: $ternary');
  print('largeString: $largeString');
  print('math: $math');
  {}{}
  print('stringOps: $stringOps');
  print('--- done ---');
  {}{}
}
