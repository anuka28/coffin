// Feature: graveyard-core, Property 15: The response parser is total
// Validates: Requirements 4.15
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/domain/repo_response_parser.dart';

import '../support/fixed_offset_zone.dart';
import 'support/grave_generators.dart';

final RunCounter _textCounter = RunCounter();
final RunCounter _valueCounter = RunCounter();

void main() {
  group('Property 15: The response parser is total', () {
    final CalendarDate today = CalendarDate(2026, 6, 1);
    final RepoRef requested = RepoRef('owner', 'repo');
    const FixedOffsetZone zone = FixedOffsetZone(Duration.zero);

    FetchResult parse(String body) => RepoResponseParser.parse(
      body,
      requested: requested,
      today: today,
      zone: zone.call,
    );

    Glados(anyJsonText, ExploreConfig(numRuns: numRuns)).test(
      'any text yields a FetchResult and never throws',
      (String text) {
        _textCounter.increment();
        final FetchResult result = parse(text);
        expect(result, anyOf(isA<FetchSucceeded>(), isA<FetchFailed>()));
      },
    );

    test('ran the configured number of times (text)', () {
      _textCounter.expectRuns(numRuns);
    });

    Glados(anyJsonValue, ExploreConfig(numRuns: numRuns)).test(
      'any encoded JSON value yields a FetchResult and never throws',
      (Object? value) {
        _valueCounter.increment();
        final FetchResult result = parse(jsonEncode(value));
        expect(result, anyOf(isA<FetchSucceeded>(), isA<FetchFailed>()));
      },
    );

    test('ran the configured number of times (values)', () {
      _valueCounter.expectRuns(numRuns);
    });

    test('deeply nested lists and objects yield a FetchResult', () {
      for (final int depth in <int>[1, 100, 1000, 10000]) {
        final String lists = '${'[' * depth}${']' * depth}';
        final String objects = '${'{"a":' * depth}null${'}' * depth}';
        expect(parse(lists), isA<FetchFailed>());
        expect(parse(objects), isA<FetchFailed>());
        // Unterminated nesting.
        expect(parse('[' * depth), isA<FetchFailed>());
        expect(
          parse('{"pushed_at":"2024-02-29T12:00:00Z","x":${'[' * depth}'),
          isA<FetchFailed>(),
        );
      }
    });
  });
}
