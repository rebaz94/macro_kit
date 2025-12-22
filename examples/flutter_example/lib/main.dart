import 'package:flutter/material.dart';
import 'package:flutter_example/example_macro/form_macro.dart';
import 'package:flutter_example/example_macro/json_schema_macro.dart';
import 'package:flutter_example/macro_context.dart' as macro;
import 'package:macro_kit/macro_kit.dart';

import 'multiple_macro_combined.dart';

part 'main.g.dart';

void main() async {
  await macro.setupMacro();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

@Macro(FormMacro())
class _MyHomePageState extends State<MyHomePage> with _MyHomePageStateForm {
  @FormzField(type: String)
  StringSchema get nameSchema => StringSchema(minLength: 3);

  // @FormField(type: int) // should be inferred
  IntegerSchema get ageSchema => IntegerSchema(minimum: 18);

  @FormzField(type: UserProfile2)
  Schema get profileSchema => UserProfile2Data.schema;

  @FormzField(type: List<String>, defaultValue: ['a', 'b', 'c'])
  ListSchema get myListSchema => ListSchema();

  Map<String, List<ValidationError>> validationErrors = const {};

  void _validateForm() async {
    validationErrors = await validate();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
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
