// Feature: graveyard-seance, Property 5: More stars never scores lower
// Validates: Requirements 2.7
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

SeanceFacts _withStars(SeanceFacts f, int stars) => SeanceFacts(
  dayCount: f.dayCount,
  archived: f.archived,
  stars: stars,
  hasDescription: f.hasDescription,
  manual: f.manual,
);

void main() {
  group('Property 5: More stars never scores lower', () {
    Glados3(
      anySeanceFacts,
      anyIntBetween(0, 1048577),
      anyIntBetween(0, 1048577),
      ExploreConfig(numRuns: numRuns),
    ).test('with all else equal, stars a <= b gives score(a) <= score(b)', (
      SeanceFacts facts,
      int x,
      int y,
    ) {
      _counter.increment();
      final int low = x < y ? x : y;
      final int high = x < y ? y : x;
      final int scoreLow = SeanceRules.evaluate(_withStars(facts, low)).score;
      final int scoreHigh = SeanceRules.evaluate(_withStars(facts, high)).score;
      expect(
        scoreLow,
        lessThanOrEqualTo(scoreHigh),
        reason: '$low stars vs $high stars on $facts',
      );
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('pinned star counts never lower the score', () {
      const List<int> stars = <int>[0, 1, 511, 1023, 2000, 60680, 181400];
      const SeanceFacts base = SeanceFacts(
        dayCount: 400,
        archived: false,
        stars: 0,
        hasDescription: false,
        manual: false,
      );
      int previous = -1;
      for (final int s in stars) {
        final int score = SeanceRules.evaluate(_withStars(base, s)).score;
        expect(score, greaterThanOrEqualTo(previous), reason: '$s stars');
        previous = score;
      }
    });
  });
}
