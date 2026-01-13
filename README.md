# Macro Kit

A blazingly fast code generation tool for Dart that generates code instantly on save—no build runner
required.

## ✨ Features

- **⚡ Lightning Fast**: Code generation in under 100ms after initial run
- **💾 Instant Generation**: Press Ctrl+S and watch your code appear immediately
- **🐛 Easy Debugging**: Debug your macros or third-party packages in real-time to understand and fix
  generation issues
- **🚫 No Build Runner**: Eliminate slow build processes and generated file conflicts
- **🎯 Flexible & Capable**: Handles most day-to-day code generation needs with macros
- **🔄 Live Development**: Changes take effect instantly—no separate build step needed

## 📦 Installation

### 1. Activate the macro tool globally

```bash
dart pub global activate macro_kit
```

Or install from source:

```bash
dart pub global activate --source path ./
```

if you updating, just deactivate first and activate again.

### 2. Add macro_kit to your project

```yaml
# pubspec.yaml
dependencies:
  macro_kit: ^latest_version
```

### 3. Configure the plugin

```yaml
# analysis_options.yaml
plugins:
  macro_kit: ^latest_version
```

### 4. Create macro context file

Create a file named `macro_context.dart` in your `lib` directory.

**If you have the macro_kit plugin installed:**

- Create an empty `macro_context.dart` file in `lib/`
- The plugin will automatically populate it with setup code and inline documentation

**Manual setup (without plugin):**

```dart
import 'dart:async';

import 'package:macro_kit/macro_kit.dart';

bool get autoRunMacro => true;

List<String> get autoRunMacroCommand => macroDartRunnerCommand;

/// Entry point for automatic macro execution - do not modify
void main() async {
  await setupMacro();
  await keepMacroRunner();
}

/// Configure and register your macros here
Future<void> setupMacro() async {
  await runMacro(
    package: PackageInfo('your_package_name'), // TODO: Update this
    autoRunMacro: autoRunMacro,
    enabled: true,
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
      // Add more macros here
    },
  );
}
```

**How it works:**

- **When `autoRunMacro = true` (default):** The macro system runs this file in a separate background
  process, generating code automatically without running your app
- **When `autoRunMacro = false` (debug mode):** You must call `setupMacro()` from your app's
  `main()` to trigger generation inside your running application (see step 5)

**Customization:**

- Change `autoRunMacroCommand` to customize how the macro process runs (add flags, use different
  runners, etc.)
- Register additional macros in the `macros` map

> [!IMPORTANT]
> **Platform support:**
> - **Desktop (macOS, Windows, Linux):** Full support for both automatic and manual modes
> - **Mobile & Web:** Automatic mode only - manual macro execution is not supported and will be
    ignored

### 5. Optional: Initialize macros in your app

Import `macro_context.dart` into your `main.dart` and call `setupMacro()`:

```dart
import 'package:my_package/macro_context.dart' as macro;

void main() async {
  await macro.setupMacro();
  runApp(MyApp());
}
```

**When is this needed?**

| Scenario                            | Behavior                                                                                                                                             |
|-------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| `autoRunMacro = true` (default)     | **Optional** - Only listens for messages sent by the macro server without generating code; doesn't generate code (desktop only, no-op on mobile/web) |
| `autoRunMacro = false` (debug mode) | **Required** - Triggers code generation inside your app (desktop only, ignored on mobile/web)                                                        |
| Production builds                   | **No effect** - Automatically disabled in release mode                                                                                               |

> [!TIP]
> **Debugging macros:** Set `autoRunMacro = false` in `macro_context.dart`, then call `setupMacro()`
> from your app's `main()`. This lets you use breakpoints and inspect macro execution in real-time.

## 🚀 Quick Start

### 1. Annotate your class

```dart
import 'package:macro_kit/macro_kit.dart';

@dataClassMacro
class User with UserData {
  const User({
    required this.id,
    required this.name,
    required this.email,
  });

  final int id;
  final String name;
  final String email;
}
```

> [!NOTE]
> Dart source code must be placed inside the `lib` directory for the macro to generate code
> properly. However, for testing purposes, you can pass an absolute path instead of a package name
> to
> force it to load into the analysis context.

### 2. Save and generate

Press **Ctrl+S** to save. Generation happens instantly!

- **First run**: ~3-5 seconds (one-time setup)
- **Subsequent runs**: <100ms ⚡

### 3. Use the generated code

The macro automatically generates:

- ✅ `fromJson(Map<String, dynamic> json)` constructor
- ✅ `toJson()` method
- ✅ Equality operators (`==`, `hashCode`)
- ✅ `copyWith()` method
- ✅ `toString()` method

```dart
// Use it immediately
final User user = UserData.fromJson({'id': 1, 'name': 'Alice', 'email': 'alice@example.com'});
final json = user.toJson();
final updated = user.copyWith(name: 'Bob');
```

### 4. Debug when needed

Unlike build_runner, you can debug macro code generation in real-time. Run your app in debug mode
and step through the generation process to identify and fix issues.

## 📚 Built-in Macros

### DataClassMacro

Generates data class boilerplate including `fromJson`, `toJson`, `copyWith`, equality operators, and
`toString`.

```dart
@dataClassMacro
class UserProfile with UserProfileData {
  const UserProfile({required this.name, required this.age});

  final String name;
  final int age;
}
```

For more information, see the [Data Class Macro](doc/data_class_macro.md) documentation.

### AssetPathMacro

Generates type-safe constants for your asset paths. Never hardcode asset strings again!

```dart
Future<void> setupMacro() async {
  await runMacro(
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
      'AssetPathMacro': AssetPathMacro.initialize,
      // Add your own macros or import from packages
    },
    assetMacros: {
      'assets': [
        AssetMacroInfo(
          macroName: 'AssetPathMacro',
          extension: '*',
          output: 'lib',
        ),
      ],
    },
  );
}
```

For more information, see the [Asset Path Macro](doc/asset_path_macro.md) documentation.

```dart
// Usage in code
final asset = Image.asset(AssetPaths.logo);
final asset = Image.asset(AssetPaths.icons.home);
```

### EmbedMacro

Embeds asset files directly into Dart source code as byte arrays. This macro scans a directory,
generates Dart code containing the raw bytes of each asset, and exposes a virtual file system
interface.

```dart
Future<void> setupMacro() async {
  await runMacro(
    macros: {
      'EmbedMacro': EmbedMacro.initialize,
    },
    assetMacros: {
      'assets': [
        AssetMacroInfo(
          macroName: 'EmbedMacro',
          extension: '.png,.jpg',
          output: 'lib/embed',
        ),
      ],
    },
  );
}
```

For additional details, refer to the [Embed Macro](doc/embed_macro.md) documentation.

```dart
// Usage example
final files = EmbedFs.current.listSync();
final myImageBytes = EmbedFs.file('/assets/image.png').readAsByteSync();
```

## 🎯 Why Macro Kit?

| Feature          | Macro Kit            | build_runner       |
|------------------|----------------------|--------------------|
| Generation Speed | <100ms               | Seconds to minutes |
| Debugging        | ✅ Full debug support | ❌ Limited          |
| File Conflicts   | ❌ Never              | ✅ Common issue     |
| IDE Integration  | ✅ Instant feedback   | ⏳ Wait for build   |
| Learning Curve   | 🟢 Simple            | 🔴 Complex         |

### Run the macro

**From CLI:**

```bash
dart run lib/macro_context.dart
```

**From IDE:**
Simply open `lib/macro_context.dart` and run it directly.

### Auto-rebuild configuration

Configuration is defined in the `macro.json` file. We recommend using CLI-based generation
primarily for CI/CD pipelines and automated testing. During regular development, the IDE plugin
automatically loads context and regenerates code when you save files—no manual code generation
needed, just like writing regular Dart code.

For CI/CD and testing environments, you'll need to set up manual generation:

1. Install macro_kit: `dart pub global activate macro_kit`
2. Start the macro server in a separate process: `macro` (normally handled by the plugin).
   Alternatively, you can import internal functions like `startMacroServer` directly if you prefer
   not to activate the plugin globally (CI only)
3. Add absolute paths for directories to regenerate—context is loaded dynamically without requiring
   the analyzer plugin

To wait for regeneration to complete, call `waitUntilRebuildCompleted` after `runMacro`.

Enable auto-rebuild in `macro.json`:

```json
{
  "config": {
    "auto_rebuild_on_connect": true,
    "always_rebuild_on_connect": false
  }
}
```

- **`auto_rebuild_on_connect`**: Automatically rebuilds when the macro server connects
- **`always_rebuild_on_connect`**: Rebuilds on every reconnection (useful for CI environments)

## ⚠️ Current Limitations

At the moment, macros can only be used on classes, top-level functions, and records. While this
supports most common scenarios, upcoming releases are expected to add:

- 🔜 Compile-time value computation
- 🔜 The ability to apply macros to variables
- 🔜 Expanded macro features for library authors
- 🔜 A broader set of built-in macros for common use cases

Despite these limitations, Macro Kit handles the majority of day-to-day code generation needs
efficiently.

## 🤝 Contributing

Contributions are welcome! Feel free to:

- 🐛 Report bugs and issues
- 💡 Suggest new features
- 🔧 Submit pull requests

## 📄 License

MIT License - see [LICENSE](LICENSE) for details