import 'package:coffin_core/src/widgets/math/ghost_bob.dart';
import 'package:coffin_core/src/widgets/math/ping_pong.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GhostBob clamping', () {
    test('period', () {
      expect(GhostBob(periodMs: 2499).periodMs, 2500);
      expect(GhostBob(periodMs: 2500).periodMs, 2500);
      expect(GhostBob(periodMs: 5000).periodMs, 5000);
      expect(GhostBob(periodMs: 5001).periodMs, 5000);
      expect(GhostBob().periodMs, 3600);
    });

    test('amplitude', () {
      expect(GhostBob(amplitude: 1.99).amplitude, 2);
      expect(GhostBob(amplitude: 2).amplitude, 2);
      expect(GhostBob(amplitude: 10).amplitude, 10);
      expect(GhostBob(amplitude: 10.01).amplitude, 10);
      expect(GhostBob(amplitude: double.nan).amplitude, 6);
      expect(GhostBob(amplitude: double.infinity).amplitude, 10);
      expect(GhostBob(amplitude: double.negativeInfinity).amplitude, 2);
      expect(GhostBob().amplitude, 6);
    });
  });

  group('GhostBob.offsetAt', () {
    final bob = GhostBob();

    test('starts near zero', () {
      expect(bob.offsetAt(0).abs(), lessThan(0.03));
    });

    test('quarter, half, three quarters and one period', () {
      // Default: period 3600, amplitude 6, phase shift 900.
      // Quarter: phase 1800, PingPong 1 -> +6.
      expect(PingPong.at(1800, 3600), 1);
      expect(bob.offsetAt(900), closeTo(6, 1e-9));
      // Half: phase 2700 folds to n = 1800, PingPong 0.5 -> 0.
      expect(PingPong.at(2700, 3600), 0.5);
      expect(bob.offsetAt(1800), closeTo(0, 1e-9));
      // Three quarters: phase 0, PingPong 0 -> -6.
      expect(PingPong.at(0, 3600), 0);
      expect(bob.offsetAt(2700), closeTo(-6, 1e-9));
      // One period: same as time 0.
      expect(bob.offsetAt(3600), bob.offsetAt(0));
    });

    test('negative time stays in range', () {
      final v = bob.offsetAt(-1);
      expect(v, inInclusiveRange(-6, 6));
      expect(v, bob.offsetAt(3599));
    });
  });

  test('staticOffset is zero and in range', () {
    expect(GhostBob.staticOffset, 0);
    expect(
      GhostBob.staticOffset,
      inInclusiveRange(-GhostBob.minAmplitude, GhostBob.minAmplitude),
    );
  });
}
