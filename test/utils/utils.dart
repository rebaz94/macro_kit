import 'package:test/test.dart';

// Matcher throwsMapperException(MapperException e) {
//   return throwsA(
//     isA<MapperException>().having(
//       (e) => e.message,
//       'message',
//       equals(e.message),
//     ),
//   );
// }
//
// Type type<T>() => T;

Matcher throwsTypeError(String errorMsg, {String? description}) {
  return throwsA(
    isA<TypeError>().having(
      (e) => e.toString(),
      description ?? 'Expected type error',
      contains(errorMsg),
    ),
  );
}
