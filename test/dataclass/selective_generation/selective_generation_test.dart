import 'dart:convert';

import 'package:macro_kit/macro_kit.dart';
import 'package:test/test.dart';

part 'selective_generation_test.g.dart';

@Macro(DataClassMacro(fromJson: false, toJson: true, copyWith: true, toStringOverride: false, equal: false))
class A with AData {
  A(this.a);

  final String a;
}

@Macro(DataClassMacro(fromJson: false, toJson: false, copyWith: false, toStringOverride: true, equal: true))
class B with BData {
  B(this.b);

  final String b;
}

@Macro(DataClassMacro(copyWithAsOption: true))
class C with CData {
  C(this.c, this.c2);

  final String? c;

  @JsonKey(copyWithAsOption: false)
  final String? c2;
}

@dataClassMacro
class E with EData {
  E(this.e, this.e2);

  @JsonKey(copyWithAsOption: true)
  final String? e;

  @JsonKey(copyWithAsOption: false)
  final String? e2;
}

@dataClassMacro
class RepoFull with RepoFullData {
  RepoFull({
    this.issues,
    this.issues2,
  });

  @JsonKey(name: 'issues', fromJson: issuesFromJson, toJson: issuesToJson)
  final Paginated<Issue>? issues;

  @JsonKey(name: 'issues', includeFromJson: false, includeToJson: false)
  final Paginated2<Issue>? issues2;

  static Paginated<Issue>? issuesFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return PaginatedData.fromJson(json, (v) => IssueData.fromJson(v as Map<String, dynamic>));
  }

  static Map<String, dynamic>? issuesToJson(Paginated<Issue>? issues) {
    return issues?.toJson((e) => e.toJson());
  }
}

@dataClassMacro
class Issue with IssueData {
  Issue({required this.name});

  final String name;
}

@dataClassMacro
class Paginated<T> with PaginatedData<T> {
  final T value;

  Paginated({required this.value});
}

@dataClassMacro
class Paginated2<T> with Paginated2Data<T> {
  final T value;

  Paginated2({required this.value});
}

void main() {
  group('Selective generation', () {
    test('Should only generate encode and copy methods', () {
      var a = A('test');

      // should work
      expect(a.toJson(), equals({'a': 'test'}));
      expect(jsonEncode(a.toJson()), equals('{"a":"test"}'));
      expect(a.copyWith(a: 'test2').a, equals('test2'));

      // should not work
      expect(a, isNot(equals(A('test'))));
      expect(a.toString(), equals("Instance of 'A'"));
    });

    test('Should only generate equals and stringify', () {
      var b = B('hi');

      // should work
      expect(b, equals(B('hi')));
      expect(b.toString(), equals('B{b: hi}'));

      // should not work
      expect(() => (b as dynamic).toJson, throwsNoSuchMethodError);
      expect(() => (b as dynamic).copyWith, throwsNoSuchMethodError);
    });

    test('Should generate copyWith with dataclass option', () {
      var c = C('hi', null);

      // should work
      expect(c, equals(C('hi', null)));
      expect(c.toString(), equals('C{c: hi, c2: null}'));
      expect(c.copyWith(c: Option.value('test2')).c, equals('test2'));
      expect(c.copyWith(c2: null).c, equals('hi'));
    });

    test('Should generate copyWith with key option', () {
      var e = E('hi', null);

      // should work
      expect(e, equals(E('hi', null)));
      expect(e.toString(), equals('E{e: hi, e2: null}'));
      expect(e.copyWith(e: Option.value('test2')).e, equals('test2'));
      expect(e.copyWith(e2: null).e, equals('hi'));
    });

    test('Should generate without generic argument', () {
      var e = RepoFull(
        issues: Paginated(value: Issue(name: 'test1')),
        issues2: Paginated2(value: Issue(name: 'test2')),
      );

      // should work
      expect(
        e,
        equals(
          RepoFull(
            issues: Paginated(value: Issue(name: 'test1')),
            issues2: Paginated2(value: Issue(name: 'test2')),
          ),
        ),
      );
      expect(
        e.toString(),
        equals(
          'RepoFull{issues: Paginated<Issue>{value: Issue{name: test1}}, issues2: Paginated2<Issue>{value: Issue{name: test2}}}',
        ),
      );
      expect(e.toJson(), {
        'issues': {
          'value': {'name': 'test1'},
        },
      });
      expect(
        e
            .copyWith(
              issues: Paginated(value: Issue(name: 'test2')),
            )
            .issues
            ?.value,
        equals(Issue(name: 'test2')),
      );
    });
  });
}
