// Feature: graveyard-scene, Property 21: Description cleaner leaves shortcode-free text unchanged apart from whitespace
// Validates: Requirements 11.9
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/description_cleaner.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

final RegExp _word = RegExp(r'\S+');
final RegExp _spaces = RegExp(r'\s+');
final RegExp _shortcodeWord = RegExp(r'^:([A-Za-z0-9_+-]{1,40}):$');
final RegExp _letter = RegExp('[A-Za-z]');

/// Independent oracle: whether a whitespace-delimited [word] is a shortcode.
bool _isShortcode(String word) {
  final RegExp shape = _shortcodeWord;
  final Match? match = shape.firstMatch(word);
  return match != null && _letter.hasMatch(match.group(1)!);
}

/// Replaces every shortcode word with a plain word, keeping all whitespace.
String _withoutShortcodes(String text) => text.replaceAllMapped(
  _word,
  (Match m) => _isShortcode(m[0]!) ? 'x' : m[0]!,
);

/// The input with whitespace runs collapsed to one space and trimmed.
String _normalised(String text) =>
    text.split(_spaces).where((String w) => w.isNotEmpty).join(' ');

void main() {
  group('Property 21: Description cleaner leaves shortcode-free text '
      'unchanged apart from whitespace', () {
    Glados(anyDescription, ExploreConfig(numRuns: numRuns)).test(
      'clean equals the whitespace-normalised input',
      (String raw) {
        _counter.increment();
        final String input = _withoutShortcodes(raw);
        expect(
          input.split(_spaces).any(_isShortcode),
          isFalse,
          reason: 'the construction must leave no shortcode word',
        );

        expect(DescriptionCleaner.clean(input), _normalised(input));
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
