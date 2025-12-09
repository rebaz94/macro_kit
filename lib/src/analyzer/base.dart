import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:dart_style/dart_style.dart';
import 'package:macro_kit/macro_kit.dart';
import 'package:macro_kit/src/analyzer/hash.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/common/logger.dart';
import 'package:macro_kit/src/common/models.dart';

abstract class MacroServer {
  void requestPluginToConnect();

  void requestClientToConnect();

  MacroClientConfiguration getMacroConfigFor(String path);

  void removeFile(String path);

  int? getClientChannelIdByMacro(String targetMacro);

  Future<RunMacroResultMsg> runMacroGenerator(int channelId, RunMacroMsg message);

  ({String genFilePath, String relativePartFilePath}) buildGeneratedFileInfo(String path);

  void onClientError(int channelId, String message, [Object? err, StackTrace? trace]);
}

typedef PendingAnalyze = ({String path, List<AnalyzingAsset>? asset, AssetChangeType type});

typedef AnalyzingAsset = ({
  AssetMacroInfo macro,
  String absoluteBasePath,
  String relativeBasePath,
  String absoluteOutputPath,
});

abstract class BaseAnalyzer implements MacroServer {
  BaseAnalyzer({required this.logger});

  final MacroLogger logger;
  final Random random = Random();
  final DartFormatter formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
    pageWidth: 120,
    trailingCommas: TrailingCommas.preserve,
  );

  late final ByteStore byteStore = MemoryCachingByteStore(NullByteStore(), 1024 * 1024 * 256);
  List<String> contexts = <String>[];
  AnalysisContextCollection contextCollection = AnalysisContextCollection(
    includedPaths: [],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );

  AnalysisSession? currentSession;

  final Map<String, File> fileCaches = {};

  /// per analyze cache for reusing common parsing like computing a class type info
  final Map<String, CountedCache> iterationCaches = {};

  final Set<String> mayContainsMacroCache = {};
  final List<PendingAnalyze> pendingAnalyze = [];
  final StreamController<bool> pendingAnalyzeCompleted = StreamController.broadcast();
  String currentAnalyzingPath = '';
  bool isAnalyzingFile = false;

  /// Contain hash of library uri path to uri of the file
  final Map<int, String> libraryPathById = {};

  /// Contains a pair of element with their prefixed import
  final Map<Element, String> importPrefixByElements = {};
  final Map<String, String> imports = {};

  /// --- internal state of required of sub types, reset per [processDartSource] call
  Map<String, AnalyzeResult> macroAnalyzeResult = {};
  List<(List<MacroConfig>, ClassFragment)> pendingClassRequiredSubTypes = [];

  int newId() => random.nextInt(100000);

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
