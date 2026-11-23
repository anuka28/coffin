// Feature: graveyard-core, Property 13: Optional fields default, extra fields are ignored
// Validates: Requirements 4.2, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.14
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/fetched_repo.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/domain/repo_response_parser.dart';

import '../support/fixed_offset_zone.dart';
import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

const List<String> _optionalKeys = <String>[
  'full_name',
  'description',
  'html_url',
  'archived',
  'stargazers_count',
];

void main() {
  group('Property 13: Optional fields default, extra fields are ignored', () {
    final CalendarDate today = CalendarDate(2026, 6, 1);
    final RepoRef requested = RepoRef('owner', 'repo');
    const FixedOffsetZone zone = FixedOffsetZone(Duration.zero);
    final CalendarDate pushedDay = CalendarDate(2024, 2, 29);

    FetchedRepo parse(Map<String, Object?> body) {
      final FetchResult result = RepoResponseParser.parse(
        jsonEncode(body),
        requested: requested,
        today: today,
        zone: zone.call,
      );
      expect(result, isA<FetchSucceeded>());
      return (result as FetchSucceeded).repo;
    }

    Glados3(
      anyListBetween<Object?>(5, 6, anyReplacement),
      anyJsonValue,
      anyJsonValue,
      ExploreConfig(numRuns: numRuns),
    ).test('optional fields follow the defaults and unknown fields change '
        'nothing', (
      List<Object?> replacements,
      Object? updatedAt,
      Object? extra,
    ) {
      _counter.increment();
      final Map<String, Object?> fields = <String, Object?>{};
      for (int i = 0; i < _optionalKeys.length; i++) {
        final Object? value = replacements[i];
        if (!identical(value, absentField)) {
          fields[_optionalKeys[i]] = value;
        }
      }
      final Map<String, Object?> body = pushedAtBody(
        '2024-02-29T12:00:00Z',
        fields: fields,
      );

      final FetchedRepo repo = parse(body);

      final Object? name = fields['full_name'];
      final String? normalized = name is String
          ? name.trim().replaceAll(RegExp(r'\s+'), ' ')
          : null;
      final Object? description = fields['description'];
      final Object? url = fields['html_url'];
      final Object? archived = fields['archived'];
      final Object? stars = fields['stargazers_count'];
      final RepoInfo expected = RepoInfo(
        fullName: normalized != null && normalized.isNotEmpty
            ? normalized
            : 'owner/repo',
        description: description is String ? description : null,
        htmlUrl: url is String ? url : null,
        archived: archived == true,
        stars: stars is int && stars >= 0 ? stars : 0,
      );
      expect(repo.info, expected);
      expect(repo.dateOfDeath, pushedDay);

      // Unknown fields, including updated_at and created_at, change nothing.
      final Map<String, Object?> noisy = Map<String, Object?>.of(body)
        ..['updated_at'] = updatedAt
        ..['created_at'] = extra
        ..['unknown_extra_field'] = extra
        ..['x'] = updatedAt;
      expect(parse(noisy), repo);
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
