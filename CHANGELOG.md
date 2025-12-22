## 0.4.0

- **Automatic Macro Generation**: Added support for running macro generation independently without
  requiring the app to be running through `macro_context.dart`.
- **New Global Config**: Added `skip_connect_rebuild_with_auto_run_macro` option to prevent
  redundant rebuilds when automatic macro generation is enabled via external processes
- **Rename Configuration File**: Renamed global configuration file from `.macro.json` to
  `macro.json`
- **Watch Logs Command**: Added new command to watch macro generation logs from terminal.
- Fix web compatibility by handling 'dart:io' imports with conditional exports

## 0.3.6

- Add support for assigning null values to nullable fields in `copyWith` methods by wrapping
  parameters in `Option<T>`. This allows distinguishing between "not provided" (keep existing value)
  and "explicitly set to null" (update to null).
    - Enable globally via `copy_with_as_option: true` in configuration for **DataClassMacro**
    - Enable per-class via `@Macro(@DataClassMacro(copyWithAsOption: true))`
    - Enable per-field via `@JsonKey(copyWithAsOption: true)`

## 0.3.5

- Added configurable serialization method names: `use_map_convention` option to generate
  `fromMap`/`toMap` instead of `fromJson`/`toJson`.
    - When `false` (default): Generates `fromJson`/`toJson` methods
    - When `true`: Generates `fromMap`/`toMap` methods
    - This is configured globally to ensure consistency across nested data classes

## 0.3.4

- Add documentation topic for pub

## 0.3.3

- Fix pub analysis point

## 0.3.2

- Add documentation

## 0.3.1

- Added individual log files for each plugin instance loaded in different analysis contexts

## 0.3.0

- **Breaking Change**: Migrated Macro plugin to the new plugin system. To upgrade:
    - Create an empty file named `macro_context.dart` in your `lib` directory
    - Add the `macro_kit` to the `plugins` section in your `analysis_options.yaml`:

```yaml
plugins:
  macro_kit: ^latest version
```

## 0.2.9

- Fix issue where macro server was unable to start automatically on Windows

## 0.2.8

- Fix example folder to use `lib` directory
- Use LocalAppData in windows

## 0.2.7

- Add support for Dart `Type` information in macros
- Fix metadata extraction from const variable annotations
- Refactor and improve internal API structure
- Change macro server to opt-out behavior: starts by default unless disabled

## 0.2.6

- Add logging for regeneration

## 0.2.5

- Force plugin to always connect to MacroServer

## 0.2.4

- Fixing release tool

## 0.2.3

- Add automatic macro server upgrade

## 0.2.2

- Add target file path to `MacroState`

## 0.2.1

- Disable linter and formatter for generated files
- Add additional logging for client messages sent by server

## 0.2.0

- Introduced a new API for defining project-level global macro configurations.
- Added support for skipping serialization/deserialization using `asLiteral` in `@JsonKey`, or by
  defining global `as_literal_types` in `macro.json` for type configurations.
- Enabled adding dynamic analysis contexts via project paths, useful for CI environments and testing
  setups.
- Improved performance and reliability when rebuilding the entire project.
- Add more documentation

## 0.1.4

- Improve watch context and remove duplicate event

## 0.1.3

- fix import from **macro.dart** to **macro_kit.dart**

## 0.1.2

- add generatedType to differentiate macro-generated code for proper combining

## 0.1.1

- Fixed version constraint

## 0.1.0

- Import and library information for macro class declarations
- Import resolution for inspected types
- Field initializer inspection capability
- Enhanced data class macro with generics, default values, super formal parameters, and inheritance
  support
- Fixed asset macro path generation on Windows
- Use internal analysis API to provide memory store
- Better preparation of system paths for macro server startup
- Skip files containing only empty class declarations
- Added API for regeneration when connecting to server
- Fixed Object.hash parameter limit issue for classes with 20+ fields (thanks @jainam-bhavasar, #2)
- Improved documentation coverage
- Expanded test suite

## 0.0.12

- remove returning `MacroManager` in `runMacro` function

## 0.0.11

- allow customizing class name for AssetPathMacro

## 0.0.10

- fix: crashing on iOS fixed

## 0.0.9

- fix: missing doc & set sdk constraints

## 0.0.8

- fix: remove default value for asset configuration

## 0.0.7

- fix: handle invalid value for the asset path macro configuration

## 0.0.6

- Adding Asset Path Generation

## 0.0.5

- Initial version released
