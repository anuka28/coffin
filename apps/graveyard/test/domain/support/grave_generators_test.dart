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

  group('resurrection generators', () {
    final RunCounter counter = RunCounter();
    Glados3(
      anyPlayingSet,
      anyGraveId,
      anyWideElapsedMs,
      ExploreConfig(numRuns: numRuns),
    ).test('produce values in range', (playing, id, wide) {
      counter.increment();
      final ids = playing.graves.map((g) => g.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.length, lessThanOrEqualTo(12));
      expect(
        playing.playing.where((p) => !ids.contains(p)).length,
        lessThanOrEqualTo(2),
      );
      expect(id, isNotEmpty);
      expect(id.codeUnits.every((c) => c >= 0x30 && c <= 0x7A), isTrue);
      expect(wide, inInclusiveRange(-500, 3300));
    });
    Glados3(
      anyStoneWidth,
      anyStoneHeight,
      anyTextScale,
      ExploreConfig(numRuns: numRuns),
    ).test('stone and text scale in range', (w, h, s) {
      expect(w, inInclusiveRange(120, 400));
      expect(h, inInclusiveRange(160, 480));
      expect(s, inInclusiveRange(1.0, 2.0));
    });
    Glados2(
      anyElapsedMs,
      anyGraveWithRisen,
      ExploreConfig(numRuns: numRuns),
    ).test('elapsed in play length', (ms, grave) {
      expect(ms, inInclusiveRange(0, 2800));
      expect(grave.id, isNotEmpty);
    });
    test('ran the configured number of times', () {
      counter.expectRuns(numRuns);
    });
  });
}
