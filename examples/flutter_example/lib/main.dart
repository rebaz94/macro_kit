import 'package:flutter/material.dart';
import 'package:flutter_example/embed/embed.dart';
import 'package:flutter_example/example_macro/form_macro.dart';
import 'package:flutter_example/example_macro/json_schema_macro.dart';
import 'package:flutter_example/macro_context.dart' as macro;
import 'package:flutter_svg/svg.dart';
import 'package:macro_kit/macro_kit.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;

import 'multiple_macro_combined.dart';

part 'main.g.dart';

void main() async {
  await macro.setupMacro();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

@Macro(FormMacro())
class _MyHomePageState extends State<MyHomePage> with _MyHomePageStateForm {
  @FormzField(type: String)
  StringSchema get nameSchema => StringSchema(minLength: 3);

  // @FormzField(type: int) // should be inferred
  IntegerSchema get ageSchema => IntegerSchema(minimum: 18);

  @FormzField(type: UserProfile2)
  Schema get profileSchema => UserProfile2Data.schema;

  @FormzField(type: List<String>, defaultValue: ['a', 'b', 'c'])
  ListSchema get myListSchema => ListSchema();

  Map<String, List<ValidationError>> validationErrors = const {};

  final images = <Widget>[];

  void _validateForm() async {
    validationErrors = await validate();
    setState(() {});
  }

  void _loadImages() {
    final dir = EmbedFS.current;
    final files = dir.listSync(recursive: true);

    images.clear();

    for (final entity in files) {
      switch (entity) {
        case EmbedFile file:
          final ext = p.extension(file.path);
          final image = switch (ext) {
            '.png' || '.jpg' => Image(image: MemoryImage(file.readAsBytesSync())),
            '.svg' => SvgPicture.memory(file.readAsBytesSync()),
            _ => null,
          };
          if (image != null) {
            images.add(image);
          }
        case EmbedDirectory dir:
          dir.listSync().forEach(print);
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'You have pushed the button this many times:',
              ),
              Text('Age Counter: '),
              ValueListenableBuilder(
                valueListenable: ageState,
                builder: (context, state, _) {
                  return Container(
                    color: state.isUndefined ? Colors.amber : null,
                    child: Text(
                      '${state.isUndefined ? 'Not Set' : state.value}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              for (final entry in validationErrors.entries)
                Row(
                  spacing: 10,
                  children: [
                    Text('Field: ${entry.key}'),
                    Text('Value: ${entry.value.join(', ')}'),
                  ],
                ),
              ...images,
            ],
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          FloatingActionButton(
            onPressed: _loadImages,
            tooltip: 'Load image',
            child: const Icon(Icons.image),
          ),
          FloatingActionButton(
            onPressed: _validateForm,
            tooltip: 'Validate',
            child: const Icon(Icons.send),
          ),
          FloatingActionButton(
            onPressed: () => age = (age ?? 0) + 1,
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
