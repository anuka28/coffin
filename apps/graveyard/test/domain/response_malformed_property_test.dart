// Feature: graveyard-core, Property 14: A body without a usable push date is malformed
// Validates: Requirements 4.2, 4.10, 4.11
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/import_failure.dart';
import 'package:graveyard/src/domain/import_failure_kind.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/domain/repo_response_parser.dart';

import '../support/fixed_offset_zone.dart';
import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

const FetchResult _malformed = FetchFailed(
  ImportFailure(ImportFailureKind.malformedResponse),
);

/// Strings that are not ISO-8601 timestamps with a time and an offset.
const List<String> _badTimestamps = <String>[
  '',
  'yesterday',
  '2024-02-29',
  '2024-02-29T12:00:00',
  '2024-02-29 12:00:00Z',
  '20240229T120000Z',
  '2024-13-45T99:99:99Z',
];

const String _validTimestamp = '2024-02-29T12:00:00Z';

void main() {
  group('Property 14: A body without a usable push date is malformed', () {
    final RepoRef requested = RepoRef('owner', 'repo');
    final CalendarDate today = CalendarDate(2026, 6, 1);
    const FixedOffsetZone zone = FixedOffsetZone(Duration.zero);

    FetchResult parse(Object? json) => RepoResponseParser.parse(
      jsonEncode(json),
      requested: requested,
      today: today,
      zone: zone.call,
    );

    Glados3(
      anyJsonValue,
      anyReplacement,
      anyIntBetween(0, _badTimestamps.length),
      ExploreConfig(numRuns: numRuns),
    ).test('non-objects and bodies with a bad pushed_at are malformed', (
      Object? value,
      Object? replacement,
      int badIndex,
    ) {
      _counter.increment();
      // A JSON value that is not an object.
      final Object? nonObject = value is Map ? <Object?>[value] : value;
      expect(parse(nonObject), _malformed);

      // An object whose pushed_at is absent, null, a non-string or a string
      // that is not a timestamp. A valid timestamp is swapped for a bad one.
      final Object? pushedAt =
          replacement is String && replacement == _validTimestamp
          ? _badTimestamps[badIndex]
          : replacement;
      final Map<String, Object?> body = pushedAtBody(
        pushedAt,
        fields: <String, Object?>{
          'full_name': 'owner/repo',
          'updated_at': _validTimestamp,
        },
      );
      expect(parse(body), _malformed);
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
