library;

export 'package:collection/collection.dart' show DeepCollectionEquality;

export 'src/analyzer/error.dart';
export 'src/client/run.dart';
export 'src/client/client_manager.dart' show MacroInitFunction;
export 'src/common/models.dart' show AutoRebuildResult;
export 'src/common/common.dart' show buildGeneratedFileInfoFor;
export 'src/core/core.dart' hide MacroX, BaseMacroGenerator;
export 'src/core/extension.dart';
export 'src/core/modifier.dart';
export 'src/macro/asset_path/asset_path_macro.dart';
export 'src/macro/data_class/config.dart' hide JsonKeyConfig, DataClassMacroConfig;
export 'src/macro/data_class/data_class_macro.dart' hide dataClassMacroCapability;
export 'src/macro/data_class/helpers.dart';
