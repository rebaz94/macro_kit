# Macro Kit Documentation

A comprehensive guide to creating and using macros in Dart with macro_kit.

## Table of Contents

1. [Introduction](#introduction)
2. [Creating a Macro Generator](#creating-a-macro-generator)
3. [Understanding Macro Capabilities](#understanding-macro-capabilities)
4. [Working with Macro Data](#working-with-macro-data)
5. [Code Generation](#code-generation)

---

## Introduction

Macro Kit enables you to generate code based on class annotations. There are two types of macros:

1. **Regular macros** - Applied to Dart code (classes, methods, etc.)
2. **Asset macros** - Applied to asset directories or files

This guide focuses on regular macros that generate code from annotated classes.

---

## Creating a Macro Generator

### Step 1: Define Your Macro Capability

First, determine what information your macro needs from the annotated class. This is done through
`MacroCapability`, which specifies what data to collect during analysis.

```dart

const dataClassMacroCapability = MacroCapability(
  classFields: true,
  filterClassInstanceFields: true,
  classConstructors: true,
);
```

### Step 2: Create Your Macro Class

Create a class that extends `MacroGenerator` and set the default capability:

```dart
class DataClassMacro extends MacroGenerator {
  const DataClassMacro({
    super.capability = dataClassMacroCapability,
    this.fromJson,
    this.toJson,
  });

  final bool? fromJson;
  final bool? toJson;
}
```

**Important:** Your macro class name must end with the suffix `Macro`.

### Step 3: Implement the Initialize Method

Create a static `initialize` method that maps configuration properties to your macro instance:

```dart
class DataClassMacro extends MacroGenerator {
  const DataClassMacro({
    super.capability = dataClassMacroCapability,
    this.fromJson,
    this.toJson,
  });

  final bool? fromJson;
  final bool? toJson;

  static DataClassMacro initialize(MacroConfig config) {
    final key = config.key;
    final props = Map.fromEntries(
        key.properties.map((e) => MapEntry(e.name, e))
    );

    return DataClassMacro(
      capability: config.capability,
      fromJson: props['fromJson']?.asBoolConstantValue(),
      toJson: props['toJson']?.asBoolConstantValue(),
    );
  }
}
```

**Helper methods for property mapping:**

- `asBoolConstantValue()` - Extract boolean values
- `asIntConstantValue()` - Extract integer values
- `asStringConstantValue()` - Extract string values
- `asDoubleConstantValue()` - Extract double values
- `asTypeValue()` - Extract type references

### Step 4: Usage

Users can now annotate classes with your macro:

```dart
@Macro(DataClassMacro())
class User with UserData {
  final String name;
  final int age;
}
```

**Recommended:** Create a constant for easier usage:

```dart

const dataClassMacro = Macro(DataClassMacro());

@dataClassMacro
class User with UserData {
  final String name;
  final int age;
}
```

### Step 5: Implement Code Generation

Implement the required methods in your `MacroGenerator`:

```dart
class DataClassMacro extends MacroGenerator {
  // ... previous code ...

  @override
  String get suffixName => 'Data';

  @override
  GeneratedType get generatedType => GeneratedType.mixin;

  @override
  void init(MacroState state) {
    // Optional: Perform any initialization work
  }

  @override
  void onClassFields(MacroState state, List<MacroProperty> fields) {
    // Process class fields and store in state if needed
    state.setData('fields', fields);
  }

  @override
  void onGenerate(MacroState state) {
    final fields = state.getData<List<MacroProperty>>('fields');
    final suffix = state.suffixName; // use the provided suffix to support combing code

    final code = StringBuffer();
    code.writeln('mixin ${state.className}$suffix {');

    // Generate your code here

    code.writeln('}');

    state.reportGeneratedCode(code.toString());
  }
}
```

**Key properties and methods:**

- `suffixName` - The suffix appended to the class name (e.g., `Data` → `UserData`).
- `generatedType` - The type of code being generated (mixin, class, abstract class, etc.).
- `init()` - Optional setup method called before generation.
- `onClassTypeParameter()` - Called when the target class has type parameters.
- `onClassFields()` - Called when class fields are collected.
- `onClassConstructors()` - Called when constructors are collected.
- `onClassMethods()` - Called when methods are collected.
- `onClassSubTypes()` - Called with all subtypes of the target class in the library.
- `onTopLevelFunctionTypeParameter()` - Called when the target function has type parameters.
- `onTopLevelFunction()` - Called when the target function is a top level function.
- `onAsset()` - Called when a monitored asset file changes in configured directories.
- `onGenerate()` - Final method where you generate and report code.

---

## Understanding Macro Capabilities

`MacroCapability` controls what information gets collected from annotated classes. This improves
performance by only analyzing what's needed.

See in details: [Macro Capability](./capability.md)

## Working with Macro Data

### MacroProperty

`MacroProperty` represents a field, parameter, return type, or type reference with comprehensive
metadata.

#### Basic Properties

```dart
class MacroProperty {
  final String name; // Property name
  final String importPrefix; // Import prefix (empty if none)
  final String type; // Dart type as string (e.g., 'String', 'List<int>')
  final TypeInfo typeInfo; // Type category (class, enum, primitive, etc.)
  final MacroModifier modifier; // Modifiers (final, late, nullable, etc.)
}
```

#### Type Information

The `typeInfo` field indicates the category of type:

- `TypeInfo.int`, `TypeInfo.string`, `TypeInfo.boolean` - Primitives
- `TypeInfo.list`, `TypeInfo.set`, `TypeInfo.map` - Collections
- `TypeInfo.clazz` - Custom classes
- `TypeInfo.enumData` - Enums
- `TypeInfo.function` - Function types
- `TypeInfo.generic` - Generic type parameters
- `TypeInfo.dynamic` - Dynamic type

#### Working with Types

```dart
// Get fully qualified type with import prefix
String dartType = property.getDartType('_i.'); // e.g., '_i.String'

// Check nullability
bool nullable = property.isNullable;

// Convert to nullable/non-nullable
MacroProperty nullableVersion = property.toNullability(intoNullable: true);

// Check if static
bool isStatic = property.isStatic;
```

#### Type Arguments (Generics)

```dart
// For List<String>
final typeArgs = property.typeArguments; // [MacroProperty(name: '', type: 'String')]

// For Map<String, int>
final keyType = property.typeArguments?.firstOrNull; // String
final valueType = property.typeArguments?.elementAtOrNull(1); // int
```

#### Constant Values

For compile-time constants:

```dart
// Extract constant values
bool? boolValue = property.asBoolConstantValue();
String? stringValue = property.asStringConstantValue();
int? intValue = property.asIntConstantValue();
double? doubleValue = property.asDoubleConstantValue();

// Convert to Dart literal
String? literal = property.constantValueToDartLiteralIfNeeded;
```

#### Macro Keys

```dart
// Access macro keys
List<MacroKey>? keys = property.keys;

// Cache and retrieve key values
String name = property.cacheFirstKeyInto<String>(
  keyName: 'name',
  convertFn: (key) => key.name,
  defaultValue: property.name,
);
```

## Code Generation

### The Generation Lifecycle

When a macro is applied to a class, the following lifecycle occurs:

1. **Initialization** - `init()` is called
2. **Data Collection** - Based on capability:
    - `onClassFields()` - If `classFields: true`
    - `onClassConstructors()` - If `classConstructors: true`
    - `onClassMethods()` - If `classMethods: true`
3. **Code Generation** - `onGenerate()` is called
4. **Code Reporting** - `state.reportGeneratedCode()` emits the generated code

### Using MacroState

`MacroState` is your workspace for storing temporary data and generating code:

**Example workflow:**

```dart
@override
void onClassFields(MacroState state, List<MacroProperty> fields) {
  // Store fields for later use
  state.setData('fields', fields);

  // Process and store additional data
  final jsonFields = fields.where((f) => !f.modifier.isStatic).toList();
  state.setData('jsonFields', jsonFields);
}

@override
void onGenerate(MacroState state) {
  final fields = state.getData<List<MacroProperty>>('fields')!;
  final jsonFields = state.getData<List<MacroProperty>>('jsonFields')!;

  final code = generateCode(state.className, fields, jsonFields);
  state.reportGeneratedCode(code);
}
```

## Code Generation & Multi-Macro Combination

Multiple macros may target the same class. The framework merges their **capabilities**, **collected
data**, and **generated output** according to the rules below. This ensures macros—whether from your
package or from different authors—can interact safely without overwriting each other’s output.

### 🔹 How Capabilities Combine Across Macros

When a class has multiple annotations:

```dart
@FirstMacro()
@SecondMacro()
class User {}
```

Each macro declares its own `MacroCapability`.

Before lifecycle execution begins, the framework merges all capabilities and still receives **only
the parts it declared** in its own capability.

---

## 🔹 Code Generation Modes

Macros may generate:

* A full wrapper class/mixin
* Only method bodies
* Both
* Nothing (analysis-only macro)

To allow combining output from multiple macros, macros must respect the generation mode.

### #### `MacroState.isCombiningGenerator`

When multiple macros are applied to the same type, the framework enters **combining mode**, meaning:

* You **must not** output a full class/mixin wrapper.
* You **must only** output members (methods, getters, fields, utility functions).

Example:

```dart
class DataClassMacro extends MacroGenerator {
  Future<void> onGenerate(MacroState state) async {
    if (state.isCombiningGenerator) {
      // Only generate members like:
    }
  }
}
```

---

## 🔹 `canBeCombined` – Opt-in/Out of Multi-Macro Combination

When reporting generated code:

```dart
class DataClassMacro extends MacroGenerator {
  Future<void> onGenerate(MacroState state) async {
    // your code here
    state.reportGenerated(generatedCode, canBeCombined: true);
  }
}
```

### If your macro **can** combine with others:

* Set `canBeCombined: true`
* Generate *only* members when `isCombiningGenerator == true`
* Generate wrappers when `isCombiningGenerator == false`

### If your macro **cannot** combine:

Set: `canBeCombined` to `false`

This ensures:

* Your macro runs **alone**
* No other macro is allowed to generate combined output
* The file will contain a complete wrapper

This is required for macros that:

* Produce a new type that must remain unique
* Perform structural rewrites
* Emit code where combining would compromise correctness
* Require positional ordering of members

# Generated Type Resolution

`generatedType` plays a key role in deciding whether macros’ outputs are merged or emitted
separately.

### Rules

1. **Same `generatedType` + all macros allow combining (`canBeCombined: true`) → Merge**

    * If two (or more) macros specify the *same* `generatedType` and each reported
      `canBeCombined: true`, the framework will aggregate their generated members and place them
      into a **single** generated type with that name (class, mixin, or extension as appropriate).
    * This is how multiple macros can collaboratively augment the same generated artifact (for
      example, the same `mixin UserData`).

2. **Different `generatedType` + all macros allow combining → Emit separate generated types**

    * If macros target **different** `generatedType` like mixin vs class but both permit combining,
      the build system **does not merge** them because
      they target different artifacts. Instead, each macro’s output becomes its own generated type.
    * This covers cases where one macro wants a mixin and another wants a concrete class; both may
      be placed in the same generated file, but they are kept as separate types and are not merged.

3. **If any macro sets `canBeCombined: false` → Exclusive ownership**

    * A macro that reports `canBeCombined: false` becomes the exclusive generator for the generated
      types it creates. Other macros that would otherwise combine are prevented from merging into
      that generated type;

### Building Type References

When generating code, use `getDartType()` to build proper type references:

```dart
String buildFieldCode(MacroProperty field, String dartCorePrefix) {
  final type = field.getDartType(dartCorePrefix);
  final name = field.name;

  if (field.modifier.isFinal) {
    return 'final $type $name;';
  } else {
    return '$type $name;';
  }
}
```

### Working with Generics

```dart
void generateGenericClass(MacroClassDeclaration declaration) {
  final typeParams = declaration.classTypeParameters ?? [];

  // Get type parameter list: <T, E>
  final typeParamStr = MacroProperty.getClassTypeParameter(typeParams);

  // Get with bounds: <T extends Object, E extends String>
  final typeParamWithBound = MacroProperty.getClassTypeParameterWithBound(typeParams);

  final code = '''
class ${declaration.className}Data$typeParamWithBound {
  // Generated code here
}
''';
}
```

### Handling Field Initializers

When a constructor parameter initializes a field:

```dart
void processConstructor(MacroClassConstructor constructor) {
  for (final param in constructor.params) {
    // Get the actual field being initialized
    final field = param.getTopFieldInitializer();

    if (field != null) {
      print('Parameter ${param.name} initializes field ${field.name}');
      print('Field type: ${field.type}');
    }
  }
}
```

### Converting Constants to Literals

When you need to output constant values as Dart code:

```dart

String classLiteral = MacroProperty.toLiteralValue(constantValue);

// Direct conversion for simple type
String? dartLiteral = property.constantValueToDartLiteralIfNeeded;
```

### Performance Considerations

1. **Request only what you need** - Use specific capability filters to minimize analysis
2. **Avoid `inspectFieldInitializer`** - This is an expensive operation; use only when necessary
3. **Cache computed values** - Use `MacroState.set()` to avoid recomputing
4. **Use `cacheFirstKeyInto()`** - Cache key lookups for repeated access

### Error Handling

Always validate your inputs:

```dart
@override
void onGenerate(MacroState state) {
  final fields = state.getData<List<MacroProperty>>('fields');

  if (fields == null || fields.isEmpty) {
    // No fields to process, generate empty implementation or skip
    state.reportGeneratedCode('');
    return;
  }

  // Continue with generation
}
```

<p align="right"><a href="../topics/Capability-topic.html">Next: Capability</a></p>