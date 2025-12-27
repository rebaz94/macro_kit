import 'package:macro_kit/src/core/core.dart';
import 'package:meta/meta.dart';

/// A `MacroCapability` describes which elements of a class (constructors,
/// fields, methods, metadata, and subtypes) should be collected and made
/// available to the macro during generation.
///
/// Each flag enables a specific category of information.
/// Some options only apply when their parent category is enabled
/// (e.g., field filters only apply when [classFields] is `true`).
///
/// This allows each macro to precisely control the level of detail it needs,
/// improving performance and avoiding unnecessary analysis work.
class MacroCapability {
  const MacroCapability({
    this.classFields = false,
    this.filterClassInstanceFields = false,
    this.filterClassStaticFields = false,
    this.filterClassIgnoreSetterOnly = true,
    this.filterClassFieldMetadata = '',
    this.classConstructors = false,
    this.filterClassConstructorParameterMetadata = '',
    this.mergeClassFieldWithConstructorParameter = false,
    this.inspectFieldInitializer = false,
    this.classMethods = false,
    this.filterClassInstanceMethod = false,
    this.filterClassStaticMethod = false,
    this.filterMethods = '',
    this.filterClassMethodMetadata = '',
    this.topLevelFunctions = false,
    this.collectClassSubTypes = false,
    this.filterCollectSubTypes = '',
  });

  static MacroCapability fromJson(Map<String, dynamic> json) {
    return MacroCapability(
      classFields: (json['cf'] as bool?) ?? false,
      filterClassInstanceFields: (json['fcif'] as bool?) ?? false,
      filterClassStaticFields: (json['fcsf'] as bool?) ?? false,
      filterClassIgnoreSetterOnly: (json['fciso'] as bool?) ?? false,
      filterClassFieldMetadata: (json['fcfm'] as String?) ?? '',
      classConstructors: (json['cc'] as bool?) ?? false,
      filterClassConstructorParameterMetadata: (json['fccpm'] as String?) ?? '',
      mergeClassFieldWithConstructorParameter: (json['mcfwcp'] as bool?) ?? false,
      inspectFieldInitializer: (json['ifi'] as bool?) ?? false,
      classMethods: (json['cm'] as bool?) ?? false,
      filterClassInstanceMethod: (json['fcim'] as bool?) ?? false,
      filterClassStaticMethod: (json['fcsm'] as bool?) ?? false,
      filterMethods: (json['fm'] as String?) ?? '',
      filterClassMethodMetadata: (json['fcmm'] as String?) ?? '',
      topLevelFunctions: (json['tlf'] as bool?) ?? false,
      collectClassSubTypes: (json['ccst'] as bool?) ?? false,
      filterCollectSubTypes: (json['fccst'] as String?) ?? '',
    );
  }

  /// Whether to retrieve all fields declared in the class.
  final bool classFields;

  /// Whether to include only instance fields.
  ///
  /// Only applies when [classFields] is `true`.
  final bool filterClassInstanceFields;

  /// Whether to include only static fields.
  ///
  /// Only applies when [classFields] is `true`.
  final bool filterClassStaticFields;

  /// Whether to include only property (getter, setter or variable declaration).
  ///
  /// Only applies when [classFields] is `true`.
  final bool filterClassIgnoreSetterOnly;

  /// Filter specified custom metadata defined on the field.
  ///
  /// To get all metadata, use '*' or filter by providing comma separated key 'JsonKey,CustomMetadata'
  ///
  /// Only applies when [classFields] is `true`.
  final String filterClassFieldMetadata;

  /// Whether to retrieve all constructors declared in the class.
  final bool classConstructors;

  /// Filter specified custom metadata defined on the constructor parameter.
  ///
  /// To get all metadata, use '*' or filter by providing comma separated key 'JsonKey,CustomMetadata'
  ///
  /// Only applies when [classConstructors] is `true`.
  final String filterClassConstructorParameterMetadata;

  /// Whether to merge metadata declared in the class field with
  /// the parameter defined in the constructor.
  ///
  /// Only applies when [classConstructors] is true.
  final bool mergeClassFieldWithConstructorParameter;

  /// Whether to infer field initializers from the target or super class.
  ///
  /// Example:
  /// ```dart
  /// class Parent {
  ///   final String name;
  ///   Parent(this.name);
  /// }
  ///
  /// class Child extends Parent {
  ///   Child(String? name) : super(name ?? ''); // nullable param, non-null field
  /// }
  /// ```
  /// When true, detects that `name` should be non-null based on the field definition.
  ///
  /// Only use it when it required to access field initializer, it's expensive operation.
  ///
  /// Only applies when [classConstructors] is true.
  final bool inspectFieldInitializer;

  /// Whether to retrieve all methods declared in the class.
  final bool classMethods;

  /// Whether to include only instance methods.
  ///
  /// Only applies when [classMethods] is `true`.
  final bool filterClassInstanceMethod;

  /// Whether to include only static methods.
  ///
  /// Only applies when [classMethods] is `true`.
  final bool filterClassStaticMethod;

  /// Filters which methods should be included from the class.
  ///
  /// This works only when [classMethods] is `true`, and the instance/static
  /// filtering (via [filterClassInstanceMethod] and [filterClassStaticMethod])
  /// has already been applied.
  ///
  /// Use:
  ///   * '*' to include all methods
  ///   * a comma-separated list to include specific methods
  ///     e.g. `'build,toJson'`
  ///
  /// The names must match the method identifiers in the class.
  final String filterMethods;

  /// Filter specified custom metadata defined on the method.
  ///
  /// To get all metadata, use '*' or filter by providing comma separated key 'JsonKey,CustomMetadata'
  final String filterClassMethodMetadata;

  /// Whether to retrieve all function declared in the library.
  final bool topLevelFunctions;

  /// Whether to include all subclasses (subtypes) of this class.
  ///
  /// When set to `true`, the generator will automatically discover and include
  /// every class that extends this class. This is primarily used
  /// for polymorphic code generation, where the base class needs to know all of
  /// its concrete implementations.
  ///
  /// Only applies to abstract or sealed classes.
  final bool collectClassSubTypes;

  /// Determines **which kinds of classes are allowed to perform subtype
  /// collection** when [collectClassSubTypes] is `true`.
  ///
  /// This filter applies to the *current class*, not the subtypes.
  /// In other words: it decides whether this class is eligible for subtype
  /// discovery based on whether it is `sealed`, `abstract`, or both.
  ///
  /// Supported values:
  ///   - `"sealed"` — only sealed classes can collect subtypes
  ///   - `"abstract"` — only abstract classes can collect subtypes
  ///   - `"sealed,abstract"` — both sealed and abstract classes
  ///   - `"*"` — any class may collect subtypes
  final String filterCollectSubTypes;

  MacroCapability combine(MacroCapability c) {
    String combineFilter(String base, String other) {
      if (base == '*' || other == '*') return '*';
      if (base.isEmpty) return other;
      if (other.isEmpty) return base;

      return '$base,$other';
    }

    return MacroCapability(
      classFields: c.classFields ? true : classFields,
      filterClassInstanceFields: c.filterClassInstanceFields ? true : filterClassInstanceFields,
      filterClassStaticFields: c.filterClassStaticFields ? true : filterClassStaticFields,
      filterClassIgnoreSetterOnly: c.filterClassIgnoreSetterOnly ? true : filterClassIgnoreSetterOnly,
      filterClassFieldMetadata: combineFilter(filterClassFieldMetadata, c.filterClassFieldMetadata),
      classConstructors: c.classConstructors ? true : classConstructors,
      filterClassConstructorParameterMetadata: combineFilter(
        filterClassConstructorParameterMetadata,
        c.filterClassConstructorParameterMetadata,
      ),
      mergeClassFieldWithConstructorParameter: c.mergeClassFieldWithConstructorParameter
          ? true
          : mergeClassFieldWithConstructorParameter,
      inspectFieldInitializer: c.inspectFieldInitializer ? true : inspectFieldInitializer,
      classMethods: c.classMethods ? true : classMethods,
      filterClassInstanceMethod: c.filterClassInstanceMethod ? true : filterClassInstanceMethod,
      filterClassStaticMethod: c.filterClassStaticMethod ? true : filterClassStaticMethod,
      filterMethods: combineFilter(filterMethods, c.filterMethods),
      filterClassMethodMetadata: combineFilter(filterClassMethodMetadata, c.filterClassMethodMetadata),
      topLevelFunctions: c.topLevelFunctions ? true : topLevelFunctions,
      collectClassSubTypes: c.collectClassSubTypes ? true : collectClassSubTypes,
      filterCollectSubTypes: combineFilter(filterCollectSubTypes, c.filterCollectSubTypes),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (classFields) 'cf': true,
      if (filterClassInstanceFields) 'fcif': true,
      if (filterClassIgnoreSetterOnly) 'fciso': true,
      if (filterClassStaticFields) 'fcsf': true,
      if (filterClassFieldMetadata.isNotEmpty) 'fcfm': filterClassFieldMetadata,
      if (classConstructors) 'cc': true,
      if (filterClassConstructorParameterMetadata.isNotEmpty) 'fccpm': filterClassConstructorParameterMetadata,
      if (mergeClassFieldWithConstructorParameter) 'mcfwcp': true,
      if (inspectFieldInitializer) 'ifi': true,
      if (classMethods) 'cm': true,
      if (filterClassInstanceMethod) 'fcim': true,
      if (filterClassStaticMethod) 'fcsm': true,
      if (filterMethods.isNotEmpty) 'fm': filterMethods,
      if (filterClassMethodMetadata.isNotEmpty) 'fcmm': filterClassMethodMetadata,
      if (topLevelFunctions) 'tlf': true,
      if (collectClassSubTypes) 'ccst': true,
      if (filterCollectSubTypes.isNotEmpty) 'fccst': filterCollectSubTypes,
    };
  }

  @override
  String toString() {
    return 'MacroCapability{classFields: $classFields, filterClassInstanceFields: $filterClassInstanceFields, filterClassStaticFields: $filterClassStaticFields, filterClassIgnoreSetterOnly: $filterClassIgnoreSetterOnly, filterClassFieldMetadata: $filterClassFieldMetadata, classConstructors: $classConstructors, filterClassConstructorParameterMetadata: $filterClassConstructorParameterMetadata, mergeClassFieldWithConstructorParameter: $mergeClassFieldWithConstructorParameter, inspectFieldInitializer: $inspectFieldInitializer, classMethods: $classMethods, filterClassInstanceMethod: $filterClassInstanceMethod, filterClassStaticMethod: $filterClassStaticMethod, filterMethods: $filterMethods, filterClassMethodMetadata: $filterClassMethodMetadata, topLevelFunctions: $topLevelFunctions, collectClassSubTypes: $collectClassSubTypes, filterCollectSubTypes: $filterCollectSubTypes}';
  }
}

/// A function type for parsing global macro configuration from JSON.
///
/// Takes a JSON map and returns a [MacroGlobalConfig] instance, or null if parsing fails.
///
/// Example:
/// ```dart
/// MacroGlobalConfig? myConfigParser(Map<String, dynamic> json) {
///   return MyMacroConfig.fromJson(json);
/// }
/// ```
typedef MacroGlobalConfigParser = MacroGlobalConfig? Function(Map<String, dynamic> json);

/// A base class for macro global configuration.
///
/// Extend this class to create custom global configurations for your macros.
/// Global configurations allow you to define project-level settings that apply
/// across all uses of a macro, reducing repetition in individual annotations.
///
/// Example:
/// ```dart
/// class MyMacroConfig extends MacroGlobalConfig {
///   MyMacroConfig({required super.id, required this.asLiteral});
///
///   final bool asLiteral;
/// }
/// ```
abstract class MacroGlobalConfig {
  const MacroGlobalConfig();
}

/// Internal base class. Extend [MacroGenerator] to implement macros.
@internal
abstract class BaseMacroGenerator {
  const BaseMacroGenerator();

  String get suffixName;

  GeneratedType get generatedType;

  MacroGlobalConfigParser? get globalConfigParser;

  Future<void> init(MacroState state);

  Future<void> onClassTypeParameter(MacroState state, List<MacroProperty> typeParameters);

  Future<void> onClassFields(MacroState state, List<MacroProperty> classFields);

  Future<void> onClassConstructors(MacroState state, List<MacroClassConstructor> classConstructor);

  Future<void> onClassMethods(MacroState state, List<MacroMethod> executable);

  Future<void> onTopLevelFunctionTypeParameter(MacroState state, List<MacroProperty> typeParameters);

  Future<void> onTopLevelFunction(MacroState state, MacroMethod function);

  Future<void> onClassSubTypes(MacroState state, List<MacroClassDeclaration> subTypes);

  Future<void> onAsset(MacroState state, MacroAssetDeclaration asset);

  Future<void> onGenerate(MacroState state);
}
