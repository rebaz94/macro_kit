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

---

<p align="right"><a href="../topics/Models-topic.html">Next: Models</a></p>