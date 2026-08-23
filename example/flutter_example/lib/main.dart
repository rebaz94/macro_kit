import 'package:flutter/material.dart';
import 'package:flutter_example/embed/embed.dart';
import 'package:flutter_example/example_macro/form_macro.dart';
import 'package:flutter_example/example_macro/json_schema_macro.dart';
import 'package:flutter_example/macro_context.dart' as macro;
import 'package:flutter_example/shader_demo/shader_cube_page.dart';
import 'package:flutter_svg/svg.dart';
import 'package:macro_kit/macro_kit.dart';

// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;

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
      title: 'MacroKit Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomeTabs(),
    );
  }
}

/// Hosts the two top-level tabs: the macro demo and the Flutter GPU shader
/// demo. Each tab owns its own widget tree and state.
class HomeTabs extends StatelessWidget {
  const HomeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Macro Example'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.home_outlined), text: 'Demo'),
              Tab(icon: Icon(Icons.view_in_ar_outlined), text: 'Shader'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ValidationPage(),
            ShaderCubePage(),
          ],
        ),
      ),
    );
  }
}

class ValidationPage extends StatefulWidget {
  const ValidationPage({super.key});

  @override
  State<ValidationPage> createState() => _ValidationPageState();
}

@Macro(FormMacro())
class _ValidationPageState extends State<ValidationPage> with _ValidationPageStateForm, AutomaticKeepAliveClientMixin {
  @FormzField(type: String)
  StringSchema get nameSchema => StringSchema(minLength: 3);

  // @FormzField(type: int) // should be inferred
  IntegerSchema get ageSchema => IntegerSchema(minimum: 18);

  @FormzField(type: List<String>, defaultValue: ['a', 'b', 'c'])
  ListSchema get myListSchema => ListSchema();

  Map<String, List<ValidationError>> validationErrors = const {};

  final images = <Widget>[];

  var _hasValidated = false;

  late final TextEditingController _nameController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? get _nameError {
    final errors = validationErrors['name'];
    if (errors == null || errors.isEmpty) return null;
    return errors.map((error) => error.toString()).join('\n');
  }

  void _validateForm() async {
    validationErrors = await validate();
    _hasValidated = true;
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
    super.build(context);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            _buildAgeCounterCard(context),
            _buildValidationCard(context),
            _buildEmbedAssetsCard(context),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          FloatingActionButton(
            onPressed: _loadImages,
            tooltip: 'Load embedded images',
            child: const Icon(Icons.image),
          ),
          FloatingActionButton(
            onPressed: _validateForm,
            tooltip: 'Validate form',
            child: const Icon(Icons.send),
          ),
          FloatingActionButton(
            onPressed: () => age = (age ?? 0) + 1,
            tooltip: 'Increment age',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeCounterCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder(
          valueListenable: ageState,
          builder: (context, state, _) {
            final isUndefined = state.isUndefined;
            final accent = isUndefined ? Colors.amber.shade800 : Colors.green;
            return Row(
              children: [
                Icon(Icons.cake_outlined, size: 32, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Age counter',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        isUndefined ? 'Not set' : '${state.value}',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    isUndefined ? Icons.help_outline : Icons.check_circle_outline,
                    size: 18,
                    color: accent,
                  ),
                  label: Text(isUndefined ? 'undefined' : 'valid'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildValidationCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              children: [
                Icon(Icons.rule_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Form validation', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (_hasValidated)
                  Chip(
                    avatar: Icon(
                      validationErrors.isEmpty ? Icons.check_circle : Icons.error,
                      size: 18,
                      color: validationErrors.isEmpty ? Colors.green : theme.colorScheme.error,
                    ),
                    label: Text(
                      validationErrors.isEmpty ? 'All valid' : '${validationErrors.length} invalid field(s)',
                    ),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Text(
                    'Not run yet',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'At least 3 characters',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge_outlined),
                errorText: _nameError,
                errorMaxLines: 3,
              ),
              onChanged: (value) {
                name = value.isEmpty ? null : value;
                if (validationErrors.containsKey('name')) {
                  validationErrors = {...validationErrors}..remove('name');
                  setState(() {});
                }
              },
            ),
            if (validationErrors.isEmpty)
              Text(
                _hasValidated
                    ? 'Every field passed validation.'
                    : 'Fill the name, then tap the send button to validate all fields.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final entry in validationErrors.entries)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 20, color: theme.colorScheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(entry.key, style: theme.textTheme.labelLarge),
                            for (final error in entry.value) Text(error.toString(), style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbedAssetsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              children: [
                Icon(Icons.image_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Embedded assets', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${images.length} loaded',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Text(
              'Decoded from EmbedFS — tap the image button to load.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (images.isEmpty)
              Container(
                height: 140,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 36,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text('No assets loaded yet', style: theme.textTheme.bodySmall),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final image in images.indexed)
                    Container(
                      width: 148,
                      height: 148,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                        color: theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      child: FittedBox(fit: BoxFit.contain, child: image.$2),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
