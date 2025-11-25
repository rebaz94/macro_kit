import 'dart:convert';

import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/core/core.dart';

String encodeMessage(Message message) {
  return jsonEncode({
    'type': message.type,
    'data': message.toJson(),
  });
}

(Message?, Object?, StackTrace?) decodeMessage(Object? rawMessage) {
  try {
    final json = (rawMessage is String ? jsonDecode(rawMessage) : rawMessage) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    final msg = switch (json['type']) {
      'plugin_connect' => PluginConnectMsg.fromJson(data),
      'contexts' => AnalysisContextsMsg.fromJson(data),
      'client_connect' => ClientConnectMsg.fromJson(data),
      'run_macro' => RunMacroMsg.fromJson(data),
      'run_macro_result' => RunMacroResultMsg.fromJson(data),
      _ => throw 'Unimplemented message type: ${json['type']}',
    };

    return (msg, null, null);
  } catch (e, s) {
    return (null, e, s);
  }
}

abstract class Message {
  String get type;

  Map<String, dynamic> toJson();
}

class PluginConnectMsg implements Message {
  PluginConnectMsg({required this.id});

  static PluginConnectMsg fromJson(Map<String, dynamic> json) {
    return PluginConnectMsg(id: (json['id'] as num).toInt());
  }

  final int id;

  @override
  String get type => 'plugin_connect';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}

class AnalysisContextsMsg implements Message {
  AnalysisContextsMsg({required this.contexts});

  static AnalysisContextsMsg fromJson(Map<String, dynamic> json) {
    return AnalysisContextsMsg(
      contexts: (json['contexts'] as List).map((e) => e as String).toList(),
    );
  }

  final List<String> contexts;

  @override
  String get type => 'contexts';

  @override
  Map<String, dynamic> toJson() {
    return {
      'contexts': contexts,
    };
  }
}

class ClientConnectMsg implements Message {
  ClientConnectMsg({
    required this.id,
    required this.macros,
    required this.runTimeout,
  });

  static ClientConnectMsg fromJson(Map<String, dynamic> json) {
    return ClientConnectMsg(
      id: (json['id'] as num).toInt(),
      macros: (json['macros'] as List).map((e) => e as String).toList(),
      runTimeout: Duration(microseconds: (json['runTimeout'] as num).toInt()),
    );
  }

  final int id;
  final List<String> macros;
  final Duration runTimeout;

  @override
  String get type => 'client_connect';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'macros': macros,
      'runTimeout': runTimeout.inMicroseconds,
    };
  }
}

class RunMacroMsg implements Message {
  RunMacroMsg({
    required this.id,
    required this.macroName,
    required this.sharedClasses,
    required this.classes,
  });

  static RunMacroMsg fromJson(Map<String, dynamic> json) {
    final sharedDec = <String, MacroClassDeclaration>{};
    final pendingUpdate = <void Function()>[];

    final classesRes = runZoneGuarded(
      fn: () {
        final rawSharedDec = json['sharedClasses'] as Map<String, dynamic>?;

        // decode shared class
        for (final entry in (rawSharedDec ?? const {}).entries) {
          final classId = entry.key;
          sharedDec[classId] = MacroClassDeclaration.fromJson(entry.value as Map<String, dynamic>);
        }

        // decode declarations
        final classes = <MacroClassDeclaration>[];
        for (final e in (json['classes'] as List?) ?? const []) {
          classes.add(MacroClassDeclaration.fromJson(e));
        }

        for (final update in pendingUpdate) {
          update();
        }
        pendingUpdate.clear();

        return classes;
      },
      values: {
        #sharedClasses: sharedDec,
        #pendingUpdates: pendingUpdate,
      },
    );

    return RunMacroMsg(
      id: (json['id'] as num).toInt(),
      macroName: json['name'] as String,
      sharedClasses: sharedDec,
      classes: classesRes,
    );
  }

  final int id;
  final String macroName;
  final Map<String, MacroClassDeclaration> sharedClasses;
  final List<MacroClassDeclaration>? classes;

  @override
  String get type => 'run_macro';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': macroName,
      if (sharedClasses.isNotEmpty) 'sharedClasses': sharedClasses.map((k, v) => MapEntry(k, v.toJson())),
      if (classes?.isNotEmpty == true) 'classes': classes!.map((e) => e.toJson()).toList(),
    };
  }
}

class RunMacroResultMsg implements Message {
  RunMacroResultMsg({required this.id, required this.result, this.error});

  static RunMacroResultMsg fromJson(Map<String, dynamic> json) {
    return RunMacroResultMsg(
      id: (json['id'] as num).toInt(),
      result: json['result'] as String,
      error: json['error'] as String?,
    );
  }

  final int id;
  final String result;
  final String? error;

  @override
  String get type => 'run_macro_result';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'result': result,
      if (error != null) 'error': error!,
    };
  }
}
