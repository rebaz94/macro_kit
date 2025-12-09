import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';
import 'dart:core' as $c;
import 'dart:core';

part 'function_fields_test.g.dart';

@Macro(DataClassMacro(copyWith: true, equal: true, toStringOverride: true))
class Example1 with Example1Data {
  const Example1({required this.functionField});

  final int Function(int)? functionField;
}

@Macro(DataClassMacro(copyWith: true, equal: true, toStringOverride: true))
class Example2 with Example2Data {
  const Example2({required this.functionField});

  final $c.int Function($c.int, {$c.String? name})? functionField;
}

@Macro(DataClassMacro(copyWith: true, equal: true, toStringOverride: true))
class Example3<T> with Example3Data<T> {
  const Example3({required this.functionField});

  final $c.int Function($c.int, {$c.String? name, required T? data})? functionField;
}


void main() {
  group('function fields', () {
    test('should check equality with function field', () {
      int fn(int x) => x + 1;

      var example1 = Example1(functionField: fn);
      var example2 = Example1(functionField: fn);
      expect(example1, equals(example2));
    });

    test('should stringify with function field', () {
      var example = Example1(functionField: (x) => x + 1);
      expect(
        example.toString(),
        equals('Example1{functionField: Closure: (int) => int}'),
      );
    });

    test('should check equality with null function field', () {
      var example1 = Example1(functionField: null);
      var example2 = Example1(functionField: null);
      expect(example1, equals(example2));
    });

    test('should stringify with null function field', () {
      var example = Example1(functionField: null);
      expect(example.toString(), equals('Example1{functionField: null}'));
    });
  });

  group('function fields with import', () {
    test('should check equality with function field', () {
      int fn(int x, {String? name}) => x + 1;

      var example1 = Example2(functionField: fn);
      var example2 = Example2(functionField: fn);
      expect(example1, equals(example2));
    });

    test('should stringify with function field', () {
      var example = Example2(functionField: (x, {String? name}) => x + 1);
      expect(
        example.toString(),
        equals('Example2{functionField: Closure: (int, {String? name}) => int}'),
      );
    });

    test('should check equality with null function field', () {
      var example1 = Example2(functionField: null);
      var example2 = Example2(functionField: null);
      expect(example1, equals(example2));
    });

    test('should stringify with null function field', () {
      var example = Example2(functionField: null);
      expect(example.toString(), equals('Example2{functionField: null}'));
    });
  });

  group('function fields with import + generic', () {
    test('should check equality with function field', () {
      int fn(int x, {String? name, int? data}) => x + 1;

      var example1 = Example3(functionField: fn);
      var example2 = Example3(functionField: fn);
      expect(example1.toString(), equals(example2.toString()));
      expect(example1, equals(example2));
    });

    test('should stringify with function field', () {
      var example = Example3(functionField: (x, {String? name, int? data}) => x + 1);
      expect(
        example.toString(),
        equals('Example3<int>{functionField: Closure: (int, {int? data, String? name}) => int}'),
      );
    });

    test('should check equality with null function field', () {
      var example1 = Example3(functionField: null);
      var example2 = Example3(functionField: null);
      expect(example1, equals(example2));
    });

    test('should stringify with null function field', () {
      var example = Example3<int>(functionField: null);
      expect(example.toString(), equals('Example3<int>{functionField: null}'));
    });
  });

}
