import 'package:coffin_core/src/router/fog_frame.dart';
import 'package:coffin_core/src/router/fog_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const math = FogMath();

  group('defaults', () {
    test('constants match the design', () {
      expect(FogMath.defaultMaxDrift, 16);
      expect(FogMath.defaultMaxBlur, 8);
      expect(FogMath.defaultDuration, const Duration(milliseconds: 450));
      expect(FogMath.minDuration, const Duration(milliseconds: 300));
      expect(FogMath.maxDuration, const Duration(milliseconds: 600));
      expect(math.maxDrift, 16);
      expect(math.maxBlur, 8);
    });
  });

  group('boundary values', () {
    test('progress 0.0 is invisible, low and fully blurred', () {
      expect(
        math.frame(0.0),
        const FogFrame(opacity: 0, dx: 0, dy: 16, blur: 8),
      );
    });

    test('progress 0.5 is halfway', () {
      expect(
        math.frame(0.5),
        const FogFrame(opacity: 0.5, dx: 0, dy: 8, blur: 4),
      );
    });

    test('progress 1.0 is settled', () {
      expect(
        math.frame(1.0),
        const FogFrame(opacity: 1, dx: 0, dy: 0, blur: 0),
      );
    });

    test('progress below 0 clamps to 0', () {
      expect(math.progress(-1.0), 0.0);
      expect(math.frame(-1.0), math.frame(0.0));
    });

    test('progress above 1 clamps to 1', () {
      expect(math.progress(2.0), 1.0);
      expect(math.frame(2.0), math.frame(1.0));
    });

    test('NaN is treated as 0.0', () {
      expect(math.progress(double.nan), 0.0);
      expect(math.frame(double.nan), math.frame(0.0));
    });

    test('infinities clamp', () {
      expect(math.progress(double.infinity), 1.0);
      expect(math.progress(double.negativeInfinity), 0.0);
    });
  });

  group('reduced motion', () {
    for (final t in <double>[0.0, 0.5, 1.0]) {
      test('no drift or blur at progress $t, opacity in range', () {
        final frame = math.frame(t, reducedMotion: true);
        expect(frame.dx, 0.0);
        expect(frame.dy, 0.0);
        expect(frame.blur, 0.0);
        expect(frame.opacity, inInclusiveRange(0.0, 1.0));
      });
    }

    test('opacity still follows progress', () {
      expect(math.opacity(0.25, reducedMotion: true), 0.25);
    });
  });

  group('custom maxima', () {
    test('scale drift and blur', () {
      const custom = FogMath(maxDrift: 40, maxBlur: 20);
      expect(custom.dy(0.0), 40);
      expect(custom.blur(0.0), 20);
      expect(custom.dy(0.5), 20);
      expect(custom.blur(0.5), 10);
    });

    test('zero maxima are allowed and give no movement', () {
      const flat = FogMath(maxDrift: 0, maxBlur: 0);
      expect(flat.dy(0.0), 0);
      expect(flat.blur(0.0), 0);
    });

    test('a negative maxDrift trips the assertion', () {
      expect(() => FogMath(maxDrift: -1), throwsAssertionError);
    });

    test('a negative maxBlur trips the assertion', () {
      expect(() => FogMath(maxBlur: -1), throwsAssertionError);
    });
  });

  group('resolveDuration', () {
    test('raises a short request to 300 ms', () {
      expect(
        math.resolveDuration(const Duration(milliseconds: 100)),
        FogMath.minDuration,
      );
    });

    test('lowers a long request to 600 ms', () {
      expect(
        math.resolveDuration(const Duration(milliseconds: 900)),
        FogMath.maxDuration,
      );
    });

    test('leaves an in-range request alone', () {
      expect(
        math.resolveDuration(const Duration(milliseconds: 450)),
        const Duration(milliseconds: 450),
      );
    });

    test('is zero under reduced motion by default', () {
      expect(
        math.resolveDuration(
          const Duration(milliseconds: 100),
          reducedMotion: true,
        ),
        Duration.zero,
      );
    });

    test('honors a short reducedDuration', () {
      expect(
        math.resolveDuration(
          FogMath.defaultDuration,
          reducedMotion: true,
          reducedDuration: const Duration(milliseconds: 150),
        ),
        const Duration(milliseconds: 150),
      );
    });

    test('clamps a long reducedDuration to the default duration', () {
      expect(
        math.resolveDuration(
          FogMath.defaultDuration,
          reducedMotion: true,
          reducedDuration: const Duration(seconds: 2),
        ),
        FogMath.defaultDuration,
      );
    });

    test('clamps a negative reducedDuration to zero', () {
      expect(
        math.resolveDuration(
          FogMath.defaultDuration,
          reducedMotion: true,
          reducedDuration: const Duration(milliseconds: -5),
        ),
        Duration.zero,
      );
    });
  });
}
