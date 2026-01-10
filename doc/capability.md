# `MacroCapability` Documentation

`MacroCapability` defines what parts of a declaration should be collected and made available to a
macro during code generation. By enabling only the information you need, you reduce analysis cost
and improve runtime performance.

Each flag controls a specific capability, and some filters only apply when their parent capability
is enabled.

For example:

* `filterClassInstanceFields` applies **only if** `classFields == true`
* `filterMethods` applies **only if** `classMethods == true`

---

## Capabilities Overview (Table)

| Capability                                | Type     | Applies When                   | Description                                                                |
|-------------------------------------------|----------|--------------------------------|----------------------------------------------------------------------------|
| `classFields`                             | `bool`   | —                              | Collect all fields declared in the class.                                  |
| `filterClassInstanceFields`               | `bool`   | `classFields == true`          | Include only instance fields.                                              |
| `filterClassStaticFields`                 | `bool`   | `classFields == true`          | Include only static fields.                                                |
| `filterClassIgnoreSetterOnly`             | `bool`   | `classFields == true`          | Ignore “setter-only” virtual fields; include getters/setters/vars.         |
| `filterClassIncludeAnnotatedFieldOnly`    | `bool`   | `classFields == true`          | Include only annotated fields.                                             |
| `filterClassFieldMetadata`                | `String` | `classFields == true`          | Filter fields by metadata. Use `"*"` or comma-separated list.              |
| `classConstructors`                       | `bool`   | —                              | Collect all constructors declared in the class.                            |
| `filterClassConstructorParameterMetadata` | `String` | `classConstructors == true`    | Filter constructor parameters by metadata. `"*"` allowed.                  |
| `mergeClassFieldWithConstructorParameter` | `bool`   | `classConstructors == true`    | Merge field metadata with constructor parameter metadata.                  |
| `inspectFieldInitializer`                 | `bool`   | `classConstructors == true`    | Detect inferred field initializers from parent/super types. (Expensive)    |
| `classMethods`                            | `bool`   | —                              | Collect all methods declared in the class.                                 |
| `filterClassInstanceMethod`               | `bool`   | `classMethods == true`         | Include only instance methods.                                             |
| `filterClassStaticMethod`                 | `bool`   | `classMethods == true`         | Include only static methods.                                               |
| `filterClassIncludeAnnotatedMethodOnly`   | `bool`   | `classMethods == true`         | Include only annotated methods.                                            |
| `filterMethods`                           | `String` | `classMethods == true`         | Filter included methods (`"*"` or list: `build,toJson`)                    |
| `filterClassMethodMetadata`               | `String` | `classMethods == true`         | Filter methods by metadata. `"*"` allowed.                                 |
| `typeDefRecords`                          | `bool`   | —                              | Collect all typedef records declared in the library.                       |
| `topLevelFunctions`                       | `bool`   | —                              | Collect all functions declared in the library.                             |
| `collectClassSubTypes`                    | `bool`   | —                              | Collect all subclasses of this class (for polymorphic generation).         |
| `filterCollectSubTypes`                   | `String` | `collectClassSubTypes == true` | Controls *which classes* can collect subtypes (`sealed`, `abstract`, `*`). |

---

## Examples

### Enable only fields with metadata:

```dart

final cap = MacroCapability(
  classFields: true,
  filterClassFieldMetadata: 'JsonKey,MyMeta',
);
```

### Enable constructors + inferred initializers:

```dart

final cap = MacroCapability(
  classConstructors: true,
  inspectFieldInitializer: true,
);
```

### Collect all subclasses for a sealed base class:

```dart

final cap = MacroCapability(
  collectClassSubTypes: true,
  filterCollectSubTypes: 'sealed',
);
```