# Macro Global Configuration

The macro system can be configured using a `macro.json` file at the root of your project. This file
contains global settings that apply to all macros, as well as macro-specific configurations.

> [!NOTE]
> For IDE autocompletion and validation, configure the JSON schema for your `macro.json` file by
> either selecting the registered `macro` schema from SchemaStore in your IDE settings, or by
> referencing it directly from GitHub at
`https://raw.githubusercontent.com/rebaz94/macro_kit/refs/heads/main/macro_schema.json`.

## File Structure

```json
{
  "config": {},
  "macros": {}
}
```

## Global Configuration Options

All global configuration options are defined under the `config` key.

### `remap_generated_file_to`

**Type:** `string`  
**Default:** None (uses default locations)

Remaps the generated file location to a custom directory. Transforms the default generated file path
to the specified directory. The path should be relative to the project root.

**Example:**

```json
{
  "config": {
    "remap_generated_file_to": "lib/gen"
  }
}
```

This will place all generated files in the `lib/gen` directory instead of their default locations.

**Common values:**

- `"lib/gen"` - Place all generated files in lib/gen
- `"lib/generated"` - Place all generated files in lib/generated
- `"generated"` - Place all generated files in a root-level generated directory

---

### `auto_rebuild_on_connect`

**Type:** `boolean`  
**Default:** `false`

Automatically rebuild generated files when the plugin connects. When enabled, forces a complete
regeneration of all macro-generated files whenever the macro plugin establishes a connection.

**Example:**

```json
{
  "config": {
    "auto_rebuild_on_connect": true
  }
}
```

**Use case:** Enable this if you want fresh generation every time your development environment
connects to the macro server.

---

### `always_rebuild_on_connect`

**Type:** `boolean`  
**Default:** `false`

Ignores cache for the current plugin session and always re-runs generation when a new client
connects to the macro server. This is more aggressive than `auto_rebuild_on_connect` as it bypasses
all caching mechanisms.

**Example:**

```json
{
  "config": {
    "always_rebuild_on_connect": true
  }
}
```

**Use case:** Enable this during debugging or when you suspect cache-related issues.

---

### `skip_connect_rebuild_with_auto_run_macro`

**Type:** `boolean`  
**Default:** `true`

Skip connect-triggered rebuilds when an external auto-run process is active. When enabled, disables
`auto_rebuild_on_connect` and `always_rebuild_on_connect` if macro generation is being handled by a
separate auto-run process. This prevents the Flutter app from triggering redundant generation when
connecting to a server that's already running automatic generation.

**Example:**

```json
{
  "config": {
    "skip_connect_rebuild_with_auto_run_macro": true
  }
}
```

**When to use:**

- Set to `true` when `autoRunMacro` in your `macro_context.dart` is `true`
- Set to `false` if you want the Flutter app to trigger generation on connect even when using
  external auto-run processes

**Default behavior:** Enabled by default to prevent duplicate work when auto-run processes are
active.

---

## Macro-Specific Configuration

For macro-specific settings, define them under the `macros` key, using the macro name as the key:

```json
{
  "macros": {
    "DataClassMacro": {
      "create_to_json": true
    },
    "YourCustomMacro": {}
  }
}
```

The structure of each macro's configuration depends on the macro implementation. Refer to the
specific macro's documentation for available options.

---

## Complete Example

```json
{
  "config": {
    "remap_generated_file_to": "lib/gen",
    "auto_rebuild_on_connect": false,
    "always_rebuild_on_connect": false,
    "skip_connect_rebuild_with_auto_run_macro": true
  },
  "macros": {
    "DataClassMacro": {
      "generate_to_string": true,
      "generate_copy_with": true
    }
  }
}
```

---

## Configuration Priority

When multiple rebuild options are set:

1. If `skip_connect_rebuild_with_auto_run_macro` is `true` AND an auto-run process is active:
    - Both `auto_rebuild_on_connect` and `always_rebuild_on_connect` are disabled

2. If `skip_connect_rebuild_with_auto_run_macro` is `false` OR no auto-run process is active:
    - `always_rebuild_on_connect` takes precedence over `auto_rebuild_on_connect`
    - If `always_rebuild_on_connect` is `true`, cache is always ignored
    - If `auto_rebuild_on_connect` is `true`, normal cache rules apply