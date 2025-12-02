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

### Run from CLI

```bash
dart run macro.dart
```

### Run from IDE

Simply open `macro.dart` in your IDE and run it directly using the run button or keyboard shortcut.

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