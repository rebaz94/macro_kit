import 'dart:io';

import 'package:hashlib/hashlib.dart';

int generateHash(String value) {
  return xxh32code(value);
}

int hashFile(File file) {
  return xxh3.fileSync(file).number();
}
