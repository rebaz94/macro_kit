## Models

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

---

<p align="right"><a href="../topics/Data Class Macro-topic.html">Next: Data Class Macro</a></p>