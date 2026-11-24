// Feature: graveyard-scene, Property 23: Thousands formatter groups digits correctly
// Validates: Requirements 12.4
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/thousands_formatter.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 23: Thousands formatter groups digits correctly', () {
    Glados(anyNonNegativeInt, ExploreConfig(numRuns: numRuns)).test(
      'first group has 1 to 3 digits without a leading zero, others have 3',
      (int n) {
        _counter.increment();
        final List<String> groups = ThousandsFormatter.format(n).split(',');
        final RegExp digits = RegExp(r'^[0-9]+$');
        for (final String group in groups) {
          expect(digits.hasMatch(group), isTrue, reason: 'group "$group"');
        }
        final String first = groups.first;
        expect(first.length, inInclusiveRange(1, 3));
        if (first.length > 1) {
          expect(first.startsWith('0'), isFalse);
        }
        if (first == '0') {
          expect(n, 0);
          expect(groups.length, 1);
        }
        for (final String group in groups.skip(1)) {
          expect(group.length, 3);
        }
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
