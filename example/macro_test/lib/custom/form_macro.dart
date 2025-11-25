import 'dart:async';

import 'package:macro_kit/macro.dart';

export 'package:flutter/foundation.dart' show ValueNotifier;

/// `FormMacro` generates form boilerplate including:
/// - ValueNotifiers wrapped in Optional for each schema field
/// - Getters and setters to access field values
/// - Dispose method to clean up notifiers
///
/// **Example**
/// ```dart
/// @formMacro
/// class Dashboard with DashboardForm {
///   @FormzField(type: String)
///   StringSchema get nameSchema => StringSchema(minLength: 3);
///
///   IntegerSchema get ageSchema => IntegerSchema(minimum: 18);
/// }
/// ```
class FormMacro extends MacroGenerator {
  const FormMacro({
    super.capability = const MacroCapability(
      classFields: true,
      filterClassInstanceFields: true,
      filterClassFieldMetadata: 'FormzField',
    ),
  });

  static FormMacro initialize(MacroConfig config) {
    return FormMacro(
      capability: config.capability,
    );
  }

  @override
  String get suffixName => 'Form';

  @override
  Future<void> init(MacroState state) async {
    if (state.targetType != TargetType.clazz) {
      throw MacroException('FormMacro can only be applied on class but applied on: ${state.targetType}');
    }
  }

  @override
  Future<void> onClassFields(MacroState state, List<MacroProperty> classFields) async {
    // Filter only schema fields
    final schemaFields = classFields.where(_isSchemaField).toList();
    state.set('schemaFields', schemaFields);
  }

  bool _isSchemaField(MacroProperty field) {
    final type = field.type.removedNullability;
    return type.endsWith('Schema') &&
        (type == 'Schema' ||
            type == 'StringSchema' ||
            type == 'IntegerSchema' ||
            type == 'NumberSchema' ||
            type == 'BoolSchema' ||
            type == 'ListSchema' ||
            type == 'ObjectSchema' ||
            type == 'NullSchema' ||
            type == 'AnySchema');
  }

  @override
  Future<void> onGenerate(MacroState state) async {
    final schemaFields = state.getOrNull<List<MacroProperty>>('schemaFields') ?? const [];

    if (schemaFields.isEmpty) {
      state.reportGenerated('');
      return;
    }

    final buff = StringBuffer();

    if (!state.isCombingGenerator) {
      buff.write('mixin ${state.targetName}${state.suffixName} {\n\n');
    }

    // Generate value notifiers
    _generateValueNotifiers(state, buff, schemaFields);

    buff.write('\n');

    // Generate getters and setters
    _generateAccessors(state, buff, schemaFields);

    buff.write('\n');

    // Generate dispose method
    _generateDispose(state, buff, schemaFields);

    if (!state.isCombingGenerator) {
      buff.write('\n}\n');
    }

    state.reportGenerated(buff.toString());
  }

  void _generateValueNotifiers(MacroState state, StringBuffer buff, List<MacroProperty> fields) {
    buff.write('  // Value notifiers for form fields\n');

    for (final field in fields) {
      final fieldName = _getFieldName(field.name);
      final stateName = '${fieldName}State';
      final dartType = _getDartType(field);
      final defaultValue = _getDefaultValue(field, dartType);

      buff.write('  final $stateName = ValueNotifier($defaultValue);\n');
    }
  }

  void _generateAccessors(MacroState state, StringBuffer buff, List<MacroProperty> fields) {
    buff.write('  // Getters and setters for form fields\n');

    for (final field in fields) {
      final fieldName = _getFieldName(field.name);
      final stateName = '${fieldName}State';
      final dartType = _getDartType(field);

      // Getter
      buff.write('  $dartType? get $fieldName {\n');
      buff.write('    final opt = $stateName.value;\n');
      buff.write('    return opt.isSet ? opt.value : null;\n');
      buff.write('  }\n\n');

      // Setter
      buff.write('  set $fieldName($dartType? value) {\n');
      buff.write('    if (value == null) {\n');
      buff.write('      $stateName.value = Optional<$dartType>.nullValue();\n');
      buff.write('    } else {\n');
      buff.write('      $stateName.value = Optional<$dartType>.value(value);\n');
      buff.write('    }\n');
      buff.write('  }\n\n');
    }
  }

  void _generateDispose(MacroState state, StringBuffer buff, List<MacroProperty> fields) {
    buff.write('  // Dispose all value notifiers\n');
    buff.write('  void dispose() {\n');

    for (final field in fields) {
      final fieldName = _getFieldName(field.name);
      final stateName = '${fieldName}State';
      buff.write('    $stateName.dispose();\n');
    }

    buff.write('  }\n');
  }

  String _getFieldName(String propertyName) {
    // Remove 'Schema' suffix if present
    if (propertyName.endsWith('Schema')) {
      return propertyName.substring(0, propertyName.length - 6);
    }
    return propertyName;
  }

  String _getDartType(MacroProperty field) {
    // Check if FormField metadata specifies a custom type
    final formFieldConfig = _getFormFieldConfig(field);
    if (formFieldConfig != null && formFieldConfig.type != null) {
      return formFieldConfig.type!.type;
    }

    // Infer from schema type
    final schemaType = field.type.removedNullability;

    switch (schemaType) {
      case 'StringSchema':
        return 'String';
      case 'IntegerSchema':
        return 'int';
      case 'NumberSchema':
        return 'double';
      case 'BoolSchema':
        return 'bool';
      case 'ListSchema':
        return 'List<dynamic>';
      case 'ObjectSchema':
        return 'Map<String, dynamic>';
      case 'NullSchema':
        return 'Null';
      case 'AnySchema':
        return 'dynamic';
      default:
        return 'dynamic';
    }
  }

  FormFieldConfig? _getFormFieldConfig(MacroProperty field) {
    for (final metadata in field.keys ?? const <MacroKey>[]) {
      if (metadata.name == 'FormzField') {
        return FormFieldConfig.fromMacroKey(metadata);
      }
    }
    return null;
  }

  String _getDefaultValue(MacroProperty field, String dartType) {
    final formFieldConfig = _getFormFieldConfig(field);

    if (formFieldConfig?.defaultValue != null) {
      final defaultValue = formFieldConfig!.defaultValue!;

      // Check if it's a function reference
      if (defaultValue.startsWith('_') || defaultValue.contains('(')) {
        // Instance or static function - will be called later
        return 'Optional<$dartType>.value($defaultValue)';
      }

      // Primitive value
      return 'Optional<$dartType>.value($defaultValue)';
    }

    // No default value provided
    return 'Optional<$dartType>.undefined()';
  }
}

class FormzField {
  const FormzField({
    this.type,
    this.defaultValue,
  });

  final Type? type;
  final Object? defaultValue;
}

/// Configuration for FormField annotation
class FormFieldConfig {
  const FormFieldConfig({
    this.type,
    this.defaultValue,
  });

  final MacroProperty? type;
  final String? defaultValue;

  static FormFieldConfig? fromMacroKey(MacroKey key) {
    final props = Map.fromEntries(key.properties.map((e) => MapEntry(e.name, e)));

    final typeValue = props['type']?.asTypeValue();
    final defaultValueProp = props['defaultValue'];

    String? defaultValue;
    if (defaultValueProp != null) {
      defaultValue = defaultValueProp.constantValueToDartLiteralIfNeeded;
    }

    return FormFieldConfig(
      type: typeValue,
      defaultValue: defaultValue,
    );
  }
}

extension MacroX on String {
  String get removedNullability {
    return replaceFirst('?', '');
  }
}

/// Optional wrapper type to track value state
class Optional<T> {
  const Optional._(this._value, this._state);

  final T? _value;
  final _OptionalState _state;

  /// Value is set
  factory Optional.value(T value) => Optional._(value, _OptionalState.set);

  /// Value is explicitly null
  factory Optional.nullValue() => Optional._(null, _OptionalState.nullValue);

  /// Value is undefined (not set)
  factory Optional.undefined() => Optional._(null, _OptionalState.undefined);

  bool get isSet => _state == _OptionalState.set;

  bool get isNull => _state == _OptionalState.nullValue;

  bool get isUndefined => _state == _OptionalState.undefined;

  T? get value => _value;

  @override
  String toString() => 'Optional($_state, $_value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Optional<T> && runtimeType == other.runtimeType && _value == other._value && _state == other._state;

  @override
  int get hashCode => Object.hash(_value, _state);
}

enum _OptionalState {
  set,
  nullValue,
  undefined,
}

/// Form validation state
enum FormValidationState {
  idle,
  validating,
  valid,
  invalid,
}

/// Form validation result
class FormValidationResult {
  const FormValidationResult({
    required this.isValid,
    required this.errors,
  });

  final bool isValid;
  final Map<String, List<String>> errors;

  @override
  String toString() => 'FormValidationResult(isValid: $isValid, errors: $errors)';
}

/// Shorthand annotation for FormMacro
const formMacro = Macro(
  FormMacro(
    capability: MacroCapability(
      classFields: true,
      filterClassInstanceFields: true,
      filterClassFieldMetadata: 'FormzField',
    ),
  ),
);

/// Combined version
const formMacroCombined = Macro(
  combine: true,
  FormMacro(
    capability: MacroCapability(
      classFields: true,
      filterClassInstanceFields: true,
      filterClassFieldMetadata: 'FormzField',
    ),
  ),
);
