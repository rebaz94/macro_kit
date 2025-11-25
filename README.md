# Macro

## Installing

1. Install the **macro** package by `dart pub global activate macro` or
   from source using `dart pub global activate --source path ./`.
2. In the `pubspec.yaml` add `macro` package.
3. In the `analysis_options.yaml` add `macro` in the plugin section

```yaml
analyzer:
  plugins:
    - macro 
```