import 'package:hashlib/hashlib.dart';

int generateHash(String value) {
  return xxh32code(value);
}
