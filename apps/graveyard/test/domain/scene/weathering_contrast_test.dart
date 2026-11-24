import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/weathering.dart';

// Color choices used here (the scene painters are not written yet):
// - Stone color: the `surface` token, which is what TombstoneCard fills with.
// - Ground color: the `background` token (design.md: "tokens.background (the
//   Ground color)").
// - Weathering fade blends the stone toward the ground by `fade`, which is
//   `level * 0.25` (Weathering.of(...).fade). This is the strictest reading,
//   since the design paints fade as a halo outside the opaque stone.
// - Focus ring: the `primary` token (TombstoneCard's focus border).
// - Delete button label: the default TextButton foreground, `primary`.
// Both are checked against the `background` token.

const double _minRatio = 3.0;

/// Blends [from] toward [to] by [t], per channel, as opaque 0xFFRRGGBB.
int _blend(int from, int to, double t) {
  int channel(int shift) {
    final a = (from >> shift) & 0xFF;
    final b = (to >> shift) & 0xFF;
    return (a + (b - a) * t).round().clamp(0, 255);
  }

  return 0xFF000000 | (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

void main() {
  const textRoles = <String>[
    'text',
    'muted',
    'primary',
    'secondary',
    'tertiary',
  ];
  // Weathering level L is reached at dayCount = L * ceiling.
  const levels = <double>[0, 0.5, 1];

  for (final tokens in CoffinColorTokens.variants) {
    group('${tokens.name} contrast over weathered stone', () {
      final surfacePairs = {
        for (final p in tokens.contrastPairs)
          if (p.backgroundName == 'surface') p.foregroundName: p.foreground,
      };

      for (final level in levels) {
        final days = (level * Weathering.weatheringCeilingDays).round();
        final result = Weathering.of(dayCount: days, graveId: 'g');
        final stone = _blend(
          tokens.surface.toARGB32(),
          tokens.background.toARGB32(),
          result.fade,
        );

        test('level $level (fade ${result.fade}) keeps text at >= 3.0', () {
          expect(result.level, level);
          for (final role in textRoles) {
            final fg = surfacePairs[role];
            expect(fg, isNotNull, reason: 'missing $role on surface');
            final ratio = WcagContrast.ratio(fg!.toARGB32(), stone);
            expect(
              ratio,
              greaterThanOrEqualTo(_minRatio),
              reason: '${tokens.name} $role over stone at level $level: $ratio',
            );
          }
        });
      }

      test('focus ring keeps >= 3.0 over the background token', () {
        final ratio = WcagContrast.ratio(
          tokens.primary.toARGB32(),
          tokens.background.toARGB32(),
        );
        expect(ratio, greaterThanOrEqualTo(_minRatio), reason: '$ratio');
      });

      test('delete button label keeps >= 3.0 over the background token', () {
        final ratio = WcagContrast.ratio(
          tokens.primary.toARGB32(),
          tokens.background.toARGB32(),
        );
        expect(ratio, greaterThanOrEqualTo(_minRatio), reason: '$ratio');
      });
    });
  }
}
