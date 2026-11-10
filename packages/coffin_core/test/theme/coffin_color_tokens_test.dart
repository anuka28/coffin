import 'dart:ui' show Color;

import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/theme/wcag_contrast.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) => WcagContrast.relativeLuminance(c.toARGB32());

void main() {
  group('CoffinColorTokens', () {
    test('night has the exact design-language hex values', () {
      const n = CoffinColorTokens.night;
      expect(n.background, const Color(0xFF0E0B16));
      expect(n.surface, const Color(0xFF1A1525));
      expect(n.raised, const Color(0xFF241C33));
      expect(n.primary, const Color(0xFF9B6BFF));
      expect(n.secondary, const Color(0xFFFF8A3D));
      expect(n.tertiary, const Color(0xFF7CFFB2));
      expect(n.error, const Color(0xFFFF4D6D));
      expect(n.text, const Color(0xFFEDE6F5));
      expect(n.muted, const Color(0xFF9A90AB));
    });

    test('daylight has light backgrounds and dark text', () {
      const d = CoffinColorTokens.daylight;
      for (final bg in [d.background, d.surface, d.raised]) {
        expect(_lum(bg), greaterThan(0.5));
      }
      expect(_lum(d.text), lessThan(0.1));
      expect(_lum(d.muted), lessThan(0.25));
    });

    test('both variants share the same type', () {
      expect(
        CoffinColorTokens.night.runtimeType,
        CoffinColorTokens.daylight.runtimeType,
      );
    });

    test('variants holds both night and daylight', () {
      expect(CoffinColorTokens.variants, hasLength(2));
      expect(CoffinColorTokens.variants, contains(CoffinColorTokens.night));
      expect(CoffinColorTokens.variants, contains(CoffinColorTokens.daylight));
    });

    for (final v in CoffinColorTokens.variants) {
      group(v.name, () {
        test('contrastPairs has 22 entries incl. 4 on-color pairs', () {
          final pairs = v.contrastPairs;
          expect(pairs, hasLength(22));
          final onPairs = pairs
              .where((p) => p.foregroundName.startsWith('on'))
              .map((p) => p.label)
              .toSet();
          expect(onPairs, {
            'onPrimary on primary',
            'onSecondary on secondary',
            'onTertiary on tertiary',
            'onError on error',
          });
        });

        test('labels are unique', () {
          final labels = v.contrastPairs.map((p) => p.label).toList();
          expect(labels.toSet(), hasLength(labels.length));
        });

        test('contains no glow-only colors', () {
          for (final p in v.contrastPairs) {
            expect(p.label.toLowerCase(), isNot(contains('glow')));
          }
        });
      });
    }

    test('night on-colors are darker than their fills', () {
      const n = CoffinColorTokens.night;
      expect(_lum(n.onPrimary), lessThan(_lum(n.primary)));
      expect(_lum(n.onSecondary), lessThan(_lum(n.secondary)));
      expect(_lum(n.onTertiary), lessThan(_lum(n.tertiary)));
      expect(_lum(n.onError), lessThan(_lum(n.error)));
    });
  });
}
