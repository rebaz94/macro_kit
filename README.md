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

### 3. Configure the analyzer plugin

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - macro_kit
```

### 4. Initialize macros in your app

Add this to your main entry point. It only runs in development and has zero impact on production
builds:

```dart
void main() async {
  await runMacro(
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
      'AssetPathMacro': AssetPathMacro.initialize,
      // Add your own macros or import from packages
    },
  );

  runApp(MyApp());
}
```

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
> properly. However, for testing purposes, you can pass an absolute path instead of a package name to
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
void main() async {
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

  runApp(MyApp());
}
```

For more information, see the [Asset Path Macro](doc/asset_path_macro.md) documentation.

```dart
// Usage in code
final asset = Image.asset(AssetPaths.logo);
final asset = Image.asset(AssetPaths.icons.home);
```

## 🎯 Why Macro Kit?

| Feature          | Macro Kit            | build_runner       |
|------------------|----------------------|--------------------|
| Generation Speed | <100ms               | Seconds to minutes |
| Debugging        | ✅ Full debug support | ❌ Limited          |
| File Conflicts   | ❌ Never              | ✅ Common issue     |
| IDE Integration  | ✅ Instant feedback   | ⏳ Wait for build   |
| Learning Curve   | 🟢 Simple            | 🔴 Complex         |

## 🔧 Running Macros Separately

You can create a dedicated macro runner file to keep your macro setup separate from your app's main
entry point.

For mobile apps, it’s recommended to use a separate macro-runner file to isolate your
macro setup from the main entry point. This remains the preferred workflow until macros are fully
supported on physical Android and iOS devices

### Create a macro runner

Create a new file `macro.dart` in your project root or `lib` directory:

```dart
// macro.dart
import 'package:macro_kit/macro_kit.dart';

void main() async {
  await runMacro(
    package: PackageInfo('your_package_name'),
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

### Run the macro

**From CLI:**

```bash
dart run macro.dart
```

**From IDE:**
Simply open `macro.dart` and run it directly.

### Auto-rebuild configuration

Configuration is defined in the `.macro.json` file. We recommend using CLI-based generation
primarily for CI/CD pipelines and automated testing. During regular development, the IDE plugin
automatically loads context and regenerates code when you save files—no manual code generation
needed, just like writing regular Dart code.

For CI/CD and testing environments, you'll need to set up manual generation:

1. Install macro_kit: `dart pub global activate macro_kit`
2. Start the macro server in a separate process: `macro` (normally handled by the plugin).
   Alternatively, you can import internal functions like `startMacroServer` directly if you prefer
   not
   to activate the plugin globally (CI only)
3. Add absolute paths for directories to regenerate—context is loaded dynamically without requiring
   the analyzer plugin

To wait for regeneration to complete, call `waitUntilRebuildCompleted` after `runMacro`.

Enable auto-rebuild in `.macro.json`:

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

Macros can currently only be applied to classes. This covers most common use cases, but future
updates will include:

- 🔜 Support for applying macros to variables and functions
- 🔜 Additional macro capabilities for library developers
- 🔜 More built-in macros for common patterns

Despite these limitations, Macro Kit handles the majority of day-to-day code generation needs
efficiently.

## 🤝 Contributing

Contributions are welcome! Feel free to:

- 🐛 Report bugs and issues
- 💡 Suggest new features
- 🔧 Submit pull requests

## 📄 License

MIT License - see [LICENSE](LICENSE) for details