// Fixed values of the pure mood classes. Every expected number is a literal
// derived by hand from the formulas of design.md (see the comments). No
// expected number is computed by the code under test. This file is pure Dart
// and runs unchanged on the VM and in Chrome.
//
// Formulas used:
//  - Bob (GhostBob, table period P and amplitude A):
//      phase = (t + P ~/ 4) % P, n = 2 * phase, if n > P then n = 2P - n,
//      x = n / P, s = x * x * (3 - 2x), offset = A * (2s - 1).
//  - Ease: smoothstep e(u) = u * u * (3 - 2u) on u clamped into 0..1.
//  - Reaction envelope: bump(p) = e(2p) for p <= 0.5, else e(2 - 2p).
//  - Mix: from + (to - from) * e(progress).
//  - Reserve: ceil(8 + 10 + 0.06 * size).
import 'package:coffin_core/src/widgets/ghost_mood.dart';
import 'package:coffin_core/src/widgets/math/mood_blend.dart';
import 'package:coffin_core/src/widgets/math/mood_bob.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:coffin_core/src/widgets/math/mood_reaction.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:flutter_test/flutter_test.dart';

const double _tol = 1e-9;

void main() {
  group('MoodBob.offsetAt fixed values', () {
    const List<int> times = <int>[0, 750, 1500, 2250, 3000];

    void pin(GhostMood mood, List<double> expected) {
      for (int i = 0; i < times.length; i++) {
        expect(
          MoodBob.offsetAt(mood, times[i]),
          closeTo(expected[i], _tol),
          reason: '${mood.name} at ${times[i]} ms',
        );
      }
    }

    test('thriving (P 3000, A 8)', () {
      // P/4 = 750.
      // t 0:    phase 750,  n 1500, x 1/2, s 1/2, 8 * 0      = 0
      // t 750:  phase 1500, n 3000, x 1,   s 1,   8 * 1      = 8
      // t 1500: phase 2250, n 4500 -> 1500, x 1/2, s 1/2     = 0
      // t 2250: phase 0,    n 0,    x 0,   s 0,   8 * (-1)   = -8
      // t 3000: phase 750 as t 0                             = 0
      pin(GhostMood.thriving, <double>[0, 8, 0, -8, 0]);
    });

    test('fed and rising share the thriving profile', () {
      pin(GhostMood.fed, <double>[0, 8, 0, -8, 0]);
      pin(GhostMood.rising, <double>[0, 8, 0, -8, 0]);
    });

    test('content (P 3600, A 6)', () {
      // P/4 = 900.
      // t 0:    phase 900,  n 1800, x 1/2, s 1/2             = 0
      // t 750:  phase 1650, n 3300, x 11/12,
      //         s = (121/144) * (7/6) = 847/864, 2s-1 = 415/432,
      //         6 * 415/432 = 415/72                         = 5.7638888...
      // t 1500: phase 2400, n 4800 -> 2400, x 2/3,
      //         s = (4/9) * (5/3) = 20/27, 2s-1 = 13/27,
      //         6 * 13/27 = 26/9                             = 2.8888888...
      // t 2250: phase 3150, n 6300 -> 900, x 1/4,
      //         s = (1/16) * (5/2) = 5/32, 2s-1 = -11/16,
      //         6 * -11/16 = -33/8                           = -4.125
      // t 3000: phase 300,  n 600, x 1/6,
      //         s = (1/36) * (8/3) = 2/27, 2s-1 = -23/27,
      //         6 * -23/27 = -46/9                           = -5.1111111...
      pin(GhostMood.content, <double>[
        0,
        5.763888888888889,
        2.888888888888889,
        -4.125,
        -5.111111111111111,
      ]);
    });

    test('hungry (P 4400, A 4)', () {
      // P/4 = 1100.
      // t 0:    phase 1100, n 2200, x 1/2                    = 0
      // t 750:  phase 1850, n 3700, x 37/44,
      //         s = (1369/1936) * (29/22) = 39701/42592,
      //         4 * (2s-1) = 18405/5324                      = 3.45698722...
      // t 1500: phase 2600, n 5200 -> 3600, x 9/11,
      //         s = (81/121) * (15/11) = 1215/1331,
      //         4 * (2s-1) = 4396/1331                       = 3.30277986...
      // t 2250: phase 3350, n 6700 -> 2100, x 21/44,
      //         s = (441/1936) * (45/22) = 19845/42592,
      //         4 * (2s-1) = -1451/5324                      = -0.27253944...
      // t 3000: phase 4100, n 8200 -> 600, x 3/22,
      //         s = (9/484) * (30/11) = 135/2662,
      //         4 * (2s-1) = -4784/1331                      = -3.59429000...
      pin(GhostMood.hungry, <double>[
        0,
        3.456987227648385,
        3.3027798647633357,
        -0.27253944402704733,
        -3.594290007513148,
      ]);
    });

    test('fading (P 5000, A 2)', () {
      // P/4 = 1250.
      // t 0:    phase 1250, n 2500, x 1/2                    = 0
      // t 750:  phase 2000, n 4000, x 4/5,
      //         s = (16/25) * (7/5) = 0.896, 2 * (2s-1)      = 1.584
      // t 1500: phase 2750, n 5500 -> 4500, x 9/10,
      //         s = 0.81 * 1.2 = 0.972, 2 * (2s-1)           = 1.888
      // t 2250: phase 3500, n 7000 -> 3000, x 3/5,
      //         s = 0.36 * 1.8 = 0.648, 2 * (2s-1)           = 0.592
      // t 3000: phase 4250, n 8500 -> 1500, x 3/10,
      //         s = 0.09 * 2.4 = 0.216, 2 * (2s-1)           = -1.136
      pin(GhostMood.fading, <double>[0, 1.584, 1.888, 0.592, -1.136]);
    });

    test('dead has no bob (amplitude 0)', () {
      pin(GhostMood.dead, <double>[0, 0, 0, 0, 0]);
    });
  });

  group('MoodReaction fixed values', () {
    test('durations are pinned literals', () {
      expect(MoodReaction.fedDurationMs, 900);
      expect(MoodReaction.risingDurationMs, 2200);
      expect(MoodReaction.durationMs(GhostMood.fed), 900);
      expect(MoodReaction.durationMs(GhostMood.rising), 2200);
    });

    test('progressAt at 0, 25, 50 and 100 percent of the duration', () {
      // progress = elapsed / duration.
      // fed:    0 / 900 = 0, 225 / 900 = 0.25, 450 / 900 = 0.5, 900 / 900 = 1
      // rising: 0 / 2200 = 0, 550 / 2200 = 0.25, 1100 / 2200 = 0.5, 1
      expect(MoodReaction.progressAt(GhostMood.fed, 0), 0);
      expect(MoodReaction.progressAt(GhostMood.fed, 225), 0.25);
      expect(MoodReaction.progressAt(GhostMood.fed, 450), 0.5);
      expect(MoodReaction.progressAt(GhostMood.fed, 900), 1);
      expect(MoodReaction.progressAt(GhostMood.rising, 0), 0);
      expect(MoodReaction.progressAt(GhostMood.rising, 550), 0.25);
      expect(MoodReaction.progressAt(GhostMood.rising, 1100), 0.5);
      expect(MoodReaction.progressAt(GhostMood.rising, 2200), 1);
    });

    test('steady moods have progress 1 and neutral values', () {
      // Duration 0 gives progress 1; scale 1, lift 0, own table opacity.
      const Map<GhostMood, double> opacity = <GhostMood, double>{
        GhostMood.thriving: 1.00,
        GhostMood.content: 0.92,
        GhostMood.hungry: 0.85,
        GhostMood.fading: 0.78,
        GhostMood.dead: 0.72,
      };
      opacity.forEach((GhostMood mood, double o) {
        expect(MoodReaction.progressAt(mood, 0), 1);
        for (final double p in <double>[0, 0.25, 0.5, 1]) {
          expect(MoodReaction.scaleAt(mood, p), 1);
          expect(MoodReaction.liftAt(mood, p), 0);
          expect(MoodReaction.opacityAt(mood, p), closeTo(o, _tol));
        }
      });
    });

    test('fed scale, lift and opacity at 0, 0.25, 0.5 and 1', () {
      // bump(0) = e(0) = 0; bump(0.25) = e(0.5) = 0.5;
      // bump(0.5) = e(1) = 1; bump(1) = e(0) = 0.
      // scale = 1 + 0.10 * bump: 1, 1.05, 1.10, 1.
      // lift  = 6 * bump:        0, 3,    6,    0.
      // opacity = table 1.00 at every progress.
      const List<double> p = <double>[0, 0.25, 0.5, 1];
      const List<double> scale = <double>[1, 1.05, 1.10, 1];
      const List<double> lift = <double>[0, 3, 6, 0];
      for (int i = 0; i < p.length; i++) {
        expect(
          MoodReaction.scaleAt(GhostMood.fed, p[i]),
          closeTo(scale[i], _tol),
        );
        expect(
          MoodReaction.liftAt(GhostMood.fed, p[i]),
          closeTo(lift[i], _tol),
        );
        expect(MoodReaction.opacityAt(GhostMood.fed, p[i]), 1.0);
      }
    });

    test('rising scale, lift and opacity at 0, 0.25, 0.5 and 1', () {
      // scale is 1 at every progress.
      // lift = 10 * bump: 0, 5, 10, 0.
      // opacity = 0.72 + 0.28 * e(p), e(0) = 0, e(0.25) = 5/32 = 0.15625,
      // e(0.5) = 0.5, e(1) = 1:
      //   0.72, 0.72 + 0.28 * 0.15625 = 0.76375, 0.72 + 0.14 = 0.86, 1.0.
      const List<double> p = <double>[0, 0.25, 0.5, 1];
      const List<double> lift = <double>[0, 5, 10, 0];
      const List<double> opacity = <double>[0.72, 0.76375, 0.86, 1.0];
      for (int i = 0; i < p.length; i++) {
        expect(MoodReaction.scaleAt(GhostMood.rising, p[i]), 1);
        expect(
          MoodReaction.liftAt(GhostMood.rising, p[i]),
          closeTo(lift[i], _tol),
        );
        expect(
          MoodReaction.opacityAt(GhostMood.rising, p[i]),
          closeTo(opacity[i], _tol),
        );
      }
    });
  });

  group('MoodBlend fixed values', () {
    test('ease at 0, 0.25, 0.5 and 1', () {
      // e(0) = 0
      // e(0.25) = 0.0625 * (3 - 0.5) = 0.0625 * 2.5 = 0.15625
      // e(0.5)  = 0.25 * (3 - 1) = 0.5
      // e(1)    = 1 * (3 - 2) = 1
      expect(MoodBlend.ease(0), 0);
      expect(MoodBlend.ease(0.25), 0.15625);
      expect(MoodBlend.ease(0.5), 0.5);
      expect(MoodBlend.ease(1), 1);
    });

    test('mix of rest(thriving) and rest(dead) at 0, 0.25, 0.5 and 1', () {
      // e = 0, 0.15625, 0.5, 1.
      // opacity = 1 + (0.72 - 1) * e = 1 - 0.28 * e:
      //   1, 1 - 0.04375 = 0.95625, 1 - 0.14 = 0.86, 0.72.
      // lean = 0 + (0.15 - 0) * e:
      //   0, 0.15 * 0.15625 = 0.0234375, 0.075, 0.15.
      // bob amplitude = 8 + (0 - 8) * e = 8 - 8 * e:
      //   8, 8 - 1.25 = 6.75, 4, 0.
      const List<double> p = <double>[0, 0.25, 0.5, 1];
      const List<double> opacity = <double>[1, 0.95625, 0.86, 0.72];
      const List<double> lean = <double>[0, 0.0234375, 0.075, 0.15];
      const List<double> amplitude = <double>[8, 6.75, 4, 0];
      final MoodPose from = MoodPose.rest(GhostMood.thriving);
      final MoodPose to = MoodPose.rest(GhostMood.dead);
      for (int i = 0; i < p.length; i++) {
        final MoodPose mixed = MoodBlend.mix(from, to, p[i]);
        expect(mixed.opacity, closeTo(opacity[i], _tol), reason: 'p ${p[i]}');
        expect(mixed.lean, closeTo(lean[i], _tol), reason: 'p ${p[i]}');
        expect(
          mixed.bobAmplitude,
          closeTo(amplitude[i], _tol),
          reason: 'p ${p[i]}',
        );
      }
    });
  });

  group('MoodTraits.reserveFor fixed values', () {
    test('24, 64, 96 and 256', () {
      // ceil(8 + 10 + 0.06 * size):
      //   24:  18 + 1.44  = 19.44 -> 20
      //   64:  18 + 3.84  = 21.84 -> 22
      //   96:  18 + 5.76  = 23.76 -> 24
      //   256: 18 + 15.36 = 33.36 -> 34
      expect(MoodTraits.reserveFor(24), 20);
      expect(MoodTraits.reserveFor(64), 22);
      expect(MoodTraits.reserveFor(96), 24);
      expect(MoodTraits.reserveFor(256), 34);
    });
  });
}
