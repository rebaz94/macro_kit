import 'package:macro_kit/macro.dart';
import 'package:test/test.dart';

part 'collection_equality_test.g.dart';

@dataClassMacro
class SetWrapper with SetWrapperData {
  final Set<String> values;

  SetWrapper(this.values);
}

@dataClassMacro
class ListWrapper with ListWrapperData {
  final List<String> values;

  ListWrapper(this.values);
}

@dataClassMacro
class MapWrapper with MapWrapperData {
  final Map<String, dynamic> values;

  MapWrapper(this.values);
}

void main() {
  group('collection equality', () {
    test('of sets', () {
      final set1 = SetWrapper({'A', 'B'});
      final set2 = SetWrapper({'B', 'A'});

      expect(set1, equals(set2));
      expect(set1 == set2, isTrue);
    });

    test('of lists', () {
      final list1 = ListWrapper(['A', 'B']);
      final list2 = ListWrapper(['A', 'B']);
      final list3 = ListWrapper(['B', 'A']);

      expect(list1, equals(list2));
      expect(list1, isNot(equals(list3)));
      expect(list1 == list2, isTrue);
      expect(list1 == list3, isFalse);

      expect(list1, equals(list2));
      expect(list1, isNot(equals(list3)));
      expect(list1 == list3, isFalse);
    });

    test('of maps', () {
      final map1 = MapWrapper({'a': 'A', 'b': 'B'});
      final map2 = MapWrapper({'b': 'B', 'a': 'A'});

      expect(map1, equals(map2));
      expect(map1 == map2, isTrue);
    });
  });
}
