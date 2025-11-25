import 'dart:isolate';

import 'package:macro_kit/src/plugin/starter.dart';

void main(List<String> args, SendPort sendPort) {
  start(args, sendPort);
}
