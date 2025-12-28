import 'dart:async';

import 'package:change_case/change_case.dart';
import 'package:collection/collection.dart';
import 'package:macro_kit/macro_kit.dart';
import 'package:macro_kit/src/analyzer/types_ext.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/macro/data_class/config.dart';
import 'package:macro_kit/src/macro/data_class/utils.dart';

/// **DataClassMacro** generates common data-class boilerplate such as
/// `fromJson`, `toJson`, `copyWith`, equality, `toString`, and (in the
/// future) constructor implementations.
///
/// The macro is fully configurable through annotation metadata and can
/// optionally support polymorphic class hierarchies via a discriminator configuration
///
/// **Example**
/// Annotate your class with `@Macro(DataClassMacro)` or use the shorthand
/// `@dataClassMacro`, then apply a `with` clause to include the generated
/// mixin, e.g.:
///
/// ```dart
/// @dataClassMacro
/// class User with UserDataClass {
///   ...
/// }
/// ```
class DataClassMacro extends MacroGenerator {
  const DataClassMacro({
    super.capability = dataClassMacroCapability,
    this.primaryConstructor,
    this.fromJson,
    this.toJson,
    this.mapTo,
    this.asCast,
    this.equal,
    this.copyWith,
    this.copyWithAsOption,
    this.toStringOverride,
    this.discriminatorKey,
    this.discriminatorValue,
    this.includeDiscriminator,
    this.defaultDiscriminator,
  });

  static DataClassMacro initialize(MacroConfig config) {
    final key = config.key;
    final props = Map.fromEntries(key.properties.map((e) => MapEntry(e.name, e)));

    return DataClassMacro(
      capability: config.capability,
      primaryConstructor: props['primaryConstructor']?.asStringConstantValue(),
      fromJson: props['fromJson']?.asBoolConstantValue(),
      toJson: props['toJson']?.asBoolConstantValue(),
      mapTo: props['mapTo']?.asBoolConstantValue(),
      asCast: props['asCast']?.asBoolConstantValue(),
      equal: props['equal']?.asBoolConstantValue(),
      copyWith: props['copyWith']?.asBoolConstantValue(),
      copyWithAsOption: props['copyWithAsOption']?.asBoolConstantValue(),
      toStringOverride: props['toStringOverride']?.asBoolConstantValue(),
      discriminatorKey: props['discriminatorKey']?.asStringConstantValue(),
      discriminatorValue: props['discriminatorValue']?.constantValue,
      includeDiscriminator: props['includeDiscriminator']?.asBoolConstantValue(),
      defaultDiscriminator: props['defaultDiscriminator']?.asBoolConstantValue(),
    );
  }

  /// if contains `.`, this is a named constructor, it can be customized in option
  /// like defining a named constructor as `test` for class Example with the following option
  ///  1. [primaryConstructor] = 'Example.test'
  ///  2. [primaryConstructor] = '.test' which is same 'Example.test'
  final String? primaryConstructor;

  /// If `true` (the default) based on global config, it generate static fromJson
  final bool? fromJson;

  /// If `true` (the default) based on global config, it generate toJson method
  final bool? toJson;

  /// If `true` (the default) based on global config, it generate map and mapOrNull method on sealed or abstract class
  final bool? mapTo;

  /// If `true` (the default) based on global config, it generate as cast method on sealed or abstract class
  final bool? asCast;

  /// If `true` (the default) based on global config, it implements equality
  final bool? equal;

  /// If `true` (the default) based on global config, it generate copyWith method
  final bool? copyWith;

  /// If `true`. it uses [Option<T>] for all fields in the generated copyWith method.
  ///
  /// the fields will use [Option<T>] to distinguish between "not provided"
  /// and "explicitly set to null", enabling proper null assignment in copyWith.
  ///
  /// Note: In a future, `Option<T>`-based copyWith will become the default behavior.
  final bool? copyWithAsOption;

  /// If `true` (the default) based on global config, it toString method
  final bool? toStringOverride;

  /// Property key used for type discriminators.
  ///
  /// For polymorphic classes this will be used for identifying the
  /// correct subtype when decoding an object.
  final String? discriminatorKey;

  /// Custom value for the discriminator property.
  ///
  /// If not set this defaults to the class name.
  ///
  /// Supported values:
  ///   * int, double, number, bool, string or
  ///   * a custom function with signature of
  ///     `bool Function(Map<String, dynamic> json)` returning `true`
  ///     to match the provided class.
  final Object? discriminatorValue;

  /// Whether to automatically include type discriminator
  ///
  /// only provide this property when there is no value provided for [discriminatorKey] or [discriminatorValue],
  final bool? includeDiscriminator;

  /// If you want this class to be the default choice when no other
  /// discriminator value matches, set it to true.
  final bool? defaultDiscriminator;

  @override
  String get suffixName => 'Data';

  @override
  GeneratedType get generatedType => GeneratedType.mixin;

  @override
  MacroGlobalConfigParser? get globalConfigParser => DataClassMacroConfig.fromJson;

  DataClassMacroConfig _getConfig(MacroState state) {
    if (state.globalConfig case DataClassMacroConfig v) {
      return v;
    }
    return const DataClassMacroConfig();
  }

  @override
  Future<void> init(MacroState state) async {
    if (state.targetType != TargetType.clazz) {
      throw MacroException('DataClassMacro can only be applied on class but applied on: ${state.targetType}');
    }
  }

  @override
  Future<void> onClassTypeParameter(MacroState state, List<MacroProperty> typeParameters) async {
    state.set('typeParams', typeParameters);
  }

  @override
  Future<void> onClassConstructors(MacroState state, List<MacroClassConstructor> classConstructor) async {
    state.set('classConstructors', classConstructor);
  }

  @override
  Future<void> onClassSubTypes(MacroState state, List<MacroClassDeclaration> subTypes) async {
    final discriminatorValues = <(MacroClassDeclaration, MacroProperty?)>[];

    subTypeLoop:
    for (final classType in subTypes) {
      for (final config in classType.configs) {
        if (config.key.name != 'DataClassMacro') continue;

        MacroProperty? discriminatorValue;
        bool useAsDefault = false;
        int allSet = 0;

        propLoop:
        for (final prop in config.key.properties) {
          switch (prop.name) {
            case 'discriminatorValue':
              discriminatorValue = prop;
            case 'defaultDiscriminator':
              useAsDefault = prop.asBoolConstantValue() ?? false;
            default:
              continue propLoop;
          }

          allSet++;
          if (allSet >= 2) break propLoop;
        }

        discriminatorValues.add((classType, discriminatorValue));

        if (useAsDefault) {
          state.set('defaultPolymorphicClass', classType);
        }

        continue subTypeLoop;
      }
    }

    if (discriminatorValues.isNotEmpty) {
      discriminatorValues.sortBy((e) => e.$1.className);
      state.set('discriminatorValues', discriminatorValues);
    }
  }

  @override
  Future<void> onGenerate(MacroState state) async {
    if (state.modifier.isAlias) {
      // alias type not supported as target
      return;
    }

    // final classFields = state.get<List<MacroField>>('classFields');
    final typeParams = state.getOrNull<List<MacroProperty>>('typeParams') ?? const [];
    final constructors = state.getOrNull<List<MacroClassConstructor>>('classConstructors') ?? const [];
    final polymorphicClass = state.modifier.isSealed || state.modifier.isAbstract;
    final dartCorePrefix = state.imports[r"import dart:core"] ?? '';
    state.set('dartCorePrefix', dartCorePrefix);

    final buff = StringBuffer();
    if (!state.isCombingGenerator) {
      buff.write('mixin ${state.targetName}${state.suffixName}');
      if (typeParams.isNotEmpty) {
        buff.write(MacroProperty.getTypeParameterWithBound(typeParams));
      }

      buff.write(' {\n');
    } else if (polymorphicClass) {
      throw MacroException('Sealed or Abstract class does not support combining generated code from different Macro');
    }

    /// generate primary constructor
    var primaryCtor = primaryConstructor?.isNotEmpty == true ? primaryConstructor! : 'new';
    if (primaryCtor.startsWith('.')) {
      primaryCtor = primaryCtor.substring(1);
    } else if (primaryCtor.contains('.')) {
      primaryCtor = primaryCtor.split('.').last;
    }

    final currentPrimaryConstructor = constructors.firstWhereOrNull((e) => e.constructorName == primaryCtor);
    final (positionlFields, namedFields, useFactoryFields) = _generatePrimaryConstructor(
      state: state,
      buff: buff,
      className: state.targetName,
      primaryCtorName: primaryCtor,
      currentPrimaryConstructor: currentPrimaryConstructor,
      classFields: const [],
    );

    // TODO: when augment released, use either final field of a class or constructor
    // it currently always uses the constructor with already added final field in the body of class
    // to define data class but that can be changed with augment, it can add field
    // into class by doing ({required String name}}.
    final fields = CombinedListView([positionlFields, namedFields]);

    buff.write('\n');

    // remove default constructor name, not needed
    if (primaryCtor == 'new') {
      primaryCtor = '';
    }

    final config = _getConfig(state);
    if (polymorphicClass) {
      _generatePolymorphicDataClass(
        state: state,
        buff: buff,
        config: config,
        typeParams: typeParams,
      );
    } else {
      _generateDataClass(
        state: state,
        buff: buff,
        config: config,
        primaryCtor: primaryCtor,
        currentPrimaryConstructor: currentPrimaryConstructor,
        typeParams: typeParams,
        positionalFields: positionlFields,
        namedFields: namedFields,
        fields: fields,
      );
    }

    if (!state.isCombingGenerator) {
      buff.write('\n}\n');
    }

    state.reportGenerated(buff.toString());
  }

  (List<MacroProperty>, List<MacroProperty>, bool) _generatePrimaryConstructor({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required String primaryCtorName,
    required List<MacroProperty> classFields,
    required MacroClassConstructor? currentPrimaryConstructor,
  }) {
    // code commented out until augment feature become stable, at that time we
    // can generate constructor using factory

    if (currentPrimaryConstructor == null) {
      // if (constant) {
      //   buff.write('const ');
      // }
      //
      // // generate constructor name
      // buff.write('$className${primaryConstructorName == 'new' ? '' : '.$primaryConstructorName'}');
      //
      // buff.write('(');
      // if (namedConstructor) {
      //   buff.write(
      //     '{${classFields.map((e) => '${e.type.contains('?') ? '' : 'required '}this.${e.name}').join(', ')}}',
      //   );
      // } else {
      //   buff.write(classFields.map((e) => 'this.${e.name}').join(', '));
      // }
      // buff.write(');\n');

      return (const [], const [], false);
    } else if (currentPrimaryConstructor.modifier.isFactory &&
        currentPrimaryConstructor.redirectFactory?.isNotEmpty == true) {
      // // generate redirect constructor
      // if (constant) {
      //   buff.write('const ');
      // }
      //
      // // generate redirect constructor name
      // buff.write(' $className${currentPrimaryConstructor.redirectFactory == 'new' ? '': currentPrimaryConstructor.redirectFactory!}');
      //
      // // constructor fields
      // buff.write('(');
      // if (currentPrimaryConstructor.positionalFields.isNotEmpty) {
      //   buff.write('\n');
      // }
      // buff.write(currentPrimaryConstructor.positionalFields.map((e) => '  this.${e.name}').join(',\n'));
      //
      // if (currentPrimaryConstructor.namedFields.isNotEmpty && currentPrimaryConstructor.positionalFields.isNotEmpty) {
      //   buff.write(', ');
      // }
      //
      // if (currentPrimaryConstructor.namedFields.isNotEmpty) {
      //   buff.write(
      //     '{\n${currentPrimaryConstructor.namedFields.map((e) {
      //       return '  ${e.type.contains('?') ? '' : 'required '}this.${e.name}';
      //     }).join(',\n')}',
      //   );
      //
      //   buff.write(',\n }');
      // }
      // buff.write(');\n\n');
      //
      // // generate the field
      // buff.write(currentPrimaryConstructor.namedFields.map((e) => ' final ${e.type} ${e.name};').join('\n'));
      // buff.write(currentPrimaryConstructor.positionalFields.map((e) => ' final ${e.type} ${e.name};').join('\n'));
      // buff.write('\n');

      return (currentPrimaryConstructor.positionalFields, currentPrimaryConstructor.namedFields, true);
    } else if (currentPrimaryConstructor.modifier.isFactory) {
      throw MacroException('Data class should be a normal class with fields or a factory constructor');
    } else {
      return (currentPrimaryConstructor.positionalFields, currentPrimaryConstructor.namedFields, true);
    }
  }

  void _generateDataClass({
    required MacroState state,
    required StringBuffer buff,
    required DataClassMacroConfig config,
    required String primaryCtor,
    required MacroClassConstructor? currentPrimaryConstructor,
    required List<MacroProperty> typeParams,
    required List<MacroProperty> positionalFields,
    required List<MacroProperty> namedFields,
    required CombinedListView<MacroProperty> fields,
  }) {
    /// generate fromJson
    if (fromJson ?? config.createFromJson ?? true) {
      _generateFromJson(
        state: state,
        buff: buff,
        ctorName: primaryCtor,
        className: state.targetName,
        typeParams: typeParams,
        positionalFields: positionalFields,
        namedFields: namedFields,
      );
    }

    /// generate toJson
    if (toJson ?? config.createToJson ?? true) {
      _generateToJson(
        state: state,
        buff: buff,
        ctorName: primaryCtor,
        className: state.targetName,
        fields: fields,
        typeParams: typeParams,
      );
    }

    /// generate copyWith
    if (copyWith ?? config.createCopyWith ?? true) {
      _generateCopyWith(
        state: state,
        buff: buff,
        className: state.targetName,
        ctorName: primaryCtor,
        positionalFields: positionalFields,
        namedFields: namedFields,
        typeParams: typeParams,
      );
    }

    /// generate equality
    if (equal ?? config.createEqual ?? true) {
      _generateEquality(
        state: state,
        buff: buff,
        className: state.targetName,
        fields: fields,
        typeParams: typeParams,
      );
    }

    /// generate toString
    if (toStringOverride ?? config.createToStringOverride ?? true) {
      _generateToString(
        state: state,
        className: state.targetName,
        buff: buff,
        fields: fields,
        typeParams: typeParams,
      );
    }
  }

  void _generatePolymorphicDataClass({
    required MacroState state,
    required StringBuffer buff,
    required DataClassMacroConfig config,
    required List<MacroProperty> typeParams,
  }) {
    // discriminator
    final discriminatorDefault = state.getOrNull<MacroClassDeclaration?>('defaultPolymorphicClass');
    final discriminatorValues =
        state.getOrNull<List<(MacroClassDeclaration, MacroProperty?)>>('discriminatorValues') ?? const [];
    final mainClassTypeParams = MacroProperty.getTypeParameter(typeParams);

    // combine generic for all sealed class
    final discriminatorTypeParamsByIndex = <int, List<MacroProperty>>{};
    final discriminatorTypeParamsByIndexRange = <int, _RangeInfo>{};
    final discriminatorTypeParams = <MacroProperty>[];
    for (int i = 0; i < discriminatorValues.length; i++) {
      final (classType, _) = discriminatorValues[i];
      if (classType.classTypeParameters?.isNotEmpty != true) {
        continue;
      }
      discriminatorTypeParamsByIndex[i] = classType.classTypeParameters!; // TODO: to remove

      final start = discriminatorTypeParams.isEmpty ? 0 : discriminatorTypeParams.length;
      discriminatorTypeParams.addAll(classType.classTypeParameters!);
      discriminatorTypeParamsByIndexRange[i] = (start: start, end: discriminatorTypeParams.length);
    }
    //
    // add type params from class
    final uniqueTypeParams = <MacroProperty>[];
    final usedTypes = <String>{};
    for (final typeParam in typeParams) {
      usedTypes.add(typeParam.name);
      uniqueTypeParams.add(typeParam);
    }

    // add discriminator type params and change their name if conflict with existing type
    final replacements = <String, String>{};
    for (final (i, typeParam) in discriminatorTypeParams.indexed) {
      if (usedTypes.contains(typeParam.name)) {
        var currentName = typeParam.name;
        do {
          currentName += r'$';
        } while (usedTypes.contains(currentName));

        replacements
          ..clear()
          ..[typeParam.name] = currentName;

        for (int k = i; k < discriminatorTypeParams.length; k++) {
          discriminatorTypeParams[i] = typeParam.updateClassTypeParameter(replacements);
        }

        usedTypes.add(currentName);
        uniqueTypeParams.add(discriminatorTypeParams[i]);
      } else {
        usedTypes.add(typeParam.name);
        uniqueTypeParams.add(typeParam);
      }
    }
    final discriminatorWithClassTypeParams = MacroProperty.getTypeParameterWithBound(uniqueTypeParams);
    final discriminatorTypeParamsCombined = MacroProperty.getTypeParameterWithBound(discriminatorTypeParams);

    /// Generate fromJson
    if (fromJson ?? config.createFromJson ?? true) {
      _generatePolymorphicFromJson(
        state: state,
        buff: buff,
        className: state.targetName,
        discriminatorDefault: discriminatorDefault,
        discriminatorValues: discriminatorValues,
        discriminatorTypeParams: discriminatorTypeParams,
        discriminatorTypeParamsByIndexRange: discriminatorTypeParamsByIndexRange,
        typeParams: typeParams,
        mainClassTypeParams: mainClassTypeParams,
        discriminatorWithClassTypeParams: discriminatorWithClassTypeParams,
      );
    }

    /// Generate toJson
    if (toJson ?? config.createToJson ?? true) {
      _generatePolymorphicToJson(
        state: state,
        buff: buff,
        className: state.targetName,
        typeParams: typeParams,
        discriminatorValues: discriminatorValues,
        discriminatorTypeParams: discriminatorTypeParams,
        discriminatorTypeParamsByIndexRange: discriminatorTypeParamsByIndexRange,
        discriminatorTypeParamsCombined: discriminatorTypeParamsCombined,
      );
    }

    /// Generate mapTo
    if (mapTo ?? config.createMapTo ?? true) {
      final allTypeParams = CombinedListView([
        discriminatorTypeParams,
        [MacroProperty(name: 'Res', importPrefix: '', type: '', typeInfo: TypeInfo.generic)],
      ]);
      final discriminatorTypeParamsCombined = MacroProperty.getTypeParameterWithBound(allTypeParams);

      _generatePolymorphicMapTo(
        state: state,
        buff: buff,
        className: state.targetName,
        discriminatorValues: discriminatorValues,
        discriminatorTypeParams: discriminatorTypeParams,
        discriminatorTypeParamsByIndexRange: discriminatorTypeParamsByIndexRange,
        mainClassTypeParams: mainClassTypeParams,
        discriminatorTypeParamsCombined: discriminatorTypeParamsCombined,
      );

      buff.write('\n');

      _generatePolymorphicMapTo(
        state: state,
        buff: buff,
        className: state.targetName,
        discriminatorValues: discriminatorValues,
        discriminatorTypeParams: discriminatorTypeParams,
        discriminatorTypeParamsByIndexRange: discriminatorTypeParamsByIndexRange,
        mainClassTypeParams: mainClassTypeParams,
        discriminatorTypeParamsCombined: discriminatorTypeParamsCombined,
        orNull: true,
      );
    }

    /// Generate copyWith
    if (copyWith ?? config.createCopyWith ?? true) {
      _generatePolymorphicCopyWith(
        state: state,
        buff: buff,
        className: state.targetName,
        discriminatorValues: discriminatorValues,
        discriminatorTypeParams: discriminatorTypeParams,
        discriminatorTypeParamsByIndexRange: discriminatorTypeParamsByIndexRange,
        mainClassTypeParams: mainClassTypeParams,
        discriminatorTypeParamsCombined: discriminatorTypeParamsCombined,
      );
    }

    if (asCast ?? config.createAsCast ?? true) {
      _generatePolymorphicAsCast(
        state: state,
        buff: buff,
        className: state.targetName,
        discriminatorValues: discriminatorValues,
        discriminatorTypeParams: discriminatorTypeParams,
        discriminatorTypeParamsByIndexRange: discriminatorTypeParamsByIndexRange,
      );
    }
  }

  (String, bool) _getFieldInitializerWithSuper(MacroProperty field, bool isNullable) {
    if (field.getTopFieldInitializer() case final fieldInitializer?) {
      return (fieldInitializer.name, fieldInitializer.isNullable);
    } else {
      return (field.name, isNullable);
    }
  }

  void _generateFromJson({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required String ctorName,
    required List<MacroProperty> positionalFields,
    required List<MacroProperty> namedFields,
    required List<MacroProperty> typeParams,
  }) {
    final config = _getConfig(state);
    final dcp = state.getOrNull<String>('dartCorePrefix') ?? '';
    final fromJsonGenericsArgs = <String>{};
    final fromJsonStaticFnName = config.useMapConvention ? 'fromMap' : 'fromJson';
    var fieldRename = config.fieldRename ?? FieldRename.none;

    String fieldCast(
      MacroProperty field,
      JsonKeyConfig? jsonKey,
      String value, {
      String? defaultValue,
      MacroProperty? mainType,
      Iterable<String>? usedUnknownEnumVals,
    }) {
      final isNullable = field.isNullable;
      final typeInfo = field.typeInfo;
      final prefix = field.importPrefix;
      var type = field.type;

      final nullable = isNullable ? '?' : '';
      final startParen = isNullable || typeInfo.isIntOrDouble ? '(' : '';
      final endParen = isNullable || typeInfo.isIntOrDouble ? ')' : '';
      final nullableDefault = isNullable && defaultValue != null ? ' ?? $defaultValue' : '';

      if (jsonKey?.isLiteral(config, type.removedNullability) == true) {
        return '$value as $prefix$type$nullableDefault';
      }

      switch (typeInfo) {
        case TypeInfo.clazz:
        case TypeInfo.clazzAugmentation:
        case TypeInfo.extension:
        case TypeInfo.extensionType:
          final (hasFn, fromJsonFn) = hasMethodOf(
            declaration: field.classInfo,
            macroName: 'DataClassMacro',
            methodName: fromJsonStaticFnName,
            configName: 'fromJson',
            staticFunction: true,
          );

          if (!hasFn) {
            throw MacroException(
              'The parameter `${field.name}` of type: ${field.type} in `$className` should add macro support or provide custom $fromJsonStaticFnName function',
            );
          }

          if (fromJsonFn != null) {
            if (fromJsonFn.params.length != 1 ||
                fromJsonFn.returns.first.type.removedNullability != type.removedNullability) {
              throw MacroException(
                'The parameter `${field.name}` of type: ${field.type} in `$className` should define $fromJsonStaticFnName function with one argument and return expected value',
              );
            }

            final fromJsonCastValue = fieldCast(fromJsonFn.params.first, null, value);
            final typeParams = MacroProperty.getTypeParameter(fromJsonFn.typeParams);

            if (isNullable) {
              return '$value == null ? $defaultValue : $prefix${type.removedNullability}.$fromJsonStaticFnName$typeParams($fromJsonCastValue)';
            }

            return '$prefix$type.$fromJsonStaticFnName$typeParams($fromJsonCastValue)';
          }

          final defaultFromJsonArg = MacroProperty(
            name: '',
            importPrefix: dcp,
            type: '${dcp}Map<${dcp}String, ${dcp}dynamic>',
            typeInfo: TypeInfo.map,
            typeArguments: [
              MacroProperty(name: '', importPrefix: dcp, type: 'String', typeInfo: TypeInfo.string),
              MacroProperty(name: '', importPrefix: dcp, type: 'dynamic', typeInfo: TypeInfo.dynamic),
            ],
          );

          final fromJsonCastValue = fieldCast(defaultFromJsonArg, null, value);
          final (clsName, typeParam) = _classTypeToMixin(prefix, type, mixinSuffix: suffixName);

          List<String>? typeParamsFromJson;
          for (final tp in field.typeArguments ?? const <MacroProperty>[]) {
            typeParamsFromJson ??= [];

            var argFnRef = '$fromJsonStaticFnName${tp.type}';
            var argFn = '${tp.importPrefix}${tp.type} Function(${dcp}Object? v) $argFnRef';

            // if class already have same generic fn, reuse it,
            // otherwise create new one with type name as suffix
            if (fromJsonGenericsArgs.contains(argFn)) {
              typeParamsFromJson.add(argFnRef);
            } else {
              argFnRef = '$fromJsonStaticFnName ${field.name}'.toCamelCase();
              argFn = '${tp.importPrefix}${tp.type} Function(${dcp}Object? v) $argFnRef';
              typeParamsFromJson.add(argFnRef);
              fromJsonGenericsArgs.add(argFn);
            }
          }

          final allTypeParamsFromJson = typeParamsFromJson?.join(', ') ?? '';
          final comma = allTypeParamsFromJson.isNotEmpty ? ', ' : '';
          final fromJsonCall =
              '$clsName.$fromJsonStaticFnName$typeParam($fromJsonCastValue$comma$allTypeParamsFromJson)';
          if (isNullable) {
            return '$value == null ? $defaultValue : $fromJsonCall';
          }

          return fromJsonCall;
        case TypeInfo.int:
          return '$startParen$value as ${prefix}num$nullable$endParen$nullable.toInt()$nullableDefault';
        case TypeInfo.double:
          return '$startParen$value as ${prefix}num$nullable$endParen$nullable.toDouble()$nullableDefault';
        case TypeInfo.num:
          return '$value as ${prefix}num$nullable$nullableDefault';
        case TypeInfo.string:
          return '$value as ${prefix}String$nullable$nullableDefault';
        case TypeInfo.boolean:
          return '$value as ${prefix}bool$nullable$nullableDefault';
        case TypeInfo.iterable:
          final elemType = field.typeArguments?.firstOrNull;
          assert(elemType != null, 'Element type of the iterable must be provided');

          if (MacroProperty.isDynamicIterable(type)) {
            if (isNullable) {
              final firstCast = type.replaceFirst('Iterable', 'List').removedNullability;
              return '$value == null ? $defaultValue : ($value as $prefix$firstCast).iterator';
            }

            final firstCast = type.replaceFirst('Iterable', 'List');
            return '($value as $prefix$firstCast).iterator';
          }

          final elemTypeStr = fieldCast(elemType!, null, 'e');
          return '($value as ${dcp}List<${dcp}dynamic>$nullable)$nullable.map((e) => $elemTypeStr)$nullableDefault';
        case TypeInfo.list:
          final elemType = field.typeArguments?.firstOrNull;
          assert(elemType != null, 'Element type of the list must be provided');

          if (MacroProperty.isDynamicList(type)) {
            return '$value as $prefix$type$nullableDefault';
          }

          final elemTypeStr = fieldCast(elemType!, null, 'e');
          return '($value as ${dcp}List<${dcp}dynamic>$nullable)$nullable.map((e) => $elemTypeStr).toList()$nullableDefault';
        case TypeInfo.map:
          final elemType = field.typeArguments?.firstOrNull;
          final elemValueType = field.typeArguments?.elementAtOrNull(1);

          assert(elemType != null, 'Key type of the map must be provided');
          assert(elemValueType != null, 'Value type of the map must be provided');

          if (MacroProperty.isDynamicMap(type)) {
            return '$value as $prefix$type$nullableDefault';
          }

          if (elemType!.isNullable) {
            throw MacroException(
              'Map keys must be one of: Object, dynamic, enum, String, BigInt, DateTime, int, Uri but got nullable type: `${elemType.type}`',
            );
          }

          final mapElemValue = fieldCast(elemValueType!, null, 'e');

          // key type is string, use it directly and only cast map value
          final elemTypePrefix = elemType.importPrefix;
          switch (elemType.typeInfo) {
            case TypeInfo.int:
              return '($value as ${dcp}Map<${dcp}String, ${dcp}dynamic>$nullable)$nullable.map((k, e) => ${dcp}MapEntry(${elemTypePrefix}int.parse(k), $mapElemValue))$nullableDefault';
            case TypeInfo.string:
              return '($value as ${dcp}Map<${dcp}String, ${dcp}dynamic>$nullable)$nullable.map((k, e) => ${dcp}MapEntry(k, $mapElemValue))$nullableDefault';
            case TypeInfo.datetime:
              final keyType = fieldCast(elemType, null, 'k');
              return '($value as ${dcp}Map<${dcp}String, ${dcp}dynamic>$nullable)$nullable.map((k, e) => ${dcp}MapEntry($elemTypePrefix$keyType, $mapElemValue))$nullableDefault';
            case TypeInfo.bigInt:
              return '($value as ${dcp}Map<${dcp}String, ${dcp}dynamic>$nullable)$nullable.map((k, e) => ${dcp}MapEntry(${elemTypePrefix}BigInt.parse(k), $mapElemValue))$nullableDefault';
            case TypeInfo.uri:
              return '($value as ${dcp}Map<${dcp}String, ${dcp}dynamic>$nullable)$nullable.map((k, e) => ${dcp}MapEntry(${elemTypePrefix}Uri.parse(k), $mapElemValue))$nullableDefault';
            case TypeInfo.enumData:
              final unknownEnumValue = jsonKey?.unknownEnumValue?.firstOrNull;

              final mapElemValue = fieldCast(
                elemValueType,
                null,
                'e',
                mainType: field,
                // use first one and provide remaining unknown default value to next type
                usedUnknownEnumVals: jsonKey?.unknownEnumValue?.skip(1),
              );
              return '($value as ${dcp}Map<${dcp}String, ${dcp}dynamic>$nullable)$nullable.map((k, e) => ${dcp}MapEntry(MacroExt.decodeEnum(${elemType.importPrefix}${elemType.type}.values, k, unknownValue: $unknownEnumValue), $mapElemValue))$nullableDefault';
            case TypeInfo.object:
              return '($value as ${dcp}Map<${dcp}Object, ${dcp}dynamic>$nullable)$nullable.map((k, e) => ${dcp}MapEntry(k, $mapElemValue))$nullableDefault';
            case TypeInfo.dynamic:
              return '($value as ${dcp}Map<${dcp}dynamic, ${dcp}dynamic>$nullable)$nullable.map((k, e) => ${dcp}MapEntry(k, $mapElemValue))$nullableDefault';
            case TypeInfo.generic:
              final genType = elemType.type.removedNullability;
              final prefix = elemType.importPrefix;
              if (elemType.isNullable) {
                return '($value as ${dcp}Map<${dcp}Object?, ${dcp}dynamic>$nullable)$nullable.map((k, e) => ${dcp}MapEntry(MacroExt.decodeNullableGeneric(k, $fromJsonStaticFnName$prefix$genType), $mapElemValue))$nullableDefault';
              }

              return '($value as ${dcp}Map<${dcp}Object?, ${dcp}dynamic>$nullable)$nullable.map((k, e) => ${dcp}MapEntry($fromJsonStaticFnName$prefix$genType(k), $mapElemValue))$nullableDefault';
            default:
              throw MacroException(
                'Map keys must be one of: Object, dynamic, enum, String, BigInt, DateTime, int, Uri but got: ${elemType.type}',
              );
          }
        case TypeInfo.set:
          final elemType = field.typeArguments?.firstOrNull;
          assert(elemType != null, 'Element type of the set must be provided');

          if (MacroProperty.isDynamicSet(type)) {
            if (isNullable) {
              final firstCast = type.replaceFirst('Set', 'List').removedNullability;
              return '$value == null ? $defaultValue : ($value as $prefix$firstCast).toSet()';
            }

            final firstCast = type.replaceFirst('Set', 'List');
            return '($value as $prefix$firstCast).toSet()';
          }

          final elemTypeStr = fieldCast(elemType!, null, 'e');

          return '($value as ${dcp}List<${dcp}dynamic>$nullable)$nullable.map((e) => $elemTypeStr).toSet()$nullableDefault';
        case TypeInfo.datetime:
          if (isNullable) {
            return 'MacroExt.decodeNullableDateTime($value)$nullableDefault';
          }

          return 'MacroExt.decodeDateTime($value)';
        case TypeInfo.duration:
          if (isNullable) {
            return '$value == null ? $defaultValue : ${prefix}Duration(microseconds: ($value as ${dcp}num).toInt())';
          }
          return '${prefix}Duration(microseconds: ($value as ${dcp}num).toInt())';
        case TypeInfo.bigInt:
          if (isNullable) {
            return '$value == null ? $defaultValue : ${prefix}BigInt.parse($value as ${dcp}String)';
          }

          return '${prefix}BigInt.parse($value as ${dcp}String)';
        case TypeInfo.uri:
          if (isNullable) {
            return '$value == null ? $defaultValue : ${prefix}Uri.parse($value as ${dcp}String)';
          }

          return '${prefix}Uri.parse($value as ${dcp}String)';
        case TypeInfo.enumData:
          final unknownEnumValue = jsonKey?.unknownEnumValue?.firstOrNull ?? usedUnknownEnumVals?.firstOrNull;

          if (isNullable) {
            final genType = type.removedNullability;
            return 'MacroExt.decodeNullableEnum($prefix$genType.values, $value, unknownValue: $unknownEnumValue)$nullableDefault';
          }

          return 'MacroExt.decodeEnum($prefix$type.values, $value, unknownValue: $unknownEnumValue)';
        case TypeInfo.symbol:
          if (isNullable) {
            return '$value == null ? $defaultValue : ${prefix}Symbol($value as ${dcp}String)';
          }

          return '${prefix}Symbol($value as ${dcp}String)';
        case TypeInfo.record:
        case TypeInfo.function:
        case TypeInfo.future:
        case TypeInfo.stream:
        case TypeInfo.nullType:
        case TypeInfo.voidType:
        case TypeInfo.type:
          if (isNullable) {
            final genType = field.toNullability(intoNullable: false).getDartType(dcp);
            return '$value == null ? $defaultValue : $value as $prefix$genType';
          }

          return '$value as $prefix$type';
        case TypeInfo.object:
          if (isNullable) {
            return value;
          }

          return '$value as ${prefix}Object';
        case TypeInfo.dynamic:
          return value;
        case TypeInfo.generic:
          if (isNullable) {
            final genType = field.type.removedNullability;
            return 'MacroExt.decodeNullableGeneric($value, $fromJsonStaticFnName$prefix$genType)$nullableDefault';
          }

          return '$fromJsonStaticFnName${field.type}($value)';
      }
    }

    String fieldValue(MacroProperty field, [bool positional = false]) {
      final key = field.cacheFirstKeyInto(
        keyName: 'JsonKey',
        convertFn: JsonKeyConfig.fromMacroKey,
        defaultValue: JsonKeyConfig.defaultKey,
      );

      // get default value from key or field initializer
      // and add const if its a constant
      var defaultValue = key.defaultValue ?? (field.constantValue != null ? MacroProperty.toLiteralValue(field) : null);
      final hasDefaultValue = defaultValue != null;
      final isConstant = key.defaultValue != null || field.constantModifier?.isConst == true;
      defaultValue =
          defaultValue != null &&
              isConstant &&
              field.typeInfo != TypeInfo.enumData &&
              !defaultValue.startsWith('const ')
          ? 'const $defaultValue'
          : defaultValue;

      final posOrNamedField = positional ? '    ' : '     ${field.name}:';

      // check is excluded from decoding
      if (key.includeFromJson == false) {
        // throw exception if no default value provided & not nullable since it we can't initiate the class
        // if nullable, set as default value,
        if (hasDefaultValue) {
          return '$posOrNamedField $defaultValue';
        } else if (field.isNullable) {
          return '$posOrNamedField null';
        } else {
          throw MacroException(
            "The parameter `${field.name}` of type: `${field.type}` in `${state.targetName}` is non-nullable and does not have default value",
          );
        }
      }

      final tag = "'${key.name?.isNotEmpty == true ? Utils.escapeQuote(key.name!) : fieldRename.renameOf(field.name)}'";
      final String jsonValue;
      if (key.readValueProp != null) {
        jsonValue = '${key.readValueProp!.getFunctionCallName()}(json, $tag)';
      } else {
        jsonValue = 'json[$tag]';
      }

      // custom fromJson or fallback to builtin
      final String value;
      if (key.fromJsonProp case MacroProperty fromJsonProp) {
        final fromJsonFn = fromJsonProp.getFunctionCallName();
        final fromJsonArgTypeProp = fromJsonProp.functionTypeInfo!.params.first;
        final fromJsonReturnTypeProp = fromJsonProp.functionTypeInfo!.returns.first;

        final expectedType = hasDefaultValue && !field.isNullable ? '${field.type}?' : field.type;
        if (!Utils.isValueTypeCanBeOfType(
          fromJsonReturnTypeProp.type,
          expectedType,
          valueTypeIsGeneric: fromJsonReturnTypeProp.typeInfo == TypeInfo.generic,
        )) {
          throw MacroException(
            'The parameter `${field.name}` of type: `${field.type}` in `${state.targetName}` has incompatible $fromJsonStaticFnName function, '
            'the $fromJsonStaticFnName return must be type of: `${field.type}` but got: `${fromJsonReturnTypeProp.type}`',
          );
        }

        final asType = ' as ${fromJsonArgTypeProp.getDartType(dcp)}';
        final fromJsonCallFallback = fromJsonReturnTypeProp.isNullable && hasDefaultValue ? ' ?? $defaultValue' : '';
        value =
            '${field.isNullable ? '$jsonValue == null ? $defaultValue : ' : ''}${'$fromJsonFn($jsonValue$asType)$fromJsonCallFallback'}';
      } else {
        if (hasDefaultValue && !field.isNullable) {
          value = fieldCast(field.toNullability(), key, jsonValue, defaultValue: defaultValue);
        } else {
          value = fieldCast(field, key, jsonValue, defaultValue: defaultValue);
        }
      }

      return '$posOrNamedField $value';
    }

    final prefix = state.importPrefix;
    final clsTypeParams = MacroProperty.getTypeParameter(typeParams);
    final clsTypeParamsWithBound = MacroProperty.getTypeParameterWithBound(typeParams);
    for (final tp in typeParams) {
      fromJsonGenericsArgs.add('${tp.name} Function(${dcp}Object? v) $fromJsonStaticFnName${tp.name}');
    }

    final positionalFieldsMapping = positionalFields.map((f) => fieldValue(f, true)).join(',\n');
    final namedFieldsMapping = namedFields.map(fieldValue).join(',\n');
    final genericArgs = fromJsonGenericsArgs.join(', ');
    final comma = genericArgs.isNotEmpty ? ', ' : '';

    buff
      ..write(
        ' static $prefix$className$clsTypeParams $fromJsonStaticFnName$clsTypeParamsWithBound(${dcp}Map<${dcp}String, ${dcp}dynamic> json$comma$genericArgs) {\n',
      )
      ..write('   return $prefix$className$clsTypeParams${ctorName.isNotEmpty ? '.' : ''}$ctorName(\n')
      ..write(positionalFieldsMapping)
      ..write(positionalFields.isNotEmpty ? ',\n' : '')
      ..write(namedFieldsMapping);
    if (namedFields.isNotEmpty) {
      buff.write(',\n');
    }

    buff
      ..write('   );\n')
      ..write('  }\n\n');
  }

  void _generateToJson({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required String ctorName,
    required CombinedListView<MacroProperty> fields,
    required List<MacroProperty> typeParams,
  }) {
    final config = _getConfig(state);
    final dcp = state.getOrNull('dartCorePrefix') ?? '';
    final toJsonFnName = config.useMapConvention ? 'toMap' : 'toJson';
    final toJsonGenericsArgs = <String>{};

    String fieldEncode(MacroProperty field, JsonKeyConfig? jsonKey, String value, bool isNullable) {
      final typeInfo = field.typeInfo;
      final type = field.type;
      final nullable = isNullable ? '?' : '';

      if (jsonKey?.isLiteral(config, type.removedNullability) == true) {
        return value;
      }

      switch (typeInfo) {
        case TypeInfo.clazz:
        case TypeInfo.clazzAugmentation:
        case TypeInfo.extension:
        case TypeInfo.extensionType:
          final (hasFn, toJsonFn) = hasMethodOf(
            declaration: field.classInfo,
            macroName: 'DataClassMacro',
            methodName: toJsonFnName,
            configName: 'toJson',
            staticFunction: false,
          );

          if (!hasFn) {
            throw MacroException(
              'Parameter `${field.name}` of type `${field.type}` in `${state.targetName}` '
              'must either have macro support enabled or provide a custom `$toJsonFnName` function.',
            );
          }

          if (toJsonFn != null) {
            if (toJsonFn.params.isNotEmpty || toJsonFn.returns.first.typeInfo == TypeInfo.voidType) {
              throw MacroException(
                'Parameter `${field.name}` of type `${field.type}` in `${state.targetName}` '
                'must define a `$toJsonFnName` method with no arguments that returns the expected JSON value.',
              );
            }
          }

          List<String>? typeParamsToJson;
          for (final tp in field.typeArguments ?? const <MacroProperty>[]) {
            typeParamsToJson ??= [];

            var argFnRef = '$toJsonFnName${tp.type}';
            var argFn = '${dcp}Object? Function(${tp.importPrefix}${tp.type} v) $argFnRef';

            // if class already have same generic fn, reuse it,
            // otherwise create new one with type name as suffix
            if (toJsonGenericsArgs.contains(argFn)) {
              typeParamsToJson.add(argFnRef);
            } else if (field.typeInfo.isClassLike) {
              argFnRef = '$toJsonFnName ${field.name}'.toCamelCase();
              argFn = '${dcp}Object? Function(${tp.importPrefix}${tp.type} v) $argFnRef';
              typeParamsToJson.add(argFnRef);
              toJsonGenericsArgs.add(argFn);
            }
          }

          final allTypeParamsToJson = typeParamsToJson?.join(', ') ?? '';
          return '$value$nullable.$toJsonFnName($allTypeParamsToJson)';
        case TypeInfo.int:
        case TypeInfo.double:
        case TypeInfo.num:
        case TypeInfo.string:
        case TypeInfo.boolean:
          return value;
        case TypeInfo.iterable:
          final elemType = field.typeArguments?.firstOrNull;
          assert(elemType != null, 'Element type of the iterable must be provided');

          if (MacroProperty.isDynamicIterable(type)) {
            return '$value$nullable.toList()';
          } else if (MacroProperty.isListEncodeDirectlyToJson(type.replaceFirst('Iterable', 'List'))) {
            return '$value$nullable.toList()';
          }

          final elemTypeStr = fieldEncode(elemType!, null, 'e', elemType.isNullable);

          return '$value$nullable.map((e) => $elemTypeStr).toList()';
        case TypeInfo.list:
          final elemType = field.typeArguments?.firstOrNull;
          assert(elemType != null, 'Element type of the list must be provided');

          if (MacroProperty.isDynamicList(type) || MacroProperty.isListEncodeDirectlyToJson(type)) {
            return value;
          }

          final elemTypeEncoded = fieldEncode(elemType!, null, 'e', elemType.isNullable);
          return '$value$nullable.map((e) => $elemTypeEncoded).toList()';
        case TypeInfo.map:
          final elemType = field.typeArguments?.firstOrNull;
          final elemValueType = field.typeArguments?.elementAtOrNull(1);

          assert(elemType != null, 'Key type of the map must be provided');
          assert(elemValueType != null, 'Value type of the map must be provided');

          if (MacroProperty.isDynamicMap(type) || MacroProperty.isMapEncodeDirectlyToJson(type)) return value;

          if (elemType!.isNullable) {
            throw MacroException(
              'Map keys must be one of: Object, dynamic, enum, String, BigInt, DateTime, int, Uri but got nullable type: `${elemType.type}`',
            );
          }

          final mapElemValue = fieldEncode(elemValueType!, null, 'e', elemValueType.isNullable);

          switch (elemType.typeInfo) {
            case TypeInfo.int:
              return '$value$nullable.map((k, e) => ${dcp}MapEntry(k.toString(), $mapElemValue))';
            case TypeInfo.string:
              final mapElemTypeStr = elemValueType.type.removedNullability;
              return switch (mapElemTypeStr) {
                'String' ||
                'int' ||
                'double' ||
                'num' ||
                'List<String>' ||
                'List<int>' ||
                'List<double>' ||
                'List<num>' => value,
                _ => '$value$nullable.map((k, e) => ${dcp}MapEntry(k, $mapElemValue))',
              };
            case TypeInfo.datetime:
              final keyType = fieldEncode(elemType, null, 'k', elemType.isNullable);
              return '$value$nullable.map((k, e) => ${dcp}MapEntry($keyType, $mapElemValue))';
            case TypeInfo.bigInt:
              return '$value$nullable.map((k, e) => ${dcp}MapEntry(k.toString(), $mapElemValue))';
            case TypeInfo.uri:
              return '$value$nullable.map((k, e) => ${dcp}MapEntry(k.toString(), $mapElemValue))';
            case TypeInfo.enumData:
              return '$value$nullable.map((k, e) => ${dcp}MapEntry(k.name, $mapElemValue))';
            case TypeInfo.object:
            case TypeInfo.dynamic:
              return '$value$nullable.map((k, e) => ${dcp}MapEntry(k, $mapElemValue))';
            case TypeInfo.generic:
              final genType = elemType.type.removedNullability;
              if (elemType.isNullable) {
                return '$value$nullable.map((k, e) => ${dcp}MapEntry(MacroExt.encodeNullableGeneric(k, $toJsonFnName$genType), $mapElemValue))';
              }

              return '$value$nullable.map((k, e) => ${dcp}MapEntry($toJsonFnName$genType(k), $mapElemValue))';
            default:
              throw MacroException(
                'Map keys must be one of: Object, dynamic, enum, String, BigInt, DateTime, int, Uri',
              );
          }
        case TypeInfo.set:
          final elemType = field.typeArguments?.firstOrNull;
          assert(elemType != null, 'Element type of the set must be provided');

          if (MacroProperty.isDynamicSet(type)) return '$value$nullable.toList()';

          final elemTypeStr = fieldEncode(elemType!, null, 'e', elemType.isNullable);

          return '$value$nullable.map((e) => $elemTypeStr).toList()';
        case TypeInfo.datetime:
          return '$value$nullable.toIso8601String()';
        case TypeInfo.duration:
          return '$value$nullable.inMicroseconds';
        case TypeInfo.bigInt:
        case TypeInfo.uri:
          return '$value$nullable.toString()';
        case TypeInfo.enumData:
          return '$value$nullable.name';
        case TypeInfo.record:
          return '$value$nullable.toString()';
        case TypeInfo.symbol:
          return '$value$nullable.toString()';
        case TypeInfo.function:
        case TypeInfo.future:
        case TypeInfo.stream:
        case TypeInfo.object:
        case TypeInfo.nullType:
        case TypeInfo.voidType:
        case TypeInfo.type:
        case TypeInfo.dynamic:
          return value;
        case TypeInfo.generic:
          final genType = type.removedNullability;
          if (isNullable) {
            return 'MacroExt.encodeNullableGeneric($value, $toJsonFnName$genType)';
          }
          return '$toJsonFnName$genType($value)';
      }
    }

    // default not to include null values
    var includeIfNull = config.includeIfNull;
    var fieldRename = config.fieldRename ?? FieldRename.none;
    final prefix = state.importPrefix;
    final disKey = discriminatorKey ?? 'type';
    bool? disKeyAdded;

    String? fieldValue(MacroProperty field) {
      final key = field.cacheFirstKeyInto(
        keyName: 'JsonKey',
        convertFn: JsonKeyConfig.fromMacroKey,
        defaultValue: JsonKeyConfig.defaultKey,
      );
      if (key.includeToJson == false) return null;

      final tagKey = key.name?.isNotEmpty == true ? Utils.escapeQuote(key.name!) : fieldRename.renameOf(field.name);
      final tag = "'$tagKey'";
      var isNullable = field.isNullable;

      if (disKeyAdded == null && tagKey == disKey) {
        disKeyAdded = true;
      }

      final String fieldPropName;
      (fieldPropName, isNullable) = _getFieldInitializerWithSuper(field, isNullable);

      // custom toJson or fallback to builtin
      final String value;
      if (key.toJsonProp case MacroProperty toJsonProp) {
        final toJson = toJsonProp.getFunctionCallName();
        final toJsonArgTypeProp = toJsonProp.functionTypeInfo!.params.first;
        final toJsonReturnNullable = toJsonProp.functionTypeInfo!.returns.first.modifier.isNullable;

        final expectedType = toJsonArgTypeProp.type;
        if (!Utils.isValueTypeCanBeOfType(
          field.type,
          expectedType,
          valueTypeIsGeneric: field.typeInfo == TypeInfo.generic,
        )) {
          throw MacroException(
            'Parameter `${field.name}` of type `${field.type}` in `${state.targetName}` '
            'has an incompatible `$toJsonFnName` function. Expected argument type: `${field.type}`, '
            'but got: `${toJsonArgTypeProp.type}`.',
          );
        }

        value = '$toJson(v.$fieldPropName)';
        isNullable = toJsonReturnNullable;
      } else {
        value = fieldEncode(field, key, 'v.$fieldPropName', isNullable);
      }

      if (field.typeArguments?.isNotEmpty == true) {
        for (final tp in field.typeArguments!) {
          var toJsonArgFnRef = '$toJsonFnName${tp.type}';
          var toJsonArgFn = '${dcp}Object? Function(${tp.importPrefix}${tp.type} v) $toJsonArgFnRef';
          if (toJsonGenericsArgs.contains(toJsonArgFn) || !field.typeInfo.isClassLike) {
            continue;
          }

          toJsonArgFnRef = '$toJsonFnName ${field.name}'.toCamelCase();
          toJsonArgFn = '${dcp}Object? Function(${tp.importPrefix}${tp.type} v) $toJsonArgFnRef';
          toJsonGenericsArgs.add(toJsonArgFn);
        }
      }

      if (isNullable) {
        return '      $tag: ${key.includeIfNull ?? includeIfNull ?? false ? '' : '?'}$value';
      }
      return '      $tag: $value';
    }

    final clsWithTypeParams = '$prefix$className${MacroProperty.getTypeParameter(typeParams)}';
    for (final tp in typeParams) {
      toJsonGenericsArgs.add('${dcp}Object? Function(${tp.name} v) $toJsonFnName${tp.name}');
    }

    final jsonMapping = fields.map(fieldValue).nonNulls.join(',\n');
    final genericArgs = toJsonGenericsArgs.join(', ');

    buff
      ..write(' ${dcp}Map<${dcp}String, ${dcp}dynamic> $toJsonFnName($genericArgs) {\n')
      ..write(fields.isNotEmpty ? '   final v = this as $clsWithTypeParams;\n' : '')
      ..write('   return <${dcp}String, ${dcp}dynamic> {\n');

    buff.write(jsonMapping);
    if (jsonMapping.isNotEmpty) {
      buff.write(',\n');
    }

    if ((includeDiscriminator == true || discriminatorKey != null || discriminatorValue != null) &&
        disKeyAdded != true) {
      final disKeyValue = "'${Utils.escapeQuote(disKey)}'";
      final disValueProp = state.macro.properties.firstWhereOrNull((e) => e.name == 'discriminatorValue');
      final Object? disValue;
      if (disValueProp != null && disValueProp.constantValue != null) {
        disValue = switch (disValueProp.typeInfo) {
          TypeInfo.string => "'${Utils.escapeQuote(disValueProp.asStringConstantValue() ?? '')}'",
          TypeInfo.int || TypeInfo.double || TypeInfo.num || TypeInfo.boolean => disValueProp.constantValue,
          TypeInfo.function => null,
          _ => "'$className'",
        };
      } else {
        disValue = "'$className'";
      }

      if (disValue != null) {
        buff.write('      $disKeyValue: $disValue,\n');
      }
    }

    buff
      ..write('   };\n')
      ..write(' }\n\n');
  }

  void _generateCopyWith({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required String ctorName,
    required List<MacroProperty> positionalFields,
    required List<MacroProperty> namedFields,
    required List<MacroProperty> typeParams,
  }) {
    if (state.modifier.isAbstract || state.modifier.isSealed) return;

    final config = _getConfig(state);
    final globalCopyWithAsOption = copyWithAsOption ?? config.copyWithAsOption;
    final dcp = state.getOrNull<String>('dartCorePrefix') ?? '';

    String? fieldParam(MacroProperty field) {
      final String dartType;
      bool useOption = false;

      if (field.isNullable) {
        final key = field.cacheFirstKeyInto(
          keyName: 'JsonKey',
          convertFn: JsonKeyConfig.fromMacroKey,
          defaultValue: JsonKeyConfig.defaultKey,
        );
        final copyWithAsOption = key.copyWithAsOption ?? globalCopyWithAsOption ?? false;
        useOption = copyWithAsOption;
        if (copyWithAsOption) {
          final innerType = field.toNullability(intoNullable: false);
          final innerTypeDart = innerType.getDartType(dcp);
          final optionType = MacroProperty(
            name: '',
            importPrefix: '',
            type: 'Option<$innerTypeDart>',
            typeInfo: TypeInfo.clazz,
            typeArguments: [innerType],
          );
          dartType = optionType.getDartType(dcp);
        } else {
          dartType = field.getDartType(dcp);
        }
      } else {
        dartType = field.getDartType(dcp);
      }

      final (fieldPropName, isNullable) = _getFieldInitializerWithSuper(field, field.isNullable);
      final type = isNullable || field.typeInfo == TypeInfo.dynamic || dartType.endsWith('?')
          ? dartType
          : '$dartType${useOption ? '' : '?'}';
      var fieldName = field.name;
      if (!fieldPropName.startsWith('_')) {
        fieldName = fieldPropName;
      }

      return '   $type $fieldName${useOption ? ' = const Option.undefined()' : ''}';
    }

    String? fieldParamCopy(MacroProperty field, [bool positional = false]) {
      final (fieldPropName, _) = _getFieldInitializerWithSuper(field, field.isNullable);
      var fieldName = field.name;
      if (!fieldPropName.startsWith('_')) {
        fieldName = fieldPropName;
      }

      // either use (field ?? v.field) for non nullable field or when not opt-in into using Option or
      // (field.isUndefined ? v.field : $fieldName.casted())
      String? assignedValue;

      if (field.isNullable) {
        final key = field.cacheFirstKeyInto(
          keyName: 'JsonKey',
          convertFn: JsonKeyConfig.fromMacroKey,
          defaultValue: JsonKeyConfig.defaultKey,
        );
        final copyWithAsOption = key.copyWithAsOption ?? globalCopyWithAsOption ?? false;
        if (copyWithAsOption) {
          assignedValue = '$fieldName.isUndefined ? v.$fieldPropName : $fieldName.casted()';
        }
      }

      // default to null coalescing if not enabled option
      assignedValue ??= '$fieldName ?? v.$fieldPropName';
      return '      ${positional ? '' : '$fieldName: '}$assignedValue';
    }

    final prefix = state.importPrefix;
    final clsWithTypeParams = '$prefix$className${MacroProperty.getTypeParameter(typeParams)}';

    // copy with params
    buff.write(' $clsWithTypeParams copyWith(');
    if (positionalFields.isNotEmpty || namedFields.isNotEmpty) {
      buff
        ..write('{')
        ..write(positionalFields.map(fieldParam).join(',\n'));

      if (positionalFields.isNotEmpty) {
        buff.write(',');
      }

      if (namedFields.isNotEmpty) {
        buff
          ..write('\n')
          ..write(namedFields.map(fieldParam).join(',\n'))
          ..write(',');
      }
      buff.write('\n }');
    }

    buff
      ..write(') {\n')
      ..write(
        positionalFields.isNotEmpty || namedFields.isNotEmpty ? '   final v = this as $clsWithTypeParams;\n' : '',
      )
      ..write('   return $clsWithTypeParams${ctorName.isNotEmpty ? '.' : ''}$ctorName(')
      ..write(positionalFields.isEmpty ? '' : '\n')
      ..write(positionalFields.map((field) => fieldParamCopy(field, true)).join(',\n'));

    if (positionalFields.isNotEmpty) {
      buff.write(',');
    }

    if (namedFields.isNotEmpty) {
      buff
        ..write('\n')
        ..write(namedFields.map((e) => fieldParamCopy(e)).join(',\n'))
        ..write(',\n');
    } else {
      buff.write('\n');
    }

    buff
      ..write('   );\n')
      ..write(' }\n');
  }

  void _generateEquality({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required CombinedListView<MacroProperty> fields,
    required List<MacroProperty> typeParams,
  }) {
    final dcp = state.getOrNull<String>('dartCorePrefix') ?? '';
    final prefix = state.importPrefix;
    final clsWithTypeParams = '$prefix$className${MacroProperty.getTypeParameter(typeParams)}';

    /// generate equality
    buff
      ..write('\n')
      ..write(' @${dcp}override\n')
      ..write(' ${dcp}bool operator ==(${dcp}Object other) {\n')
      ..write(
        fields.isNotEmpty ? '   final v = this as $clsWithTypeParams;\n' : '',
      )
      ..write(
        '   return ${dcp}identical(this, other) ||\n     (other.runtimeType == runtimeType && other is $clsWithTypeParams',
      );
    if (fields.isNotEmpty) {
      buff.write(' &&\n');
    }

    buff
      ..write(
        fields
            .map((field) {
              final (fieldPropName, _) = _getFieldInitializerWithSuper(field, field.isNullable);

              return field.deepEquality
                  ? '     const DeepCollectionEquality().equals(other.$fieldPropName, v.$fieldPropName)'
                  : '     (${dcp}identical(other.$fieldPropName, v.$fieldPropName) || other.$fieldPropName == v.$fieldPropName)';
            })
            .join(' &&\n'),
      )
      ..write(');\n')
      ..write(' }\n\n');

    /// generate hash
    if (fields.isNotEmpty && fields.length <= 19) {
      buff
        ..write(' @${dcp}override\n')
        ..write(' ${dcp}int get hashCode {\n')
        ..write(
          fields.isNotEmpty ? '   final v = this as $clsWithTypeParams;\n' : '',
        )
        ..write('  return ${dcp}Object.hash(\n')
        ..write('   runtimeType, ')
        ..write(
          fields
              .map(
                (field) {
                  final (fieldPropName, _) = _getFieldInitializerWithSuper(field, field.isNullable);
                  return field.deepEquality
                      ? 'const DeepCollectionEquality().hash(v.$fieldPropName)'
                      : 'v.$fieldPropName';
                },
              )
              .join(', '),
        );

      if (fields.isNotEmpty) {
        buff.write(',');
      }

      buff.write('\n  );\n }\n\n');
    } else {
      buff
        ..write(' @${dcp}override\n')
        ..write(' ${dcp}int get hashCode {\n')
        ..write(
          fields.isNotEmpty ? '   final v = this as $clsWithTypeParams;\n' : '',
        )
        ..write('   return ${dcp}Object.hashAll([\n')
        ..write('     runtimeType, ')
        ..write(
          fields
              .map(
                (field) {
                  final (fieldPropName, _) = _getFieldInitializerWithSuper(field, field.isNullable);
                  return field.deepEquality
                      ? 'const DeepCollectionEquality().hash(v.$fieldPropName)'
                      : 'v.$fieldPropName';
                },
              )
              .join(', '),
        );

      if (fields.isNotEmpty) {
        buff.write(',');
      }

      buff.write('\n   ]);\n }\n\n');
    }
  }

  void _generateToString({
    required MacroState state,
    required String className,
    required StringBuffer buff,
    required CombinedListView<MacroProperty> fields,
    required List<MacroProperty> typeParams,
  }) {
    final dcp = state.getOrNull<String>('dartCorePrefix') ?? '';
    final prefix = state.importPrefix;
    final clsWithGenericParam = '$prefix$className${MacroProperty.getTypeParameter(typeParams)}';
    final genericParamAsType = typeParams.isNotEmpty == true ? '<\$${typeParams.map((tp) => tp.name).join(',')}>' : '';

    buff
      ..write(' @${dcp}override\n')
      ..write(' ${dcp}String toString() {\n')
      ..write(
        fields.isNotEmpty ? '   final v = this as $clsWithGenericParam;\n' : '',
      )
      ..write(
        "   return '$prefix$className$genericParamAsType{${fields.map((field) {
          final (fieldPropName, _) = _getFieldInitializerWithSuper(field, field.isNullable);
          return '${field.name}: \${v.$fieldPropName}';
        }).join(', ')}}';\n",
      )
      ..write(' }\n');
  }

  void _generatePolymorphicFromJson({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required MacroClassDeclaration? discriminatorDefault,
    required List<(MacroClassDeclaration, MacroProperty?)> discriminatorValues,
    required List<MacroProperty> discriminatorTypeParams,
    required Map<int, _RangeInfo> discriminatorTypeParamsByIndexRange,
    required List<MacroProperty> typeParams,
    required String mainClassTypeParams,
    required String discriminatorWithClassTypeParams,
  }) {
    final config = _getConfig(state);
    final fromJsonStaticFnName = config.useMapConvention ? 'fromMap' : 'fromJson';

    String caseCast(MacroClassDeclaration classSubType, List<MacroProperty>? classTypeParams, String value) {
      final (hasFn, fromJsonFn) = hasMethodOf(
        declaration: classSubType,
        macroName: 'DataClassMacro',
        methodName: fromJsonStaticFnName,
        configName: 'fromJson',
        staticFunction: true,
      );

      if (!hasFn) {
        throw MacroException(
          'Subtype `${classSubType.className}` must also use DataClassMacro to support polymorphic serialization.',
        );
      }

      if (fromJsonFn != null) {
        if (fromJsonFn.params.length != 1 || fromJsonFn.returns.first.classInfo?.className != classSubType.className) {
          throw MacroException(
            'Subtype `${classSubType.className}` must define a `$fromJsonStaticFnName` function with one parameter and a compatible return type.',
          );
        }

        final typeParams = MacroProperty.getTypeParameter(fromJsonFn.typeParams);
        return '${classSubType.importPrefix}${classSubType.className}.$fromJsonStaticFnName$typeParams($value)';
      }

      final typeParams = MacroProperty.getTypeParameter(classTypeParams ?? const []);
      return '${classSubType.importPrefix}${classSubType.className}$suffixName.$fromJsonStaticFnName$typeParams($value)';
    }

    String switchCaseValue(
      MacroClassDeclaration subTypeInfo,
      MacroProperty? discriminatorValue,
      List<MacroProperty>? typeParams, {
      String? customCaseKey,
    }) {
      // json argument value
      final jsonValue = typeParams?.isNotEmpty == true
          ? 'json, ${typeParams!.map((tp) => '$fromJsonStaticFnName${tp.name}').join(', ')}'
          : 'json';
      if (discriminatorValue == null) {
        return '${customCaseKey ?? "'${subTypeInfo.className}'"} => ${caseCast(subTypeInfo, typeParams, jsonValue)}';
      }

      if (discriminatorValue.requireConversionToLiteral == true) {
        return "${jsonLiteralAsDart(discriminatorValue.constantValue)} => ${caseCast(subTypeInfo, typeParams, jsonValue)}";
      } else if (discriminatorValue.typeInfo == TypeInfo.function) {
        if (discriminatorValue.functionTypeInfo == null ||
            discriminatorValue.functionTypeInfo!.params.length != 1 ||
            !discriminatorValue.functionTypeInfo!.params.first.isMapStringDynamicType ||
            discriminatorValue.functionTypeInfo!.returns.first.typeInfo != TypeInfo.boolean) {
          throw MacroException(
            'Invalid discriminator function. Expected a matcher with signature '
            'bool Function(Map<String, dynamic> json) that returns true when the subtype should be selected '
            'but got: ${discriminatorValue.constantValue}.',
          );
        }

        return '_ when ${discriminatorValue.constantValue}(json) => ${caseCast(subTypeInfo, typeParams, jsonValue)}';
      }

      throw 'invalid state: $subTypeInfo';
    }

    final dcp = state.getOrNull<String>('dartCorePrefix') ?? '';
    final prefix = state.importPrefix;
    final discriminatorDefaultFromJson = discriminatorDefault?.classTypeParameters
        ?.map((tp) => tp.copyWith(name: '${discriminatorDefault.className}${tp.name}'))
        .toList();
    final genericArgs = discriminatorTypeParams.isNotEmpty
        ? ',{${discriminatorTypeParams.map((tp) => 'required ${tp.name} Function(${dcp}Object? v) $fromJsonStaticFnName${tp.name}').join(', ')},}'
        : '';

    buff
      ..write(
        ' static $prefix$className$mainClassTypeParams $fromJsonStaticFnName$discriminatorWithClassTypeParams(${dcp}Map<${dcp}String, ${dcp}dynamic> json$genericArgs) {\n',
      )
      ..write("   final type = json['${Utils.escapeQuote(discriminatorKey ?? 'type')}'];\n")
      ..write('   return switch(type) {\n');

    final discriminatorCases = discriminatorValues
        .mapIndexed((i, e) {
          final range = discriminatorTypeParamsByIndexRange[i];
          final discriminatorClassTypeParam = range != null
              ? discriminatorTypeParams.sublist(range.start, range.end)
              : null;
          return switchCaseValue(e.$1, e.$2, discriminatorClassTypeParam);
        })
        .join(',\n');

    buff
      ..write(discriminatorCases)
      ..write(discriminatorValues.isNotEmpty ? ',\n' : '')
      ..write(
        discriminatorDefault != null
            ? switchCaseValue(discriminatorDefault, null, discriminatorDefaultFromJson, customCaseKey: '_')
            : '',
      )
      ..write(
        discriminatorDefault == null
            ? "_ => throw InvalidDiscriminatorException('Unrecognized discriminator value \"\$type\" for $className. No default subtype is defined.'),\n"
            : '',
      )
      ..write('   }${mainClassTypeParams.isNotEmpty ? ' as $prefix$className$mainClassTypeParams' : ''};\n')
      ..write('  }\n\n');
  }

  void _generatePolymorphicToJson({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required List<MacroProperty> typeParams,
    required List<(MacroClassDeclaration, MacroProperty?)> discriminatorValues,
    required List<MacroProperty> discriminatorTypeParams,
    required Map<int, _RangeInfo> discriminatorTypeParamsByIndexRange,
    required String discriminatorTypeParamsCombined,
  }) {
    final config = _getConfig(state);
    final toJsonFnName = config.useMapConvention ? 'toMap' : 'toJson';
    final dcp = state.getOrNull('dartCorePrefix') ?? '';

    String switchCaseValue(
      MacroClassDeclaration subTypeInfo,
      List<MacroProperty>? typeParams, {
      String? customCaseKey,
    }) {
      final classTypeParam = MacroProperty.getTypeParameter(typeParams ?? const []);
      final classType = '${subTypeInfo.importPrefix}${subTypeInfo.className}$classTypeParam';
      return '$classType v => v.$toJsonFnName(${typeParams?.map((e) => '$toJsonFnName${e.name}').join(', ') ?? ''})';
    }

    final genericArgs = discriminatorTypeParams.isNotEmpty
        ? '{${discriminatorTypeParams.map((tp) => 'required ${dcp}Object? Function(${tp.name} value) $toJsonFnName${tp.name}').join(', ')},}'
        : '';

    buff
      ..write(
        ' ${dcp}Map<${dcp}String, ${dcp}dynamic> ${toJsonFnName}By$discriminatorTypeParamsCombined($genericArgs) {\n',
      )
      ..write('   return switch(this) {\n');

    final cases = discriminatorValues
        .mapIndexed((i, e) {
          final range = discriminatorTypeParamsByIndexRange[i];
          final typeParams = range != null ? discriminatorTypeParams.sublist(range.start, range.end) : null;
          return switchCaseValue(e.$1, typeParams);
        })
        .join(',\n');

    buff
      ..write(cases)
      ..write(discriminatorValues.isNotEmpty ? ',\n' : '')
      ..write(
        "_ => throw InvalidDiscriminatorException('Unrecognized discriminator value \"\$runtimeType\" for $className.'),\n",
      )
      ..write('   };\n')
      ..write('  }\n\n');
  }

  void _generatePolymorphicMapTo({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required List<(MacroClassDeclaration, MacroProperty?)> discriminatorValues,
    required List<MacroProperty> discriminatorTypeParams,
    required Map<int, _RangeInfo> discriminatorTypeParamsByIndexRange,
    required String mainClassTypeParams,
    required String discriminatorTypeParamsCombined,
    bool orNull = false,
  }) {
    // final dcp = state.getOrNull<String>('dartCorePrefix') ?? '';
    final prefix = state.importPrefix;

    String switchCaseValue(
      MacroClassDeclaration subTypeInfo,
      List<MacroProperty>? typeParams, {
      String? customCaseKey,
    }) {
      final argName = subTypeInfo.className.toCamelCase();
      final classTypeParam = MacroProperty.getTypeParameter(typeParams ?? const []);
      final classType = '${subTypeInfo.importPrefix}${subTypeInfo.className}$classTypeParam';
      return '$classType v => ${orNull ? '$argName?.call(v)' : '$argName(v)'}';
    }

    final args = discriminatorValues.isNotEmpty
        ? '{${discriminatorValues.mapIndexed((i, e) {
            final range = discriminatorTypeParamsByIndexRange[i];
            final typeParams = range != null ? discriminatorTypeParams.sublist(range.start, range.end) : null;
            final classTypeParams = MacroProperty.getTypeParameter(typeParams ?? const []);
            final classType = '${e.$1.importPrefix}${e.$1.className}$classTypeParams';
            return '${orNull ? '' : 'required'} Res${orNull ? '?' : ''} Function($classType value)${orNull ? '?' : ''} ${e.$1.className.toCamelCase()}';
          }).join(',\n')}${orNull ? ',}\n' : ',\nRes Function($prefix$className$mainClassTypeParams value)? fallback,}\n'}'
        : '';

    buff
      ..write(
        ' Res${orNull ? '?' : ''} map${orNull ? 'OrNull' : ''}$discriminatorTypeParamsCombined($args) {\n',
      )
      ..write('   return switch(this) {\n');

    final discriminatorCases = discriminatorValues
        .mapIndexed((i, e) {
          final range = discriminatorTypeParamsByIndexRange[i];
          final typeParams = range != null ? discriminatorTypeParams.sublist(range.start, range.end) : null;
          return switchCaseValue(e.$1, typeParams);
        })
        .join(',\n');

    buff
      ..write(discriminatorCases)
      ..write(discriminatorValues.isNotEmpty ? ',\n' : '')
      ..write(
        orNull || discriminatorValues.isEmpty
            ? ''
            : '_  when fallback != null => fallback(this as $className$mainClassTypeParams),\n',
      )
      ..write(
        orNull
            ? '_ => null'
            : "_ => throw InvalidDiscriminatorException('Unrecognized discriminator value \"\$runtimeType\" for $className.'),\n",
      )
      ..write('   };\n')
      ..write('  }\n\n');
  }

  void _generatePolymorphicCopyWith({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required List<(MacroClassDeclaration, MacroProperty?)> discriminatorValues,
    required List<MacroProperty> discriminatorTypeParams,
    required Map<int, _RangeInfo> discriminatorTypeParamsByIndexRange,
    required String mainClassTypeParams,
    required String discriminatorTypeParamsCombined,
  }) {
    // final dcp = state.getOrNull<String>('dartCorePrefix') ?? '';

    String switchCaseValue(
      MacroClassDeclaration subTypeInfo,
      List<MacroProperty>? typeParams, {
      String? customCaseKey,
    }) {
      final argName = subTypeInfo.className.toCamelCase();
      final classTypeParams = MacroProperty.getTypeParameter(typeParams ?? const []);
      final classType = '${subTypeInfo.className}$classTypeParams';
      return '${subTypeInfo.importPrefix}$classType v => $argName != null ? $argName(v) : v.copyWith()';
    }

    final prefix = state.importPrefix;
    final args = discriminatorValues.isNotEmpty
        ? '{${discriminatorValues.mapIndexed((i, e) {
            final range = discriminatorTypeParamsByIndexRange[i];
            final typeParams = range != null ? discriminatorTypeParams.sublist(range.start, range.end) : null;
            final classTypeParams = MacroProperty.getTypeParameter(typeParams ?? const []);
            final classType = '${e.$1.importPrefix}${e.$1.className}$classTypeParams';
            return '$classType Function($classType value)? ${e.$1.className.toCamelCase()}';
          }).join(',\n')},}'
        : '';

    buff
      ..write(
        ' $prefix$className$mainClassTypeParams copyWithBy$discriminatorTypeParamsCombined($args) {\n',
      )
      ..write('   return switch(this) {\n');

    final discriminatorCases = discriminatorValues
        .mapIndexed((i, e) {
          final range = discriminatorTypeParamsByIndexRange[i];
          final typeParams = range != null ? discriminatorTypeParams.sublist(range.start, range.end) : null;
          return switchCaseValue(e.$1, typeParams);
        })
        .join(',\n');

    buff
      ..write(discriminatorCases)
      ..write(discriminatorValues.isNotEmpty ? ',\n' : '')
      ..write(
        "_ => throw InvalidDiscriminatorException('Unrecognized discriminator value \"\$runtimeType\" for $className.'),\n",
      )
      ..write('   }${mainClassTypeParams.isNotEmpty ? ' as $prefix$className$mainClassTypeParams' : ''} ;\n')
      ..write('  }\n\n');
  }

  void _generatePolymorphicAsCast({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required List<(MacroClassDeclaration, MacroProperty?)> discriminatorValues,
    required List<MacroProperty> discriminatorTypeParams,
    required Map<int, _RangeInfo> discriminatorTypeParamsByIndexRange,
  }) {
    final dcp = state.getOrNull<String>('dartCorePrefix') ?? '';

    String asTypeFunction(MacroClassDeclaration subTypeInfo, List<MacroProperty>? typeParams) {
      final classTypeParams = MacroProperty.getTypeParameter(typeParams ?? const []);
      final classTypeParamsWithBound = MacroProperty.getTypeParameterWithBound(typeParams ?? const []);
      final classType = '${subTypeInfo.importPrefix}${subTypeInfo.className}$classTypeParams';

      return '''
      @${dcp}pragma('vm:prefer-inline')
      $classType as${subTypeInfo.className}$classTypeParamsWithBound() {
        return this as $classType;
      }
      ''';
    }

    buff.write(
      discriminatorValues
          .mapIndexed((i, e) {
            final range = discriminatorTypeParamsByIndexRange[i];
            final typeParams = range != null ? discriminatorTypeParams.sublist(range.start, range.end) : null;
            return asTypeFunction(e.$1, typeParams);
          })
          .join('\n\n'),
    );
  }

  (String, String) _classTypeToMixin(String importPrefix, String type, {required String mixinSuffix}) {
    final t = type.removedNullability;

    final start = t.indexOf('<');
    if (start == -1) {
      return ('$importPrefix$t$mixinSuffix', '');
    }

    final end = t.lastIndexOf('>');
    if (end == -1) {
      return ('$importPrefix${t.substring(start)}$mixinSuffix', '');
    }

    return ('$importPrefix${t.substring(0, start)}$mixinSuffix', (t.substring(start, end + 1)));
  }
}

extension on MacroProperty {
  bool get deepEquality {
    return switch (typeInfo) {
      TypeInfo.list || TypeInfo.map || TypeInfo.iterable || TypeInfo.set => true,
      _ => false,
    };
  }
}

typedef _RangeInfo = ({int start, int end});

/// **DataClassMacro** generates common data-class boilerplate such as
/// `fromJson`, `toJson`, `copyWith`, equality, `toString`, and (in the
/// future) constructor implementations.
///
/// The macro is fully configurable through annotation metadata and can
/// optionally support polymorphic class hierarchies via a discriminator configuration
///
/// **Example**
/// Annotate your class with `@Macro(DataClassMacro)` or use the shorthand
/// `@dataClassMacro`, then apply a `with` clause to include the generated
/// mixin, e.g.:
///
/// ```dart
/// @dataClassMacro
/// class User with UserDataClass {
///   ...
/// }
/// ```
const dataClassMacro = Macro(
  DataClassMacro(
    capability: dataClassMacroCapability,
  ),
);

/// see [dataClassMacro]
const dataClassMacroCombined = Macro(
  combine: true,
  DataClassMacro(
    capability: dataClassMacroCapability,
  ),
);

const dataClassMacroCapability = MacroCapability(
  classConstructors: true,
  filterClassConstructorParameterMetadata: 'JsonKey',
  mergeClassFieldWithConstructorParameter: true,
  collectClassSubTypes: true,
  filterCollectSubTypes: 'sealed,abstract',
  inspectFieldInitializer: true,
);
