// Feature: graveyard-seance, Property 11: Manual graves get the Remembered_Bonus and can reach every band
// Validates: Requirements 2.1, 2.8, 3.1, 4.6
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/seance/revival_band.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Age points of the design staircase, written out independently of the rules.
int _agePoints(int days) {
  const List<List<int>> steps = <List<int>>[
    <int>[30, 70],
    <int>[90, 66],
    <int>[180, 56],
    <int>[365, 46],
    <int>[730, 34],
    <int>[1095, 24],
    <int>[1825, 14],
    <int>[3650, 6],
  ];
  for (final List<int> step in steps) {
    if (days <= step[0]) return step[1];
  }
  return 0;
}

SeanceFacts _manual(int days, {bool hasDescription = false}) => SeanceFacts(
  dayCount: days,
  archived: false,
  stars: 0,
  hasDescription: hasDescription,
  manual: true,
);

void main() {
  group('Property 11: Manual graves', () {
    Glados(anyManualFacts, ExploreConfig(numRuns: numRuns)).test(
      'score is the age points plus the bonus, whatever hasDescription says',
      (SeanceFacts facts) {
        _counter.increment();
        final int score = SeanceRules.evaluate(facts).score;
        final int expected = (_agePoints(facts.dayCount) + 6).clamp(0, 100);

        final SeanceFacts github = SeanceFacts(
          dayCount: facts.dayCount,
          archived: false,
          stars: 0,
          hasDescription: true,
          manual: false,
        );

        expect(score, expected);
        expect(score, SeanceRules.evaluate(github).score);
        expect(
          score,
          SeanceRules.evaluate(
            _manual(facts.dayCount, hasDescription: !facts.hasDescription),
          ).score,
        );
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('pinned: 60 days is 72, Ready to rise', () {
      final result = SeanceRules.evaluate(_manual(60));
      expect(result.score, 72);
      expect(result.band, RevivalBand.readyToRise);
    });

    test('pinned: 365 days is 52, Stirring', () {
      final result = SeanceRules.evaluate(_manual(365));
      expect(result.score, 52);
      expect(result.band, RevivalBand.stirring);
    });

    test('pinned: 4,015 days is 6, Restless', () {
      final result = SeanceRules.evaluate(_manual(4015));
      expect(result.score, 6);
      expect(result.band, RevivalBand.restless);
    });
  });
}
