import 'package:coffin_core/src/theme/coffin_glow.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

/// Any 32-bit ARGB color, including translucent ones.
Generator<Color> get _anyColor => any.intInRange(0, 0x100000000).map(Color.new);

/// Intensity in (0, 1].
Generator<double> get _intensity => any.doubleInRange(0.0001, 1);

/// Index into [_radii]; the first entry is "no override".
Generator<int> get _radiusIndex => any.intInRange(0, 4);

const List<double?> _radii = <double?>[null, 0, 4, 40];

void main() {
  group('CoffinGlow property: glow shape', () {
    const numRuns = 200;
    var executedRuns = 0;

    // Feature: haunted-theme, Property 3
    // Validates: Requirements 6.1, 6.2, 6.3
    Glados3(
      _anyColor,
      _intensity,
      _radiusIndex,
      ExploreConfig(numRuns: numRuns),
    ).test('glow is non-empty, zero-offset, positive-blur, color-preserving', (
      color,
      intensity,
      radiusIndex,
    ) {
      executedRuns++;
      final double? override = _radii[radiusIndex];
      final BoxDecoration d = CoffinGlow.decoration(
        color: color,
        intensity: intensity,
        borderRadius: override == null ? null : BorderRadius.circular(override),
      );

      final List<BoxShadow> shadows = d.boxShadow ?? const <BoxShadow>[];
      expect(shadows, isNotEmpty);
      for (final BoxShadow s in shadows) {
        expect(s.offset, Offset.zero);
        expect(s.blurRadius, greaterThan(0));
        expect(s.color.r, color.r);
        expect(s.color.g, color.g);
        expect(s.color.b, color.b);
      }
      expect(d.borderRadius, BorderRadius.circular(override ?? 16));
    });

    test('property body executed for every requested run', () {
      expect(executedRuns, numRuns);
    });
  });

  group('CoffinGlow property: intensity clamping', () {
    const numRuns = 200;
    var executedRuns = 0;

    // Feature: haunted-theme, Property 4
    // Validates: Requirements 6.5, 6.6
    Glados2(
      _anyColor,
      any.doubleInRange(-5, 5),
      ExploreConfig(numRuns: numRuns),
    ).test('decoration equals the one for clamped intensity; 0 means no glow', (
      color,
      intensity,
    ) {
      executedRuns++;
      final double clamped = intensity.clamp(0.0, 1.0);
      final BoxDecoration actual = CoffinGlow.decoration(
        color: color,
        intensity: intensity,
      );
      final BoxDecoration expected = CoffinGlow.decoration(
        color: color,
        intensity: clamped,
      );

      expect(actual, expected);
      if (clamped == 0) {
        expect(actual.boxShadow ?? const <BoxShadow>[], isEmpty);
      }
    });

    test('property body executed for every requested run', () {
      expect(executedRuns, numRuns);
    });
  });

  group('CoffinGlow property: blur monotonicity', () {
    const numRuns = 200;
    var executedRuns = 0;
    const color = Color(0xFF9B6BFF);

    double totalBlur(double intensity) {
      final BoxDecoration d = CoffinGlow.decoration(
        color: color,
        intensity: intensity,
      );
      return (d.boxShadow ?? const <BoxShadow>[]).fold<double>(
        0,
        (sum, s) => sum + s.blurRadius,
      );
    }

    // Feature: haunted-theme, Property 5
    // Validates: Requirements 6.8
    Glados2(
      any.doubleInRange(0, 1),
      any.doubleInRange(0, 1),
      ExploreConfig(numRuns: numRuns),
    ).test('total blur at a is <= total blur at b when a <= b', (x, y) {
      executedRuns++;
      final double a = x < y ? x : y;
      final double b = x < y ? y : x;
      expect(totalBlur(a), lessThanOrEqualTo(totalBlur(b)));
    });

    test('intensity 0 yields total blur 0', () {
      expect(totalBlur(0), 0);
    });

    test('property body executed for every requested run', () {
      expect(executedRuns, numRuns);
    });
  });

  group('CoffinGlow property: determinism', () {
    const numRuns = 200;
    var executedRuns = 0;

    // Feature: haunted-theme, Property 6
    // Validates: Requirements 6.7
    // The third value packs the optional fill (bit 0) and radius index.
    Glados3(
      _anyColor,
      any.doubleInRange(-100, 100),
      any.intInRange(0, 8),
      ExploreConfig(numRuns: numRuns),
    ).test('two calls with equal arguments return equal decorations', (
      color,
      intensity,
      packed,
    ) {
      executedRuns++;
      final Color? fill = packed.isEven
          ? null
          : Color(color.toARGB32() ^ 0x00FFFFFF);
      final double? override = _radii[packed ~/ 2];
      BoxDecoration build() => CoffinGlow.decoration(
        color: color,
        intensity: intensity,
        fill: fill,
        borderRadius: override == null ? null : BorderRadius.circular(override),
      );

      expect(build(), build());
    });

    test('property body executed for every requested run', () {
      expect(executedRuns, numRuns);
    });
  });
}
