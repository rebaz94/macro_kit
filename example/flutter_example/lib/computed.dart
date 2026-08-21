// ignore_for_file: unused_element

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:macro_kit/macro_kit.dart';

part 'computed.g.dart';

final data = 32;

@Macro(ComputeMacro())
final _versionMacro = compute(() => 1.toString());

@Macro(ComputeMacro())
final _myAgeMacro = compute(
  () => 'MyAge: $data',
  deps: [data],
);

@Macro(ComputeMacro())
final _randomNumberMacro = compute(() => Random().nextInt(1000), deps: macroBuildOnce);

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
