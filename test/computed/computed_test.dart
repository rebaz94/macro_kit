import 'package:macro_kit/macro_kit.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:macro_kit/macro_kit.dart';

part 'computed_test.g.dart';

@dataClassMacro
class Test with TestData  {
  Test({required this.id, required this.name, required this.name2});

  final String id;
  final String name;
  final String name2;
}


@Macro(ComputeMacro())
final versionMacro = compute(() => 1.toString());

void main() => computeRunner();