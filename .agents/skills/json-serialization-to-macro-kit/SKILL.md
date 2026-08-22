---
name: json-serialization-to-macro-kit
description: Migrate Dart JSON serialization from json_serializable/build_runner to macro_kit DataClassMacro. Use when converting a Dart/Flutter project away from build_runner codegen, removing json_serializable/json_annotation dependencies, replacing @JsonSerializable/@JsonKey annotations, or switching to instant macro-based generation. Covers setup, per-class conversion, config mapping, enum/converter handling, cleanup, and verification.
---

# Migrate json_serializable → macro_kit

Convert classes using `package:json_serializable` + `build_runner` to macro_kit's `DataClassMacro`
(`@dataClassMacro`), which generates `fromJson`/`toJson` — plus equality, `copyWith`, `toString`,
and sealed-class `map`/`mapOrNull`/casts — instantly on save into the same `.g.dart` part files,
with no build step. The first generation initializes the analyzer and takes ~3–5 seconds depending
on project size; later generations finish under 100ms most of the time.

Requires Dart SDK `>=3.10.0`. Generated source must live under `lib/`.

## 1. Audit first

Search the target package and inventory every feature in use before converting:

- Annotations: `@JsonSerializable`, `@JsonKey`, `@JsonEnum`, `@JsonValue`, `@JsonConverter`
- Imports: `package:json_annotation/*`, `part '*.g.dart'` with `_$XFromJson` / `_$XToJson` helpers
- Config: `build.yaml` (codegen options), pubspec deps `build_runner`, `json_serializable`,
  `json_annotation`
- CI/scripts running `dart run build_runner build --delete-conflicting-outputs`

Map each finding using the tables below, then convert file-by-file.

## 2. One-time setup

1. Activate the CLI globally: `dart pub global activate macro_kit` (deactivate + reactivate when
   updating).
2. Add the dependency:
   ```yaml
   # pubspec.yaml
   dependencies:
     macro_kit: ^latest_version
   ```
3. Enable the analyzer plugin:
   ```yaml
   # analysis_options.yaml
   plugins:
     macro_kit: ^latest_version
   ```
4. Create `lib/macro_context.dart`. With the plugin installed and initialized, create an empty
   file — it is automatically populated with the default boilerplate and inline documentation.
   Alternatively, provide it manually like the flutter example does:
   ```dart
   import 'dart:async';

   import 'package:macro_kit/macro_kit.dart';

   bool get autoRunMacro => true;

   List<String> get autoRunMacroCommand => macroDartRunnerCommand; // pure Dart; use
   // macroFlutterRunnerCommand if macros depend on Flutter SDK

   void main() async {
     await setupMacro();
     await keepMacroRunner();
   }

   Future<void> setupMacro() async {
     await runMacro(
       package: PackageInfo('<package_name>'), // must match pubspec name
       autoRunMacro: autoRunMacro,
       enabled: true,
       macros: {
         'DataClassMacro': DataClassMacro.initialize,
       },
     );
   }
   ```
5. Import `macro_context.dart` in the app entry point and call `setupMacro()` from `main()`:
   ```dart
   import 'package:<package_name>/macro_context.dart' as macro;

   void main() async {
     await macro.setupMacro();
     runApp(MyApp()); // rest of app startup
   }
   ```
6. Optional project-wide config via `macro.json` at the project root (see Global config mapping).
   For IDE autocompletion/validation of `macro.json`, point the IDE at the JSON schema shipped at
   the macro_kit repo root (`/Volumes/Projects/Server/swiftybase/macro/macro_schema.json`) — also
   available on SchemaStore or at
   `https://raw.githubusercontent.com/rebaz94/macro_kit/refs/heads/main/macro_schema.json`.

**How `autoRunMacro` drives generation:**

- `true` (default): `macro_context.dart` runs automatically in a separate background process whose
  sole purpose is generating code. Nothing needs to be invoked manually.
- `false` (debug mode): generation happens inside the running Dart/Flutter app when
  `macro.setupMacro()` executes in `main()`. Use this to debug your own or existing macros with
  breakpoints. Debugging requires a desktop environment (macOS/Windows/Linux) so generation works
  as expected — running Flutter on mobile devices/web is not supported for generation.

## 3. Convert each class

Before (json_serializable):

```dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  User({required this.id, required this.name});

  @JsonKey(name: 'user_name')
  final String name;
  final int id;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```

After (macro_kit):

```dart
import 'package:macro_kit/macro_kit.dart';

part 'user.g.dart'; // keep the part directive — macro_kit writes this file

@dataClassMacro
class User with UserData {
  User({required this.id, required this.name});

  @JsonKey(name: 'user_name')
  final String name;
  final int id;
}
```

Rules:

1. Replace `@JsonSerializable()` with `@dataClassMacro` (shorthand) or
   `@Macro(DataClassMacro(...))`.
2. **Add the mixin** `with {ClassName}Data` — it is never generated onto the class automatically.
3. Delete manual factory delegates (`factory User.fromJson(...) => _$UserFromJson(json)`) and
   `toJson()` delegating to `_$UserToJson(this)`, plus any top-level `_$*` helpers.
4. Keep `part 'user.g.dart';`.
5. Update call sites: `User.fromJson(x)` → `UserData.fromJson(x)` (the static lives on the
   generated mixin). Instance calls like `user.toJson()` / `.copyWith()` stay unchanged.

## 4. `@JsonKey` mapping

macro_kit ships its own `@JsonKey` (from `package:macro_kit/macro_kit.dart`) with identical
semantics for most parameters:

| json_annotation `@JsonKey`            | macro_kit `@JsonKey`                                                                                        |
|---------------------------------------|-------------------------------------------------------------------------------------------------------------|
| `name:`                               | ✅ same                                                                                                      |
| `defaultValue:`                       | ✅ same (also accepts static functions/const constructors)                                                   |
| `fromJson:` / `toJson:`               | ✅ same (top-level/static functions, factories; generics OK)                                                 |
| `includeIfNull:`                      | ✅ same                                                                                                      |
| `includeFromJson:` / `includeToJson:` | ✅ same                                                                                                      |
| `readValue:`                          | ✅ same                                                                                                      |
| `unknownEnumValue:`                   | ✅ but wrap value: `EnumValue(MyEnum.unknown)`; multiple enum types in one generic: `EnumValue.of([e1, e2])` |
| `disallowNullValue:`                  | ❌ unsupported                                                                                               |
| `required:`                           | ❌ unsupported (use constructor `required` or `defaultValue`)                                                |
| `@JsonConverter(...)`                 | inline as `fromJson:` / `toJson:` on the field                                                              |
| —                                     | extras: `asLiteral:` (pass-through type), `copyWithAsOption:`, `asRequired:`                                |

External/unserializable types work via converters, including external statics/factories:

```dart
@JsonKey(fromJson: ExternalModel.fromJson, toJson: externalModelToJson)
final ExternalModel model;
```

## 5. Global config mapping (`build.yaml` → `macro.json`)

Put options under `"macros"` → `"DataClassMacro"` in `macro.json` at the project root:

| json_serializable option                                                | macro.json key                                                                                                                             |
|-------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| `fieldRename: FieldRename.snake`                                        | `"field_rename": "snake_case"` (`none` default, also `kebab_case`, `pascal_case`) — global only; override per field with `@JsonKey(name:)` |
| `includeIfNull: true`                                                   | `"include_if_null": true`                                                                                                                  |
| method naming (`fromJson/toJson` vs `fromMap/toMap`)                    | `"use_map_convention": true` switches to fromMap/toMap                                                                                     |
| `createFactory: false`                                                  | per-class `@Macro(DataClassMacro(fromJson: false))`                                                                                        |
| `createToJson: false`                                                   | per-class `@Macro(DataClassMacro(toJson: false))`                                                                                          |
| `explicitToJson`                                                        | not needed — nested serialization is automatic                                                                                             |
| `genericArgumentFactories`                                              | not needed — generics handled automatically                                                                                                |
| `anyMap`, `checked`, `disallowUnrecognizedKeys`, `createFieldMap`, etc. | ❌ unsupported                                                                                                                              |

Example `macro.json`:

```json
{
  "config": {
    "auto_rebuild_on_connect": true,
    "always_rebuild_on_connect": false
  },
  "macros": {
    "DataClassMacro": {
      "field_rename": "snake_case",
      "include_if_null": false,
      "as_literal_types": [
        "GeoPoint",
        "Timestamp"
      ],
      "use_map_convention": false
    }
  }
}
```

## 6. Behavioral differences & gotchas

- ⚠️ **`include_if_null` defaults to `false`** in macro_kit (json_serializable defaults to `true`):
  null fields are omitted from `toJson()` output unless you set `"include_if_null": true` globally
  or `@JsonKey(includeIfNull: true)` per field. Verify wire-format expectations after migration.
- Enums encode/decode by `.name` by default — same as json_serializable's default, so no change.
  For `@JsonEnum(valueField:)` / `@JsonValue(...)` custom values, write converter functions and use
  `@JsonKey(fromJson:, toJson:)`. Unknown-value fallback uses
  `@JsonKey(unknownEnumValue: EnumValue(...))`.
- `DateTime` is handled automatically (ISO-8601 strings plus numeric epoch values).
- Records (`(String, {int x})`) are supported as field types.
- Sealed/abstract hierarchies gain polymorphic deserialization (not available in json_serializable):
  `discriminatorKey`, `discriminatorValue` (primitive or `bool Function(Map)` matcher),
  `includeDiscriminator`, `defaultDiscriminator`; generates `map`/`mapOrNull`/`asX()` casts.
- Free bonuses beyond json codegen: `==`/`hashCode`, `copyWith` (opt-in `copyWithAsOption` for
  explicit nulls), `toString`.
- If a field type can't be mapped, generation errors point at the field — resolve with
  `@JsonKey(fromJson:/toJson:/asLiteral:)`.

## 7. Cleanup checklist

- pubspec: remove `build_runner` (dev), `json_serializable` (dev); remove `json_annotation` only
  after all its imports are gone (`@JsonKey` now comes from `macro_kit`).
- Delete `build.yaml`.
- CI: replace `dart run build_runner build --delete-conflicting-outputs` with:
  ```bash
  dart pub global activate macro_kit
  macro rebuild [target]   # regenerates every registered context without a target
  ```
  Use `"always_rebuild_on_connect": true` in `macro.json` when relying on server-connect flows.
- Remove stale `.g.dart` files only where codegen was removed entirely (keep parts still used).
- Ensure converted sources live under `lib/`.

## 8. Verify

1. Trigger generation without running anything manually: keep `autoRunMacro = true` so the
   background process regenerates on save, or (debug mode) run the app on desktop with
   `await macro.setupMacro()` in `main()`. Then save a converted file in the IDE.
   Alternatively, force a full regeneration from the terminal with `macro rebuild [target]`
   (no target = every registered context), then check the output.
2. Confirm `<file>.g.dart` now contains `mixin <ClassName>Data` implementations.
3. Analyzer and test suite pass.
4. No leftovers: search for `json_annotation`, `_\$.*FromJson`, `_\$.*ToJson`, `build_runner` —
   zero hits expected.
5. Spot-check round-trips (`expect(XData.fromJson(x.toJson()), x)`) and null-inclusion behavior in
   serialized output against the pre-migration format.
