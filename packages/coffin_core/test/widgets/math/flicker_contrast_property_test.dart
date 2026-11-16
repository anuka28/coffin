import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/theme/wcag_contrast.dart';
import 'package:coffin_core/src/widgets/math/flicker_schedule.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/color_blend.dart';
import '../support/widget_generators.dart';

const int _numRuns = 200;
final RunCounter _counter = RunCounter();

/// Every (token set, surface name, surface color) the text is drawn over.
List<(CoffinColorTokens, String, int)> _pairs() =>
    <(CoffinColorTokens, String, int)>[
      for (final CoffinColorTokens set in CoffinColorTokens.variants) ...[
        (set, 'background', set.background.toARGB32()),
        (set, 'surface', set.surface.toARGB32()),
        (set, 'raised', set.raised.toARGB32()),
      ],
    ];

void main() {
  group('FlickerSchedule contrast', () {
    _counter.reset();

    // Feature: spooky-widgets, Property 11: Flicker keeps text readable
    // Validates: Requirements 8.13
    Glados2(anySeed, anyElapsed, ExploreConfig(numRuns: _numRuns)).test(
      'flickering text keeps at least 4.5:1 over every surface in both sets',
      (seed, elapsed) {
        _counter.increment();
        final double opacity = FlickerSchedule(seed).opacityAt(elapsed);
        for (final (CoffinColorTokens set, String name, int bg) in _pairs()) {
          final int drawn = blendOver(set.text.toARGB32(), bg, opacity);
          final double ratio = WcagContrast.ratio(drawn, bg);
          expect(
            ratio >= WcagContrast.aaNormalText,
            isTrue,
            reason:
                'seed=$seed elapsed=$elapsed opacity=$opacity '
                '${set.name}/$name ratio=$ratio',
          );
        }
      },
    );

    test('ran every requested run', () {
      expect(_counter.runs > 0 && _counter.runs == _numRuns, isTrue);
    });

    test('worst case at the minimum opacity passes for all six pairs', () {
      for (final (CoffinColorTokens set, String name, int bg) in _pairs()) {
        final int drawn = blendOver(
          set.text.toARGB32(),
          bg,
          FlickerSchedule.minOpacity,
        );
        final double ratio = WcagContrast.ratio(drawn, bg);
        expect(
          ratio >= WcagContrast.aaNormalText,
          isTrue,
          reason: '${set.name}/$name ratio=$ratio',
        );
      }
    });
  });
}
