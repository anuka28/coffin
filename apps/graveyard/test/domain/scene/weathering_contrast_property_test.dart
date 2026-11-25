// Feature: graveyard-scene, Property 16: Weathered contrast stays above the minimum
// Validates: Requirements 8.1, 8.5
import 'dart:ui' show Color;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/weathering.dart';
import 'package:graveyard/src/domain/scene/weathering_result.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Minimum contrast ratio for text over weathered stone.
const double _minRatio = 3.0;

/// Text roles checked against the stone (the `surface` token).
const List<String> _textRoles = <String>[
  'text',
  'muted',
  'primary',
  'secondary',
  'tertiary',
];

/// Blends [from] toward [to] by [t], per channel, as opaque 0xFFRRGGBB.
/// Same blend as weathering_contrast_test.dart.
int _blend(int from, int to, double t) {
  int channel(int shift) {
    final int a = (from >> shift) & 0xFF;
    final int b = (to >> shift) & 0xFF;
    return (a + (b - a) * t).round().clamp(0, 255);
  }

  return 0xFF000000 | (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

void main() {
  group('Property 16: Weathered contrast stays above the minimum', () {
    Glados3(
      anyDayCount,
      anyMixedGraveId,
      anyThemeTokens,
      ExploreConfig(numRuns: numRuns),
    ).test('stone after the fade and each text token keep a ratio >= 3.0', (
      int dayCount,
      String id,
      CoffinColorTokens tokens,
    ) {
      _counter.increment();
      final WeatheringResult result = Weathering.of(
        dayCount: dayCount,
        graveId: id,
      );
      final int stone = _blend(
        tokens.surface.toARGB32(),
        tokens.background.toARGB32(),
        result.fade,
      );
      final Map<String, Color> surfacePairs = <String, Color>{
        for (final p in tokens.contrastPairs)
          if (p.backgroundName == 'surface') p.foregroundName: p.foreground,
      };

      for (final String role in _textRoles) {
        final Color? fg = surfacePairs[role];
        expect(fg, isNotNull, reason: 'missing $role on surface');
        final double ratio = WcagContrast.ratio(fg!.toARGB32(), stone);
        expect(
          ratio,
          greaterThanOrEqualTo(_minRatio),
          reason:
              '${tokens.name} $role at day $dayCount, fade ${result.fade}: '
              '$ratio',
        );
      }
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
