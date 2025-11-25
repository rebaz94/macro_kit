# Macro Kit

A blazingly fast code generation tool for Dart that generates code instantly on save—no build runner required.

## Features

- **⚡ Lightning Fast**: Generate code in under 100ms after the initial run
- **🎯 Instant Generation**: Simply press Ctrl+S and watch your code appear
- **🐛 Easy Debugging**: Debug your own macros or third-party packages to understand and fix code generation issues
- **🚫 No Build Runner**: Say goodbye to slow build processes and generated file conflicts
- **🔧 Flexible**: Apply macros to classes with enough capability for most day-to-day code generation needs

## Installation

### 1. Activate the macro tool globally
```bash
dart pub global activate macro_kit
```

Or install from source:
```bash
dart pub global activate --source path ./
```

### 2. Add macro_kit to your project

In your `pubspec.yaml`:
```yaml
dependencies:
  macro_kit: ^latest_version
```

### 3. Configure the analyzer plugin

In your `analysis_options.yaml`:
```yaml
analyzer:
  plugins:
    - macro_kit
```

### 4. Initialize macros in your app

Add this code to your main entry point. This only runs in development mode and has no effect in production.
```dart
void main() async {
  await runMacro(
    macros: {
      'DataClassMacro': DataClassMacro.initialize,
      'MyMacro': MyMacro.initialize,
      // Add your own macros or use from other packages
    },
  );

  runApp(MyApp());
}
```

## Usage

### 1. Annotate your class

To apply a macro like `DataClassMacro` to your class:
```dart
@dataClassMacro
class UserProfile with UserProfileData {
  const UserProfile({required this.name, required this.age});

  final String name;
  final int age;
}
```

### 2. Save and generate

Press **Ctrl+S** to save the file. Code generation happens instantly!

- First run: ~3-5 seconds
- Subsequent runs: <100ms

The macro will automatically generate:
- `fromJson` method
- `toJson` method
- `Equality` operators
- `toString` method

### 3. Debug when needed

If your macro isn't generating code properly, simply run your app in debug mode and step through the generation process to identify and fix issues.

## Example
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

// Generated code includes:
// - User.fromJson(Map<String, dynamic> json)
// - Map<String, dynamic> toJson()
// - operator ==(Object other)
// - int get hashCode
// - String toString()
```

## Limitations

Currently, macros can only be applied to classes with limited functionality. However, this provides sufficient capability for most common code generation tasks. Future updates will include:
- Support for applying macros to variables
- More information exposed to library developers for building custom packages


## Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## License

This repo is licenced under MIT.