// Feature: graveyard-core, Property 12: Clamping keeps the date in range
// Validates: Requirements 4.12, 4.13
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

const RepoRef _requested = RepoRef('octo', 'cat');

/// Days subtracted from the generated local date so some of them fall before
/// 1970-01-01 (the generator itself starts on that day).
const int _shiftDays = 400;

CalendarDate _parseDate({
  required CalendarDate local,
  required CalendarDate today,
  required int offsetMinutes,
  required int secondOfDay,
}) {
  final int offsetSeconds = offsetMinutes * 60;
  // The instant whose local calendar day under the offset is `local`.
  final int seconds = local.epochDay * 86400 + secondOfDay - offsetSeconds;
  final String pushedAt = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toIso8601String();
  final FetchResult result = RepoResponseParser.parse(
    jsonEncode(pushedAtBody(pushedAt)),
    requested: _requested,
    today: today,
    zone: FixedOffsetZone(Duration(minutes: offsetMinutes)).call,
  );
  expect(result, isA<FetchSucceeded>());
  return (result as FetchSucceeded).repo.dateOfDeath;
}

void _expectClamped(
  CalendarDate local,
  CalendarDate today,
  int offsetMinutes,
  int secondOfDay,
) {
  final CalendarDate died = _parseDate(
    local: local,
    today: today,
    offsetMinutes: offsetMinutes,
    secondOfDay: secondOfDay,
  );

  expect(died.compareTo(CalendarDate.earliest) >= 0, isTrue);
  expect(died.compareTo(today) <= 0, isTrue);
  if (local.compareTo(today) > 0) {
    expect(died, today, reason: '$local is after $today');
  } else if (local.compareTo(CalendarDate.earliest) < 0) {
    expect(died, CalendarDate.earliest, reason: '$local is before 1970');
  } else {
    expect(died, local, reason: '$local is in range');
  }
}

void main() {
  group('Property 12: Clamping keeps the date in range', () {
    // One int carries both the second of the day and the offset index.
    Glados3(
      anyCalendarDate,
      anyCalendarDate,
      anyIntBetween(0, 86400 * 53),
      ExploreConfig(numRuns: numRuns),
    ).test('the date is clamped to 1970-01-01 and Today, else unchanged', (
      CalendarDate generated,
      CalendarDate today,
      int packed,
    ) {
      _counter.increment();
      final CalendarDate local = CalendarDate.fromEpochDay(
        generated.epochDay - _shiftDays,
      );
      final int offsetMinutes = -720 + 30 * (packed ~/ 86400);
      _expectClamped(local, today, offsetMinutes, packed % 86400);
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('a future local date returns Today', () {
      final CalendarDate today = CalendarDate(2026, 5, 10);
      _expectClamped(CalendarDate(2026, 5, 11), today, 0, 0);
      _expectClamped(CalendarDate(2099, 12, 31), today, 840 - 120, 86399);
    });

    test('a local date before 1970-01-01 returns 1970-01-01', () {
      final CalendarDate today = CalendarDate(2026, 5, 10);
      _expectClamped(CalendarDate(1969, 12, 31), today, 0, 0);
      _expectClamped(CalendarDate(1960, 6, 1), today, -300, 43200);
    });

    test('Today and 1970-01-01 themselves are unchanged', () {
      final CalendarDate today = CalendarDate(2026, 5, 10);
      _expectClamped(today, today, 0, 0);
      _expectClamped(CalendarDate.earliest, today, 0, 0);
    });
  });
}
