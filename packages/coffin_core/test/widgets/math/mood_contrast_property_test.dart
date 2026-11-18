import 'package:coffin_core/coffin_core.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/color_blend.dart';
import '../support/mood_generators.dart';
import '../support/widget_generators.dart' show RunCounter;

const int _numRuns = 200;
const double _minRatio = 3.0;
final RunCounter _counter = RunCounter();

void main() {
  group('Mood contrast property', () {
    _counter.reset();

    // Feature: ghost-moods, Property 3: Every mood keeps its contrast in both themes
    // Validates: Requirements 4.4, 14.2, 21.9
    Glados(
      anyMood,
      ExploreConfig(numRuns: _numRuns),
    ).test('body and eyes keep at least 3.0:1 in night and daylight', (mood) {
      _counter.increment();
      final double opacity = MoodTraits.of(mood).opacity;
      final sets = <(String, CoffinColorTokens, int)>[
        (
          'night',
          CoffinColorTokens.night,
          CoffinColorTokens.night.text.toARGB32(),
        ),
        (
          'daylight',
          CoffinColorTokens.daylight,
          CoffinColorTokens.daylight.primary.toARGB32(),
        ),
      ];
      for (final (String name, CoffinColorTokens set, int bodyColor) in sets) {
        final int background = set.background.toARGB32();
        final int body = blendOver(bodyColor, background, opacity);
        final double bodyRatio = WcagContrast.ratio(body, background);
        final double eyeRatio = WcagContrast.ratio(background, body);
        expect(
          bodyRatio >= _minRatio,
          isTrue,
          reason: 'body vs background: mood=$mood set=$name ratio=$bodyRatio',
        );
        expect(
          eyeRatio >= _minRatio,
          isTrue,
          reason: 'eye vs body: mood=$mood set=$name ratio=$eyeRatio',
        );
      }
    });

    test('ran every requested run', () {
      expect(_counter.runs > 0 && _counter.runs == _numRuns, isTrue);
    });
  });
}
