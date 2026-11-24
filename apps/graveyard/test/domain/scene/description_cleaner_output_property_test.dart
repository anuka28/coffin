// Feature: graveyard-scene, Property 19: Description cleaner removes only whole-word shortcodes
// Validates: Requirements 11.8
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/description_cleaner.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

final RegExp _whitespace = RegExp(r'\s+');
final RegExp _shortcode = RegExp(r'^:[A-Za-z0-9_+-]{1,40}:$');
final RegExp _letter = RegExp('[A-Za-z]');

/// Independent oracle: tokens of [input] that are not shortcodes, joined by
/// single spaces.
String _expected(String input) {
  final List<String> tokens = input
      .split(_whitespace)
      .where((String t) => t.isNotEmpty)
      .where((String t) => !(_shortcode.hasMatch(t) && _letter.hasMatch(t)))
      .toList();
  return tokens.join(' ');
}

void main() {
  group(
    'Property 19: Description cleaner removes only whole-word shortcodes',
    () {
      Glados(anyDescription, ExploreConfig(numRuns: numRuns)).test(
        'output equals the input tokens minus shortcode tokens',
        (String input) {
          _counter.increment();
          final String output = DescriptionCleaner.clean(input);
          expect(output, _expected(input));
          expect(output.length, lessThanOrEqualTo(input.length));
          expect(output, output.trim());
          expect(output.contains('  '), isFalse);
        },
      );

      test('ran the configured number of times', () {
        _counter.expectRuns(numRuns);
      });
    },
  );
}
