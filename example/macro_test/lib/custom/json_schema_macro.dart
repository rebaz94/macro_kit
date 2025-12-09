import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:macro_kit/macro_kit.dart';

export 'package:json_schema_builder/json_schema_builder.dart';

/// Annotation for adding JSON Schema metadata to class fields
class JsonField {
  const JsonField({
    this.description,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.format,
    this.minimum,
    this.maximum,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
    this.multipleOf,
    this.minItems,
    this.maxItems,
    this.uniqueItems,
    this.enumValues,
    this.defaultValue,
    this.required,
    this.nullable,
  });

  final String? description;

  // String constraints
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final String? format; // e.g., 'email', 'uri', 'date-time', 'uuid'

  // Number constraints
  final num? minimum;
  final num? maximum;
  final bool? exclusiveMinimum;
  final bool? exclusiveMaximum;
  final num? multipleOf;

  // Array constraints
  final int? minItems;
  final int? maxItems;
  final bool? uniqueItems;

  // Enum values
  final List<Object>? enumValues;

  // Default value
  final Object? defaultValue;

  // Required field override
  final bool? required;

  // Nullable override
  final bool? nullable;
}

/// Configuration for the JSON Schema generation
class JsonSchemaConfig {
  const JsonSchemaConfig({
    this.title,
    this.description,
    this.additionalProperties = false,
    this.requiredFields,
    this.schemaVersion = 'http://json-schema.org/draft-07/schema#',
  });

  final String? title;
  final String? description;
  final bool additionalProperties;
  final List<String>? requiredFields;
  final String schemaVersion;
}

/// `JsonSchemaMacro` generates JSON Schema definitions from Dart classes
/// annotated with `@JsonField` metadata.
///
/// **Features:**
/// - Inline schemas for simple nested classes
/// - `$ref` and `$defs` for recursive types
/// - `anyOf` for polymorphic (sealed/abstract) classes with discriminator support
///
/// **Example**
/// ```dart
/// @jsonSchemaMacro
/// class UserProfile with UserProfileSchema {
///   @JsonField(description: 'Username')
///   final String username;
///
///   @JsonField(description: 'User address')
///   final Address address;
/// }
/// ```
class JsonSchemaMacro extends MacroGenerator {
  const JsonSchemaMacro({
    super.capability = const MacroCapability(
      classConstructors: true,
      filterClassConstructorParameterMetadata: 'JsonField',
      mergeClassFieldWithConstructorParameter: true,
      collectClassSubTypes: true,
      filterCollectSubTypes: 'sealed,abstract',
    ),
    this.config = const JsonSchemaConfig(),
  });

  static JsonSchemaMacro initialize(MacroConfig macroConfig) {
    final key = macroConfig.key;
    final props = Map.fromEntries(
      key.properties.map((e) => MapEntry(e.name, e)),
    );

    return JsonSchemaMacro(
      capability: macroConfig.capability,
      config: JsonSchemaConfig(
        title: props['title']?.asStringConstantValue(),
        description: props['description']?.asStringConstantValue(),
        additionalProperties: props['additionalProperties']?.asBoolConstantValue() ?? false,
        schemaVersion: props['schemaVersion']?.asStringConstantValue() ?? 'http://json-schema.org/draft-07/schema#',
      ),
    );
  }

  final JsonSchemaConfig config;

  @override
  String get suffixName => 'Schema';

  @override
  GeneratedType get generatedType => GeneratedType.mixin;

  @override
  Future<void> init(MacroState state) async {
    if (state.targetType != TargetType.clazz) {
      throw MacroException(
        'JsonSchemaMacro can only be applied to classes but applied on: ${state.targetType}',
      );
    }
  }

  @override
  Future<void> onClassConstructors(MacroState state, List<MacroClassConstructor> classConstructor) async {
    final primaryCtor = 'new';
    final currentCtor = classConstructor.firstWhereOrNull((e) => e.constructorName == primaryCtor);

    final List<MacroProperty> classFields;

    if (currentCtor == null) {
      classFields = const <MacroProperty>[];
    } else if (currentCtor.modifier.isFactory && currentCtor.redirectFactory?.isNotEmpty == true) {
      classFields = CombinedListView([currentCtor.positionalFields, currentCtor.namedFields]);
    } else if (currentCtor.modifier.isFactory) {
      throw MacroException('Json Schema class should be a normal class with fields or a factory constructor');
    } else {
      classFields = CombinedListView([currentCtor.positionalFields, currentCtor.namedFields]);
    }

    state.set('classFields', classFields);

    // Analyze fields for nested class references and detect recursion
    final nestedClasses = <String>{};
    final recursiveClasses = <String>{};

    _analyzeFieldsForRecursion(
      className: state.targetName,
      fields: classFields,
      visited: {state.targetName},
      nestedClasses: nestedClasses,
      recursiveClasses: recursiveClasses,
    );

    state.set('nestedClasses', nestedClasses);
    state.set('recursiveClasses', recursiveClasses);
  }

  @override
  Future<void> onClassSubTypes(MacroState state, List<MacroClassDeclaration> subTypes) async {
    // Store subtypes for polymorphic schema generation
    if (subTypes.isNotEmpty) {
      state.set('subTypes', subTypes);
    }
  }

  void _analyzeFieldsForRecursion({
    required String className,
    required List<MacroProperty> fields,
    required Set<String> visited,
    required Set<String> nestedClasses,
    required Set<String> recursiveClasses,
  }) {
    for (final field in fields) {
      final fieldClassName = _getClassNameFromField(field);
      if (fieldClassName == null) continue;

      nestedClasses.add(fieldClassName);

      // Check for recursion
      if (visited.contains(fieldClassName)) {
        recursiveClasses.add(fieldClassName);
        continue;
      }

      // Check if field's class has fields we can analyze
      if (field.classInfo?.classFields != null) {
        _analyzeFieldsForRecursion(
          className: fieldClassName,
          fields: field.classInfo!.classFields!,
          visited: {...visited, fieldClassName},
          nestedClasses: nestedClasses,
          recursiveClasses: recursiveClasses,
        );
      }
    }
  }

  String? _getClassNameFromField(MacroProperty field) {
    switch (field.typeInfo) {
      case TypeInfo.clazz:
      case TypeInfo.clazzAugmentation:
      case TypeInfo.extensionType:
        return field.classInfo?.className;
      case TypeInfo.list:
      case TypeInfo.iterable:
      case TypeInfo.set:
        final elemType = field.typeArguments?.firstOrNull;
        if (elemType?.typeInfo.isClassLike == true) {
          return elemType?.classInfo?.className;
        }
        return null;
      default:
        return null;
    }
  }

  @override
  Future<void> onGenerate(MacroState state) async {
    final classFields = state.get<List<MacroProperty>>('classFields');
    final recursiveClasses = state.get<Set<String>>('recursiveClasses');
    final subTypes = state.getOrNull<List<MacroClassDeclaration>>('subTypes');
    final isPolymorphic = subTypes?.isNotEmpty ?? false;

    final buff = StringBuffer();

    if (!state.isCombingGenerator) {
      buff.write('mixin ${state.targetName}${state.suffixName} {\n');
    }

    if (isPolymorphic) {
      _generatePolymorphicSchema(
        state: state,
        buff: buff,
        className: state.targetName,
        parentFields: classFields,
        subTypes: subTypes!,
        recursiveClasses: recursiveClasses,
      );
    } else {
      _generateSchemaGetter(
        state: state,
        buff: buff,
        className: state.targetName,
        fields: classFields,
        recursiveClasses: recursiveClasses,
      );
    }

    if (!state.isCombingGenerator) {
      buff.write('}\n');
    }

    state.reportGenerated(buff.toString());
  }

  void _generatePolymorphicSchema({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required List<MacroProperty> parentFields,
    required List<MacroClassDeclaration> subTypes,
    required Set<String> recursiveClasses,
  }) {
    final schemaTitle = config.title ?? className;
    final schemaDescription = config.description ?? 'Schema for $className';

    // Extract discriminator key from parent class (sealed/abstract)
    final parentDiscriminatorInfo = _extractDiscriminatorInfo(state);
    final discriminatorKey = parentDiscriminatorInfo.key;

    buff.write('  static Schema get schema {\n');
    buff.write('    return S.combined(\n');
    buff.write("      title: '$schemaTitle',\n");
    buff.write("      description: '$schemaDescription',\n");
    buff.write('      anyOf: [\n');

    for (final subType in subTypes) {
      final subClassName = subType.className;

      // Get discriminator info from the subtype class
      final subDiscriminatorInfo = _extractDiscriminatorInfoFromClass(subType);

      // Determine if we should include discriminator for this subtype
      final shouldIncludeDiscriminator =
          subDiscriminatorInfo.includeDiscriminator ||
          subDiscriminatorInfo.hasExplicitValue ||
          parentDiscriminatorInfo.includeDiscriminator;

      // Skip discriminator if value is a function (not a primitive)
      final skipDiscriminator = subDiscriminatorInfo.isFunction;

      // Get the discriminator value: explicit value > class name
      final discriminatorValue = subDiscriminatorInfo.value ?? subClassName;

      // Build the subtype schema with parent fields + discriminator
      buff.write('        S.object(\n');
      buff.write("          title: '$subClassName',\n");

      // Collect all required fields (parent + subtype)
      final allRequiredFields = <String>[];

      // Add parent required fields
      for (final field in parentFields) {
        final jsonField = _extractJsonFieldConfig(field);
        final isRequired = jsonField?.required ?? !field.isNullable;
        final name = jsonField?.name ?? field.name;
        if (isRequired) {
          allRequiredFields.add(name);
        }
      }

      // Add discriminator as required if we should include it
      if (shouldIncludeDiscriminator && !skipDiscriminator) {
        allRequiredFields.add(discriminatorKey);
      }

      // Add subtype's own fields if available
      if (subType.classFields != null) {
        for (final field in subType.classFields!) {
          final jsonField = _extractJsonFieldConfig(field);
          final isRequired = jsonField?.required ?? !field.isNullable;
          final name = jsonField?.name ?? field.name;
          if (isRequired && !allRequiredFields.contains(name)) {
            allRequiredFields.add(name);
          }
        }
      }

      if (allRequiredFields.isNotEmpty) {
        buff.write('          required: [');
        buff.write(allRequiredFields.map((f) => "'$f'").join(', '));
        buff.write('],\n');
      }

      buff.write('          properties: {\n');

      // Add discriminator field first (only if not a function)
      if (shouldIncludeDiscriminator && !skipDiscriminator) {
        buff.write("            '$discriminatorKey': S.string(\n");
        buff.write("              description: 'Type discriminator',\n");
        buff.write("              enumValues: ['${_escapeString(discriminatorValue)}'],\n");
        buff.write('            ),\n');
      }

      // Add parent fields
      for (final field in parentFields) {
        _generateFieldSchema(
          state: state,
          buff: buff,
          field: field,
          recursiveClasses: recursiveClasses,
          indent: '            ',
        );
      }

      // Add subtype-specific fields
      if (subType.classFields != null) {
        for (final field in subType.classFields!) {
          // Skip if already defined in parent
          if (parentFields.any((pf) => pf.name == field.name)) {
            continue;
          }
          _generateFieldSchema(
            state: state,
            buff: buff,
            field: field,
            recursiveClasses: recursiveClasses,
            indent: '            ',
          );
        }
      }

      buff.write('          },\n');
      buff.write('          additionalProperties: ${config.additionalProperties},\n');
      buff.write('        ),\n');
    }

    buff.write('      ],\n');

    // Add $defs for recursive subtypes
    if (recursiveClasses.isNotEmpty) {
      buff.write('      defs: {\n');
      for (final subType in subTypes) {
        final subClassName = subType.className;
        if (recursiveClasses.contains(subClassName)) {
          buff.write("        '$subClassName': $subClassName${state.suffixName}.schema,\n");
        }
      }
      buff.write('      },\n');
    }

    buff.write('    );\n');
    buff.write('  }\n\n');
  }

  _DiscriminatorInfo _extractDiscriminatorInfo(MacroState state) {
    // Look for DataClassMacro in the current class
    final dataClassMacro = state.remainingMacro.firstWhereOrNull(
      (m) => m.name == 'DataClassMacro',
    );

    if (dataClassMacro == null) {
      // Check in the main macro metadata
      final macroKey = state.macro;
      if (macroKey.name == 'DataClassMacro') {
        return _parseDiscriminatorFromKey(macroKey);
      }
      return _DiscriminatorInfo(
        key: 'type',
        includeDiscriminator: false,
        hasExplicitValue: false,
        isFunction: false,
      );
    }

    return _parseDiscriminatorFromKey(dataClassMacro);
  }

  _DiscriminatorInfo _extractDiscriminatorInfoFromClass(MacroClassDeclaration classDecl) {
    final dataClassConfig = classDecl.configs.firstWhereOrNull(
      (c) => c.key.name == 'DataClassMacro',
    );

    if (dataClassConfig == null) {
      return _DiscriminatorInfo(
        key: 'type',
        includeDiscriminator: false,
        hasExplicitValue: false,
        isFunction: false,
      );
    }

    return _parseDiscriminatorFromKey(dataClassConfig.key);
  }

  _DiscriminatorInfo _parseDiscriminatorFromKey(MacroKey key) {
    final props = Map.fromEntries(
      key.properties.map((e) => MapEntry(e.name, e)),
    );

    final discriminatorKeyProp = props['discriminatorKey'];
    final discriminatorValueProp = props['discriminatorValue'];
    final includeDiscriminatorProp = props['includeDiscriminator'];

    final discriminatorKey = discriminatorKeyProp?.asStringConstantValue();
    final includeDiscriminator = includeDiscriminatorProp?.asBoolConstantValue();

    // Check if discriminatorValue exists and what type it is
    String? discriminatorValue;
    bool hasExplicitValue = false;
    bool isFunction = false;

    if (discriminatorValueProp != null) {
      hasExplicitValue = true;

      // Check if it's a function type
      if (discriminatorValueProp.typeInfo == TypeInfo.function) {
        isFunction = true;
      } else {
        // It's a primitive value (string, int, double, bool)
        final value = discriminatorValueProp.constantValue;
        if (value != null) {
          discriminatorValue = value.toString();
        }
      }
    }

    // Determine if we should include discriminator:
    // 1. includeDiscriminator is explicitly true
    // 2. discriminatorKey is explicitly set
    // 3. discriminatorValue is explicitly set (and not a function)
    final shouldInclude = includeDiscriminator == true || discriminatorKey != null || (hasExplicitValue && !isFunction);

    return _DiscriminatorInfo(
      key: discriminatorKey ?? 'type',
      value: discriminatorValue,
      includeDiscriminator: shouldInclude,
      hasExplicitValue: hasExplicitValue,
      isFunction: isFunction,
    );
  }

  void _generateSchemaGetter({
    required MacroState state,
    required StringBuffer buff,
    required String className,
    required List<MacroProperty> fields,
    required Set<String> recursiveClasses,
  }) {
    final schemaTitle = config.title ?? className;
    final schemaDescription = config.description ?? 'Schema for $className';

    // Collect required fields
    final requiredFields = <String>[];
    for (final field in fields) {
      final jsonField = _extractJsonFieldConfig(field);
      final isRequired = jsonField?.required ?? !field.isNullable;
      final name = jsonField?.name ?? field.name;
      if (isRequired) {
        requiredFields.add(name);
      }
    }

    buff.write('  static Schema get schema {\n');
    buff.write('    return S.object(\n');
    buff.write("      title: '$schemaTitle',\n");
    buff.write("      description: '$schemaDescription',\n");

    if (requiredFields.isNotEmpty) {
      buff.write('      required: [');
      buff.write(requiredFields.map((f) => "'$f'").join(', '));
      buff.write('],\n');
    }

    buff.write('      properties: {\n');

    for (final field in fields) {
      _generateFieldSchema(
        state: state,
        buff: buff,
        field: field,
        recursiveClasses: recursiveClasses,
      );
    }

    buff.write('      },\n');

    // Add $defs for recursive types
    if (recursiveClasses.isNotEmpty) {
      buff.write('      defs: {\n');
      for (final refClass in recursiveClasses) {
        buff.write("        '$refClass': $refClass${state.suffixName}.schema,\n");
      }
      buff.write('      },\n');
    }

    buff.write('      additionalProperties: ${config.additionalProperties},\n');
    buff.write('    );\n');
    buff.write('  }\n\n');
  }

  void _generateFieldSchema({
    required MacroState state,
    required StringBuffer buff,
    required MacroProperty field,
    required Set<String> recursiveClasses,
    String indent = '        ',
  }) {
    final jsonField = _extractJsonFieldConfig(field);
    final fieldName = jsonField?.name ?? field.name;

    buff.write("$indent'$fieldName': ");

    switch (field.typeInfo) {
      case TypeInfo.string:
        _generateStringSchema(buff, field, jsonField);
        break;
      case TypeInfo.int:
        _generateIntegerSchema(buff, field, jsonField);
        break;
      case TypeInfo.double:
      case TypeInfo.num:
        _generateNumberSchema(buff, field, jsonField);
        break;
      case TypeInfo.boolean:
        _generateBooleanSchema(buff, field, jsonField);
        break;
      case TypeInfo.list:
      case TypeInfo.iterable:
        _generateArraySchema(state, buff, field, jsonField, recursiveClasses);
        break;
      case TypeInfo.map:
        _generateObjectSchema(buff, field, jsonField);
        break;
      case TypeInfo.enumData:
        _generateEnumSchema(buff, field, jsonField);
        break;
      case TypeInfo.datetime:
        _generateDateTimeSchema(buff, field, jsonField);
        break;
      case TypeInfo.clazz:
      case TypeInfo.clazzAugmentation:
      case TypeInfo.extensionType:
        _generateClassSchema(state, buff, field, jsonField, recursiveClasses);
        break;
      default:
        _generateGenericSchema(buff, field, jsonField);
    }

    buff.write(',\n');
  }

  void _generateClassSchema(
    MacroState state,
    StringBuffer buff,
    MacroProperty field,
    _JsonFieldData? config,
    Set<String> recursiveClasses,
  ) {
    final className = field.classInfo?.className;

    if (className == null) {
      buff.write('S.any()');
      return;
    }

    // Check if the class has jsonSchemaMacro
    final hasJsonSchemaMacro =
        field.classInfo?.configs.any(
          (c) => c.key.name == 'JsonSchemaMacro',
        ) ??
        false;

    if (!hasJsonSchemaMacro) {
      buff.write('S.any() /* Warning: $className should have @jsonSchemaMacro */');
      return;
    }

    if (recursiveClasses.contains(className)) {
      // Use $ref for recursive types
      buff.write("<String, Object?>{'\\\$ref': '#/\\\$defs/$className'} as Schema");
    } else {
      // Inline the schema by calling the generated static getter
      buff.write('$className${state.suffixName}.schema');
    }
  }

  void _generateStringSchema(StringBuffer buff, MacroProperty field, _JsonFieldData? config) {
    buff.write('S.string(');

    final params = <String>[];

    if (config?.description != null) {
      params.add("description: '${_escapeString(config!.description!)}'");
    }

    if (config?.minLength != null) {
      params.add('minLength: ${config!.minLength}');
    }

    if (config?.maxLength != null) {
      params.add('maxLength: ${config!.maxLength}');
    }

    if (config?.pattern != null) {
      params.add("pattern: r'${config!.pattern}'");
    }

    if (config?.format != null) {
      params.add("format: '${config!.format}'");
    }

    if (config?.enumValues != null) {
      params.add('enumValues: ${_formatEnumValues(config!.enumValues!)}');
    }

    if (config?.defaultValue != null && config!.defaultValue is String) {
      params.add("defaultValue: '${_escapeString(config.defaultValue.toString())}'");
    }

    if (params.isNotEmpty) {
      buff.write('\n          ');
      buff.write(params.join(',\n          '));
      buff.write(',\n        ');
    }

    buff.write(')');
  }

  void _generateIntegerSchema(StringBuffer buff, MacroProperty field, _JsonFieldData? config) {
    buff.write('S.integer(');

    final params = <String>[];

    if (config?.description != null) {
      params.add("description: '${_escapeString(config!.description!)}'");
    }

    if (config?.minimum != null) {
      params.add('minimum: ${config!.minimum}');
    }

    if (config?.maximum != null) {
      params.add('maximum: ${config!.maximum}');
    }

    if (config?.exclusiveMinimum != null) {
      params.add('exclusiveMinimum: ${config!.exclusiveMinimum}');
    }

    if (config?.exclusiveMaximum != null) {
      params.add('exclusiveMaximum: ${config!.exclusiveMaximum}');
    }

    if (config?.multipleOf != null) {
      params.add('multipleOf: ${config!.multipleOf}');
    }

    if (config?.enumValues != null) {
      params.add('enumValues: ${config!.enumValues}');
    }

    if (config?.defaultValue != null) {
      params.add('defaultValue: ${config!.defaultValue}');
    }

    if (params.isNotEmpty) {
      buff.write('\n          ');
      buff.write(params.join(',\n          '));
      buff.write(',\n        ');
    }

    buff.write(')');
  }

  void _generateNumberSchema(StringBuffer buff, MacroProperty field, _JsonFieldData? config) {
    buff.write('S.number(');

    final params = <String>[];

    if (config?.description != null) {
      params.add("description: '${_escapeString(config!.description!)}'");
    }

    if (config?.minimum != null) {
      params.add('minimum: ${config!.minimum}');
    }

    if (config?.maximum != null) {
      params.add('maximum: ${config!.maximum}');
    }

    if (config?.exclusiveMinimum != null) {
      params.add('exclusiveMinimum: ${config!.exclusiveMinimum}');
    }

    if (config?.exclusiveMaximum != null) {
      params.add('exclusiveMaximum: ${config!.exclusiveMaximum}');
    }

    if (config?.multipleOf != null) {
      params.add('multipleOf: ${config!.multipleOf}');
    }

    if (config?.defaultValue != null) {
      params.add('defaultValue: ${config!.defaultValue}');
    }

    if (params.isNotEmpty) {
      buff.write('\n          ');
      buff.write(params.join(',\n          '));
      buff.write(',\n        ');
    }

    buff.write(')');
  }

  void _generateBooleanSchema(StringBuffer buff, MacroProperty field, _JsonFieldData? config) {
    buff.write('S.boolean(');

    if (config?.description != null) {
      buff.write("\n          description: '${_escapeString(config!.description!)}',\n        ");
    }

    buff.write(')');
  }

  void _generateArraySchema(
    MacroState state,
    StringBuffer buff,
    MacroProperty field,
    _JsonFieldData? config,
    Set<String> recursiveClasses,
  ) {
    buff.write('S.list(');

    final params = <String>[];

    if (config?.description != null) {
      params.add("description: '${_escapeString(config!.description!)}'");
    }

    // Generate items schema based on element type
    final elemType = field.typeArguments?.firstOrNull;
    if (elemType != null) {
      final itemsSchema = _generateItemSchema(state, elemType, recursiveClasses);
      params.add('items: $itemsSchema');
    }

    if (config?.minItems != null) {
      params.add('minItems: ${config!.minItems}');
    }

    if (config?.maxItems != null) {
      params.add('maxItems: ${config!.maxItems}');
    }

    if (config?.uniqueItems != null) {
      params.add('uniqueItems: ${config!.uniqueItems}');
    }

    if (params.isNotEmpty) {
      buff.write('\n          ');
      buff.write(params.join(',\n          '));
      buff.write(',\n        ');
    }

    buff.write(')');
  }

  void _generateObjectSchema(StringBuffer buff, MacroProperty field, _JsonFieldData? config) {
    buff.write('S.object(');

    if (config?.description != null) {
      buff.write("\n          description: '${_escapeString(config!.description!)}',\n        ");
    }

    buff.write(')');
  }

  void _generateEnumSchema(StringBuffer buff, MacroProperty field, _JsonFieldData? config) {
    buff.write('S.string(');

    final params = <String>[];

    if (config?.description != null) {
      params.add("description: '${_escapeString(config!.description!)}'");
    }

    // Get enum values from the type
    final enumType = field.type.replaceAll('?', '');
    params.add("enumValues: $enumType.values.map((e) => e.name).toList()");

    if (params.isNotEmpty) {
      buff.write('\n          ');
      buff.write(params.join(',\n          '));
      buff.write(',\n        ');
    }

    buff.write(')');
  }

  void _generateDateTimeSchema(StringBuffer buff, MacroProperty field, _JsonFieldData? config) {
    buff.write('S.string(');

    final params = <String>[];

    if (config?.description != null) {
      params.add("description: '${_escapeString(config!.description!)}'");
    }

    params.add("format: 'date-time'");

    if (params.isNotEmpty) {
      buff.write('\n          ');
      buff.write(params.join(',\n          '));
      buff.write(',\n        ');
    }

    buff.write(')');
  }

  void _generateGenericSchema(StringBuffer buff, MacroProperty field, _JsonFieldData? config) {
    // Fallback to any type
    buff.write('S.any(');

    if (config?.description != null) {
      buff.write("\n          description: '${_escapeString(config!.description!)}',\n        ");
    }

    buff.write(')');
  }

  String _generateItemSchema(
    MacroState state,
    MacroProperty elemType,
    Set<String> recursiveClasses,
  ) {
    switch (elemType.typeInfo) {
      case TypeInfo.string:
        return 'S.string()';
      case TypeInfo.int:
        return 'S.integer()';
      case TypeInfo.double:
      case TypeInfo.num:
        return 'S.number()';
      case TypeInfo.boolean:
        return 'S.boolean()';
      case TypeInfo.enumData:
        final enumType = elemType.type.replaceAll('?', '');
        return "S.string(enumValues: $enumType.values.map((e) => e.name).toList())";
      case TypeInfo.clazz:
      case TypeInfo.clazzAugmentation:
      case TypeInfo.extensionType:
        final className = elemType.classInfo?.className;
        if (className == null) return 'S.any()';

        final hasJsonSchemaMacro = elemType.classInfo?.configs.any((c) => c.key.name == 'JsonSchemaMacro') ?? false;

        if (!hasJsonSchemaMacro) {
          return 'S.any() /* Warning: $className should have @jsonSchemaMacro */';
        }

        if (recursiveClasses.contains(className)) {
          return "<String,Object?>{'\\\$ref': '#/\\\$defs/$className'} as Schema";
        } else {
          return '$className${state.suffixName}.schema';
        }
      default:
        return 'S.any()';
    }
  }

  _JsonFieldData? _extractJsonFieldConfig(MacroProperty field) {
    String? getFieldNameFromJsonKey() {
      final jsonKey = field.keys?.firstWhereOrNull((k) => k.name == 'JsonKey');
      return jsonKey?.properties.firstWhereOrNull((e) => e.name == 'name')?.asStringConstantValue();
    }

    final jsonFieldKey = field.keys?.firstWhereOrNull((k) => k.name == 'JsonField');
    if (jsonFieldKey == null) {
      final name = getFieldNameFromJsonKey();
      if (name?.isNotEmpty == true) {
        return _JsonFieldData(name: name);
      }

      return null;
    }

    final props = Map.fromEntries(
      jsonFieldKey.properties.map((e) => MapEntry(e.name, e)),
    );

    String? name = props['name']?.asStringConstantValue();
    if (name == null || name.isEmpty) {
      name = getFieldNameFromJsonKey();
    }

    return _JsonFieldData(
      name: name,
      description: props['description']?.asStringConstantValue(),
      minLength: props['minLength']?.asIntConstantValue(),
      maxLength: props['maxLength']?.asIntConstantValue(),
      pattern: props['pattern']?.asStringConstantValue(),
      format: props['format']?.asStringConstantValue(),
      minimum: props['minimum']?.asNumConstantValue(),
      maximum: props['maximum']?.asNumConstantValue(),
      exclusiveMinimum: props['exclusiveMinimum']?.asBoolConstantValue(),
      exclusiveMaximum: props['exclusiveMaximum']?.asBoolConstantValue(),
      multipleOf: props['multipleOf']?.asNumConstantValue(),
      minItems: props['minItems']?.asIntConstantValue(),
      maxItems: props['maxItems']?.asIntConstantValue(),
      uniqueItems: props['uniqueItems']?.asBoolConstantValue(),
      enumValues: props['enumValues']?.constantValue as List<Object>?,
      defaultValue: props['defaultValue']?.constantValue,
      required: props['required']?.asBoolConstantValue(),
      nullable: props['nullable']?.asBoolConstantValue(),
    );
  }

  String _escapeString(String str) {
    return str.replaceAll("'", "\\'").replaceAll('\n', '\\n');
  }

  String _formatEnumValues(List<Object> values) {
    return '[${values.map((v) => v is String ? "'$v'" : v.toString()).join(', ')}]';
  }
}

class _JsonFieldData {
  const _JsonFieldData({
    this.name,
    this.description,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.format,
    this.minimum,
    this.maximum,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
    this.multipleOf,
    this.minItems,
    this.maxItems,
    this.uniqueItems,
    this.enumValues,
    this.defaultValue,
    this.required,
    this.nullable,
  });

  final String? name;
  final String? description;
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final String? format;
  final num? minimum;
  final num? maximum;
  final bool? exclusiveMinimum;
  final bool? exclusiveMaximum;
  final num? multipleOf;
  final int? minItems;
  final int? maxItems;
  final bool? uniqueItems;
  final List<Object>? enumValues;
  final Object? defaultValue;
  final bool? required;
  final bool? nullable;
}

class _DiscriminatorInfo {
  const _DiscriminatorInfo({
    required this.key,
    this.value,
    required this.includeDiscriminator,
    required this.hasExplicitValue,
    required this.isFunction,
  });

  /// The discriminator key (e.g., 'type', 'kind')
  /// Comes from the parent sealed/abstract class
  final String key;

  /// The discriminator value (e.g., 'cat', 'dog', 'its_my_cat')
  /// Comes from the subtype class, or defaults to class name
  final String? value;

  /// Whether to include the discriminator in the schema
  final bool includeDiscriminator;

  /// Whether discriminatorValue was explicitly set in metadata
  final bool hasExplicitValue;

  /// Whether discriminatorValue is a function type (should be skipped)
  final bool isFunction;
}

/// Shorthand annotation for JSON Schema macro
const jsonSchemaMacro = Macro(
  JsonSchemaMacro(
    capability: MacroCapability(
      classConstructors: true,
      filterClassConstructorParameterMetadata: 'JsonField',
      mergeClassFieldWithConstructorParameter: true,
      collectClassSubTypes: true,
      filterCollectSubTypes: 'sealed,abstract',
    ),
  ),
);
