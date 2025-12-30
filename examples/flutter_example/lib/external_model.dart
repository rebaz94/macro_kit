import 'package:macro_kit/macro_kit.dart';

part 'external_model.g.dart';

@dataClassMacro
class Wrapped with WrappedData {
  Wrapped({
    required this.id,
    required this.model,
  });

  final String id;

  @JsonKey(fromJson: ExternalModel.fromJson, toJson: toJsonExt)
  final ExternalModel model;

  static Object? toJsonExt(ExternalModel m) => m;
}

class ExternalModel {
  ExternalModel({required this.data});

  factory ExternalModel.fromJson(Map<String, dynamic> json) {
    return ExternalModel(data: json['data'] as String);
  }

  final String data;
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

  static Object? toJsonExt(ExternalModel2<String> m) => m;
}

class ExternalModel2<T> {
  ExternalModel2({required this.data});

  factory ExternalModel2.fromJson(Map<String, dynamic> json) {
    return ExternalModel2(data: json['data'] as T);
  }

  final T data;
}

@dataClassMacro
class Wrapped3 with Wrapped3Data {
  Wrapped3({
    required this.id,
    required this.model,
  });

  final String id;
  @JsonKey(fromJson: CustomModel.fromJson<String>, toJson: toJ)
  final CustomModel<String> model;

  static CustomModel<String> fromJ(Map<String, dynamic> json) {
    return CustomModel.fromJson(json);
  }


  static Map<String, dynamic> toJ(CustomModel<String> model) {
    return model.toJson();
  }
}

class CustomModel<T> {
  CustomModel({required this.data});

  static CustomModel<T> fromJson<T>(Map<String, dynamic> json) {
    return CustomModel<T>(
      data: json['data'] as T,
    );
  }

  Map<String, dynamic> toJson() {
    return {'data': data};
  }

  final T data;
}
