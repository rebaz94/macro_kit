import 'dart:convert';

import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

part 'external_from_json_factory_test.g.dart';

@dataClassMacro
class Wrapped with WrappedData {
  Wrapped({
    required this.id,
    required this.model,
  });

  final String id;

  @JsonKey(fromJson: ExternalModel.fromJson, toJson: toJsonExt)
  final ExternalModel model;

  static Object? toJsonExt(ExternalModel m) => {'data': m.data};
}

class ExternalModel {
  ExternalModel({required this.data});

  factory ExternalModel.fromJson(Map<String, dynamic> json) {
    return ExternalModel(data: json['data'] as String);
  }

  final String data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ExternalModel && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;
}

@dataClassMacro
class Wrapped2 with Wrapped2Data {
  Wrapped2({
    required this.id,
    required this.model,
  });

  final String id;

  @JsonKey(fromJson: ExternalModel2<String>.fromJson, toJson: toJsonExt)
  final ExternalModel2<String> model;

  static Object? toJsonExt(ExternalModel2<String> m) => {'data': m.data};
}

class ExternalModel2<T> {
  ExternalModel2({required this.data});

  factory ExternalModel2.fromJson(Map<String, dynamic> json) {
    return ExternalModel2(data: json['data'] as T);
  }

  final T data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ExternalModel2 && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;
}

void main() {
  group('external fromJson factory', () {
    test('from json succeeds-1', () {
      var w = Wrapped(
        id: '1',
        model: ExternalModel(data: 'hello'),
      );
      expect(WrappedData.fromJson(jsonDecode('{"id": "1", "model": {"data": "hello"}}')), w);
    });

    test('to json succeeds-1', () {
      var w = Wrapped(
        id: '1',
        model: ExternalModel(data: 'hello'),
      );
      expect(jsonEncode(w.toJson()), equals('{"id":"1","model":{"data":"hello"}}'));
    });

    test('from json succeeds-2', () {
      var w = Wrapped2(
        id: '1',
        model: ExternalModel2(data: 'hello'),
      );
      expect(Wrapped2Data.fromJson(jsonDecode('{"id": "1", "model": {"data": "hello"}}')), w);
    });

    test('to json succeeds-2', () {
      var w = Wrapped2(
        id: '1',
        model: ExternalModel2(data: 'hello'),
      );
      expect(jsonEncode(w.toJson()), equals('{"id":"1","model":{"data":"hello"}}'));
    });
  });
}
