// Feature: graveyard-core, Property 22: The rate-limit wait is rounded up and at least one minute
// Validates: Requirements 9.3
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/rate_limit_wait.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Base moment the generated offsets are added to.
final DateTime _base = DateTime.utc(2026, 5, 10, 12);

void main() {
  group('Property 22: The rate-limit wait is rounded up and at least one '
      'minute', () {
    // Offsets from -3600 s to 100,000 s, in milliseconds.
    Glados2(
      anyIntBetween(-3600 * 1000, 100000 * 1000 + 1),
      anyIntBetween(-3600 * 1000, 100000 * 1000 + 1),
      ExploreConfig(numRuns: numRuns),
    ).test('the wait is at least 1, not below the exact wait, and under it '
        'plus one minute', (int resetOffsetMs, int nowOffsetMs) {
      _counter.increment();
      final DateTime resetAt = _base.add(Duration(milliseconds: resetOffsetMs));
      final DateTime now = _base.add(Duration(milliseconds: nowOffsetMs));
      final int diffMs = resetOffsetMs - nowOffsetMs;
      final double exact = diffMs / 60000;

      final int minutes = RateLimitWait.minutes(resetAt: resetAt, now: now);

      expect(minutes, greaterThanOrEqualTo(1));
      expect(minutes, greaterThanOrEqualTo(exact));
      if (diffMs > 60000) {
        expect(minutes, lessThan(exact + 1));
      }
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('examples: past, equal, partial and exact minutes', () {
      final DateTime now = _base;
      int wait(int ms) => RateLimitWait.minutes(
        resetAt: now.add(Duration(milliseconds: ms)),
        now: now,
      );
      expect(wait(-3600000), 1);
      expect(wait(0), 1);
      expect(wait(1), 1);
      expect(wait(60000), 1);
      expect(wait(60001), 2);
      expect(wait(120000), 2);
      expect(wait(100000000), 1667);
    });
  });
}
