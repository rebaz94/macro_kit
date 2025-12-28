import 'dart:convert';

import 'package:flutter_example/example_macro/timed_macro.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:macro_kit/macro_kit.dart';

part 'measure_time.g.dart';

@dataClassMacro
class Todo with TodoData {
  const Todo({
    required this.id,
    required this.userId,
    required this.title,
    required this.completed,
  });

  final int id;
  final int userId;
  final String title;
  final bool completed;
}

@dataClassMacro
class Todos with TodosData {
  Todos({required this.items});

  static Todos fromJsonList(List json) {
    return Todos(items: json.map((e) => TodoData.fromJson(e as Map<String, dynamic>)).toList());
  }

  final List<Todo> items;
}

@timedMacro
Future<Todos> _getTodos() async {
  final result = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/todos'));
  final res = jsonDecode(result.body);
  return Todos.fromJsonList(res as List);
}

@timedMacro
Future<Todo> _getTodoById(int id) async {
  final result = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/todos/$id'));
  return TodoData.fromJson(jsonDecode(result.body) as Map<String, dynamic>);
}

@timedMacro
Future<Todo> getTodoOf({required int id}) async {
  final result = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/todos/$id'));
  return TodoData.fromJson(jsonDecode(result.body) as Map<String, dynamic>);
}

void operation(int i) {}

@timedMacro
void syncFunctions([void Function(int i) fn = operation, bool? a = true, bool? c]) {
  for (int i = 0; i < 10; i++) {
    fn(i);
  }
}

@timedMacro
void syncFunctions2(void Function(int i) fn, {bool a = false, bool b = true, required String c}) {
  for (int i = 0; i < 10; i++) {
    fn(i);
  }
}

@timedMacro
void syncFunctions3({
  void Function(int i) fn = operation,
  void Function(int i)? fn2,
  bool a = false,
  bool b = true,
  required String c,
}) {
  for (int i = 0; i < 10; i++) {
    fn(i);
  }
}

void testTodoExample() async {
  final (todos, time1) = await getTodos();
  final (todo1, time2) = await getTodoById(1);
  final (todo2, time3) = await getTodoOfTimed(id: 2);

  print('All Todos: time to complete: $time1, result: $todos');
  print('Todo 1   : time to complete: $time2, result: $todo1');
  print('Todo 2   : time to complete: $time3, result: $todo2');
}
