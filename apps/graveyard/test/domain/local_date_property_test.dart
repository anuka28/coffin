// Feature: graveyard-core, Property 10: The local date is the instant plus the offset
// Validates: Requirements 4.1, 4.3, 4.17, 4.22
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/domain/repo_response_parser.dart';

import '../support/fixed_offset_zone.dart';
import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Integer floor division for a positive [divisor], web-safe.
int _floorDiv(int a, int divisor) {
  final int q = a ~/ divisor;
  return (a % divisor != 0 && a < 0) ? q - 1 : q;
}

void main() {
  group('Property 10: The local date is the instant plus the offset', () {
    // Far beyond any generated local date, so Today never clamps.
    final CalendarDate today = CalendarDate.fromEpochDay(60000);
    final RepoRef requested = RepoRef('owner', 'repo');

    Glados2(
      anyInstantSeconds,
      anyOffsetMinutes,
      ExploreConfig(numRuns: numRuns),
    ).test('dateOfDeath equals floorDiv(seconds + offsetSeconds, 86400)', (
      int seconds,
      int offsetMinutes,
    ) {
      _counter.increment();
      final String pushedAt = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ).toIso8601String();
      final FetchResult result = RepoResponseParser.parse(
        jsonEncode(<String, Object?>{'pushed_at': pushedAt}),
        requested: requested,
        today: today,
        zone: FixedOffsetZone(Duration(minutes: offsetMinutes)).call,
      );
      expect(result, isA<FetchSucceeded>());
      final CalendarDate actual = (result as FetchSucceeded).repo.dateOfDeath;
      final int day = _floorDiv(seconds + offsetMinutes * 60, 86400);
      if (day >= 0) {
        expect(actual, CalendarDate.fromEpochDay(day));
      } else {
        // Before 1970-01-01 the date is clamped to the earliest day.
        expect(actual, CalendarDate.earliest);
      }
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
