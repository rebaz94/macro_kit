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
    required this.assetMacros,
    required this.runTimeout,
  });

  static ClientConnectMsg fromJson(Map<String, dynamic> json) {
    return ClientConnectMsg(
      id: (json['id'] as num).toInt(),
      macros: (json['macros'] as List).map((e) => e as String).toList(),
      assetMacros: (json['assetMacros'] as Map).map(
        (k, v) {
          return MapEntry(
            k as String,
            (v as List).map((e) => AssetMacroInfo.fromJson(e as Map<String, dynamic>)).toList(),
          );
        },
      ),
      runTimeout: Duration(microseconds: (json['runTimeout'] as num).toInt()),
    );
  }

  final int id;
  final List<String> macros;
  final Map<String, List<AssetMacroInfo>> assetMacros;
  final Duration runTimeout;

  @override
  String get type => 'client_connect';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'macros': macros,
      'assetMacros': assetMacros.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
      'runTimeout': runTimeout.inMicroseconds,
    };
  }
}

class RunMacroMsg implements Message {
  RunMacroMsg({
    required this.id,
    required this.macroName,
    required this.imports,
    required this.libraryPaths,
    this.sharedClasses = const {},
    this.classes,
    this.assetDeclaration,
    this.assetConfig,
    this.assetBasePath,
    this.assetAbsoluteBasePath,
    this.assetAbsoluteOutputPath,
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
      imports: (json['imports'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      libraryPaths: (json['libraryPaths'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(num.parse(k).toInt(), v as String),
      ),
      sharedClasses: sharedDec,
      classes: classesRes,
      assetDeclaration: json['asset'] != null
          ? MacroAssetDeclaration.fromJson(json['asset'] as Map<String, dynamic>)
          : null,
      assetConfig: json['assetConfig'] as Map<String, dynamic>?,
      assetBasePath: json['assetBasePath'] as String?,
      assetAbsoluteBasePath: json['assetAbsoluteBasePath'] as String?,
      assetAbsoluteOutputPath: json['assetAbsoluteOutputPath'] as String?,
    );
  }

  /// Unique id of the run
  final int id;

  /// Name of the macro to run
  final String macroName;

  /// Map of imports from the analyzed file, where the key is the import path
  /// and the value is the import prefix (if any)
  final Map<String, String> imports;

  /// Map of library IDs to their full file paths for target declarations
  final Map<int, String> libraryPaths;

  /// The shared classes by id which seen multiple times in analysis
  final Map<String, MacroClassDeclaration> sharedClasses;

  /// The class declarations of a processed dart code
  final List<MacroClassDeclaration>? classes;

  /// The file or directory which triggered macro generation
  final MacroAssetDeclaration? assetDeclaration;

  /// The asset configuration
  final Map<String, dynamic>? assetConfig;

  /// The relative path of asset directory which triggered macro
  final String? assetBasePath;

  /// The absolute path of asset directory which triggered macro
  final String? assetAbsoluteBasePath;

  /// The absolute path of output directory
  final String? assetAbsoluteOutputPath;

  @override
  String get type => 'run_macro';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': macroName,
      'imports': imports,
      'libraryPaths': libraryPaths.map((k, v) => MapEntry(k.toString(), v)),
      if (sharedClasses.isNotEmpty) 'sharedClasses': sharedClasses.map((k, v) => MapEntry(k, v.toJson())),
      if (classes?.isNotEmpty == true) 'classes': classes!.map((e) => e.toJson()).toList(),
      if (assetDeclaration != null) 'asset': assetDeclaration!.toJson(),
      if (assetConfig != null) 'assetConfig': assetConfig,
      if (assetBasePath != null) 'assetBasePath': assetBasePath,
      if (assetAbsoluteBasePath != null) 'assetAbsoluteBasePath': assetAbsoluteBasePath,
      if (assetAbsoluteOutputPath != null) 'assetAbsoluteOutputPath': assetAbsoluteOutputPath,
    };
  }
}

class RunMacroResultMsg implements Message {
  RunMacroResultMsg({
    required this.id,
    required this.result,
    this.generatedFiles,
    this.error,
  });

  static RunMacroResultMsg fromJson(Map<String, dynamic> json) {
    return RunMacroResultMsg(
      id: (json['id'] as num).toInt(),
      result: json['result'] as String,
      generatedFiles: (json['generatedFiles'] as List?)?.map((e) => e as String).toList(),
      error: json['error'] as String?,
    );
  }

  final int id;
  final String result;
  final String? error;
  final List<String>? generatedFiles;

  @override
  String get type => 'run_macro_result';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'result': result,
      if (generatedFiles?.isNotEmpty == true) 'generatedFiles': generatedFiles!,
      if (error != null) 'error': error!,
    };
  }
}
