import 'package:coffin_core/src/widgets/math/ping_pong.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/widget_generators.dart';

const int _numRuns = 300;
final RunCounter _counter = RunCounter();

void main() {
  group('PingPong property', () {
    _counter.reset();

    // Feature: spooky-widgets, Property 1: Ping-pong shape
    // Validates: Requirements 7.3, 7.6, 9.6
    Glados3(
      anyIntBetween(2, 90001),
      anyIntBetween(0, 4294967296),
      anyIntBetween(0, 4294967296),
      ExploreConfig(numRuns: _numRuns),
    ).test('value is in range, starts at 0, is symmetric and rises', (
      period,
      a,
      b,
    ) {
      _counter.increment();
      final int phase = a % period;
      final String why = 'period=$period a=$a b=$b phase=$phase';

      final double v = PingPong.at(phase, period);
      expect(v.isFinite, isTrue, reason: why);
      expect(v, inInclusiveRange(0.0, 1.0), reason: why);

      expect(PingPong.at(0, period), 0.0, reason: why);

      if (phase > 0) {
        expect(
          PingPong.at(phase, period),
          PingPong.at(period - phase, period),
          reason: 'symmetry: $why',
        );
      }

      // Two phases in [0, P ~/ 2]: the larger one never gives a lower value.
      final int half = period ~/ 2;
      final int p = a % (half + 1);
      final int q = b % (half + 1);
      final int lo = p < q ? p : q;
      final int hi = p < q ? q : p;
      expect(
        PingPong.at(lo, period) <= PingPong.at(hi, period),
        isTrue,
        reason: 'monotone: lo=$lo hi=$hi $why',
      );
    });

    test('ran every requested run', () {
      expect(_counter.runs > 0 && _counter.runs == _numRuns, isTrue);
    });
  });
}
