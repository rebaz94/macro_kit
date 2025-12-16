import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

import '../../utils/utils.dart';

part 'as_literal_test.g.dart';

class GeoPoint {
  const GeoPoint(this.lat, this.long);

  final double lat;
  final double long;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint && runtimeType == other.runtimeType && lat == other.lat && long == other.long;

  @override
  int get hashCode => lat.hashCode ^ long.hashCode;
}

class CustomGeoPoint {
  const CustomGeoPoint(this.lat, this.long);

  final double lat;
  final double long;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomGeoPoint && runtimeType == other.runtimeType && lat == other.lat && long == other.long;

  @override
  int get hashCode => lat.hashCode ^ long.hashCode;
}

@dataClassMacro
class A with AData {
  A({
    required this.a,
    this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
  });

  static GeoPoint geoPointFromJson(Map<String, dynamic> json) {
    return GeoPoint((json['lat'] as num).toDouble(), (json['long'] as num).toDouble());
  }

  static Map<String, dynamic> geoPointToJson(GeoPoint point) {
    return {'lat': point.lat, 'long': point.long};
  }

  static T asLiteralFromToJson<T>(dynamic v) => v as T;

  @JsonKey(asLiteral: true)
  final GeoPoint a;

  @JsonKey(asLiteral: true)
  final GeoPoint? b;

  @JsonKey(asLiteral: true, defaultValue: GeoPoint(1, 1))
  final GeoPoint? c;

  @JsonKey(asLiteral: true, defaultValue: GeoPoint(2, 2))
  final GeoPoint d;

  @JsonKey(fromJson: geoPointFromJson, toJson: geoPointToJson)
  final GeoPoint e;

  // project level literal
  final CustomGeoPoint f;

  // disable literal
  @JsonKey(asLiteral: false, fromJson: asLiteralFromToJson, toJson: asLiteralFromToJson)
  final CustomGeoPoint g;
}

void main() {
  group(
    'As literal Serialization',
    () {
      test('from json success', () {
        expect(
          AData.fromJson({
            'a': GeoPoint(1, 1),
            'b': GeoPoint(2, 2),
            'c': null,
            'd': null,
            'e': {'lat': 3, 'long': 3},
            'f': CustomGeoPoint(10, 10),
            'g': CustomGeoPoint(10, 10),
          }),
          A(
            a: GeoPoint(1, 1),
            b: GeoPoint(2, 2),
            c: GeoPoint(1, 1),
            d: GeoPoint(2, 2),
            e: GeoPoint(3, 3),
            f: CustomGeoPoint(10, 10),
            g: CustomGeoPoint(10, 10),
          ),
        );

        expect(
          AData.fromJson({
            'a': GeoPoint(1, 1),
            'b': GeoPoint(2, 2),
            'c': GeoPoint(30, 30),
            'd': GeoPoint(22, 22),
            'e': {'lat': 3, 'long': 3},
            'f': CustomGeoPoint(10, 10),
            'g': CustomGeoPoint(10, 10),
          }),
          A(
            a: GeoPoint(1, 1),
            b: GeoPoint(2, 2),
            c: GeoPoint(30, 30),
            d: GeoPoint(22, 22),
            e: GeoPoint(3, 3),
            f: CustomGeoPoint(10, 10),
            g: CustomGeoPoint(10, 10),
          ),
        );
      });

      test('from map throws', () {
        expect(
          () => AData.fromJson({
            'b': GeoPoint(2, 2),
            'c': null,
            'd': null,
            'e': {'lat': 3, 'long': 3},
          }),
          throwsTypeError(r"type 'Null' is not a subtype of type 'GeoPoint' in type cast"),
        );
      });

      test('to json succeeds', () {
        final a = AData.fromJson({
          'a': GeoPoint(1, 1),
          'b': GeoPoint(2, 2),
          'c': null,
          'd': null,
          'e': {'lat': 3, 'long': 3},
          'f': CustomGeoPoint(10, 10),
          'g': CustomGeoPoint(10, 10),
        });

        final json = {
          'a': GeoPoint(1, 1),
          'b': GeoPoint(2, 2),
          'c': GeoPoint(1, 1),
          'd': GeoPoint(2, 2),
          'e': {'lat': 3.0, 'long': 3.0},
          'f': CustomGeoPoint(10, 10),
          'g': CustomGeoPoint(10, 10),
        };
        expect(a.toJson(), equals(json));
        expect(AData.fromJson(json), equals(a));
      });
    },
  );
}
