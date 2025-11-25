part of 'example1.dart';

mixin Profile1Json<T extends num> {
  static Profile1<T> fromJson<T extends num>(Map<String, dynamic> json, T Function(Object? v) fromJsonT) {
    return Profile1<T>(
      genericData: fromJsonT(json['genericData']),
      genericData2: MacroExt.decodeNullableGeneric(json['genericData2'], fromJsonT),
      customGeneric: json['customGeneric'] == null
          ? null
          : CustomGeneric<String, bool, int>.fromJson(json['customGeneric'] as Map<String, dynamic>),
      someGeneric: Profile1.someGenericFromJson(json['someGeneric'] as Map<String, dynamic>),
      name: json['Name'] as String,
      age: (json['age'] as num).toInt(),
      someInt: Profile1.intFromStr(Profile1.readStr(json, 'someInt') as String?),
      point: (json['point'] as num?)?.toDouble() ?? 1,
      address: json['address'] as String? ?? Profile1.getDefaultAddress(),
      address2: Profile1.address2FromJson(json['address2'] as String?) ?? Profile1.getDefaultAddress(),
      address3: 'rebaz',
      address4: null,
      intVal: (json['intVal'] as num?)?.toInt(),
      codable: SomeData.fromJson(json['codable'] as Map<String, dynamic>),
      codable2: json['codable2'] == null ? null : SomeData.fromJson(json['codable2'] as Map<String, dynamic>),
      codable3: SomeData2.fromJson((json['codable3'] as num).toInt()),
      codable4: SomeData3.fromJson(json['codable4'] as String),
      list: (json['list'] as List<dynamic>).map((e) => e as String).toList(),
      list2: (json['list2'] as List<dynamic>?)?.map((e) => e as String).toList(),
      list3: (json['list3'] as List<dynamic>?)?.map((e) => (e as num?)?.toInt()).toList(),
      map: json['map'] as Map<String, dynamic>,
      map1: (json['map1'] as Map<String, dynamic>).map((k, e) => MapEntry(k, (e as num).toDouble())),
      map2: (json['map2'] as Map<Object, dynamic>).map((k, e) => MapEntry(k, (e as num).toDouble())),
      map3: (json['map3'] as Map<dynamic, dynamic>).map((k, e) => MapEntry(k, (e as num).toDouble())),
      map4: (json['map4'] as Map<dynamic, dynamic>).map((k, e) => MapEntry(k, (e as num).toDouble())),
      map5: (json['map5'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(MacroExt.decodeEnum(MyEnumData.values, k, unknownValue: null), (e as num).toInt()),
      ),
      map6: (json['map6'] as Map<String, dynamic>).map((k, e) => MapEntry(BigInt.parse(k), (e as num).toDouble())),
      map7: (json['map7'] as Map<String, dynamic>).map((k, e) => MapEntry(MacroExt.decodeDateTime(k), e as String)),
      map8: (json['map8'] as Map<String, dynamic>).map((k, e) => MapEntry(int.parse(k), (e as num).toInt())),
      map9: (json['map9'] as Map<String, dynamic>).map((k, e) => MapEntry(Uri.parse(k), (e as num).toInt())),
      map10: (json['map10'] as Map<String, dynamic>?)?.map((k, e) => MapEntry(int.parse(k), (e as num).toDouble())),
      map11: (json['map11'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      map12: (json['map12'] as Map<Object?, dynamic>).map((k, e) => MapEntry(fromJsonT(k), e as String)),
      dateTime: MacroExt.decodeDateTime(json['dateTime']),
      dateTime2: MacroExt.decodeNullableDateTime(json['dateTime2']),
      dateTime3: (json['dateTime3'] as List<dynamic>).map((e) => MacroExt.decodeNullableDateTime(e)).toList(),
      duration: Duration(microseconds: (json['duration'] as num).toInt()),
      duration2: json['duration2'] == null ? null : Duration(microseconds: (json['duration2'] as num).toInt()),
      bigInt: BigInt.parse(json['bigInt'] as String),
      bigInt2: json['bigInt2'] == null ? null : BigInt.parse(json['bigInt2'] as String),
      uri: Uri.parse(json['uri'] as String),
      uri2: json['uri2'] == null ? null : Uri.parse(json['uri2'] as String),
      enumData: MacroExt.decodeEnum(MyEnumData.values, json['enumData'], unknownValue: null),
      enumData2: MacroExt.decodeNullableEnum(MyEnumData.values, json['enumData2'], unknownValue: null),
      enumData3: MacroExt.decodeNullableEnum(MyEnumData.values, json['enumData3'], unknownValue: MyEnumData.c),
      obj: json['obj'] as Object,
      obj2: json['obj2'],
      dynamicVal: json['dynamicVal'],
    );
  }

  Map<String, dynamic> toJson(Object? Function(T v) toJsonT) {
    final v = this as Profile1<T>;
    return <String, dynamic>{
      'genericData': toJsonT(v.genericData),
      'genericData2': MacroExt.encodeNullableGeneric(v.genericData2, toJsonT),
      'customGeneric': v.customGeneric?.toJson(),
      'someGeneric': Profile1.someGenericToJson(v.someGeneric),
      'Name': v.name,
      'age': v.age,
      'someInt': v.someInt,
      'point': v.point,
      'address': v.address,
      'address2': v.address2,
      'intVal': Profile1.intValueToJson(v.intVal),
      'codable': v.codable.toJson(),
      'codable2': v.codable2?.toJson(),
      'codable3': v.codable3.toJson(),
      'codable4': v.codable4.toJson(),
      'list': v.list.map((e) => e).toList(),
      'list2': v.list2?.map((e) => e).toList(),
      'list3': v.list3?.map((e) => e).toList(),
      'map': v.map,
      'map1': v.map1,
      'map2': v.map2.map((k, e) => MapEntry(k, e)),
      'map3': v.map3.map((k, e) => MapEntry(k, e)),
      'map4': v.map4.map((k, e) => MapEntry(k, e)),
      'map5': v.map5.map((k, e) => MapEntry(k.name, e)),
      'map6': v.map6.map((k, e) => MapEntry(k.toString(), e)),
      'map7': v.map7.map((k, e) => MapEntry(k.toIso8601String(), e)),
      'map8': v.map8.map((k, e) => MapEntry(k.toString(), e)),
      'map9': v.map9.map((k, e) => MapEntry(k.toString(), e)),
      'map10': v.map10?.map((k, e) => MapEntry(k.toString(), e)),
      'map11': v.map11,
      'map12': v.map12.map((k, e) => MapEntry(toJsonT(k), e)),
      'dateTime': v.dateTime.toIso8601String(),
      'dateTime2': v.dateTime2?.toIso8601String(),
      'dateTime3': v.dateTime3.map((e) => e?.toIso8601String()).toList(),
      'duration': v.duration.inMicroseconds,
      'duration2': v.duration2?.inMicroseconds,
      'bigInt': v.bigInt.toString(),
      'bigInt2': v.bigInt2?.toString(),
      'uri': v.uri.toString(),
      'uri2': v.uri2?.toString(),
      'enumData': v.enumData.name,
      'enumData2': v.enumData2?.name,
      'enumData3': ?v.enumData3?.name,
      'obj': v.obj,
      'obj2': v.obj2,
      'dynamicVal': v.dynamicVal,
    };
  }

  Profile1<T> copyWith({
    T? genericData,
    T? genericData2,
    CustomGeneric<String, bool, int>? customGeneric,
    SomeGeneric<int>? someGeneric,
    String? name,
    int? age,
    int? someInt,
    double? point,
    String? address,
    String? address2,
    String? address3,
    String? address4,
    int? intVal,
    SomeData? codable,
    SomeData? codable2,
    SomeData2? codable3,
    SomeData3? codable4,
    List<String>? list,
    List<String>? list2,
    List<int?>? list3,
    Map<String, dynamic>? map,
    Map<String, double>? map1,
    Map<Object, double>? map2,
    Map<dynamic, double>? map3,
    Map<dynamic, double>? map4,
    Map<MyEnumData, int>? map5,
    Map<BigInt, double>? map6,
    Map<DateTime, String>? map7,
    Map<int, int>? map8,
    Map<Uri, int>? map9,
    Map<int, double>? map10,
    Map<String, List<String>>? map11,
    Map<T, String>? map12,
    DateTime? dateTime,
    DateTime? dateTime2,
    List<DateTime?>? dateTime3,
    Duration? duration,
    Duration? duration2,
    BigInt? bigInt,
    BigInt? bigInt2,
    Uri? uri,
    Uri? uri2,
    MyEnumData? enumData,
    MyEnumData? enumData2,
    MyEnumData? enumData3,
    Object? obj,
    Object? obj2,
    dynamic dynamicVal,
  }) {
    final v = this as Profile1<T>;
    return Profile1<T>(
      genericData: genericData ?? v.genericData,
      genericData2: genericData2 ?? v.genericData2,
      customGeneric: customGeneric ?? v.customGeneric,
      someGeneric: someGeneric ?? v.someGeneric,
      name: name ?? v.name,
      age: age ?? v.age,
      someInt: someInt ?? v.someInt,
      point: point ?? v.point,
      address: address ?? v.address,
      address2: address2 ?? v.address2,
      address3: address3 ?? v.address3,
      address4: address4 ?? v.address4,
      intVal: intVal ?? v.intVal,
      codable: codable ?? v.codable,
      codable2: codable2 ?? v.codable2,
      codable3: codable3 ?? v.codable3,
      codable4: codable4 ?? v.codable4,
      list: list ?? v.list,
      list2: list2 ?? v.list2,
      list3: list3 ?? v.list3,
      map: map ?? v.map,
      map1: map1 ?? v.map1,
      map2: map2 ?? v.map2,
      map3: map3 ?? v.map3,
      map4: map4 ?? v.map4,
      map5: map5 ?? v.map5,
      map6: map6 ?? v.map6,
      map7: map7 ?? v.map7,
      map8: map8 ?? v.map8,
      map9: map9 ?? v.map9,
      map10: map10 ?? v.map10,
      map11: map11 ?? v.map11,
      map12: map12 ?? v.map12,
      dateTime: dateTime ?? v.dateTime,
      dateTime2: dateTime2 ?? v.dateTime2,
      dateTime3: dateTime3 ?? v.dateTime3,
      duration: duration ?? v.duration,
      duration2: duration2 ?? v.duration2,
      bigInt: bigInt ?? v.bigInt,
      bigInt2: bigInt2 ?? v.bigInt2,
      uri: uri ?? v.uri,
      uri2: uri2 ?? v.uri2,
      enumData: enumData ?? v.enumData,
      enumData2: enumData2 ?? v.enumData2,
      enumData3: enumData3 ?? v.enumData3,
      obj: obj ?? v.obj,
      obj2: obj2 ?? v.obj2,
      dynamicVal: dynamicVal ?? v.dynamicVal,
    );
  }

  @override
  bool operator ==(Object other) {
    final v = this as Profile1<T>;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Profile1<T> &&
            (identical(other.genericData, v.genericData) || other.genericData == v.genericData) &&
            (identical(other.genericData2, v.genericData2) || other.genericData2 == v.genericData2) &&
            (identical(other.customGeneric, v.customGeneric) || other.customGeneric == v.customGeneric) &&
            (identical(other.someGeneric, v.someGeneric) || other.someGeneric == v.someGeneric) &&
            (identical(other.name, v.name) || other.name == v.name) &&
            (identical(other.age, v.age) || other.age == v.age) &&
            (identical(other.someInt, v.someInt) || other.someInt == v.someInt) &&
            (identical(other.point, v.point) || other.point == v.point) &&
            (identical(other.address, v.address) || other.address == v.address) &&
            (identical(other.address2, v.address2) || other.address2 == v.address2) &&
            (identical(other.address3, v.address3) || other.address3 == v.address3) &&
            (identical(other.address4, v.address4) || other.address4 == v.address4) &&
            (identical(other.intVal, v.intVal) || other.intVal == v.intVal) &&
            (identical(other.codable, v.codable) || other.codable == v.codable) &&
            (identical(other.codable2, v.codable2) || other.codable2 == v.codable2) &&
            (identical(other.codable3, v.codable3) || other.codable3 == v.codable3) &&
            (identical(other.codable4, v.codable4) || other.codable4 == v.codable4) &&
            const DeepCollectionEquality().equals(other.list, v.list) &&
            const DeepCollectionEquality().equals(other.list2, v.list2) &&
            const DeepCollectionEquality().equals(other.list3, v.list3) &&
            const DeepCollectionEquality().equals(other.map, v.map) &&
            const DeepCollectionEquality().equals(other.map1, v.map1) &&
            const DeepCollectionEquality().equals(other.map2, v.map2) &&
            const DeepCollectionEquality().equals(other.map3, v.map3) &&
            const DeepCollectionEquality().equals(other.map4, v.map4) &&
            const DeepCollectionEquality().equals(other.map5, v.map5) &&
            const DeepCollectionEquality().equals(other.map6, v.map6) &&
            const DeepCollectionEquality().equals(other.map7, v.map7) &&
            const DeepCollectionEquality().equals(other.map8, v.map8) &&
            const DeepCollectionEquality().equals(other.map9, v.map9) &&
            const DeepCollectionEquality().equals(other.map10, v.map10) &&
            const DeepCollectionEquality().equals(other.map11, v.map11) &&
            const DeepCollectionEquality().equals(other.map12, v.map12) &&
            (identical(other.dateTime, v.dateTime) || other.dateTime == v.dateTime) &&
            (identical(other.dateTime2, v.dateTime2) || other.dateTime2 == v.dateTime2) &&
            const DeepCollectionEquality().equals(other.dateTime3, v.dateTime3) &&
            (identical(other.duration, v.duration) || other.duration == v.duration) &&
            (identical(other.duration2, v.duration2) || other.duration2 == v.duration2) &&
            (identical(other.bigInt, v.bigInt) || other.bigInt == v.bigInt) &&
            (identical(other.bigInt2, v.bigInt2) || other.bigInt2 == v.bigInt2) &&
            (identical(other.uri, v.uri) || other.uri == v.uri) &&
            (identical(other.uri2, v.uri2) || other.uri2 == v.uri2) &&
            (identical(other.enumData, v.enumData) || other.enumData == v.enumData) &&
            (identical(other.enumData2, v.enumData2) || other.enumData2 == v.enumData2) &&
            (identical(other.enumData3, v.enumData3) || other.enumData3 == v.enumData3) &&
            (identical(other.obj, v.obj) || other.obj == v.obj) &&
            (identical(other.obj2, v.obj2) || other.obj2 == v.obj2) &&
            (identical(other.dynamicVal, v.dynamicVal) || other.dynamicVal == v.dynamicVal));
  }

  @override
  int get hashCode {
    final v = this as Profile1<T>;
    return Object.hashAll([
      runtimeType,
      v.genericData,
      v.genericData2,
      v.customGeneric,
      v.someGeneric,
      v.name,
      v.age,
      v.someInt,
      v.point,
      v.address,
      v.address2,
      v.address3,
      v.address4,
      v.intVal,
      v.codable,
      v.codable2,
      v.codable3,
      v.codable4,
      const DeepCollectionEquality().hash(v.list),
      const DeepCollectionEquality().hash(v.list2),
      const DeepCollectionEquality().hash(v.list3),
      const DeepCollectionEquality().hash(v.map),
      const DeepCollectionEquality().hash(v.map1),
      const DeepCollectionEquality().hash(v.map2),
      const DeepCollectionEquality().hash(v.map3),
      const DeepCollectionEquality().hash(v.map4),
      const DeepCollectionEquality().hash(v.map5),
      const DeepCollectionEquality().hash(v.map6),
      const DeepCollectionEquality().hash(v.map7),
      const DeepCollectionEquality().hash(v.map8),
      const DeepCollectionEquality().hash(v.map9),
      const DeepCollectionEquality().hash(v.map10),
      const DeepCollectionEquality().hash(v.map11),
      const DeepCollectionEquality().hash(v.map12),
      v.dateTime,
      v.dateTime2,
      const DeepCollectionEquality().hash(v.dateTime3),
      v.duration,
      v.duration2,
      v.bigInt,
      v.bigInt2,
      v.uri,
      v.uri2,
      v.enumData,
      v.enumData2,
      v.enumData3,
      v.obj,
      v.obj2,
      v.dynamicVal,
    ]);
  }

  @override
  String toString() {
    final v = this as Profile1<T>;
    return 'Profile1<$T>{genericData: ${v.genericData}, genericData2: ${v.genericData2}, customGeneric: ${v.customGeneric}, someGeneric: ${v.someGeneric}, name: ${v.name}, age: ${v.age}, someInt: ${v.someInt}, point: ${v.point}, address: ${v.address}, address2: ${v.address2}, address3: ${v.address3}, address4: ${v.address4}, intVal: ${v.intVal}, codable: ${v.codable}, codable2: ${v.codable2}, codable3: ${v.codable3}, codable4: ${v.codable4}, list: ${v.list}, list2: ${v.list2}, list3: ${v.list3}, map: ${v.map}, map1: ${v.map1}, map2: ${v.map2}, map3: ${v.map3}, map4: ${v.map4}, map5: ${v.map5}, map6: ${v.map6}, map7: ${v.map7}, map8: ${v.map8}, map9: ${v.map9}, map10: ${v.map10}, map11: ${v.map11}, map12: ${v.map12}, dateTime: ${v.dateTime}, dateTime2: ${v.dateTime2}, dateTime3: ${v.dateTime3}, duration: ${v.duration}, duration2: ${v.duration2}, bigInt: ${v.bigInt}, bigInt2: ${v.bigInt2}, uri: ${v.uri}, uri2: ${v.uri2}, enumData: ${v.enumData}, enumData2: ${v.enumData2}, enumData3: ${v.enumData3}, obj: ${v.obj}, obj2: ${v.obj2}, dynamicVal: ${v.dynamicVal}}';
  }
}
