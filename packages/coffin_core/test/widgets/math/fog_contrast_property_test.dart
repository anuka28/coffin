import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/theme/wcag_contrast.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/color_blend.dart';
import '../support/widget_generators.dart';

const int _numRuns = 200;
final RunCounter _counter = RunCounter();

/// Every (token set, base name, base color, text name, text color) pair.
List<(CoffinColorTokens, String, int, String, int)> _combos() =>
    <(CoffinColorTokens, String, int, String, int)>[
      for (final CoffinColorTokens set in CoffinColorTokens.variants)
        for (final (String, int) base in <(String, int)>[
          ('background', set.background.toARGB32()),
          ('surface', set.surface.toARGB32()),
        ])
          for (final (String, int) fg in <(String, int)>[
            ('text', set.text.toARGB32()),
            ('muted', set.muted.toARGB32()),
          ])
            (set, base.$1, base.$2, fg.$1, fg.$2),
    ];

void main() {
  group('Fog contrast', () {
    _counter.reset();

    // Feature: spooky-widgets, Property 12: Fog keeps text readable
    // Validates: Requirements 6.10
    Glados2(
      anyIntBetween(1, 6),
      anyIntBetween(30, 41),
      ExploreConfig(numRuns: _numRuns),
    ).test(
      'text and muted keep at least 4.5:1 over fogged background and surface',
      (layers, thousandths) {
        _counter.increment();
        final double alpha = thousandths / 1000;
        for (final (
              CoffinColorTokens set,
              String baseName,
              int base,
              String fgName,
              int fg,
            )
            in _combos()) {
          final int fogged = blendRepeated(
            set.primary.toARGB32(),
            base,
            alpha,
            layers,
          );
          final double ratio = WcagContrast.ratio(fg, fogged);
          expect(
            ratio >= WcagContrast.aaNormalText,
            isTrue,
            reason:
                'layers=$layers alpha=$alpha ${set.name}/$baseName/$fgName '
                'ratio=$ratio',
          );
        }
      },
    );

    test('ran every requested run', () {
      expect(_counter.runs > 0 && _counter.runs == _numRuns, isTrue);
    });

    test('worst case (5 layers, alpha 0.04) passes for all 8 combinations', () {
      for (final (
            CoffinColorTokens set,
            String baseName,
            int base,
            String fgName,
            int fg,
          )
          in _combos()) {
        final int fogged = blendRepeated(set.primary.toARGB32(), base, 0.04, 5);
        final double ratio = WcagContrast.ratio(fg, fogged);
        expect(
          ratio >= WcagContrast.aaNormalText,
          isTrue,
          reason: '${set.name}/$baseName/$fgName ratio=$ratio',
        );
        if (set.name == 'night' && baseName == 'surface' && fgName == 'muted') {
          expect(ratio.toStringAsFixed(2), '4.65');
        }
        if (set.name == 'daylight' &&
            baseName == 'background' &&
            fgName == 'muted') {
          expect(ratio.toStringAsFixed(2), '5.25');
        }
      }
    });
  });
}
