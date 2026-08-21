import 'dart:math';

import 'package:flutter/material.dart';
import 'package:macro_kit/macro_kit.dart';

part 'test.g.dart';

final data = 30;

@Macro(ComputeMacro())
final _versionMacro = compute(() => 2.toString());

@Macro(ComputeMacro())
final _version2Macro = compute(
  () => data.toString(),
  deps: [data],
);

@Macro(ComputeMacro())
final _version3Macro = compute(() => Random().nextInt(1000));

@Macro(ComputeMacro())
final _version4Macro = compute(() {
  return 4;
});

@Macro(ComputeMacro())
final _version5Macro = compute(
  () => Colors.green,
  encode: (value) => value.value.toString(),
  decode: (value) => 'Color($value)',
);

@Macro(ComputeMacro())
final _version6Macro = compute(
  () => DartCode('2 | 10'),
);

// ddsssg2d
