## Installation

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


---

<p align="right"><a href="../topics/Models-topic.html">Next: Models</a></p>