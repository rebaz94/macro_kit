import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

// Test cases
void main() {
  print('Running Type Replacer Tests...\n');

  final tests = [
    // Simple type replacement
    Test(
      name: 'Simple type replacement',
      input: 'T',
      replacements: {'T': 'T1'},
      expected: 'T1',
    ),

    // Generic with single type parameter
    Test(
      name: 'Generic with single type parameter',
      input: 'Map<String, T>',
      replacements: {'T': 'T1'},
      expected: 'Map<String, T1>',
    ),

    // Generic with no space after comma
    Test(
      name: 'Generic with no space after comma',
      input: 'Map<String,T>',
      replacements: {'T': 'T1'},
      expected: 'Map<String,T1>',
    ),

    // Type with extends bound
    Test(
      name: 'Type with extends bound',
      input: 'T extends Comparable<G>',
      replacements: {'T': 'T1'},
      expected: 'T1 extends Comparable<G>',
    ),

    // Type extending itself (recursive bound)
    Test(
      name: 'Type extending itself in bound',
      input: 'T extends Codable<T>',
      replacements: {'T': 'T1'},
      expected: 'T1 extends Codable<T1>',
    ),

    // Multiple types with shared bounds
    Test(
      name: 'Multiple types with shared bounds',
      input: 'T extends Codable<T>, T2 extends Codable<T>',
      replacements: {'T': 'T1'},
      expected: 'T1 extends Codable<T1>, T2 extends Codable<T1>',
    ),

    // Multiple replacements at once
    Test(
      name: 'Multiple replacements',
      input: 'Map<T, U>',
      replacements: {'T': 'T1', 'U': 'U1'},
      expected: 'Map<T1, U1>',
    ),

    // Complex nested generics
    Test(
      name: 'Complex nested generics',
      input: 'List<Map<T, Future<T>>>',
      replacements: {'T': 'T1'},
      expected: 'List<Map<T1, Future<T1>>>',
    ),

    // Type at different positions
    Test(
      name: 'Type at different positions',
      input: 'T Function(T, List<T>)',
      replacements: {'T': 'T1'},
      expected: 'T1 Function(T1, List<T1>)',
    ),

    // Should not replace partial matches
    Test(
      name: 'Should not replace partial matches',
      input: 'T1 extends Comparable<T>',
      replacements: {'T': 'T2'},
      expected: 'T1 extends Comparable<T2>',
    ),

    // Multiple type parameters in bounds
    Test(
      name: 'Multiple type parameters in bounds',
      input: 'T extends Comparable<T>, U extends List<T>',
      replacements: {'T': 'T1', 'U': 'U1'},
      expected: 'T1 extends Comparable<T1>, U1 extends List<T1>',
    ),

    // Empty replacement map
    Test(
      name: 'Empty replacement map',
      input: 'Map<String, T>',
      replacements: {},
      expected: 'Map<String, T>',
    ),

    // Type with spaces around operators
    Test(
      name: 'Type with spaces around extends',
      input: 'T  extends  Comparable<T>',
      replacements: {'T': 'T1'},
      expected: 'T1  extends  Comparable<T1>',
    ),

    // Multiple occurrences in same position
    Test(
      name: 'Type used multiple times',
      input: 'T Function(T) Function(T)',
      replacements: {'T': 'T1'},
      expected: 'T1 Function(T1) Function(T1)',
    ),

    // Nullable types
    Test(
      name: 'Nullable type',
      input: 'T?',
      replacements: {'T': 'T1'},
      expected: 'T1?',
    ),

    // List literal style
    Test(
      name: 'List literal style',
      input: '[T]',
      replacements: {'T': 'T1'},
      expected: '[T1]',
    ),

    // Type in return position with arrow
    Test(
      name: 'Function with arrow return',
      input: 'T Function() => T',
      replacements: {'T': 'T1'},
      expected: 'T1 Function() => T1',
    ),

    // Type with &, | operators (intersection/union types)
    Test(
      name: 'Intersection type',
      input: 'T & U',
      replacements: {'T': 'T1', 'U': 'U1'},
      expected: 'T1 & U1',
    ),

    Test(
      name: 'Union type',
      input: 'T | U',
      replacements: {'T': 'T1', 'U': 'U1'},
      expected: 'T1 | U1',
    ),

    // Type after colon (named parameters, record types)
    Test(
      name: 'Named parameter type',
      input: '{required T value}',
      replacements: {'T': 'T1'},
      expected: '{required T1 value}',
    ),

    Test(
      name: 'Record type',
      input: '(int, T)',
      replacements: {'T': 'T1'},
      expected: '(int, T1)',
    ),

    Test(
      name: 'Named record type',
      input: '({int a, T b})',
      replacements: {'T': 'T1'},
      expected: '({int a, T1 b})',
    ),

    // Type with asterisk (pointer-like syntax, uncommon but possible)
    Test(
      name: 'Type with special char after',
      input: 'List<T>*',
      replacements: {'T': 'T1'},
      expected: 'List<T1>*',
    ),

    // Consecutive type parameters
    Test(
      name: 'Consecutive types no delimiter',
      input: 'T T',
      replacements: {'T': 'T1'},
      expected: 'T1 T1',
    ),

    // Type in "super" bound
    Test(
      name: 'Super bound',
      input: 'T super Comparable<T>',
      replacements: {'T': 'T1'},
      expected: 'T1 super Comparable<T1>',
    ),

    // FutureOr and other special generic types
    Test(
      name: 'FutureOr type',
      input: 'FutureOr<T>',
      replacements: {'T': 'T1'},
      expected: 'FutureOr<T1>',
    ),

    // Type with semicolon (multiple declarations)
    Test(
      name: 'Multiple declarations with semicolon',
      input: 'T foo; T bar',
      replacements: {'T': 'T1'},
      expected: 'T1 foo; T1 bar',
    ),

    // Type after equals (typedef, type alias)
    Test(
      name: 'Type alias',
      input: 'typedef MyType = T',
      replacements: {'T': 'T1'},
      expected: 'typedef MyType = T1',
    ),

    // Very short type names that could be confused
    Test(
      name: 'Single char types',
      input: 'E extends T, T extends U, U extends V',
      replacements: {'E': 'E1', 'T': 'T1', 'U': 'U1', 'V': 'V1'},
      expected: 'E1 extends T1, T1 extends U1, U1 extends V1',
    ),

    // Type at start and end
    Test(
      name: 'Type at start and end',
      input: 'T extends Comparable<int> implements List<T>',
      replacements: {'T': 'T1'},
      expected: 'T1 extends Comparable<int> implements List<T1>',
    ),

    // TEST CASES FOR SORTING LOGIC
    // These would fail without sorting keys by length (descending)
    Test(
      name: 'Replacing T and T1 - T1 should not be partially matched',
      input: 'T1 extends Comparable<T>',
      replacements: {'T': 'NewT', 'T1': 'NewT1'},
      expected: 'NewT1 extends Comparable<NewT>',
    ),

    Test(
      name: 'Replacing T, T1, T10 - longest first',
      input: 'Map<T10, Map<T1, T>>',
      replacements: {'T': 'A', 'T1': 'B', 'T10': 'C'},
      expected: 'Map<C, Map<B, A>>',
    ),

    Test(
      name: 'Type names as substrings of each other',
      input: 'Type extends TypeParam<TypeParameter>',
      replacements: {'Type': 'T1', 'TypeParam': 'T2', 'TypeParameter': 'T3'},
      expected: 'T1 extends T2<T3>',
    ),

    Test(
      name: 'E, E1, E10, E2 all present',
      input: 'E10, E2, E1, E',
      replacements: {'E': 'A', 'E1': 'B', 'E2': 'C', 'E10': 'D'},
      expected: 'D, C, B, A',
    ),

    Test(
      name: 'Abc and Ab - ensure Abc replaced first',
      input: 'Abc<Ab>',
      replacements: {'Ab': 'X', 'Abc': 'Y'},
      expected: 'Y<X>',
    ),

    Test(
      name: 'Complex nesting with similar names',
      input: 'Result<ResultSet<ResultType>>',
      replacements: {'Result': 'R', 'ResultSet': 'RS', 'ResultType': 'RT'},
      expected: 'R<RS<RT>>',
    ),
  ];

  for (final testCase in tests) {
    test(
      testCase.name,
      () {
        final result = MacroProperty.replaceTypeParameter(testCase.input, testCase.replacements);
        final success = result == testCase.expected;

        if (!success) {
          print('✗ ${testCase.name}');
          print('  Input:    ${testCase.input}');
          print('  Expected: ${testCase.expected}');
          print('  Got:      $result');
        }

        expect(success, isTrue);
      },
    );
  }
}

class Test {
  final String name;
  final String input;
  final Map<String, String> replacements;
  final String expected;

  Test({
    required this.name,
    required this.input,
    required this.replacements,
    required this.expected,
  });
}
