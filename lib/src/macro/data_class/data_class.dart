import 'dart:async';

import 'package:change_case/change_case.dart';
import 'package:macro_kit/macro.dart';
import 'package:macro_kit/src/analyzer/types_ext.dart';
import 'package:macro_kit/src/core/core.dart';
import 'package:macro_kit/src/macro/data_class/config.dart';
import 'package:macro_kit/src/macro/data_class/utils.dart';

/// `DataClassMacro` generates common data-class boilerplate such as
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
    super.capability = const MacroCapability(
      classConstructors: true,
      filterClassConstructorParameterMetadata: 'JsonKey',
      mergeClassFieldWithConstructorParameter: true,
      collectClassSubTypes: true,
      filterCollectSubTypes: 'sealed,abstract',
    ),
    this.primaryConstructor,
    this.fromJson,
    this.toJson,
    this.mapTo,
    this.equal,
    this.copyWith,
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
      equal: props['equal']?.asBoolConstantValue(),
      copyWith: props['copyWith']?.asBoolConstantValue(),
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

  /// If `true` (the default) based on global config, it implements static fromJson
  final bool? fromJson;

  /// If `true` (the default) based on global config, it implements toJson method
  final bool? toJson;

  /// If `true` (the default) based on global config, it implements map and mapOrNull method on sealed or abstract class
  final bool? mapTo;

  /// If `true` (the default) based on global config, it implements equality
  final bool? equal;

  /// If `true` (the default) based on global config, it copyWith method
  final bool? copyWith;

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

  DataClassMacroConfig _getConfig(MacroState state) {
    return state.getOrNull<DataClassMacroConfig>('data_class_macro_config') ?? DataClassMacroConfig.defaultConfig;
  }

  @override
  String get suffixName => 'Data';

  @override
  Future<void> init(MacroState state) async {
    if (state.targetType != TargetType.clazz) {
      throw MacroException('DataClassMacro can only be applied on class but applied on: ${state.targetType}');
    }
  }

  @override
  Future<void> onClassTypeParameter(MacroState state, List<String> typeParameters) async {
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
    // final classFields = state.get<List<MacroField>>('classFields');
    final typeParams = state.getOrNull<List<String>>('typeParams') ?? const [];
    final constructors = state.getOrNull<List<MacroClassConstructor>>('classConstructors') ?? const [];
    final polymorphicClass = state.modifier.isSealed || state.modifier.isAbstract;

    final buff = StringBuffer();
    if (!state.isCombingGenerator) {
      buff.write('mixin ${state.targetName}Data');
      if (typeParams.isNotEmpty) {
        buff.write(computeClassTypeParamWithBound(typeParams));
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
    final fields = CombinedIterableView([positionlFields, namedFields]);

    buff.write('\n');

    // remove default constructor name, not needed
    if (primaryCtor == 'new') {
      primaryCtor = '';
    }

    final config = _getConfig(state);
    if (polymorphicClass) {
      final disDefault = state.getOrNull<MacroClassDeclaration?>('defaultPolymorphicClass');
      final disValues =
          state.getOrNull<List<(MacroClassDeclaration, MacroProperty?)>>('discriminatorValues') ?? const [];
      final mainClassTypeParams = typeParams.isNotEmpty ? '<${typeParams.join(',')}>' : '';

      // combine generic for all sealed class
      final disTypeNameParamsByIndex = <int, List<String>>{};
      final disTypeNameParams = <String>[];
      for (int i = 0; i < disValues.length; i++) {
        final (classType, _) = disValues[i];
        if (classType.classTypeParameters?.isNotEmpty != true) {
          continue;
        }

        final typeNames = classType.classTypeParameters!.map((e) => '${classType.className}$e').toList();
        disTypeNameParams.addAll(typeNames);
        disTypeNameParamsByIndex[i] = typeNames;
      }

      if (fromJson ?? config.createFromJson ?? true) {
        final allTypeNameParams = typeParams.isEmpty ? disTypeNameParams : [...typeParams, ...disTypeNameParams];
        final disTypeParams = allTypeNameParams.isNotEmpty ? '<${allTypeNameParams.join(',')}>' : '';
        final disGenericParam = disTypeParams.isNotEmpty ? computeClassTypeParamWithBound(allTypeNameParams) : '';

        _generatePolymorphicFromJson(
          state: state,
          buff: buff,
          className: state.targetName,
          disDefault: disDefault,
          disValues: disValues,
          disTypeNameParams: disTypeNameParams,
          disTypeNameParamsByIndex: disTypeNameParamsByIndex,
          mainClassTypeParams: mainClassTypeParams,
          disGenericParam: disGenericParam,
        );
      }

      if (toJson ?? config.createToJson ?? true) {
        final disTypeParams = disTypeNameParams.isNotEmpty ? '<${disTypeNameParams.join(',')}>' : '';
        final disGenericParam = disTypeParams.isNotEmpty ? computeClassTypeParamWithBound(disTypeNameParams) : '';

        _generatePolymorphicToJson(
          state: state,
          buff: buff,
          className: state.targetName,
          typeParams: typeParams,
          disValues: disValues,
          disTypeNameParams: disTypeNameParams,
          disTypeNameParamsByIndex: disTypeNameParamsByIndex,
          mainClassTypeParams: mainClassTypeParams,
          disGenericParam: disGenericParam,
        );
      }

      if ((mapTo ?? config.createMapTo ?? true) && polymorphicClass) {
        final allTypeNameParams = disTypeNameParams.toList()..add('Res');
        final disTypeParams = allTypeNameParams.isNotEmpty ? '<${allTypeNameParams.join(',')}>' : '';
        final disGenericParam = disTypeParams.isNotEmpty ? computeClassTypeParamWithBound(allTypeNameParams) : '';

        _generatePolymorphicMapTo(
          state: state,
          buff: buff,
          className: state.targetName,
          disValues: disValues,
          disTypeNameParams: disTypeNameParams,
          disTypeNameParamsByIndex: disTypeNameParamsByIndex,
          mainClassTypeParams: mainClassTypeParams,
          disGenericParam: disGenericParam,
        );

        buff.write('\n');

        _generatePolymorphicMapTo(
          state: state,
          buff: buff,
          className: state.targetName,
          disValues: disValues,
          disTypeNameParams: disTypeNameParams,
          disTypeNameParamsByIndex: disTypeNameParamsByIndex,
          mainClassTypeParams: mainClassTypeParams,
          disGenericParam: disGenericParam,
          orNull: true,
        );
      }

      if (copyWith ?? config.createCopyWith ?? true) {
        final disTypeParams = disTypeNameParams.isNotEmpty ? '<${disTypeNameParams.join(',')}>' : '';
        final disGenericParam = disTypeParams.isNotEmpty ? computeClassTypeParamWithBound(disTypeNameParams) : '';

        _generatePolymorphicCopyWith(
          state: state,
          buff: buff,
          className: state.targetName,
          disValues: disValues,
          disTypeNameParams: disTypeNameParams,
          disTypeNameParamsByIndex: disTypeNameParamsByIndex,
          mainClassTypeParams: mainClassTypeParams,
          disGenericParam: disGenericParam,
        );
      }
    } else {
      if (fromJson ?? config.createFromJson ?? true) {
        _generateFromJson(
          state: state,
          buff: buff,
          ctorName: primaryCtor,
          className: state.targetName,
          typeParams: typeParams,
          positionalFields: positionlFields,
          namedFields: namedFields,
        );
      }

      if (toJson ?? config.createToJson ?? true) {
        _generateToJson(
          state: state,
          buff: buff,
          constructor: currentPrimaryConstructor,
          ctorName: primaryCtor,
          className: state.targetName,
          fields: fields,
          typeParams: typeParams,
        );
      }

      if (copyWith ?? config.createCopyWith ?? true) {
        _generateCopyWith(
          state: state,
          buff: buff,
          className: state.targetName,
          constructor: currentPrimaryConstructor,
          ctorName: primaryCtor,
          positionalFields: positionlFields,
          namedFields: namedFields,
          generics: typeParams,
        );
      }
    }

    /// generate equality
    if ((equal ?? config.createEqual ?? true) && !polymorphicClass) {
      _generateEquality(
        state: state,
        buff: buff,
        className: state.targetName,
        constructor: currentPrimaryConstructor,
        fields: fields,
        generics: typeParams,
      );
    }

    /// generate toString
    if ((toStringOverride ?? config.createToStringOverride ?? true) && !polymorphicClass) {
      _generateToString(
        state: state,
        className: state.targetName,
        constructor: currentPrimaryConstructor,
        buff: buff,
        fields: fields,
        generics: typeParams,
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

  void _generateFromJson({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required String ctorName,
    required List<MacroProperty> positionalFields,
    required List<MacroProperty> namedFields,
    required List<String> typeParams,
  }) {
    String fieldCast(MacroProperty field, String value) {
      final isNullable = field.isNullable;
      final typeInfo = field.typeInfo;
      var type = field.type;

      final nullable = isNullable ? '?' : '';
      final startParen = isNullable || typeInfo.isIntOrDouble ? '(' : '';
      final endParen = isNullable || typeInfo.isIntOrDouble ? ')' : '';

      switch (typeInfo) {
        case TypeInfo.clazz:
        case TypeInfo.clazzAugmentation:
        case TypeInfo.extension:
        case TypeInfo.extensionType:
          final (hasFn, fromJsonFn) = hasMethodOf(
            declaration: field.classInfo,
            macroName: 'DataClassMacro',
            name: 'fromJson',
            configName: 'fromJson',
            staticFunction: true,
          );

          if (!hasFn) {
            throw MacroException(
              'The parameter `${field.name}` of type: ${field.type} in `$className` should add macro support or provide custom fromJson function',
            );
          }

          if (fromJsonFn != null) {
            if (fromJsonFn.params.length != 1 ||
                fromJsonFn.returns.first.type.removedNullability != type.removedNullability) {
              throw MacroException(
                'The parameter `${field.name}` of type: ${field.type} in `$className` should define fromJson function with one argument and return expected value',
              );
            }

            final fromJsonCastValue = fieldCast(fromJsonFn.params.first, value);
            final typeParams = fromJsonFn.typeParams.isNotEmpty == true ? '<${fromJsonFn.typeParams.join(',')}>' : '';

            if (isNullable) {
              return '$value == null ? null : ${type.removedNullability}.fromJson$typeParams($fromJsonCastValue)';
            }

            return '$type.fromJson$typeParams($fromJsonCastValue)';
          }

          final defaultFromJsonArg = MacroProperty(
            name: '',
            type: 'Map<String, dynamic>',
            typeInfo: TypeInfo.map,
            typeArguments: [
              MacroProperty(name: '', type: 'String', typeInfo: TypeInfo.string),
              MacroProperty(name: '', type: 'dynamic', typeInfo: TypeInfo.dynamic),
            ],
          );
          final fromJsonCastValue = fieldCast(defaultFromJsonArg, value);
          if (isNullable) {
            final (clsName, typeParam) = _classTypeToMixin(type, mixinSuffix: 'Data');
            return '$value == null ? null : $clsName.fromJson$typeParam($fromJsonCastValue)';
          }

          final (clsName, typeParam) = _classTypeToMixin(type, mixinSuffix: 'Data');
          return '$clsName.fromJson$typeParam($fromJsonCastValue)';
        case TypeInfo.int:
          return '$startParen$value as num$nullable$endParen$nullable.toInt()';
        case TypeInfo.double:
          return '$startParen$value as num$nullable$endParen$nullable.toDouble()';
        case TypeInfo.num:
          return '$value as num$nullable';
        case TypeInfo.string:
          return '$value as String$nullable';
        case TypeInfo.boolean:
          return '$value as bool$nullable';
        case TypeInfo.iterable:
          final elemType = field.typeArguments?.firstOrNull;
          assert(elemType != null, 'Element type of the iterable must be provided');

          if (MacroProperty.isDynamicIterable(type)) {
            if (isNullable) {
              final firstCast = type.replaceFirst('Iterable', 'List').removedNullability;
              return '$value == null ? null : ($value as $firstCast).iterator';
            }

            final firstCast = type.replaceFirst('Iterable', 'List');
            return '($value as $firstCast).iterator';
          }

          final elemTypeStr = fieldCast(elemType!, 'e');

          return '($value as List<dynamic>$nullable)$nullable.map((e) => $elemTypeStr)';
        case TypeInfo.list:
          final elemType = field.typeArguments?.firstOrNull;
          assert(elemType != null, 'Element type of the list must be provided');

          if (MacroProperty.isDynamicList(type)) {
            return '$value as $type';
          }

          final elemTypeStr = fieldCast(elemType!, 'e');

          return '($value as List<dynamic>$nullable)$nullable.map((e) => $elemTypeStr).toList()';
        case TypeInfo.map:
          final elemType = field.typeArguments?.firstOrNull;
          final elemValueType = field.typeArguments?.elementAtOrNull(1);

          assert(elemType != null, 'Key type of the map must be provided');
          assert(elemValueType != null, 'Value type of the map must be provided');

          if (MacroProperty.isDynamicMap(type)) {
            return '$value as $type';
          }

          if (elemType!.isNullable) {
            throw MacroException(
              'Map keys must be one of: Object, dynamic, enum, String, BigInt, DateTime, int, Uri but got nullable type: `${elemType.type}`',
            );
          }

          final mapElemValue = fieldCast(elemValueType!, 'e');

          // key type is string, use it directly and only cast map value
          switch (elemType.typeInfo) {
            case TypeInfo.int:
              return '($value as Map<String, dynamic>$nullable)$nullable.map((k, e) => MapEntry(int.parse(k), $mapElemValue))';
            case TypeInfo.string:
              return '($value as Map<String, dynamic>$nullable)$nullable.map((k, e) => MapEntry(k, $mapElemValue))';
            case TypeInfo.datetime:
              final keyType = fieldCast(elemType, 'k');
              return '($value as Map<String, dynamic>$nullable)$nullable.map((k, e) => MapEntry($keyType, $mapElemValue))';
            case TypeInfo.bigInt:
              return '($value as Map<String, dynamic>$nullable)$nullable.map((k, e) => MapEntry(BigInt.parse(k), $mapElemValue))';
            case TypeInfo.uri:
              return '($value as Map<String, dynamic>$nullable)$nullable.map((k, e) => MapEntry(Uri.parse(k), $mapElemValue))';
            case TypeInfo.enumData:
              final key = elemType.cacheFirstKeyInto('JsonKey', JsonKeyConfig.fromMacroKey);
              return '($value as Map<String, dynamic>$nullable)$nullable.map((k, e) => MapEntry(MacroExt.decodeEnum(${elemType.type}.values, k, unknownValue: ${key?.unknownEnumValue}), $mapElemValue))';
            case TypeInfo.object:
              return '($value as Map<Object, dynamic>$nullable)$nullable.map((k, e) => MapEntry(k, $mapElemValue))';
            case TypeInfo.dynamic:
              return '($value as Map<dynamic, dynamic>$nullable)$nullable.map((k, e) => MapEntry(k, $mapElemValue))';
            case TypeInfo.generic:
              final genType = elemType.type.removedNullability;
              if (elemType.isNullable) {
                return '($value as Map<Object?, dynamic>$nullable)$nullable.map((k, e) => MapEntry(MacroExt.decodeNullableGeneric(k, fromJson$genType), $mapElemValue))';
              }

              return '($value as Map<Object?, dynamic>$nullable)$nullable.map((k, e) => MapEntry(fromJson$genType(k), $mapElemValue))';
            default:
              throw MacroException(
                'Map keys must be one of: Object, dynamic, enum, String, BigInt, DateTime, int, Uri',
              );
          }
        case TypeInfo.set:
          final elemType = field.typeArguments?.firstOrNull;
          assert(elemType != null, 'Element type of the set must be provided');

          if (MacroProperty.isDynamicSet(type)) {
            if (isNullable) {
              final firstCast = type.replaceFirst('Set', 'List').removedNullability;
              return '$value == null ? null : ($value as $firstCast).toSet()';
            }

            final firstCast = type.replaceFirst('Set', 'List');
            return '($value as $firstCast).toSet()';
          }

          final elemTypeStr = fieldCast(elemType!, 'e');

          return '($value as List<dynamic>$nullable)$nullable.map((e) => $elemTypeStr).toSet()';
        case TypeInfo.datetime:
          if (isNullable) {
            return 'MacroExt.decodeNullableDateTime($value)';
          }

          return 'MacroExt.decodeDateTime($value)';
        case TypeInfo.duration:
          if (isNullable) {
            return '$value == null ? null : Duration(microseconds: ($value as num).toInt())';
          }
          return 'Duration(microseconds: ($value as num).toInt())';
        case TypeInfo.bigInt:
          if (isNullable) {
            return '$value == null ? null : BigInt.parse($value as String)';
          }

          return 'BigInt.parse($value as String)';
        case TypeInfo.uri:
          if (isNullable) {
            return '$value == null ? null : Uri.parse($value as String)';
          }

          return 'Uri.parse($value as String)';
        case TypeInfo.enumData:
          final key = field.cacheFirstKeyInto('JsonKey', JsonKeyConfig.fromMacroKey);
          if (isNullable) {
            final genType = type.removedNullability;
            return 'MacroExt.decodeNullableEnum($genType.values, $value, unknownValue: ${key?.unknownEnumValue})';
          }

          return 'MacroExt.decodeEnum($type.values, $value, unknownValue: ${key?.unknownEnumValue})';
        case TypeInfo.symbol:
          if (isNullable) {
            return '$value == null ? null : Symbol($value as String)';
          }

          return 'Symbol($value as String)';
        case TypeInfo.record:
        case TypeInfo.function:
        case TypeInfo.future:
        case TypeInfo.stream:
        case TypeInfo.nullType:
        case TypeInfo.voidType:
        case TypeInfo.type:
          if (isNullable) {
            final genType = type.removedNullability;
            return '$value == null ? null : $value as $genType';
          }

          return '$value as $type';
        case TypeInfo.object:
          if (isNullable) {
            return value;
          }

          return '$value as Object';
        case TypeInfo.dynamic:
          return value;
        case TypeInfo.generic:
          if (isNullable) {
            final genType = field.type.removedNullability;
            return 'MacroExt.decodeNullableGeneric($value, fromJson$genType)';
          }

          return 'fromJson${field.type}($value)';
      }
    }

    final config = _getConfig(state);
    var fieldRename = config.fieldRename ?? FieldRename.none;

    String fieldValue(MacroProperty field, [bool positional = false]) {
      final key = field.cacheFirstKeyInto('JsonKey', JsonKeyConfig.fromMacroKey) ?? JsonKeyConfig.defaultKey;
      final posOrNamedField = positional ? '    ' : '     ${field.name}:';
      final defaultValue =
          key.defaultValue ?? (field.constantValue != null ? MacroProperty.toLiteralValue(field) : null);
      final hasDefaultValue = defaultValue != null;

      // if excluded from decoding
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
      if (key.readValue != null) {
        jsonValue = '${key.readValue}(json, $tag)';
      } else {
        jsonValue = 'json[$tag]';
      }

      // custom fromJson or fallback to builtin
      final String value;
      if (key.fromJson != null) {
        final checkType = hasDefaultValue && !field.isNullable ? '${field.type}?' : field.type;
        if (!Utils.isValueTypeCanBeOfType(key.fromJsonReturnType ?? '', checkType)) {
          throw MacroException(
            'The parameter `${field.name}` of type: `${field.type}` in `${state.targetName}` has incompatible fromJson function, '
            'the fromJson return must be type of: `${field.type}` but got: `${key.fromJsonReturnType ?? ''}`',
          );
        }

        final fromJsonRetTypeNullable = key.fromJsonReturnType?.endsWith('?') == true;
        final asType = key.fromJsonArgType != null ? ' as ${key.fromJsonArgType}' : '';
        final fromJsonCallFallback = fromJsonRetTypeNullable && hasDefaultValue ? ' ?? $defaultValue' : '';
        value =
            '${field.isNullable ? '$jsonValue == null ? ${defaultValue ?? 'null'} : ' : ''}${'${key.fromJson}($jsonValue$asType)$fromJsonCallFallback'}';
      } else {
        final nullWithDefaultValue = hasDefaultValue ? field.toNullableType() : field;
        value = fieldCast(nullWithDefaultValue, jsonValue);
      }

      if (hasDefaultValue) {
        return '$posOrNamedField $value ?? $defaultValue';
      }
      return '$posOrNamedField $value';
    }

    final genericParam = typeParams.isNotEmpty ? '<${typeParams.join(',')}>' : '';
    final dartGenericParam = genericParam.isNotEmpty ? computeClassTypeParamWithBound(typeParams) : '';
    final genericArgs = typeParams.isNotEmpty
        ? ', ${typeParams.map((e) => '$e Function(Object? v) fromJson$e').join(', ')}'
        : '';

    buff
      ..write(' static $className$genericParam fromJson$dartGenericParam(Map<String, dynamic> json$genericArgs) {\n')
      ..write('   return $className$genericParam${ctorName.isNotEmpty ? '.' : ''}$ctorName(\n')
      ..write(positionalFields.map((e) => fieldValue(e, true)).join(',\n'))
      ..write(positionalFields.isNotEmpty ? ',\n' : '')
      ..write(namedFields.map(fieldValue).join(',\n'));
    if (namedFields.isNotEmpty) {
      buff.write(',\n');
    }

    buff
      ..write('   );\n')
      ..write('  }\n\n');
  }

  void _generatePolymorphicFromJson({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required MacroClassDeclaration? disDefault,
    required List<(MacroClassDeclaration, MacroProperty?)> disValues,
    required List<String> disTypeNameParams,
    required Map<int, List<String>> disTypeNameParamsByIndex,
    required String mainClassTypeParams,
    required String disGenericParam,
  }) {
    String caseCast(MacroClassDeclaration classSubType, String value) {
      final (hasFn, fromJsonFn) = hasMethodOf(
        declaration: classSubType,
        macroName: 'DataClassMacro',
        name: 'fromJson',
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
            'Subtype `${classSubType.className}` must define a `fromJson` function with one parameter and a compatible return type.',
          );
        }

        final typeParamsName = fromJsonFn.typeParams.map((e) => '${classSubType.className}$e');
        final typeParams = fromJsonFn.typeParams.isNotEmpty == true ? '<${typeParamsName.join(',')}>' : '';
        return '${classSubType.className}.fromJson$typeParams($value)';
      }

      final typeParamsName = classSubType.classTypeParameters?.map((e) => '${classSubType.className}$e');
      final typeParams = classSubType.classTypeParameters?.isNotEmpty == true ? '<${typeParamsName!.join(',')}>' : '';
      return '${classSubType.className}Data.fromJson$typeParams($value)';
    }

    String switchCaseValue(
      MacroClassDeclaration subTypeInfo,
      MacroProperty? discriminatorValue,
      List<String>? typeParams, {
      String? customCaseKey,
    }) {
      final jsonValue = typeParams?.isNotEmpty == true
          ? 'json, ${typeParams!.map((e) => 'fromJson$e').join(', ')}'
          : 'json';
      if (discriminatorValue == null) {
        return '${customCaseKey ?? "'${subTypeInfo.className}'"} => ${caseCast(subTypeInfo, jsonValue)}';
      }

      if (discriminatorValue.requireConversionToLiteral == true) {
        return "${jsonLiteralAsDart(discriminatorValue.constantValue)} => ${caseCast(subTypeInfo, jsonValue)}";
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

        return '_ when ${discriminatorValue.constantValue}(json) => ${caseCast(subTypeInfo, jsonValue)}';
      }

      throw 'invalid state: $subTypeInfo';
    }

    final disDefaultFromJson = disDefault?.classTypeParameters?.map((e) => '${disDefault.className}$e').toList();
    final genericArgs = disTypeNameParams.isNotEmpty
        ? ',{${disTypeNameParams.map((e) => 'required $e Function(Object? v) fromJson$e').join(', ')},}'
        : '';

    buff
      ..write(
        ' static $className$mainClassTypeParams fromJson$disGenericParam(Map<String, dynamic> json$genericArgs) {\n',
      )
      ..write("   final type = json['${Utils.escapeQuote(discriminatorKey ?? 'type')}'];\n")
      ..write('   return switch(type) {\n')
      ..write(disValues.mapIndexed((i, e) => switchCaseValue(e.$1, e.$2, disTypeNameParamsByIndex[i])).join(',\n'))
      ..write(disValues.isNotEmpty ? ',\n' : '')
      ..write(disDefault != null ? switchCaseValue(disDefault, null, disDefaultFromJson, customCaseKey: '_') : '')
      ..write(
        disDefault == null
            ? "_ => throw InvalidDiscriminatorException('Unrecognized discriminator value \"\$type\" for $className. No default subtype is defined.'),\n"
            : '',
      )
      ..write('   }${mainClassTypeParams.isNotEmpty ? ' as $className$mainClassTypeParams' : ''};\n')
      ..write('  }\n\n');
  }

  void _generateToJson({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required String ctorName,
    required MacroClassConstructor? constructor,
    required CombinedIterableView<MacroProperty> fields,
    required List<String> typeParams,
  }) {
    String fieldEncode(MacroProperty field, String value) {
      final isNullable = field.isNullable;
      final typeInfo = field.typeInfo;
      final type = field.type;
      final nullable = isNullable ? '?' : '';

      switch (typeInfo) {
        case TypeInfo.clazz:
        case TypeInfo.clazzAugmentation:
        case TypeInfo.extension:
        case TypeInfo.extensionType:
          final (hasFn, toJsonFn) = hasMethodOf(
            declaration: field.classInfo,
            macroName: 'DataClassMacro',
            name: 'toJson',
            configName: 'toJson',
            staticFunction: false,
          );

          if (!hasFn) {
            throw MacroException(
              'Parameter `${field.name}` of type `${field.type}` in `${state.targetName}` '
              'must either have macro support enabled or provide a custom `toJson` function.',
            );
          }

          if (toJsonFn != null) {
            if (toJsonFn.params.isNotEmpty || toJsonFn.returns.first.typeInfo == TypeInfo.voidType) {
              throw MacroException(
                'Parameter `${field.name}` of type `${field.type}` in `${state.targetName}` '
                'must define a `toJson` method with no arguments that returns the expected JSON value.',
              );
            }
          }

          return '$value$nullable.toJson()';
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

          final elemTypeStr = fieldEncode(elemType!, 'e');

          return '$value$nullable.map((e) => $elemTypeStr).toList()';
        case TypeInfo.list:
          final elemType = field.typeArguments?.firstOrNull;
          assert(elemType != null, 'Element type of the list must be provided');

          if (MacroProperty.isDynamicList(type) || MacroProperty.isListEncodeDirectlyToJson(type)) {
            return value;
          }

          final elemTypeEncoded = fieldEncode(elemType!, 'e');
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

          final mapElemValue = fieldEncode(elemValueType!, 'e');

          switch (elemType.typeInfo) {
            case TypeInfo.int:
              return '$value$nullable.map((k, e) => MapEntry(k.toString(), $mapElemValue))';
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
                _ => '$value$nullable.map((k, e) => MapEntry(k, $mapElemValue))',
              };
            case TypeInfo.datetime:
              final keyType = fieldEncode(elemType, 'k');
              return '$value$nullable.map((k, e) => MapEntry($keyType, $mapElemValue))';
            case TypeInfo.bigInt:
              return '$value$nullable.map((k, e) => MapEntry(k.toString(), $mapElemValue))';
            case TypeInfo.uri:
              return '$value$nullable.map((k, e) => MapEntry(k.toString(), $mapElemValue))';
            case TypeInfo.enumData:
              return '$value$nullable.map((k, e) => MapEntry(k.name, $mapElemValue))';
            case TypeInfo.object:
            case TypeInfo.dynamic:
              return '$value$nullable.map((k, e) => MapEntry(k, $mapElemValue))';
            case TypeInfo.generic:
              final genType = elemType.type.removedNullability;
              if (elemType.isNullable) {
                return '$value$nullable.map((k, e) => MapEntry(MacroExt.encodeNullableGeneric(k, toJson$genType), $mapElemValue))';
              }

              return '$value$nullable.map((k, e) => MapEntry(toJson$genType(k), $mapElemValue))';
            default:
              throw MacroException(
                'Map keys must be one of: Object, dynamic, enum, String, BigInt, DateTime, int, Uri',
              );
          }
        case TypeInfo.set:
          final elemType = field.typeArguments?.firstOrNull;
          assert(elemType != null, 'Element type of the set must be provided');

          if (MacroProperty.isDynamicSet(type)) return '$value$nullable.toList()';

          final elemTypeStr = fieldEncode(elemType!, 'e');

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
            return 'MacroExt.encodeNullableGeneric($value, toJson$genType)';
          }
          return 'toJson$genType($value)';
      }
    }

    // default not to include null values
    final config = _getConfig(state);
    var includeIfNull = config.includeIfNull;
    var fieldRename = config.fieldRename ?? FieldRename.none;

    String? fieldValue(MacroProperty field) {
      final key = field.cacheFirstKeyInto('JsonKey', JsonKeyConfig.fromMacroKey) ?? JsonKeyConfig.defaultKey;
      if (key.includeToJson == false) return null;

      final tag = "'${key.name?.isNotEmpty == true ? Utils.escapeQuote(key.name!) : fieldRename.renameOf(field.name)}'";
      var isNullable = field.isNullable;

      final fieldInitializer = constructor?.constantInitializers?[field.name];
      final String fieldPropName;

      if (fieldInitializer != null) {
        fieldPropName = fieldInitializer.name;
        isNullable = fieldInitializer.isNullable;
      } else {
        fieldPropName = field.name;
      }

      // custom toJson or fallback to builtin
      final String value;
      if (key.toJson != null) {
        if (!Utils.isValueTypeCanBeOfType(field.type, key.toJsonArgType ?? '')) {
          throw MacroException(
            'Parameter `${field.name}` of type `${field.type}` in `${state.targetName}` '
            'has an incompatible `toJson` function. Expected argument type: `${field.type}`, '
            'but got: `${key.toJsonArgType ?? ''}`.',
          );
        }

        value = '${key.toJson}(v.$fieldPropName)';
        isNullable = key.toJsonReturnNullable == null ? isNullable : key.toJsonReturnNullable == true;
      } else {
        value = fieldEncode(field, 'v.$fieldPropName');
      }

      if (isNullable) {
        return '      $tag: ${key.includeIfNull ?? includeIfNull ?? false ? '' : '?'}$value';
      }
      return '      $tag: $value';
    }

    final clsWithGenericParam = typeParams.isNotEmpty ? '$className<${typeParams.join(',')}>' : className;
    final genericArgs = typeParams.isNotEmpty
        ? typeParams.map((e) => 'Object? Function($e v) toJson$e').join(', ')
        : '';

    buff
      ..write(' Map<String, dynamic> toJson($genericArgs) {\n')
      ..write(fields.isNotEmpty ? '   final v = this as $clsWithGenericParam;\n' : '')
      ..write('   return <String, dynamic> {\n');

    if (includeDiscriminator == true || discriminatorKey != null || discriminatorValue != null) {
      final disKey = "'${Utils.escapeQuote(discriminatorKey ?? 'type')}'";
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
        buff.write('      $disKey: $disValue,\n');
      }
    }

    buff.write(fields.map(fieldValue).nonNulls.join(',\n'));

    if (fields.isNotEmpty) {
      buff.write(',\n');
    }

    buff
      ..write('   };\n')
      ..write(' }\n\n');
  }

  void _generatePolymorphicToJson({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required List<String> typeParams,
    required List<(MacroClassDeclaration, MacroProperty?)> disValues,
    required List<String> disTypeNameParams,
    required Map<int, List<String>> disTypeNameParamsByIndex,
    required String mainClassTypeParams,
    required String disGenericParam,
  }) {
    String switchCaseValue(
      MacroClassDeclaration subTypeInfo,
      List<String>? typeParams, {
      String? customCaseKey,
    }) {
      final hasTypeParams = typeParams?.isNotEmpty == true;
      if (!hasTypeParams) {
        return '${subTypeInfo.className} v => v.toJson()';
      }

      final classType = '${subTypeInfo.className}<${typeParams!.map((e) => e).join(', ')}>';
      return '$classType v => v.toJson(${typeParams.map((e) => 'toJson$e').join(', ')})';
    }

    final genericArgs = disTypeNameParams.isNotEmpty
        ? '{${disTypeNameParams.map((e) => 'required Object? Function($e value) toJson$e').join(', ')},}'
        : '';

    buff
      ..write(
        ' Map<String, dynamic> toJsonBy$disGenericParam($genericArgs) {\n',
      )
      ..write('   return switch(this) {\n')
      ..write(disValues.mapIndexed((i, e) => switchCaseValue(e.$1, disTypeNameParamsByIndex[i])).join(',\n'))
      ..write(disValues.isNotEmpty ? ',\n' : '')
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
    required List<(MacroClassDeclaration, MacroProperty?)> disValues,
    required List<String> disTypeNameParams,
    required Map<int, List<String>> disTypeNameParamsByIndex,
    required String mainClassTypeParams,
    required String disGenericParam,
    bool orNull = false,
  }) {
    String switchCaseValue(
      MacroClassDeclaration subTypeInfo,
      List<String>? typeParams, {
      String? customCaseKey,
    }) {
      final hasTypeParams = typeParams?.isNotEmpty == true;
      final argName = subTypeInfo.className.toSnakeCase();
      final orNullCheck = orNull ? '$argName?.call(v)' : '$argName(v)';
      if (!hasTypeParams) {
        return '${subTypeInfo.className} v => $orNullCheck';
      }

      final classType = '${subTypeInfo.className}<${typeParams!.map((e) => e).join(', ')}>';
      return '$classType v => $orNullCheck';
    }

    final args = disValues.isNotEmpty
        ? '{${disValues.mapIndexed((i, e) {
            final typeParams = disTypeNameParamsByIndex[i]?.join(',') ?? '';
            final classWithType = '${e.$1.className}${typeParams.isNotEmpty ? '<$typeParams>' : ''}';
            return '${orNull ? '' : 'required'} Res${orNull ? '?' : ''} Function($classWithType value)${orNull ? '?' : ''} ${e.$1.className.toSnakeCase()}';
          }).join(',\n')}${orNull ? ',}\n' : ',\nRes Function($className$mainClassTypeParams value)? fallback,}\n'}'
        : '';

    buff
      ..write(
        ' Res${orNull ? '?' : ''} map${orNull ? 'OrNull' : ''}$disGenericParam($args) {\n',
      )
      ..write('   return switch(this) {\n')
      ..write(disValues.mapIndexed((i, e) => switchCaseValue(e.$1, disTypeNameParamsByIndex[i])).join(',\n'))
      ..write(disValues.isNotEmpty ? ',\n' : '')
      ..write(
        orNull || disValues.isEmpty
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

  void _generateCopyWith({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required String ctorName,
    required MacroClassConstructor? constructor,
    required List<MacroProperty> positionalFields,
    required List<MacroProperty> namedFields,
    required List<String> generics,
  }) {
    if (state.modifier.isAbstract || state.modifier.isSealed) return;

    String? fieldParam(MacroProperty field) {
      final type = field.isNullable || field.typeInfo == TypeInfo.dynamic ? field.type : '${field.type}?';
      return '   $type ${field.name}';
    }

    String? fieldParamCopy(MacroProperty field, [bool positional = false]) {
      final fieldInitializer = constructor?.constantInitializers?[field.name];
      final String fieldPropName;

      if (fieldInitializer != null) {
        fieldPropName = fieldInitializer.name;
      } else {
        fieldPropName = field.name;
      }

      return '      ${positional ? '' : '${field.name}: '}${field.name} ?? v.$fieldPropName';
    }

    final clsWithGenericParam = generics.isNotEmpty == true ? '$className<${generics.join(',')}>' : className;

    // copy with params
    buff.write(' $className copyWith(');
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
        positionalFields.isNotEmpty || namedFields.isNotEmpty ? '   final v = this as $clsWithGenericParam;\n' : '',
      )
      ..write('   return $className${ctorName.isNotEmpty ? '.' : ''}$ctorName(')
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

  void _generatePolymorphicCopyWith({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required List<(MacroClassDeclaration, MacroProperty?)> disValues,
    required List<String> disTypeNameParams,
    required Map<int, List<String>> disTypeNameParamsByIndex,
    required String mainClassTypeParams,
    required String disGenericParam,
  }) {
    String switchCaseValue(
      MacroClassDeclaration subTypeInfo,
      List<String>? typeParams, {
      String? customCaseKey,
    }) {
      final hasTypeParams = typeParams?.isNotEmpty == true;
      final argName = subTypeInfo.className.toSnakeCase();
      if (!hasTypeParams) {
        return '${subTypeInfo.className} v => $argName != null ? $argName(v) : v.copyWith()';
      }

      final classType = '${subTypeInfo.className}<${typeParams!.map((e) => e).join(', ')}>';
      return '$classType v => $argName != null ? $argName(v) : v.copyWith()';
    }

    final args = disValues.isNotEmpty
        ? '{${disValues.mapIndexed((i, e) {
            final typeParams = disTypeNameParamsByIndex[i]?.join(',') ?? '';
            final classWithType = '${e.$1.className}${typeParams.isNotEmpty ? '<$typeParams>' : ''}';
            return '$classWithType Function($classWithType value)? ${e.$1.className.toSnakeCase()}';
          }).join(',\n')}}'
        : '';

    buff
      ..write(
        ' $className$mainClassTypeParams copyWithBy$disGenericParam($args) {\n',
      )
      ..write('   return switch(this) {\n')
      ..write(disValues.mapIndexed((i, e) => switchCaseValue(e.$1, disTypeNameParamsByIndex[i])).join(',\n'))
      ..write(disValues.isNotEmpty ? ',\n' : '')
      ..write(
        "_ => throw InvalidDiscriminatorException('Unrecognized discriminator value \"\$runtimeType\" for $className.'),\n",
      )
      ..write('   }${mainClassTypeParams.isNotEmpty ? ' as $className$mainClassTypeParams' : ''} ;\n')
      ..write('  }\n\n');
  }

  void _generateEquality({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required MacroClassConstructor? constructor,
    required CombinedIterableView<MacroProperty> fields,
    required List<String> generics,
  }) {
    final clsWithGenericParam = generics.isNotEmpty == true ? '$className<${generics.join(',')}>' : className;

    /// generate equality
    buff
      ..write('\n')
      ..write(' @override\n')
      ..write(' bool operator ==(Object other) {\n')
      ..write(
        fields.isNotEmpty ? '   final v = this as $clsWithGenericParam;\n' : '',
      )
      ..write(
        '   return identical(this, other) ||\n     (other.runtimeType == runtimeType && other is $clsWithGenericParam',
      );
    if (fields.isNotEmpty) {
      buff.write(' &&\n');
    }

    buff
      ..write(
        fields
            .map((field) {
              final fieldInitializer = constructor?.constantInitializers?[field.name];
              final String fieldPropName;

              if (fieldInitializer != null) {
                fieldPropName = fieldInitializer.name;
              } else {
                fieldPropName = field.name;
              }

              return field.deepEquality == true
                  ? '     const DeepCollectionEquality().equals(other.$fieldPropName, v.$fieldPropName)'
                  : '     (identical(other.$fieldPropName, v.$fieldPropName) || other.$fieldPropName == v.$fieldPropName)';
            })
            .join(' &&\n'),
      )
      ..write(');\n')
      ..write(' }\n\n');

    /// generate hash
    if (fields.isNotEmpty && fields.length <= 20) {
      buff
        ..write(' @override\n')
        ..write(' int get hashCode {\n')
        ..write(
          fields.isNotEmpty ? '   final v = this as $clsWithGenericParam;\n' : '',
        )
        ..write('  return Object.hash(\n')
        ..write('   runtimeType, ')
        ..write(
          fields
              .map(
                (field) {
                  final fieldInitializer = constructor?.constantInitializers?[field.name];
                  final String fieldPropName;

                  if (fieldInitializer != null) {
                    fieldPropName = fieldInitializer.name;
                  } else {
                    fieldPropName = field.name;
                  }

                  return field.deepEquality == true
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
        ..write(' @override\n')
        ..write(' int get hashCode {\n')
        ..write(
          fields.isNotEmpty ? '   final v = this as $clsWithGenericParam;\n' : '',
        )
        ..write('   return Object.hashAll([\n')
        ..write('     runtimeType, ')
        ..write(
          fields
              .map(
                (field) {
                  final fieldInitializer = constructor?.constantInitializers?[field.name];
                  final String fieldPropName;

                  if (fieldInitializer != null) {
                    fieldPropName = fieldInitializer.name;
                  } else {
                    fieldPropName = field.name;
                  }

                  return field.deepEquality == true
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
    required MacroClassConstructor? constructor,
    required CombinedIterableView<MacroProperty> fields,
    required List<String> generics,
  }) {
    final clsWithGenericParam = generics.isNotEmpty == true ? '$className<${generics.join(',')}>' : className;
    final genericParamAsType = generics.isNotEmpty == true ? '<\$${generics.join(',')}>' : '';

    buff
      ..write(' @override\n')
      ..write(' String toString() {\n')
      ..write(
        fields.isNotEmpty ? '   final v = this as $clsWithGenericParam;\n' : '',
      )
      ..write(
        "   return '$className$genericParamAsType{${fields.map((field) {
          late final fieldInitializer = constructor?.constantInitializers?[field.name];
          final String fieldPropName;

          if (fieldInitializer != null) {
            fieldPropName = fieldInitializer.name;
          } else {
            fieldPropName = field.name;
          }

          return '${field.name}: \${v.$fieldPropName}';
        }).join(', ')}}';\n",
      )
      ..write(' }\n');
  }

  (String, String) _classTypeToMixin(String type, {required String mixinSuffix}) {
    final t = type.removedNullability;

    final start = t.indexOf('<');
    if (start == -1) {
      return ('$t$mixinSuffix', '');
    }

    final end = t.lastIndexOf('>');
    if (end == -1) {
      return ('${t.substring(start)}$mixinSuffix', '');
    }

    return ('${t.substring(0, start)}$mixinSuffix', (t.substring(start, end + 1)));
  }
}

/// `DataClassMacro` generates common data-class boilerplate such as
/// `fromJson`, `toJson`, `copyWith`, equality, `toString`, and (in the
/// future) constructor implementations.
///
/// The macro is fully configurable through annotation metadata and can
/// optionally support polymorphic class hierarchies via a
const dataClassMacro = Macro(
  DataClassMacro(
    capability: MacroCapability(
      classConstructors: true,
      filterClassConstructorParameterMetadata: 'JsonKey',
      mergeClassFieldWithConstructorParameter: true,
      collectClassSubTypes: true,
      filterCollectSubTypes: 'sealed,abstract',
    ),
  ),
);

/// see [dataClassMacro]
const dataClassMacroCombined = Macro(
  combine: true,
  DataClassMacro(
    capability: MacroCapability(
      classConstructors: true,
      filterClassConstructorParameterMetadata: 'JsonKey',
      mergeClassFieldWithConstructorParameter: true,
      collectClassSubTypes: true,
      filterCollectSubTypes: 'sealed,abstract',
    ),
  ),
);
