---
name: compute-macro
description: Use macro_kit ComputeMacro to execute Dart code at generation time and embed the result as a constant in generated .g.dart code. Use when asked to compute values at build/compile time, embed derived constants (versions, timestamps, dates, colors, build metadata, asset/config JSON), generate declarations from code, or when reading or writing compute()/@Macro(ComputeMacro()) usage in Dart projects using macro_kit. Covers modifiers, DartCode embedding, encode/decode, deps and caching, runner strategies, recipes, and gotchas.
---

# ComputeMacro

`ComputeMacro` runs Dart code once at generation time and materializes the result into a generated
top-level declaration in the `.g.dart` part file. Annotate a **top-level variable** initialized with
a `compute(...)` call; the body executes in an isolated process during generation and the result is
written as a constant — no manual committing of derived values, no separate build step.

> Constraint: top-level variables only (not classes, fields, or methods).

## Registration

In the project's `lib/macro_context.dart`:

```dart
Future<void> setupMacro() async {
  await runMacro(
    package: PackageInfo('<package_name>'),
    autoRunMacro: autoRunMacro,
    enabled: true,
    macros: {
      'ComputeMacro': ComputeMacro.initialize, // add alongside other macros
    },
  );
}
```

With the macro_kit analyzer plugin installed and initialized, creating an empty
`lib/macro_context.dart` auto-populates it with this boilerplate; otherwise provide it manually.
The file must then be wired into the app entry point:

```dart
import 'package:<package_name>/macro_context.dart' as macro;

void main() async {
  await macro.setupMacro();
  // ... app startup
}
```

- `autoRunMacro = true` (default): `macro_context.dart` runs automatically in a separate background
  process that generates code on save — nothing to invoke manually.
- `autoRunMacro = false` (debug mode): generation runs inside the app when `setupMacro()` executes
  in `main()`, enabling breakpoint debugging of macros. Requires a desktop environment
  (macOS/Windows/Linux); generating inside Flutter running on mobile/web is not supported.

The source file needs a `part '<file>.g.dart';` directive and imports
`package:macro_kit/macro_kit.dart`. Add `// ignore_for_file: unused_element` if the sentinel
variables would trip lints.

## Basic usage

```dart

@Macro(ComputeMacro())
final _versionMacro = compute(() => '1.0.0');
```

Generates:

```dart

const version = '1.0.0';
```

Shorthand annotation also works: `@computeMacro`.

### Generated name derivation

| Annotated name     | Generated name | Rule                      |
|--------------------|----------------|---------------------------|
| `_versionMacro`    | `version`      | leading `_` removed       |
| `_appVersionMacro` | `appVersion`   | trailing `Macro` removed  |
| `counterMacro`     | `counter`      | underscore not required   |
| `_secretMacro`     | `_secret`      | with `isPrivate` modifier |

## Output modifiers (`ComputeModifier`)

Default output is `const`.

```dart
// final — required when the value can't be const (e.g., DateTime.parse(...))
@Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true)))
final _nowMacro = compute(() => DateTime.now().toString());

// var — rebuildable placeholder on every regeneration
@Macro(ComputeMacro(modifier: ComputeModifier(isVar: true)))
final _mutableMacro = compute(() => 'rebuildable');

// private generated name
@Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true, isPrivate: true)))
final _secretMacro = compute(() => 'hidden');
```

| Option          | Effect                                                                                |
|-----------------|---------------------------------------------------------------------------------------|
| `isFinal`       | generates `final name = value;`                                                       |
| `isVar`         | generates `var name = value;`                                                         |
| `isPrivate`     | prefixes generated name with `_`                                                      |
| `isDeclaration` | embeds result verbatim as raw top-level declarations (see below); other flags ignored |

## Serialization modes

1. **Automatic** (default): value must be sendable across an isolate boundary — primitives
   (`String`, `int`, `double`, `bool`, `null`), `List`s, and `Map`s of sendable values are written
   as Dart literals.
2. **Raw expression via `DartCode`**: embeds the returned string verbatim — for types that don't
   exist at generation time or aren't serializable:
   ```dart
   @Macro(ComputeMacro())
   final _colorMacro = compute<DartCode>(
     () => DartCode('Color(0xFF${123.toRadixString(16).padLeft(6, '0')})'),
   );
   // Generates: const color = Color(0xFF00007B);
   ```
3. **Whole declarations**: return `DartCode` with `ComputeModifier(isDeclaration: true)` to emit
   classes/enums/mixins/extensions/typedefs/top-level functions directly into the `.g.dart`
   (no wrapping variable):
   ```dart
   @Macro(ComputeMacro(modifier: ComputeModifier(isDeclaration: true)))
   final _userModelMacro = compute<DartCode>(
     () => DartCode('class UserModel { final String name; const UserModel(this.name); }'),
   );
   ```
4. **Custom `encode`/`decode`**: convert non-serializable runtime values to a Dart expression
   string:
   ```dart
   @Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true)))
   final _dateMacro = compute(
     () => DateTime.now(),
     encode: (v) => v.toIso8601String(),
     decode: (v) => "DateTime.parse('$v')",
   );
   ```

Both callbacks run inside the temp execution file.

## Dependencies & incremental caching

Each generated variable stores a hash constant (e.g. `const _versionMacroHash = 2953536757;`).
Unchanged hashes are never re-executed.

- **Without `deps`:** the whole source file is hashed — any edit re-executes.
- **With identifier `deps`:** only changes to the compute body or listed identifiers re-execute:
  ```dart
  @Macro(ComputeMacro())
  final _resultMacro = compute(() => helper.process(config), deps: [config, helper]);
  ```
- **File `deps`:** strings containing `/` are file paths (relative to project root); any change to
  tracked file content forces re-execution:
  ```dart
  @Macro(ComputeMacro())
  final _appConfigMacro = compute(
    () => jsonDecode(File('assets/config.json').readAsStringSync()),
    deps: ['assets/config.json'],
  );
  ```
  Strings without `/` are rejected with a warning. Dependency files are hashed at generation time;
  they are not watched live. Bodies run with the project root as working directory, so relative
  `File(...)` paths resolve from there.
- **Build once:** `deps: macroBuildOnce` executes exactly once and caches permanently across normal
  saves — ideal for random/expensive values:
  ```dart
  @Macro(ComputeMacro())
  final _randomNumberMacro = compute(() => Random().nextInt(1000), deps: macroBuildOnce);
  ```
- **Forced rebuilds** bypass all caching (including `macroBuildOnce`): when
  `"always_rebuild_on_connect": true` is set in `macro.json`, or via CLI `macro rebuild [target]`
  (no target = every registered context). Use `macro rebuild` in CI so other tools consume freshly
  written `.g.dart` files.

## Execution strategies

Compute bodies execute in a temp copy of the source file (same directory) with cwd set to the
project root; code generated by other macros in the same file is inlined, so bodies may reference
generated types (e.g., data class mixins). Force a strategy with a comment at the top of the file:

| Comment                    | Strategy                                                      |
|----------------------------|---------------------------------------------------------------|
| `// macro-runner: isolate` | Pure Dart isolate via `Isolate.spawnUri` (no Flutter imports) |
| `// macro-runner: dart`    | Dart VM via `dart run <tempFile>`                             |
| `// macro-runner: flutter` | Flutter test runner via `flutter test <tempFile>`             |

Default matches the project type: `flutter test` for Flutter projects, `dart run` otherwise.

## Recipes

- Version/build constants: read `pubspec.yaml`/env inside `compute(() => ...)` and embed as `const`.
- Flutter colors: `encode`/`decode` or `DartCode` (see Serialization modes, mode 2).
- Asset JSON → const map: `jsonDecode(File(...).readAsStringSync())` + matching file `dep`.
- Non-deterministic values (timestamps/random): decide between `macroBuildOnce`, `isVar`, or
  intentional re-execution via `deps`.

## Gotchas

- Top-level variables only; annotate the sentinel variable, reference the derived generated name.
- Values crossing isolate boundaries must be sendable — otherwise use `DartCode`,
  `encode`/`decode`, or `isDeclaration`.
- Non-const results need `isFinal` (or `isVar`) — plain `const` generation will fail otherwise.
- Cached values stay stable across saves; edits outside `deps` don't re-run when `deps` is present;
  use forced rebuilds (`macro rebuild`) to refresh everything deliberately.
- Generation happens on save/watch/connect/rebuild; ensure `macro_context.dart` is registered and
  the plugin configured before expecting `.g.dart` output.
