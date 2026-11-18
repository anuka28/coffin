import 'package:coffin_core/src/widgets/ghost_mood.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:flutter_test/flutter_test.dart';

MoodPose _withWeight(MoodPose p, int index, double w) {
  final List<double> ws = List<double>.of(p.weights);
  ws[index] = w;
  return MoodPose(
    weights: List<double>.unmodifiable(ws),
    opacity: p.opacity,
    lean: p.lean,
    droop: p.droop,
    scale: p.scale,
    lift: p.lift,
    bobAmplitude: p.bobAmplitude,
  );
}

void main() {
  group('MoodPose.rest', () {
    for (final GhostMood mood in GhostMood.values) {
      test('${mood.name} has one weight of 1 and takes the table numbers', () {
        final MoodPose p = MoodPose.rest(mood);
        final MoodTraits t = MoodTraits.of(mood);
        expect(p.weights.length, 7);
        expect(p.weights.fold<double>(0, (double a, double b) => a + b), 1);
        expect(p.weights.where((double w) => w == 1).length, 1);
        expect(p.weights[mood.index], 1);
        expect(p.opacity, t.opacity);
        expect(p.lean, t.lean);
        expect(p.droop, t.droop);
        expect(p.bobAmplitude, t.bobAmplitude);
        expect(p.scale, 1);
        expect(p.lift, 0);
      });
    }

    test('weights list cannot be modified', () {
      final MoodPose p = MoodPose.rest(GhostMood.content);
      expect(() => p.weights[0] = 0.5, throwsUnsupportedError);
      expect(() => p.weights.add(1), throwsUnsupportedError);
    });
  });

  group('copyWith', () {
    test('changes only the named fields', () {
      final MoodPose base = MoodPose.rest(GhostMood.hungry);
      final MoodPose c = base.copyWith(opacity: 0.5, scale: 1.05, lift: 3);
      expect(c.opacity, 0.5);
      expect(c.scale, 1.05);
      expect(c.lift, 3);
      expect(c.weights, base.weights);
      expect(c.lean, base.lean);
      expect(c.droop, base.droop);
      expect(c.bobAmplitude, base.bobAmplitude);
      expect(base.copyWith(), base);
      expect(base.copyWith(lift: 2).scale, base.scale);
      expect(base.copyWith(scale: 1.1).opacity, base.opacity);
    });
  });

  group('equality', () {
    test('equal poses agree on == and hashCode', () {
      final MoodPose a = MoodPose.rest(GhostMood.fading);
      final MoodPose b = MoodPose.rest(GhostMood.fading);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a changed number or weight differs', () {
      final MoodPose a = MoodPose.rest(GhostMood.fading);
      final List<MoodPose> others = <MoodPose>[
        a.copyWith(opacity: 0.5),
        a.copyWith(scale: 1.01),
        a.copyWith(lift: 1),
        _withWeight(a, 0, 0.25),
        MoodPose.rest(GhostMood.dead),
      ];
      for (final MoodPose o in others) {
        expect(o == a, isFalse, reason: '$o');
        expect(o.hashCode == a.hashCode, isFalse, reason: '$o');
      }
    });

    test('toString names the class', () {
      expect(MoodPose.rest(GhostMood.dead).toString(), startsWith('MoodPose('));
    });
  });

  group('reach', () {
    test('rest(rising) at 96: up 0.06 * 96, none down, body width only', () {
      final MoodPose p = MoodPose.rest(GhostMood.rising);
      expect(p.upwardReach(96), closeTo(0.06 * 96, 1e-9));
      expect(p.downwardReach(96), 0);
      expect(p.horizontalReach(96), closeTo(0.4 * 96, 1e-9));
    });

    test('rest(dead) at 96 sideways: 0.4 + 0.075 + 0.02 of size', () {
      final MoodPose p = MoodPose.rest(GhostMood.dead);
      expect(p.horizontalReach(96), closeTo(0.495 * 96, 1e-9));
      expect(p.upwardReach(96), closeTo(0.06 * 96, 1e-9));
      expect(p.downwardReach(96), closeTo(0.06 * 96, 1e-9));
    });

    test('lift and pop add to the upward reach', () {
      final MoodPose p = MoodPose.rest(GhostMood.rising)
          .copyWith(lift: 10, scale: 1.1);
      expect(p.upwardReach(100), closeTo(10 + 5 + 6, 1e-9));
    });

    test('size is clamped to 24..256 and NaN is 64', () {
      final MoodPose p = MoodPose.rest(GhostMood.dead);
      expect(p.upwardReach(0), p.upwardReach(24));
      expect(p.upwardReach(4000), p.upwardReach(256));
      expect(p.upwardReach(double.nan), p.upwardReach(64));
      expect(p.horizontalReach(double.nan), p.horizontalReach(64));
    });

    test('reaches are never negative and never NaN', () {
      final List<double> sizes = <double>[
        double.nan,
        double.negativeInfinity,
        double.infinity,
        -5,
        0,
        24,
        96,
        4000,
      ];
      for (final GhostMood m in GhostMood.values) {
        final MoodPose p = MoodPose.rest(m);
        for (final double s in sizes) {
          for (final double r in <double>[
            p.upwardReach(s),
            p.downwardReach(s),
            p.horizontalReach(s),
          ]) {
            expect(r.isNaN, isFalse, reason: '$m $s');
            expect(r >= 0, isTrue, reason: '$m $s');
          }
        }
      }
    });
  });
}
