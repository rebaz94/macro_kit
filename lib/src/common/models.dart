import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/core/platform/platform.dart';

String encodeMessage(Message message) {
  return jsonEncode({
    'type': message.type,
    'data': message.toJson(),
  });
}

Map<String, dynamic> encodeMessageAsMap(Message message) {
  return {
    'type': message.type,
    'data': message.toJson(),
  };
}

(Message?, Object?, StackTrace?) decodeMessage(Object? rawMessage) {
  try {
    final json = (rawMessage is String ? jsonDecode(rawMessage) : rawMessage) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    final msg = switch (json['type']) {
      'plugin_connect' => PluginConnectMsg.fromJson(data),
      'contexts' => AnalysisContextsMsg.fromJson(data),
      'request_client_to_connect' => RequestClientToConnectMsg.fromJson(data),
      'request_plugin_to_connect' => RequestPluginToConnectMsg.fromJson(data),
      'client_connect' => ClientConnectMsg.fromJson(data),
      'accepted_vm_service' => AcceptedVmServiceConnectMsg.fromJson(data),
      'close_vm_service' => CloseVmServiceConnectMsg.fromJson(data),
      'request_macros_config' => RequestMacrosConfigMsg.fromJson(data),
      'sync_macros_config' => SyncMacrosConfigMsg.fromJson(data),
      'run_macro' => RunMacroMsg.fromJson(data),
      'run_macro_result' => RunMacroResultMsg.fromJson(data),
      'auto_rebuild_on_connect_result' => AutoRebuildOnConnectResultMsg.fromJson(data),
      'general_message' => GeneralMessage.fromJson(data),
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
  PluginConnectMsg({
    required this.id,
    required this.initialContexts,
    required this.versionCode,
    required this.versionName,
  });

  static PluginConnectMsg fromJson(Map<String, dynamic> json) {
    return PluginConnectMsg(
      id: (json['id'] as num).toInt(),
      initialContexts: (json['contexts'] as List).map((e) => e as String).toList(),
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 1,
      versionName: json['versionName'] as String? ?? '0.2.2',
    );
  }

  final int id;
  final List<String> initialContexts;
  final int versionCode;
  final String versionName;

  @override
  String get type => 'plugin_connect';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contexts': initialContexts,
      'versionCode': versionCode,
      'versionName': versionName,
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

class RequestClientToConnectMsg implements Message {
  RequestClientToConnectMsg();

  static RequestClientToConnectMsg fromJson(Map<String, dynamic> json) {
    return RequestClientToConnectMsg();
  }

  @override
  String get type => 'request_client_to_connect';

  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}

class RequestPluginToConnectMsg implements Message {
  RequestPluginToConnectMsg();

  static RequestPluginToConnectMsg fromJson(Map<String, dynamic> json) {
    return RequestPluginToConnectMsg();
  }

  @override
  String get type => 'request_plugin_to_connect';

  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}

class ClientConnectMsg implements Message {
  ClientConnectMsg({
    required this.id,
    required this.platform,
    required this.package,
    required this.macros,
    required this.assetMacros,
    required this.runTimeout,
    required this.autoRunMacro,
    required this.managedByMacroServer,
  });

  static ClientConnectMsg fromJson(Map<String, dynamic> json) {
    return ClientConnectMsg(
      id: (json['id'] as num).toInt(),
      platform: MacroPlatform.values.byName(json['platform'] as String),
      package: PackageInfo.fromJson(json['packages'] as Map<String, dynamic>),
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
      autoRunMacro: json['autoRunMacro'] as bool,
      managedByMacroServer: json['managedByMacroServer'] as bool,
    );
  }

  final int id;
  final MacroPlatform platform;
  final PackageInfo package;
  final List<String> macros;
  final Map<String, List<AssetMacroInfo>> assetMacros;
  final Duration runTimeout;
  final bool autoRunMacro;
  final bool managedByMacroServer;

  @override
  String get type => 'client_connect';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'platform': platform.name,
      'packages': package.toJson(),
      'macros': macros,
      'assetMacros': assetMacros.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
      'runTimeout': runTimeout.inMicroseconds,
      'autoRunMacro': autoRunMacro,
      'managedByMacroServer': managedByMacroServer,
    };
  }
}

class AcceptedVmServiceConnectMsg implements Message {
  AcceptedVmServiceConnectMsg();

  static AcceptedVmServiceConnectMsg fromJson(Map<String, dynamic> json) {
    return AcceptedVmServiceConnectMsg();
  }

  @override
  String get type => 'accepted_vm_service';

  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}

class CloseVmServiceConnectMsg implements Message {
  CloseVmServiceConnectMsg({
    required this.closeCode,
    required this.closeReason,
  });

  static CloseVmServiceConnectMsg fromJson(Map<String, dynamic> json) {
    return CloseVmServiceConnectMsg(
      closeCode: (json['closeCode'] as num?)?.toInt(),
      closeReason: json['closeReason'] as String?,
    );
  }

  final int? closeCode;
  final String? closeReason;

  @override
  String get type => 'close_vm_service';

  @override
  Map<String, dynamic> toJson() {
    return {
      if (closeCode != null) 'closeCode': closeCode,
      if (closeReason != null) 'closeReason': closeReason,
    };
  }
}

class RequestMacrosConfigMsg implements Message {
  RequestMacrosConfigMsg({
    required this.clientId,
    required this.filePath,
  });

  static RequestMacrosConfigMsg fromJson(Map<String, dynamic> json) {
    return RequestMacrosConfigMsg(
      clientId: (json['id'] as num).toInt(),
      filePath: json['path'] as String,
    );
  }

  final int clientId;
  final String filePath;

  @override
  String get type => 'request_macros_config';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': clientId,
      'path': filePath,
    };
  }
}

class SyncMacrosConfigMsg implements Message {
  const SyncMacrosConfigMsg({
    required this.config,
  });

  static SyncMacrosConfigMsg fromJson(Map<String, dynamic> json) {
    return SyncMacrosConfigMsg(
      config: UserMacroConfig.fromJson(json['config'] as Map<String, dynamic>),
    );
  }

  /// All macro configuration by keyed by macro name
  final UserMacroConfig config;

  @override
  String get type => 'sync_macros_config';

  @override
  Map<String, dynamic> toJson() {
    return {
      'config': config.toJson(),
    };
  }
}

class UserMacroConfig {
  const UserMacroConfig({
    required this.id,
    required this.context,
    required this.configs,
    required this.remapGeneratedFileTo,
  });

  static UserMacroConfig fromJson(Map<String, dynamic> json) {
    return UserMacroConfig(
      id: (json['id'] as num).toInt(),
      context: json['context'] as String,
      configs: json['configs'] as Map<String, dynamic>,
      remapGeneratedFileTo: json['remapGeneratedFileTo'] as String? ?? '',
    );
  }

  /// Unique id of the config, that can be used to cache parsed configs
  final int id;

  /// The context path root
  final String context;

  /// The user macro configuration
  final Map<String, dynamic> configs;

  /// The global project remap generated file path
  final String remapGeneratedFileTo;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'context': context,
      'configs': configs,
      if (remapGeneratedFileTo.isNotEmpty) 'remapGeneratedFileTo': remapGeneratedFileTo,
    };
  }
}

class RunMacroMsg implements Message {
  RunMacroMsg({
    required this.id,
    required this.path,
    required this.macroName,
    required this.imports,
    required this.libraryPaths,
    this.sharedClasses = const {},
    this.classes,
    this.records,
    this.topLevelFunctions,
    this.assetDeclaration,
    this.assetConfig,
    this.assetBasePath,
    this.assetAbsoluteBasePath,
    this.assetAbsoluteOutputPath,
  });

  static RunMacroMsg fromJson(Map<String, dynamic> json) {
    final sharedDec = <String, MacroClassDeclaration>{};
    final pendingUpdate = <void Function()>[];

    final (classesRes, records, functionRes) = runZoneGuarded(
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
          classes.add(MacroClassDeclaration.fromJson(e as Map<String, dynamic>));
        }

        final functions = <MacroFunctionDeclaration>[];
        for (final e in (json['functions'] as List?) ?? const []) {
          functions.add(MacroFunctionDeclaration.fromJson(e as Map<String, dynamic>));
        }

        final records = <MacroRecordDeclaration>[];
        for (final e in (json['records'] as List?) ?? const []) {
          records.add(MacroRecordDeclaration.fromJson(e as Map<String, dynamic>));
        }

        for (final update in pendingUpdate) {
          update();
        }
        pendingUpdate.clear();

        return (classes, records, functions);
      },
      values: {
        #sharedClasses: sharedDec,
        #pendingUpdates: pendingUpdate,
      },
    );

    return RunMacroMsg(
      id: (json['id'] as num).toInt(),
      path: json['path'] as String,
      macroName: json['name'] as String,
      imports: (json['imports'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      libraryPaths: (json['libraryPaths'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(num.parse(k).toInt(), v as String),
      ),
      sharedClasses: sharedDec,
      classes: classesRes,
      records: records,
      topLevelFunctions: functionRes,
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

  /// The absolute path of the file that triggered the macro
  final String path;

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

  /// The top level record declarations of a processed dart code
  final List<MacroRecordDeclaration>? records;

  /// The top level function declarations of a processed dart code
  final List<MacroFunctionDeclaration>? topLevelFunctions;

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
      'path': path,
      'name': macroName,
      'imports': imports,
      'libraryPaths': libraryPaths.map((k, v) => MapEntry(k.toString(), v)),
      if (sharedClasses.isNotEmpty) 'sharedClasses': sharedClasses.map((k, v) => MapEntry(k, v.toJson())),
      if (classes?.isNotEmpty == true) 'classes': classes!.map((e) => e.toJson()).toList(),
      if (records?.isNotEmpty == true) 'records': records!.map((e) => e.toJson()).toList(),
      if (topLevelFunctions?.isNotEmpty == true) 'functions': topLevelFunctions!.map((e) => e.toJson()).toList(),
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

class AutoRebuildOnConnectResultMsg implements Message {
  AutoRebuildOnConnectResultMsg({
    required this.results,
  });

  static AutoRebuildOnConnectResultMsg fromJson(Map<String, dynamic> json) {
    return AutoRebuildOnConnectResultMsg(
      results: (json['results'] as List)
          .map((e) => RegeneratedContextResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// The regenerated context result
  final List<RegeneratedContextResult> results;

  @override
  String get type => 'auto_rebuild_on_connect_result';

  @override
  Map<String, dynamic> toJson() {
    return {
      'results': results.map((e) => e.toJson()).toList(),
    };
  }
}

/// Result of an automatic macro rebuild operation.
///
/// This class encapsulates the outcome of rebuilding one or more macro contexts,
/// including success/failure status and timing information for each context.
class AutoRebuildResult {
  const AutoRebuildResult({
    required this.results,
  });

  static AutoRebuildResult fromJson(Map<String, dynamic> json) {
    return AutoRebuildResult(
      results: (json['results'] as List)
          .map((e) => RegeneratedContextResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// List of individual context rebuild results.
  ///
  /// Each entry corresponds to one package/context that was processed during
  /// the rebuild operation. Results may include both successful and failed rebuilds.
  final List<RegeneratedContextResult> results;

  Map<String, dynamic> toJson() {
    return {
      'results': results.map((e) => e.toJson()).toList(),
    };
  }
}

/// Result of regenerating a single macro context.
///
/// Contains the context identifier, any error that occurred, and timing information
/// for the regeneration operation.
class RegeneratedContextResult {
  const RegeneratedContextResult({
    required this.package,
    required this.context,
    required this.error,
    required this.completedInMilliseconds,
  });

  static RegeneratedContextResult fromJson(Map<String, dynamic> json) {
    return RegeneratedContextResult(
      package: json['package'] as String,
      context: json['context'] as String,
      error: json['error'] as String?,
      completedInMilliseconds: (json['completedInMs'] as num).toInt(),
    );
  }

  /// The name of the package
  final String package;

  /// The context (package path) that was regenerated.
  ///
  /// Typically represents a package or module path where macros were rebuilt.
  final String context;

  /// The error message if regeneration failed, or null if successful.
  ///
  /// When non-null, indicates that the macro regeneration for this context
  /// encountered an error and may not have completed successfully.
  final String? error;

  /// Total time taken to regenerate this context, in milliseconds.
  ///
  /// This includes all processing time for macro regeneration within the context,
  /// regardless of whether the operation succeeded or failed.
  final int completedInMilliseconds;

  /// Converts this result to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'package': package,
      'context': context,
      'error': error,
      'completedInMs': completedInMilliseconds,
    };
  }

  /// Returns true if this context was regenerated successfully (no error).
  bool get isSuccess => error == null;

  @override
  String toString() {
    return 'RegeneratedContextResult{package: $package, context: $context, error: $error, completedInMilliseconds: $completedInMilliseconds}';
  }
}

class GeneralMessage implements Message {
  const GeneralMessage({
    required this.message,
    this.level = Level.INFO,
  });

  static GeneralMessage fromJson(Map<String, dynamic> json) {
    final level = (json['level'] as String).split(':');
    return GeneralMessage(
      message: json['message'] as String,
      level: Level(level.first, int.parse(level.last)),
    );
  }

  final String message;
  final Level level;

  @override
  String get type => 'general_message';

  @override
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'level': '${level.name}:${level.value}',
    };
  }
}
