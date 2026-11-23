// Feature: graveyard-core, Property 17: The dead-for text is never malformed
// Validates: Requirements 5.8, 5.11
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/dead_for_formatter.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

final RegExp _shape = RegExp(
  r'^(Died today|Dead for ([1-9][0-9]*) (day|week|month|year)s?)$',
);

/// The forbidden phrases as whole numbers: `1 years` must not match inside
/// `51 years`, which is a valid text.
final List<RegExp> _forbidden = <RegExp>[
  RegExp(r'(?<![0-9])0 days'),
  RegExp(r'(?<![0-9])1 days'),
  RegExp(r'(?<![0-9])1 weeks'),
  RegExp(r'(?<![0-9])1 months'),
  RegExp(r'(?<![0-9])1 years'),
  RegExp('-'),
];

void main() {
  group('Property 17: The dead-for text is never malformed', () {
    Glados2(
      anyCalendarDate,
      anyCalendarDate,
      ExploreConfig(numRuns: numRuns),
    ).test('the text is non-empty, stable and has a well-formed shape', (
      CalendarDate death,
      CalendarDate today,
    ) {
      _counter.increment();
      final String text = DeadForFormatter.format(death, today);

      expect(text, isNotEmpty);
      expect(DeadForFormatter.format(death, today), text);
      for (final RegExp bad in _forbidden) {
        expect(
          bad.hasMatch(text),
          isFalse,
          reason: '"$text" matches /${bad.pattern}/',
        );
      }

      final RegExpMatch? match = _shape.firstMatch(text);
      expect(match, isNotNull, reason: '"$text" has the wrong shape');
      if (text != 'Died today') {
        final int count = int.parse(match!.group(2)!);
        final String unit = match.group(3)!;
        expect(count, isPositive);
        expect(
          text.endsWith(count == 1 ? unit : '${unit}s'),
          isTrue,
          reason: '"$text" has the wrong singular or plural',
        );
      }
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('named examples have the expected shape', () {
      final CalendarDate today = CalendarDate(2026, 3, 8);
      expect(DeadForFormatter.format(today, today), 'Died today');
      expect(
        DeadForFormatter.format(CalendarDate(2026, 3, 9), today),
        'Died today',
      );
      expect(
        DeadForFormatter.format(CalendarDate(2026, 3, 7), today),
        'Dead for 1 day',
      );
      expect(
        DeadForFormatter.format(CalendarDate(2025, 3, 8), today),
        'Dead for 1 year',
      );
    });
  });
}
