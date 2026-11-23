// Feature: graveyard-core, Property 16: The dead-for text follows the calendar model
// Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.9
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/dead_for.dart';
import 'package:graveyard/src/domain/dead_for_unit.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Independent model: the largest `k` from 0 to 1200 for which the death date
/// moved by `k` months is not after [today].
int _modelMonths(CalendarDate death, CalendarDate today) {
  var months = 0;
  for (var k = 0; k <= 1200; k++) {
    if (death.addMonthsClamped(k).compareTo(today) <= 0) {
      months = k;
    } else {
      break;
    }
  }
  return months;
}

/// The decision table of the design, applied to the model's month count.
DeadFor _model(CalendarDate death, CalendarDate today) {
  final int days = death.daysUntil(today);
  if (days <= 0) return const DeadFor(DeadForUnit.today, 0);
  final int months = _modelMonths(death, today);
  if (months >= 12) return DeadFor(DeadForUnit.years, months ~/ 12);
  if (months >= 1) return DeadFor(DeadForUnit.months, months);
  if (days >= 7) return DeadFor(DeadForUnit.weeks, days ~/ 7);
  return DeadFor(DeadForUnit.days, days);
}

void main() {
  group('Property 16: The dead-for text follows the calendar model', () {
    Glados2(
      anyCalendarDate,
      anyCalendarDate,
      ExploreConfig(numRuns: numRuns),
    ).test('DeadFor.between equals the independent model', (
      CalendarDate death,
      CalendarDate drawnToday,
    ) {
      _counter.increment();
      // The model searches 0 to 1200 months only, so keep Today inside that
      // range (a span over 100 years would saturate the model, not the code).
      final CalendarDate limit = death.addMonthsClamped(1200);
      final CalendarDate today = drawnToday.compareTo(limit) > 0
          ? limit
          : drawnToday;
      final DeadFor actual = DeadFor.between(death, today);
      final DeadFor expected = _model(death, today);
      expect(
        actual,
        expected,
        reason: 'death $death, today $today: ${actual.text}',
      );
      if (death.compareTo(today) > 0) {
        expect(actual.text, 'Died today');
      }
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('a death on the 31st and Today on a shorter month end is 1 month', () {
      final CalendarDate death = CalendarDate(2025, 1, 31);
      expect(death.wholeMonthsUntil(CalendarDate(2025, 2, 28)), 1);
      expect(
        DeadFor.between(death, CalendarDate(2025, 2, 28)).text,
        'Dead for 1 month',
      );
      expect(
        DeadFor.between(death, CalendarDate(2025, 2, 27)).text,
        'Dead for 3 weeks',
      );
    });
  });
}
