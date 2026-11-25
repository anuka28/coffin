// Feature: graveyard-resurrection, Property 4: Raise and Lay_To_Rest keep every other field
// Validates: Requirements 2.10, 2.12
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/raise_rules.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void _expectFieldsKept(Grave before, Grave after) {
  expect(after.id, before.id);
  expect(after.name, before.name);
  expect(after.dateOfDeath, before.dateOfDeath);
  expect(after.source, before.source);
  expect(after.repo, before.repo);
}

void main() {
  group('Property 4: Raise and Lay_To_Rest keep every other field', () {
    Glados2(
      anyGraveWithRisen,
      anyCalendarDate,
      ExploreConfig(numRuns: numRuns),
    ).test('id, name, dateOfDeath, source and repo stay equal', (
      Grave grave,
      CalendarDate today,
    ) {
      _counter.increment();
      _expectFieldsKept(grave, RaiseRules.raise(grave, today));
      _expectFieldsKept(grave, RaiseRules.layToRest(grave));
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
