import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:dart_style/dart_style.dart';
import 'package:macro_kit/macro.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/logger.dart';
import 'package:macro_kit/src/analyzer/models.dart';
import 'package:meta/meta.dart';

abstract class MacroServer {
  void requestPluginToConnect();

  void requestClientToConnect();

  MacroClientConfiguration getMacroConfigFor(String path);

  void removeFile(String path);

  int? getClientChannelFor(String targetMacro);

  Future<RunMacroResultMsg> runMacroGenerator(int channelId, RunMacroMsg message);

  ({String genFilePath, String relativePartFilePath}) buildGeneratedFileInfo(String path);

  void onClientError(int channelId, String message, [Object? err, StackTrace? trace]);
}

abstract class BaseAnalyzer implements MacroServer {
  BaseAnalyzer({required this.logger});

  final MacroLogger logger;
  final Random random = Random();
  final DartFormatter formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
    pageWidth: 120,
    trailingCommas: TrailingCommas.preserve,
  );

  List<String> contexts = <String>[];
  AnalysisContextCollection contextCollection = AnalysisContextCollection(
    includedPaths: [],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );

  final Map<String, File> fileCaches = {};

  /// per analyze cache for reusing common parsing like computing a class type info
  final Map<String, CountedCache> iterationCaches = {};
  final Set<String> mayContainsMacroCache = {};
  final List<String> pendingAnalyze = [];
  String currentAnalyzingPath = '';
  bool isAnalyzingFile = false;

  /// --- internal state of required of sub types, reset per [processSource] call
  Map<String, AnalyzeResult> macroAnalyzeResult = {};
  List<(List<MacroConfig>, ClassFragment)> pendingClassRequiredSubTypes = [];

  int newId() => random.nextInt(100000);

  @internal
  MacroClassDeclaration? parseClass(ClassFragment classFragment, {List<MacroConfig>? collectSubTypeConfig});
}
