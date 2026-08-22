// ignore_for_file: unused_element
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:macro_kit/macro_kit.dart';

part 'color.g.dart';

@Macro(ComputeMacro())
final _heroDominantColor = compute(
  () async {
    final bytes = File('assets/images/hero.jpg').readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // Get raw RGBA pixel bytes
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = byteData!.buffer.asUint8List();

    int r = 0, g = 0, b = 0, count = 0;
    for (int i = 0; i < pixels.length; i += 4) {
      r += pixels[i];
      g += pixels[i + 1];
      b += pixels[i + 2];
      count++;
    }

    return DartCode('Color(${(0xFF << 24) | ((r ~/ count) << 16) | ((g ~/ count) << 8) | (b ~/ count)})');
  },
  deps: ['assets/images/hero.jpg'],
);
