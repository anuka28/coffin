// Feature: graveyard-seance, Property 6: A description never scores lower
// Validates: Requirements 2.8
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

SeanceFacts _withDescription(SeanceFacts f, {required bool described}) =>
    SeanceFacts(
      dayCount: f.dayCount,
      archived: f.archived,
      stars: f.stars,
      hasDescription: described,
      manual: f.manual,
    );

void main() {
  group('Property 6: A description never scores lower', () {
    Glados(anySeanceFacts, ExploreConfig(numRuns: numRuns)).test(
      'with all else equal, a description scores at least as high as none',
      (SeanceFacts facts) {
        _counter.increment();
        final int without = SeanceRules.evaluate(
          _withDescription(facts, described: false),
        ).score;
        final int with_ = SeanceRules.evaluate(
          _withDescription(facts, described: true),
        ).score;
        expect(with_, greaterThanOrEqualTo(without), reason: '$facts');
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('pinned: a description adds the bonus below the clamp', () {
      const SeanceFacts base = SeanceFacts(
        dayCount: 400,
        archived: false,
        stars: 0,
        hasDescription: false,
        manual: false,
      );
      final int without = SeanceRules.evaluate(base).score;
      final int with_ = SeanceRules.evaluate(
        _withDescription(base, described: true),
      ).score;
      expect(with_, without + 6);
    });
  });
}
