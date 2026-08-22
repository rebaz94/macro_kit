// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:macro_kit/macro_kit.dart';

part 'basic.g.dart';

final data = 32;

@Macro(ComputeMacro())
final _versionMacro = compute(() => 1.toString());

@Macro(ComputeMacro())
final _myAgeMacro = compute(
  () => 'MyAge: $data',
  deps: [data],
);

@Macro(ComputeMacro())
final _myFavColorMacro = compute(
  () => Colors.green,
  encode: (value) => value.toARGB32().toString(),
  decode: (value) => 'Color($value)',
);

@Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true)))
final _rawCodeMacro = compute(
  () => DartCode('() { return 99 / 33; } ()'),
);
