import 'package:analyzer/dart/element/element.dart';
import 'package:macro_kit/src/analyzer/base.dart';
import 'package:macro_kit/src/analyzer/internal_models.dart';
import 'package:macro_kit/src/analyzer/utils/hash.dart';
import 'package:macro_kit/src/core/core.dart';

mixin AnalyzeFunction on BaseAnalyzer {
  @override
  Future<MacroFunctionDeclaration?> parseTopLevelFunction(TopLevelFunctionFragment functionFragment) async {
    // combine all declared macro in one list and share with each config
    // (one function can have many metadata attached, we parsed config based on each metadata)
    List<MacroConfig> macroConfigs = [];
    Set<String> macroNames = {};
    bool combined = false;

    final functionName = functionFragment.element.name ?? '';

    // 1. get all metadata attached to the function
    final annotations = functionFragment.metadata.annotations;
    for (final macroAnnotation in annotations) {
      if (!isValidAnnotation(macroAnnotation, className: 'Macro', pkgName: 'macro')) {
        continue;
      }

      final macroConfig = await computeMacroMetadata(macroAnnotation);
      if (macroConfig == null) {
        // if no compute macro metadata, return
        continue;
      }

      final capability = macroConfig.capability;
      if (!capability.topLevelFunctions) {
        // if there is no capability, return it
        logger.info('Top level function: $functionName does not defined any Macro capability, ignored');
        continue;
      }

      macroConfigs.add(macroConfig);
      macroNames.add(macroConfig.key.name);
    }

    // 2. combine each requested capability to produce one result, then
    //    at execution time only provide the requested capability.
    //    * the generator maybe get extra data if not easily removed or for performance reason
    MacroCapability capability;
    if (macroConfigs.isEmpty) {
      // does not contain macro and not allowed
      return null;
    }

    capability = macroConfigs.first.capability;

    // combine capability
    for (final config in macroConfigs.skip(1)) {
      capability = capability.combine(config.capability);
      combined = true;
    }

    final fnTypeParams = await parseTypeParameter(
      capability,
      functionFragment.typeParameters.map((e) => e.element).toList(),
    );

    final functionElem = functionFragment.element;
    final function = await getFunctionInfo(
      functionElem,
      fnTypeParams,
      capability: capability,
      filterMethodMetadata: capability.filterClassMethodMetadata,
      macroKeys: null,
      isAsynchronous: functionFragment.isAsynchronous,
      isSynchronous: functionFragment.isSynchronous,
      isGenerator: functionFragment.isGenerator,
      isAugmentation: functionFragment.isAugmentation,
    );

    final (cacheKey, functionId) = functionDeclarationCachedKey(functionFragment, capability);
    final importPrefix = importPrefixByElements[functionElem] ?? '';
    final libraryPath = functionElem.library.uri.toString();
    final libraryId = generateHash(libraryPath);
    libraryPathById[libraryId] = libraryPath;

    final declaration = MacroFunctionDeclaration(
      libraryId: libraryId,
      functionId: functionId,
      configs: macroConfigs,
      importPrefix: importPrefix,
      info: function,
      typeParameters: fnTypeParams,
    );

    if (combined) {
      macroAnalyzeResult.putIfAbsent(macroNames.first, () => AnalyzeResult()).topLevelFunctions.add(declaration);
    } else {
      for (final name in macroNames) {
        macroAnalyzeResult.putIfAbsent(name, () => AnalyzeResult()).topLevelFunctions.add(declaration);
      }
    }

    iterationCaches[cacheKey] = CountedCache(declaration);
    return declaration;
  }
}
