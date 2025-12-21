import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:dart_style/dart_style.dart';
import 'package:hashlib/hashlib.dart';
import 'package:macro_kit/macro_kit.dart';
import 'package:macro_kit/src/analyzer/utils/hash.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/utils/spawner.dart';
import 'package:macro_kit/src/analyzer/types.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/common/models.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';
import 'package:yaml/yaml.dart';

typedef PendingPath = ({String path, ChangeType type, bool force});
typedef PendingAnalyze = ({List<AnalyzingAsset>? asset});

typedef AnalyzingAsset = ({
  AssetMacroInfo macro,
  String absoluteBasePath,
  String relativeBasePath,
  String absoluteOutputPath,
});

abstract class MacroServerInterface {
  void requestPluginToConnect();

  void requestClientToConnect();

  int? getClientChannelIdByMacro(String targetMacro, String filePath);

  Future<RunMacroResultMsg> runMacroGenerator(int channelId, RunMacroMsg message);

  ({String genFilePath, String relativePartFilePath}) buildGeneratedFileInfo(String path);

  void sendMessageMacroClients(GeneralMessage message, {int? clientId});

  void onClientError(int channelId, String message, [Object? err, StackTrace? trace]);
}

class DefaultFakeServerInterface implements MacroServerInterface {
  const DefaultFakeServerInterface();

  static final exception = Exception('Server is not initiated yet!');

  @override
  ({String genFilePath, String relativePartFilePath}) buildGeneratedFileInfo(String path) {
    throw exception;
  }

  @override
  int? getClientChannelIdByMacro(String targetMacro, String filePath) {
    throw exception;
  }

  @override
  void onClientError(int channelId, String message, [Object? err, StackTrace? trace]) {}

  @override
  void requestClientToConnect() {}

  @override
  void requestPluginToConnect() {}

  @override
  Future<RunMacroResultMsg> runMacroGenerator(int channelId, RunMacroMsg message) {
    throw exception;
  }

  @override
  void sendMessageMacroClients(GeneralMessage message, {int? clientId}) {}
}

abstract class BaseAnalyzer {
  BaseAnalyzer({
    required this.logger,
    required this.server,
  });

  final MacroLogger logger;
  MacroServerInterface server;

  final DartFormatter formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
    pageWidth: 120,
    trailingCommas: TrailingCommas.preserve,
  );

  late final ByteStore byteStore = MemoryCachingByteStore(NullByteStore(), 1024 * 1024 * 256);
  List<String> analysisContextPaths = [];
  AnalysisContextCollection contextCollection = AnalysisContextCollection(
    includedPaths: [],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );

  AnalysisSession? currentSession;

  final Map<String, File> fileCaches = {};

  /// per analyze cache for reusing common parsing like computing a class type info
  final Map<String, CountedCache> iterationCaches = {};

  final Set<String> mayContainsMacroCache = {};
  final Map<PendingPath, PendingAnalyze> pendingAnalyze = {};
  final StreamController<bool> pendingAnalyzeCompleted = StreamController.broadcast();
  final PendingAnalyze defaultNullPendingAnalyzeValue = (asset: null);
  final Stopwatch stopWatch = Stopwatch();
  String currentAnalyzingPath = '';
  String lastAnalyzingPath = '';
  ChangeType lastChangeType = ChangeType.MODIFY;
  bool isAnalyzingFile = false;

  /// Contain hash of library uri path to uri of the file
  final Map<int, String> libraryPathById = {};

  /// Contains a pair of element with their prefixed import
  final Map<Element, String> importPrefixByElements = {};
  final Map<String, String> imports = {};

  /// --- internal state of required of sub types, reset per [processDartSource] call
  Map<String, AnalyzeResult> macroAnalyzeResult = {};
  List<(List<MacroConfig>, ClassFragment)> pendingClassRequiredSubTypes = [];

  @internal
  int lastTime = DateTime.now().millisecondsSinceEpoch;

  @pragma('vm:prefer-inline')
  int getDiffFromLastExecution() {
    final newTime = DateTime.now().millisecondsSinceEpoch;
    final res = newTime - lastTime;
    lastTime = newTime;
    return res;
  }

  bool lockOrReturnInProgressClassFieldsFor(Fragment fragment) {
    final key = 'inProgress:${'${fragment.element.name}:${fragment.element.library?.uri.toString()}'}';
    if (iterationCaches.containsKey(key)) {
      return true;
    }

    iterationCaches[key] = CountedCache(true);
    return false;
  }

  void clearInProgressClassFieldsFor(Fragment fragment) {
    final key = 'inProgress:${'${fragment.element.name}:${fragment.element.library?.uri.toString()}'}';
    iterationCaches.remove(key);
  }

  @pragma('vm:prefer-inline')
  String loadContextPackageName(String context) {
    try {
      final pubspecContent = loadYamlNode(File(p.join(context, 'pubspec.yaml')).readAsStringSync());
      return switch (pubspecContent.value['name']) {
        String v => v,
        _ => '',
      };
    } catch (e) {
      logger.error(
        'Unable to read package name from pubspec.yaml for context: $context. '
        'Using full context path as package name fallback.',
      );
      return context;
    }
  }

  @pragma('vm:prefer-inline')
  MacroClientConfiguration loadMacroConfig(String context, String packageName) {
    try {
      final content = jsonDecode(File(p.join(context, 'macro.json')).readAsStringSync());
      if (content is Map) {
        return MacroClientConfiguration.fromJson(newId(), context, packageName, content as Map<String, dynamic>);
      }
    } on PathNotFoundException {
      //
    } catch (e) {
      logger.error('Failed to read macro configuration for: $context');
    }

    return MacroClientConfiguration.withDefault(newId(), context, packageName);
  }

  @pragma('vm:prefer-inline')
  Future<MacroContextSourceCodeInfo> evaluateMacroContextConfiguration(
    String filePath, {
    MacroContextSourceCodeInfo? existingSourceContext,
  }) async {
    try {
      final contextFile = File(filePath);
      if (!contextFile.existsSync()) {
        return MacroContextSourceCodeInfo.testContext();
      }

      final content = contextFile.readAsStringSync();
      final hashId = xxh3code(content);
      if (existingSourceContext?.hashId == hashId) {
        return existingSourceContext!;
      }

      final result = await MacroContextSourceCodeInfo.fromSource(hashId, content);
      switch (result) {
        case SpawnError<MacroContextSourceCodeInfo>():
          logger.error('Failed to evaluate macro_context.dart for: $filePath', result.error, result.trace);
          return const MacroContextSourceCodeInfo(hashId: 0, autoRun: false, runCommand: []);
        case SpawnData<MacroContextSourceCodeInfo>():
          return result.data;
      }
    } catch (e, s) {
      logger.error('Failed to evaluate macro_context.dart for: $filePath', e, s);
      return const MacroContextSourceCodeInfo(hashId: 0, autoRun: false, runCommand: []);
    }
  }

  void removeFile(String path) {
    try {
      (fileCaches[path] ?? File(path)).deleteSync();
    } on PathNotFoundException {
      return;
    } catch (e) {
      logger.error('Failed to delete file', e);
    }
  }

  Future<MacroClassDeclaration?> parseClass(
    ClassFragment classFragment, {
    List<MacroConfig>? collectSubTypeConfig,
    List<ElementAnnotation>? typeAliasAnnotation,
    String? typeAliasClassName,
  });

  Future<(List<MacroProperty>?, List<MacroProperty>?, bool)> parseClassFields(
    MacroCapability capability,
    InterfaceFragment classFragment,
    List<MacroProperty>? classTypeParams,
  );

  Future<(List<MacroClassConstructor>, List<MacroProperty>?, bool)> parseClassConstructors(
    MacroCapability capability,
    InterfaceFragment classFragment,
    List<MacroProperty>? classTypeParams,
    List<MacroProperty>? classFields,
  );

  Future<(List<MacroMethod>?, bool)> parseClassMethods(
    MacroCapability capability,
    InterfaceFragment classFragment,
    List<MacroProperty>? classTypeParams,
  );

  Future<List<MacroProperty>> parseTypeParameter(
    MacroCapability capability,
    List<TypeParameterElement> typeParameterElements,
  );

  Future<MacroClassDeclaration?> parseEnum(
    EnumFragment enumFragment, {
    required MacroCapability fallbackCapability,
    List<ElementAnnotation>? typeAliasAnnotation,
    String? typeAliasClassName,
  });

  Future<void> collectClassSubTypes(
    List<(List<MacroConfig>, ClassFragment)> pendingRequiredSubTypes,
    LibraryFragment libraryFragment,
    Map<String, AnalyzeResult> macroAnalyzeResult,
  ) async {
    for (final (capability, classFragment) in pendingRequiredSubTypes) {
      // get sub types
      final subTypes = findSubTypesOf(classFragment.element, libraryFragment);
      if (subTypes.isEmpty) continue;

      // convert to macro declaration
      final classDeclaration = <MacroClassDeclaration>[];
      for (final classSubType in subTypes) {
        final declaration = await parseClass(classSubType, collectSubTypeConfig: capability);
        if (declaration != null) {
          classDeclaration.add(declaration);
        }
      }

      final targetClassRequestedSubTypes = classFragment.element.name ?? '';
      // add subtypes only for the class that requested and has collectSubTypes capability
      for (final analyzeRes in macroAnalyzeResult.values) {
        classLoop:
        for (final clazz in analyzeRes.classes) {
          if (clazz.className != targetClassRequestedSubTypes) continue;

          for (final config in clazz.configs) {
            if (config.capability.collectClassSubTypes) {
              //  clazz.subTypes never be null because we init with empty
              clazz.subTypes?.addAll(classDeclaration);
              continue classLoop;
            }
          }
        }
      }
    }
  }

  List<ClassFragment> findSubTypesOf(ClassElement baseClass, LibraryFragment libraryFragment) {
    final result = <ClassFragment>[];
    for (final classElem in libraryFragment.element.classes) {
      if (_isSubTypeOf(classElem, baseClass, libraryFragment)) {
        result.add(classElem.firstFragment);
      }
    }

    return result;
  }

  // --- internal ----
  bool isValidAnnotation(
    ElementAnnotation? annotation, {
    required String className,
    required String pkgName,
  });

  Future<MacroConfig?> computeMacroMetadata(ElementAnnotation macroMetadata);

  Future<List<MacroKey>?> computeMacroKeys(String filter, Metadata metadata, MacroCapability capability);

  Future<MacroKey?> computeMacroKey(String keyName, ElementAnnotation macroMetadata, MacroCapability capability);

  Future<({Object? constantValue, MacroModifier modifier, bool reqConversion})?> computeConstantInitializerValue(
    String fieldName,
    DartObject fieldValue,
    MacroCapability capability,
  );

  Future<({Object? constantValue, MacroModifier modifier, bool reqConversion})> computeMacroKeyValue(
    String fieldName,
    DartObject fieldValue,
    MacroCapability capability,
  );

  Future<TypeInfoResult> getTypeInfoFrom(
    Object? /*Element?|DartType*/ elem,
    List<MacroProperty> genericParams,
    String filterMethodMetadata,
    MacroCapability capability,
  );

  Future<MacroMethod> getFunctionInfo(
    Object? method,
    List<MacroProperty> genericParams, {
    required MacroCapability capability,
    required String filterMethodMetadata,
    required List<MacroKey>? macroKeys,
    String? fnName,
    bool isAsynchronous = false,
    bool isSynchronous = false,
    bool isGenerator = false,
    bool isAugmentation = false,
  });

  List<DartType> getTypeArguments(DartType type, String forName);

  Future<List<MacroProperty>> createMacroTypeArguments(
    List<DartType> types,
    List<MacroProperty> genericParams,
    MacroCapability capability,
    String filterMethodMetadata, {
    int? mustTake,
  });

  Future<MacroProperty?> inspectStaticFromJson(
    DartType type,
    List<MacroProperty> genericParams,
    String filterMethodMetadata,
    MacroCapability capability,
  );

  // --- internal ----

  bool _isSubTypeOf(InterfaceElement type, ClassElement target, LibraryFragment libraryFragment) {
    final superType = type.supertype;
    if (superType != null && superType.element == target) return true;

    // Check implements
    for (final interface in type.interfaces) {
      if (interface.element == target) return true;
    }

    // Check mixins
    for (final mixin in type.mixins) {
      if (mixin.element == target) return true;
    }

    // OPTIONAL: recursively check inherited subtypes
    if (type.supertype != null) {
      return _isSubTypeOf(type.supertype!.element, target, libraryFragment);
    }

    return false;
  }

  (String, String) classDeclarationCachedKey(
    ClassFragment classFragment,
    MacroCapability capability, [
    String? typeAliasName,
  ]) {
    final className = typeAliasName ?? classFragment.element.name;
    final uri = classFragment.element.library.uri.toString();
    final id = '$className:${generateHash('$capability$className$uri')}';
    return ('classDec:$id', id);
  }

  (String, String) enumDeclarationCachedKey(
    EnumFragment enumFragment,
    MacroCapability capability, [
    String? typeAliasName,
  ]) {
    final enumName = typeAliasName ?? enumFragment.element.name;
    final uri = enumFragment.element.library.uri.toString();
    final id = '$enumName:${generateHash('$capability$enumName$uri')}';
    return ('enumDec:$id', id);
  }
}
