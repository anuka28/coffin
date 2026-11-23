import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;

import 'grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('grave generators', () {
    Glados3(
      anyCalendarDate,
      anyOffsetMinutes,
      anyProjectName,
      ExploreConfig(numRuns: numRuns),
    ).test('produce values in range', (date, offset, name) {
      _counter.increment();
      expect(date.epochDay, inInclusiveRange(0, lastGeneratedEpochDay));
      expect((offset + 720) % 30, 0);
      expect(offset, inInclusiveRange(-720, 840));
      expect(name.runes.length, lessThanOrEqualTo(90));
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
