import 'package:macro_kit/macro.dart';
import 'package:test/test.dart';

part 'extends_sealed_test.g.dart';

@dataClassMacro
class Person with PersonData {
  final String name;
  final Car car;

  Person(this.name, this.car);
}

@dataClassMacro
class Car with CarData {
  final String model;
  final Brand? brand;

  Car(this.brand, this.model);
}

@dataClassMacro
class Brand with BrandData {
  final String name;

  Brand(this.name);
}

// abstract
@Macro(DataClassMacro(discriminatorKey: 'type'))
abstract class ItemList<T> with ItemListData<T> {
  final List<T> items2;

  ItemList(List<T>? items) : items2 = items ?? [];
}

@Macro(DataClassMacro(includeDiscriminator: true))
class BrandList extends ItemList<Brand?> with BrandListData {
  BrandList(super.items);
}

@Macro(DataClassMacro(includeDiscriminator: true))
class NamedItemList<T> extends ItemList<T> with NamedItemListData<T> {
  String name;

  NamedItemList(this.name, List<T>? items) : super(items);
}

@Macro(DataClassMacro(includeDiscriminator: true))
class KeyedItemList<K, T> extends ItemList<T> with KeyedItemListData<K, T> {
  K key;

  KeyedItemList(this.key, List<T>? items) : super(items);
}

@Macro(DataClassMacro(includeDiscriminator: true))
class ComparableItemList<T extends Comparable<T>> extends ItemList<T> with ComparableItemListData<T> {
  ComparableItemList(super.items);
}

@Macro(DataClassMacro(includeDiscriminator: true))
class ComparableItemList1<T1 extends Map<String, T2>, T2> extends ItemList<String>
    with ComparableItemList1Data<T1, T2> {
  ComparableItemList1(super.items);
}

// sealed
@dataClassMacro
sealed class ItemList1<T> with ItemList1Data<T> {
  final List<T> items2;

  ItemList1(List<T>? items) : items2 = items ?? [];
}

@Macro(DataClassMacro(includeDiscriminator: true))
class BrandList1 extends ItemList1<Brand?> with BrandList1Data {
  BrandList1(super.items);
}

@Macro(DataClassMacro(includeDiscriminator: true))
class NamedItemList1<T> extends ItemList1<T> with NamedItemList1Data<T> {
  String name;

  NamedItemList1(this.name, List<T>? items) : super(items);
}

@Macro(DataClassMacro(includeDiscriminator: true))
class KeyedItemList1<K, T> extends ItemList1<T> with KeyedItemList1Data<K, T> {
  K key;

  KeyedItemList1(this.key, List<T>? items) : super(items);
}

@Macro(DataClassMacro(includeDiscriminator: true))
class ComparableItemList2<T extends Comparable<T>> extends ItemList1<T> with ComparableItemList2Data<T> {
  ComparableItemList2(super.items);
}

@Macro(DataClassMacro(includeDiscriminator: true))
class ComparableItemList3<T1 extends Map<String, T2>, T2> extends ItemList1<String>
    with ComparableItemList3Data<T1, T2> {
  ComparableItemList3(super.items);
}

void main() {
  group('Class with sealed/abstract', () {
    test('Should generate dataClass', () {
      var a = Person('Max', Car(Brand('Audi'), 'A8'));
      var aDupe = Person('Max', Car(Brand('Audi'), 'A8'));

      var b = Car(Brand('Audi'), 'A8');
      var bDupe = Car(Brand('Audi'), 'A8');

      expect(
        a.toJson(),
        equals({
          'name': 'Max',
          'car': {
            'brand': {'name': 'Audi'},
            'model': 'A8',
          },
        }),
      );
      expect(a.copyWith(name: 'BMW').name, equals('BMW'));
      expect(a, equals(aDupe));

      expect(
        b.toJson(),
        equals({
          'brand': {'name': 'Audi'},
          'model': 'A8',
        }),
      );
      expect(b.copyWith(model: 'A10').model, equals('A10'));
      expect(b, equals(bDupe));
    });

    test('Should generate dataClass with abstract', () {
      var a = BrandList([Brand('Audi')]);
      var aDupe = BrandList([Brand('Audi')]);

      var b = NamedItemList<String>('named', ['a', 'b']);
      var bDupe = NamedItemList<String>('named', ['a', 'b']);

      var c = KeyedItemList<String, int>('named', [1, 2]);
      var cDupe = KeyedItemList<String, int>('named', [1, 2]);

      var d = ComparableItemList<String>(['a', 'b']);
      var dDupe = ComparableItemList<String>(['a', 'b']);

      var e = ComparableItemList1<Map<String, int>, int>(['a', 'b']);
      var eDupe = ComparableItemList1<Map<String, int>, int>(['a', 'b']);

      expect(
        a.toJson(),
        equals({
          'items': [
            {'name': 'Audi'},
          ],
          'type': 'BrandList',
        }),
      );
      expect(a.copyWith(items2: [Brand('BMW')]).items2, equals([Brand('BMW')]));
      expect(a, equals(aDupe));
      expect(a, isA<ItemList<Brand?>>());

      expect(
        b.toJson((v) => v),
        equals({
          'name': 'named',
          'items': ['a', 'b'],
          'type': 'NamedItemList',
        }),
      );
      expect(b.copyWith(name: 'A10').name, equals('A10'));
      expect(b, equals(bDupe));
      expect(b, isA<ItemList<String>>());

      expect(
        c.toJson((v) => v, (v) => v),
        equals({
          'key': 'named',
          'items': [1, 2],
          'type': 'KeyedItemList',
        }),
      );
      expect(c.copyWith(key: 'A10').key, equals('A10'));
      expect(c, equals(cDupe));
      expect(c, isA<ItemList<int>>());

      expect(
        d.toJson((v) => v),
        equals({
          'items': ['a', 'b'],
          'type': 'ComparableItemList',
        }),
      );
      expect(d.copyWith(items2: ['a', 'b', 'c']).items2, equals(['a', 'b', 'c']));
      expect(d, equals(dDupe));
      expect(d, isA<ItemList<String>>());

      expect(
        e.toJson(
          (v) => v,
          (v) => v,
        ),
        equals({
          'items': ['a', 'b'],
          'type': 'ComparableItemList1',
        }),
      );
      expect(e.copyWith(items2: ['a', 'b', 'c']).items2, equals(['a', 'b', 'c']));
      expect(e, equals(eDupe));
      expect(e, isA<ItemList<String>>());
    });

    test('Should generate dataClass with sealed', () {
      var a = BrandList1([Brand('Audi')]);
      var aDupe = BrandList1([Brand('Audi')]);

      var b = NamedItemList1<String>('named', ['a', 'b']);
      var bDupe = NamedItemList1<String>('named', ['a', 'b']);

      var c = KeyedItemList1<String, int>('named', [1, 2]);
      var cDupe = KeyedItemList1<String, int>('named', [1, 2]);

      var d = ComparableItemList2<String>(['a', 'b']);
      var dDupe = ComparableItemList2<String>(['a', 'b']);

      var e = ComparableItemList3<Map<String, int>, int>(['a', 'b']);
      var eDupe = ComparableItemList3<Map<String, int>, int>(['a', 'b']);

      expect(
        a.toJson(),
        equals({
          'items': [
            {'name': 'Audi'},
          ],
          'type': 'BrandList1',
        }),
      );
      expect(a.copyWith(items2: [Brand('BMW')]).items2, equals([Brand('BMW')]));
      expect(a, equals(aDupe));
      expect(a, isA<ItemList1<Brand?>>());

      expect(
        b.toJson((v) => v),
        equals({
          'name': 'named',
          'items': ['a', 'b'],
          'type': 'NamedItemList1',
        }),
      );
      expect(b.copyWith(name: 'A10').name, equals('A10'));
      expect(b, equals(bDupe));
      expect(b, isA<ItemList1<String>>());

      expect(
        c.toJson((v) => v, (v) => v),
        equals({
          'key': 'named',
          'items': [1, 2],
          'type': 'KeyedItemList1',
        }),
      );
      expect(c.copyWith(key: 'A10').key, equals('A10'));
      expect(c, equals(cDupe));
      expect(c, isA<ItemList1<int>>());

      expect(
        d.toJson((v) => v),
        equals({
          'items': ['a', 'b'],
          'type': 'ComparableItemList2',
        }),
      );
      expect(d.copyWith(items2: ['a', 'b', 'c']).items2, equals(['a', 'b', 'c']));
      expect(d, equals(dDupe));
      expect(d, isA<ItemList1<String>>());

      expect(
        e.toJson(
          (v) => v,
          (v) => v,
        ),
        equals({
          'items': ['a', 'b'],
          'type': 'ComparableItemList3',
        }),
      );
      expect(e.copyWith(items2: ['a', 'b', 'c']).items2, equals(['a', 'b', 'c']));
      expect(e, equals(eDupe));
      expect(e, isA<ItemList1<String>>());
    });
  });
}
