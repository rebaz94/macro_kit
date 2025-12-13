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
  defining global `as_literal_types` in `.macro.json` for type configurations.
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
