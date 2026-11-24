// Validates: Requirements 2.1, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 14.1
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/seance/revival_band.dart';
import 'package:graveyard/src/domain/seance/revival_steps.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_result.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';

/// Largest integer that is exact on Flutter Web (2^53 - 1).
const int _maxSafeInt = 9007199254740991;

SeanceFacts _facts({
  int dayCount = 0,
  bool archived = false,
  int stars = 0,
  bool hasDescription = false,
  bool manual = false,
}) => SeanceFacts(
  dayCount: dayCount,
  archived: archived,
  stars: stars,
  hasDescription: hasDescription,
  manual: manual,
);

int _score(SeanceFacts f) => SeanceRules.evaluate(f).score;

void main() {
  group('SeanceRules.evaluate age points', () {
    const Map<int, int> expected = <int, int>{
      0: 70,
      30: 70,
      31: 66,
      90: 66,
      91: 56,
      180: 56,
      181: 46,
      365: 46,
      366: 34,
      730: 34,
      731: 24,
      1095: 24,
      1096: 14,
      1825: 14,
      1826: 6,
      3650: 6,
      3651: 0,
    };
    expected.forEach((int days, int points) {
      test('dayCount $days gives $points', () {
        expect(_score(_facts(dayCount: days)), points);
      });
    });

    test('age points never increase as dayCount grows', () {
      int previous = _score(_facts(dayCount: 0));
      for (int days = 1; days <= 4000; days++) {
        final int current = _score(_facts(dayCount: days));
        expect(current <= previous, isTrue, reason: 'day $days');
        previous = current;
      }
    });
  });

  group('SeanceRules.evaluate star points', () {
    test('0 stars give 0 points', () {
      expect(_score(_facts(dayCount: 3651, stars: 0)), 0);
    });

    test('1 star gives 2 points', () {
      expect(_score(_facts(dayCount: 3651, stars: 1)), 2);
    });

    test('511 stars give 10 points', () {
      expect(_score(_facts(dayCount: 3651, stars: 511)), 10);
    });

    test('1023 stars and above give exactly 10 points', () {
      for (final int stars in <int>[1023, 1024, 2000, 60680, 181400, 1048576]) {
        expect(
          _score(_facts(dayCount: 3651, stars: stars)),
          10,
          reason: '$stars',
        );
      }
    });

    test('star points never decrease with more stars', () {
      int previous = 0;
      for (int stars = 0; stars <= 2100; stars++) {
        final int current = _score(_facts(dayCount: 3651, stars: stars));
        expect(current >= previous, isTrue, reason: '$stars stars');
        previous = current;
      }
    });

    test('a negative star count gives 0 points', () {
      expect(_score(_facts(dayCount: 3651, stars: -5)), 0);
    });
  });

  group('SeanceRules.evaluate Remembered_Bonus', () {
    test('a manual grave gets 6 with hasDescription true', () {
      expect(
        _score(_facts(dayCount: 3651, manual: true, hasDescription: true)),
        6,
      );
    });

    test('a manual grave gets 6 with hasDescription false', () {
      expect(_score(_facts(dayCount: 3651, manual: true)), 6);
    });

    test('a described GitHub grave gets 6', () {
      expect(_score(_facts(dayCount: 3651, hasDescription: true)), 6);
    });

    test('an undescribed GitHub grave gets 0', () {
      expect(_score(_facts(dayCount: 3651)), 0);
    });
  });

  group('SeanceRules.evaluate archived penalty', () {
    test('archived lowers the raw score by exactly 25', () {
      final int plain = _score(_facts(dayCount: 100, stars: 40));
      final int archived = _score(
        _facts(dayCount: 100, stars: 40, archived: true),
      );
      expect(plain - archived, 25);
    });

    test('archived at day 0 with no other points gives 45', () {
      expect(_score(_facts(archived: true)), 45);
    });
  });

  group('SeanceRules.evaluate bounds', () {
    test('the raw maximum of 86 stays at 86', () {
      expect(
        _score(_facts(dayCount: 0, stars: 1023, hasDescription: true)),
        86,
      );
    });

    test(
      'the same maximum is reached by a manual grave with 10 star points',
      () {
        expect(_score(_facts(dayCount: 0, stars: 1023, manual: true)), 86);
      },
    );

    test('an archived grave dead 4015 days with no bonus clamps to 0', () {
      final SeanceResult result = SeanceRules.evaluate(
        _facts(dayCount: 4015, archived: true),
      );
      expect(result.score, 0);
      expect(result.band, RevivalBand.restless);
    });

    test('every score of a sample sweep is within 0 to 100', () {
      for (final int days in <int>[0, 30, 31, 365, 366, 3650, 3651, 20000]) {
        for (final bool archived in <bool>[false, true]) {
          for (final bool described in <bool>[false, true]) {
            for (final int stars in <int>[0, 1, 511, 1023, 181400]) {
              final int score = _score(
                _facts(
                  dayCount: days,
                  archived: archived,
                  hasDescription: described,
                  stars: stars,
                ),
              );
              expect(score, inInclusiveRange(0, 100));
            }
          }
        }
      }
    });

    test('the largest star count below 2^53 does not throw', () {
      final SeanceFacts facts = _facts(dayCount: 0, stars: _maxSafeInt - 1);
      expect(() => SeanceRules.evaluate(facts), returnsNormally);
      expect(_score(facts), 80);
    });

    test('a huge dayCount does not throw', () {
      final SeanceFacts facts = _facts(dayCount: _maxSafeInt - 1);
      expect(() => SeanceRules.evaluate(facts), returnsNormally);
      expect(_score(facts), 0);
    });
  });

  group('SeanceRules.evaluate result', () {
    test('band and steps come from the score and facts', () {
      final SeanceFacts f = _facts(dayCount: 400, archived: true);
      final SeanceResult result = SeanceRules.evaluate(f);
      expect(result.band, RevivalBand.forScore(result.score));
      expect(result.steps, RevivalSteps.choose(f));
      expect(result.steps, hasLength(3));
    });

    test('the same facts give an equal result twice', () {
      final SeanceFacts f = _facts(dayCount: 500, stars: 40, manual: true);
      expect(SeanceRules.evaluate(f), SeanceRules.evaluate(f));
    });

    test('equal but separate facts give an equal result', () {
      expect(
        SeanceRules.evaluate(_facts(dayCount: 77, stars: 3)),
        SeanceRules.evaluate(_facts(dayCount: 77, stars: 3)),
      );
    });
  });
}
