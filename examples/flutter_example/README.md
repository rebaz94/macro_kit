# flutter_example

This example demonstrates various features of macro_kit.

* macro_context.dart shows how to set up macro_kit and register macros.
* main.dart demonstrates a sample macro called FormMacro, which generates a form from a provided
  JSON schema. It also showcases the Embed macro, which embeds a specified asset directory directly
  into the source code (the generated embed output is located in lib/embed).
* The other files highlight different features of the built-in `DataClassMacro` and
  `AssetPathMacro`.
* The example_macro folder contains multiple macro examples, including how to create new macros and
  how to apply macros to top-level functions, records, and classes.