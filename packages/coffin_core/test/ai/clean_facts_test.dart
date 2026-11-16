import 'package:coffin_core/src/ai/ai_fact_keys.dart';
import 'package:coffin_core/src/ai/clean_facts.dart';
import 'package:flutter_test/flutter_test.dart';

int? _streak(Object? value) =>
    CleanFacts.from(<String, Object?>{AiFactKeys.streakCount: value})
        .streakCount;

String? _ghost(Object? value) =>
    CleanFacts.from(<String, Object?>{AiFactKeys.ghostName: value}).ghostName;

void main() {
  group('CleanFacts counts', () {
    // Expected counts from design.md's cross-platform list.
    final cases = <String, (Object?, int?)>{
      '0': (0, 0),
      '-0.0': (-0.0, 0),
      '5.0': (5.0, 5),
      '1000000': (1000000, 1000000),
      '1000000.0': (1000000.0, 1000000),
      '1000001': (1000001, null),
      '-1': (-1, null),
      '0.5': (0.5, null),
      'NaN': (double.nan, null),
      'Infinity': (double.infinity, null),
      '-Infinity': (double.negativeInfinity, null),
      "'5'": ('5', null),
      'true': (true, null),
      'null': (null, null),
      '4294967295': (4294967295, null),
      'list': (<int>[5], null),
    };
    cases.forEach((label, c) {
      test('$label -> ${c.$2}', () {
        expect(_streak(c.$1), c.$2);
        final days = CleanFacts.from(<String, Object?>{
          AiFactKeys.daysSinceLastCommit: c.$1,
        }).daysSinceLastCommit;
        expect(days, c.$2);
      });
    });

    test('-0.0 prints as 0', () {
      expect('${_streak(-0.0)}', '0');
      expect('${_streak(0.0)}', '0');
    });

    test('5.0 and 5 both give 5', () {
      expect(_streak(5.0), 5);
      expect(_streak(5), 5);
      expect(_streak(5.0).toString(), '5');
    });
  });

  group('CleanFacts names', () {
    test('keeps emoji and accents', () {
      expect(_ghost('  Bóo \u{1F47B}  '), 'Bóo \u{1F47B}');
    });

    test('drops control characters', () {
      expect(_ghost('Bo\u0000\u0007o'), 'Boo');
    });

    test('cuts at 24 units without splitting a pair', () {
      final long = _ghost('${'a' * 23}\u{1F47B}${'b' * 10}');
      expect(long, 'a' * 23);
      expect(_ghost('x' * 40), 'x' * 24);
    });

    test('a banned word is missing', () {
      expect(_ghost('Murderous'), isNull);
    });

    test('a blank or empty name is missing', () {
      expect(_ghost('   \t\n'), isNull);
      expect(_ghost(''), isNull);
      expect(_ghost('\u0000'), isNull);
    });

    test('a wrong-type name is missing', () {
      expect(_ghost(5), isNull);
      expect(_ghost(true), isNull);
      expect(_ghost(null), isNull);
      expect(_ghost(<String>['Boo']), isNull);
    });

    test('project name is read from its own key', () {
      final facts = CleanFacts.from(<String, Object?>{
        AiFactKeys.projectName: ' Old  Repo ',
      });
      expect(facts.projectName, 'Old Repo');
      expect(facts.ghostName, isNull);
    });
  });

  group('CleanFacts keys', () {
    test('extra keys and an empty key are ignored', () {
      final facts = CleanFacts.from(<String, Object?>{
        '': 7,
        'other': 'Boo',
        'streak': 3,
        AiFactKeys.streakCount: 2,
      });
      expect(facts.streakCount, 2);
      expect(facts.daysSinceLastCommit, isNull);
      expect(facts.ghostName, isNull);
      expect(facts.projectName, isNull);
    });

    test('an empty map gives no facts', () {
      final facts = CleanFacts.from(const <String, Object?>{});
      expect(facts.streakCount, isNull);
      expect(facts.daysSinceLastCommit, isNull);
      expect(facts.ghostName, isNull);
      expect(facts.projectName, isNull);
    });
  });
}
