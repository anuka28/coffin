// Feature: graveyard-core, Property 11: A push made now reads as "Died today"
// Validates: Requirements 4.18, 4.22
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/dead_for_formatter.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/domain/repo_response_parser.dart';

import '../support/fake_clock.dart';
import '../support/fixed_offset_zone.dart';
import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

final RepoRef _requested = RepoRef('octo', 'ghost');

/// Parses a body whose `pushed_at` is [instant], with Today read from a
/// [FakeClock] set to the same instant, both through [offsetMinutes].
({FetchResult result, CalendarDate today}) _pushNow(
  DateTime instant,
  int offsetMinutes,
) {
  final FixedOffsetZone zone = FixedOffsetZone(
    Duration(minutes: offsetMinutes),
  );
  final CalendarDate today = CalendarDate.fromDateTime(
    zone(FakeClock(instant).now()),
  );
  final FetchResult result = RepoResponseParser.parse(
    '{"pushed_at":"${instant.toIso8601String()}"}',
    requested: _requested,
    today: today,
    zone: zone.call,
  );
  return (result: result, today: today);
}

void main() {
  group('Property 11: A push made now reads as "Died today"', () {
    Glados2(
      anyInstantSeconds,
      anyOffsetMinutes,
      ExploreConfig(numRuns: numRuns),
    ).test('a push made now gives the date of Today and "Died today"', (
      int seconds,
      int offsetMinutes,
    ) {
      _counter.increment();
      final DateTime instant = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      );
      final (:FetchResult result, :CalendarDate today) = _pushNow(
        instant,
        offsetMinutes,
      );

      expect(result, isA<FetchSucceeded>());
      final CalendarDate death = (result as FetchSucceeded).repo.dateOfDeath;
      expect(death, today);
      expect(death.daysUntil(today), 0);
      expect(DeadForFormatter.format(death, today), 'Died today');
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('a push at 23:30 UTC in a zone at +02:00 died today', () {
      final DateTime instant = DateTime.utc(2026, 3, 8, 23, 30);
      final (:FetchResult result, :CalendarDate today) = _pushNow(instant, 120);
      expect(today, CalendarDate(2026, 3, 9));
      final FetchSucceeded ok = result as FetchSucceeded;
      expect(ok.repo.dateOfDeath, today);
      expect(ok.repo.info, isA<RepoInfo>());
      expect(DeadForFormatter.format(ok.repo.dateOfDeath, today), 'Died today');
    });
  });
}
