import 'dart:math' as math_lib;

import 'package:coffin_core/src/router/fog_frame.dart';
import 'package:coffin_core/src/router/fog_math.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group;
import 'package:glados/glados.dart' hide expect, group, test;

/// Progress values, including ones outside 0..1.
Generator<double> get _anyProgress => any.doubleInRange(-5, 5);

/// Progress values at or past the end of the animation.
Generator<double> get _afterEnd => any.doubleInRange(1, 5);

/// Progress values at or before the start of the animation.
Generator<double> get _beforeStart => any.doubleInRange(-5, 0);

/// Requested durations from slightly negative to several seconds.
Generator<Duration> get _anyDuration =>
    any.intInRange(-1000, 5000).map((ms) => Duration(milliseconds: ms));

const FogMath _math = FogMath();
const int _numRuns = 200;

void main() {
  group('FogMath property: output ranges', () {
    // Feature: fog-router, Property 1
    // Validates: Requirements 4.3, 4.4, 5.1, 5.7
    Glados2(_anyProgress, any.bool, ExploreConfig(numRuns: _numRuns)).test(
      'opacity, drift and blur stay in range',
      (t, reduced) {
        final FogFrame f = _math.frame(t, reducedMotion: reduced);
        final String why = 'input t=$t reduced=$reduced -> $f';
        expect(f.opacity, inInclusiveRange(0.0, 1.0), reason: why);
        expect(f.dx, 0.0, reason: why);
        expect(f.dy, inInclusiveRange(0.0, _math.maxDrift), reason: why);
        expect(f.blur, inInclusiveRange(0.0, _math.maxBlur), reason: why);
      },
    );

    // Same property with non-default maxima.
    Glados3(
      _anyProgress,
      any.doubleInRange(0, 100),
      any.doubleInRange(0, 100),
      ExploreConfig(numRuns: _numRuns),
    ).test('ranges follow custom maxima', (t, maxDrift, maxBlur) {
      final FogMath custom = FogMath(maxDrift: maxDrift, maxBlur: maxBlur);
      final FogFrame f = custom.frame(t);
      final String why = 't=$t maxDrift=$maxDrift maxBlur=$maxBlur -> $f';
      expect(f.dy, inInclusiveRange(0.0, maxDrift), reason: why);
      expect(f.blur, inInclusiveRange(0.0, maxBlur), reason: why);
    });
  });

  group('FogMath property: settled end state', () {
    // Feature: fog-router, Property 5
    // Validates: Requirements 2.9, 4.5, 4.6, 5.7
    Glados2(_afterEnd, any.bool, ExploreConfig(numRuns: _numRuns)).test(
      'at or after progress 1 the page is settled',
      (t, reduced) {
        final FogFrame f = _math.frame(t, reducedMotion: reduced);
        expect(
          f,
          const FogFrame(opacity: 1, dx: 0, dy: 0, blur: 0),
          reason: 'input t=$t reduced=$reduced',
        );
      },
    );

    Glados2(_beforeStart, any.bool, ExploreConfig(numRuns: _numRuns)).test(
      'at or before progress 0 the page is invisible',
      (t, reduced) {
        expect(
          _math.opacity(t, reducedMotion: reduced),
          0.0,
          reason: 'input t=$t reduced=$reduced',
        );
      },
    );
  });

  group('FogMath property: monotonicity', () {
    // Feature: fog-router, Property 2
    // Validates: Requirements 4.3, 5.2, 5.7
    Glados3(
      _anyProgress,
      _anyProgress,
      any.bool,
      ExploreConfig(numRuns: _numRuns),
    ).test('opacity never decreases as progress increases', (x, y, reduced) {
      final double a = math_lib.min(x, y);
      final double b = math_lib.max(x, y);
      expect(
        _math.opacity(a, reducedMotion: reduced),
        lessThanOrEqualTo(_math.opacity(b, reducedMotion: reduced)),
        reason: 'inputs a=$a b=$b reduced=$reduced',
      );
    });

    // Feature: fog-router, Property 4
    // Validates: Requirements 2.2, 2.3, 5.5, 5.7
    Glados2(_anyProgress, _anyProgress, ExploreConfig(numRuns: _numRuns)).test(
      'drift and blur never increase as progress increases',
      (x, y) {
        final double a = math_lib.min(x, y);
        final double b = math_lib.max(x, y);
        final String why = 'inputs a=$a b=$b';
        expect(_math.dy(a), greaterThanOrEqualTo(_math.dy(b)), reason: why);
        expect(_math.blur(a), greaterThanOrEqualTo(_math.blur(b)), reason: why);
      },
    );
  });

  group('FogMath property: reduced motion, durations, determinism', () {
    // Feature: fog-router, Property 3
    // Validates: Requirements 3.1, 3.2, 4.8, 5.3, 5.4, 5.7
    Glados(_anyProgress, ExploreConfig(numRuns: _numRuns)).test(
      'reduced motion gives exactly zero offset and blur',
      (t) {
        final FogFrame f = _math.frame(t, reducedMotion: true);
        final String why = 'input t=$t -> $f';
        expect(f.dx, 0.0, reason: why);
        expect(f.dy, 0.0, reason: why);
        expect(f.blur, 0.0, reason: why);
        expect(f.opacity, inInclusiveRange(0.0, 1.0), reason: why);
      },
    );

    // Feature: fog-router, Property 6
    // Validates: Requirements 2.4, 2.8, 3.5, 5.7
    Glados2(
      _anyDuration,
      _anyDuration,
      ExploreConfig(numRuns: _numRuns),
    ).test('resolved durations obey the rules', (requested, reducedDuration) {
      final String why =
          'requested=$requested reducedDuration=$reducedDuration';

      final Duration normal = _math.resolveDuration(requested);
      expect(normal, greaterThanOrEqualTo(FogMath.minDuration), reason: why);
      expect(normal, lessThanOrEqualTo(FogMath.maxDuration), reason: why);

      final Duration instant = _math.resolveDuration(
        requested,
        reducedMotion: true,
      );
      expect(instant, Duration.zero, reason: why);

      final Duration reduced = _math.resolveDuration(
        requested,
        reducedMotion: true,
        reducedDuration: reducedDuration,
      );
      expect(reduced, greaterThanOrEqualTo(Duration.zero), reason: why);
      expect(reduced, lessThanOrEqualTo(FogMath.defaultDuration), reason: why);
    });

    // Feature: fog-router, Property 7
    // Validates: Requirements 4.7, 5.7
    Glados2(_anyProgress, any.bool, ExploreConfig(numRuns: _numRuns)).test(
      'equal inputs give equal frames',
      (t, reduced) {
        expect(
          _math.frame(t, reducedMotion: reduced),
          _math.frame(t, reducedMotion: reduced),
          reason: 'input t=$t reduced=$reduced',
        );
      },
    );
  });
}
