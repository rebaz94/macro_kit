// ignore_for_file: unused_element
import 'package:flutter/material.dart';
import 'package:macro_kit/macro_kit.dart';

part 'type.g.dart';

final _variants = [
  {'name': 'primary', 'bg': 0xFF3366FF, 'fg': 0xFFFFFFFF, 'radius': 12.0},
  {'name': 'danger', 'bg': 0xFFE53935, 'fg': 0xFFFFFFFF, 'radius': 12.0},
  {'name': 'ghost', 'bg': 0x00000000, 'fg': 0xFF3366FF, 'radius': 12.0},
];

@Macro(ComputeMacro(modifier: ComputeModifier(isDeclaration: true)))
final _buttonStyles = compute(
  () {
    final buffer = StringBuffer('class ButtonStyles {\n');
    buffer.writeln('  ButtonStyles._();\n');

    for (final v in _variants) {
      final fieldName = v['name'] as String;
      buffer.writeln('''
  static const $fieldName = ButtonStyle(
    backgroundColor: MaterialStatePropertyAll(Color(${v['bg']})),
    foregroundColor: MaterialStatePropertyAll(Color(${v['fg']})),
    shape: MaterialStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(${v['radius']}))),
    ),
  );
''');
    }

    buffer.writeln('}');

    return DartCode(buffer.toString());
  },
  deps: [_variants],
);

final routes = [
  {'name': 'home', 'path': '/home'},
  {'name': 'search', 'path': '/search'},
  {'name': 'profile', 'path': '/profile'},
];

@Macro(ComputeMacro(modifier: ComputeModifier(isDeclaration: true)))
final _routeEnum = compute(() {
  final values = routes.map((r) => "${r['name']}('${r['path']}')").join(',\n  ');

  return DartCode('''
enum AppRoute {
  $values;

  final String path;
  const AppRoute(this.path);
}
''');
});
