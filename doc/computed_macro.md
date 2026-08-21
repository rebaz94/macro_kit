## ComputeMacro

`ComputeMacro` is a macro that executes Dart code at compile time and materializes the result into a
generated top-level variable. Annotate a top-level variable initialized with a `compute(...)` call,
and the macro runs the function body in an isolated process during generation, then writes the
result directly into the generated `.g.dart` file as a constant.

This makes it possible to derive constants from arbitrary Dart code—string manipulation, date
math, build metadata, random values—without committing generated values by hand or running a build
step separately.

> [!IMPORTANT]
> `ComputeMacro` currently supports **top-level variables only**.

## Features

* ✅ **Compile-Time Execution**: Runs your compute body once at generation time and embeds the result
* ✅ **Automatic Serialization**: Primitives, lists, and maps are serialized to Dart literals without
  extra configuration
* ✅ **Raw Code Embedding**: Use `DartCode` to inject arbitrary Dart expressions into generated code
* ✅ **Custom Serialization**: Convert any runtime value with `encode`/`decode` callbacks
* ✅ **Incremental Caching**: Results are cached and only recomputed when the body or declared
  dependencies change
* ✅ **Flexible Output**: Generate `const`, `final`, or `var` declarations with optional private names

## Setup

Register the macro in your `macro_context.dart` file:

```dart
Future<void> setupMacro() async {
  await runMacro(
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
      'ComputeMacro': ComputeMacro.initialize,
      // Add more macros here
    },
  );
}
```

## Basic Usage

Annotate a top-level variable whose initializer is a `compute(...)` call:

```dart
@Macro(ComputeMacro())
final _versionMacro = compute(() => '1.0.0');
```

Generates:

```dart
const version = '1.0.0';
```

The shorthand annotation works as well:

```dart
@computeMacro
final _versionMacro = compute(() => '1.0.0');
```

### Generated Name Derivation

The generated variable name is derived from the annotated variable name:

| Annotated Name       | Generated Name | Rule                          |
|----------------------|----------------|-------------------------------|
| `_versionMacro`      | `version`      | Leading `_` removed           |
| `_appVersionMacro`   | `appVersion`   | Trailing `Macro` removed      |
| `counterMacro`       | `counter`      | Underscore not required       |
| `_secretMacro`       | `_secret`      | With `isPrivate` modifier     |

## Generated Declaration Modifiers

By default a `const` declaration is generated. Use `ComputeModifier` to change the output:

```dart
// Default: const
@Macro(ComputeMacro())
final _versionMacro = compute(() => '1.0.0');
// Generates: const version = '1.0.0';

// Explicit final — required when the value can't be const
@Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true)))
final _nowMacro = compute(() => DateTime.now().toString());
// Generates: final now = '...';

// var — rebuildable on every regeneration
@Macro(ComputeMacro(modifier: ComputeModifier(isVar: true)))
final _mutableMacro = compute(() => 'rebuildable');
// Generates: var mutable = '...';

// Private name + final
@Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true, isPrivate: true)))
final _secretMacro = compute(() => 'hidden');
// Generates: final _secret = 'hidden';
```

### `ComputeModifier` Options

| Option      | Type    | Default | Description                                    |
|-------------|---------|---------|------------------------------------------------|
| `isFinal`   | `bool`  | `false` | Generates `final name = value;`                |
| `isVar`     | `bool`  | `false` | Generates `var name = value;`                  |
| `isPrivate` | `bool`  | `false` | Prefixes the generated name with `_`           |

When no keyword flag is set, `const` is generated.

## Serialization

### Automatic Serialization

When no options are provided, the computed value must be sendable across an isolate boundary.
Primitives (`String`, `int`, `double`, `bool`, `null`), `List`s, and `Map`s of sendable values are
serialized automatically:

```dart
@Macro(ComputeMacro())
final _listValMacro = compute(() => [1, 2, 3]);
// Generates: const listVal = [1, 2, 3];
```

### Raw Code with `DartCode`

To embed raw Dart source instead of a literal value, return a `DartCode`. The expression is copied
into the generated code verbatim—useful for types that don't exist at generation time or can't be
serialized (e.g., Flutter's `Color`):

```dart
@Macro(ComputeMacro())
final _colorMacro = compute<DartCode>(
  () => DartCode('Color(0xFF${123.toRadixString(16).padLeft(6, '0')})'),
);
// Generates: const color = Color(0xFF00007B);
```

### Custom Serialization with `encode`/`decode`

For runtime values that aren't automatically serializable (e.g., `DateTime`, enums), provide an
`encode` callback that converts the value to a string, and optionally a `decode` callback that turns
the encoded string back into a Dart expression:

```dart
@Macro(ComputeMacro(modifier: ComputeModifier(isFinal: true)))
final _dateMacro = compute(
  () => DateTime.now(),
  encode: (v) => v.toIso8601String(),
  decode: (v) => "DateTime.parse('$v')",
);
// Generates something like:
// final date = DateTime.parse('2026-08-21T10:30:00.000');
```

Both callbacks run inside the temp execution file; the generator receives the final Dart expression.

## Dependencies & Incremental Caching

Every generated variable stores a hash constant next to its value, e.g.
`const _versionMacroHash = 2953536757;`. On regeneration, stored hashes are compared against fresh
hashes so unchanged values are never re-executed—results stay stable across saves.

### Without `deps`

The entire source file content is hashed. Any edit in the file triggers re-execution.

### With `deps`

Only changes to the compute body itself or to the listed dependencies trigger re-execution:

```dart
final config = Config.parse('...');
final helper = Helper();

@Macro(ComputeMacro())
final _resultMacro = compute(
  () => helper.process(config),
  deps: [config, helper], // only rebuild when these change
);
```

Dependencies may reference same-file variables, functions, or identifiers imported from other files.

### Build Once

Use the `macroBuildOnce` sentinel to execute exactly once and cache the result permanently—ideal
for non-deterministic or expensive values you want frozen at first build:

```dart
@Macro(ComputeMacro())
final _randomNumberMacro = compute(
  () => Random().nextInt(1000),
  deps: macroBuildOnce, // builds once, never rebuilds
);
```

## Execution Strategies

Compute bodies are executed in a temporary copy of your source file placed in the same directory.
Add one of the following comments at the top of the file to force a specific strategy:

| Comment                             | Strategy                                                          |
|-------------------------------------|-------------------------------------------------------------------|
| `// --macro-use-isolate-computer`   | Pure Dart isolate via `Isolate.spawnUri` (no Flutter imports)     |
| `// --macro-use-dart-computer`      | Dart VM via `dart run <tempFile>`                                 |
| `// --macro-use-flutter-computer`   | Flutter test runner via `flutter test <tempFile>`                 |

When no comment is present, the strategy matches the project runner type: `flutter test` for Flutter
projects, `dart run` otherwise. Generated code from other macros in the same file is inlined into
the temp file, so compute bodies can reference generated types (e.g., data class mixins).

## How It Works

1. **Extraction**: The analyzer extracts the compute body source text from the AST along with any
   `encode`, `decode`, and `deps` arguments
2. **Hashing**: A hash is computed from the body plus dependencies (or the whole file when `deps`
   is omitted)
3. **Cache Check**: If the hash matches the stored hash in `.g.dart`, the cached value is reused
4. **Temp File**: Otherwise the source file is copied to a temp file in the same directory with a
   generated `main()` entrypoint appended
5. **Execution**: The temp file runs in an isolate or subprocess, calling each compute body
6. **Serialization**: Results are transported back and serialized into Dart literals
7. **Generation**: The `.g.dart` file is written with the hash constant followed by the generated
   variable declaration

---

<p align="right"><a href="../topics/Asset Path Macro-topic.html">Next: Asset Path Macro</a></p>
