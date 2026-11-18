import 'package:coffin_core/src/widgets/ghost_mood.dart';
import 'package:coffin_core/src/widgets/math/mood_blend.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/mood_chain.dart';
import '../support/mood_generators.dart';
import '../support/widget_generators.dart';

const int _numRuns = 300;
const int _interruptedRuns = 200;
final RunCounter _easeCounter = RunCounter();
final RunCounter _endpointsCounter = RunCounter();
final RunCounter _interruptedCounter = RunCounter();

void main() {
  group('MoodBlend interrupted blends property', () {
    _interruptedCounter.reset();

    // Feature: ghost-moods, Property 6: Interrupted blends have no jump and stay valid mixes
    // Validates: Requirements 7.5, 7.6, 9.4
    Glados(
      anyChain,
      ExploreConfig(numRuns: _interruptedRuns),
    ).test('interrupted blends have no jump and stay valid mixes', (chain) {
      _interruptedCounter.increment();
      final String why = 'chain=$chain';
      final MoodPose reached = applyChain(chain);

      double sum = 0;
      for (final double w in reached.weights) {
        expect(w >= 0 && w <= 1, isTrue, reason: 'weight $w: $why');
        sum += w;
      }
      expect((sum - 1).abs() <= 1e-9, isTrue, reason: 'sum $sum: $why');

      for (final String field in poseFields) {
        final (double lo, double hi) = tableRange(field);
        final double v = poseField(reached, field);
        expect(v.isFinite, isTrue, reason: '$field not finite: $why');
        expect(
          v,
          inInclusiveRange(lo - 1e-9, hi + 1e-9),
          reason: '$field: $why',
        );
      }

      // Starting the next blend (progress 0) leaves the pose unchanged.
      for (final GhostMood next in <GhostMood>[chain.first.$1, chain.last.$1]) {
        expect(
          MoodBlend.mix(reached, MoodPose.rest(next), 0),
          reached,
          reason: 'jump toward $next: $why',
        );
      }
    });

    test('ran every requested run', () {
      expect(
        _interruptedCounter.runs > 0 &&
            _interruptedCounter.runs == _interruptedRuns,
        isTrue,
      );
    });
  });

  group('MoodBlend ease property', () {
    _easeCounter.reset();

    // Feature: ghost-moods, Property 4: The blend easing is monotonic, bounded and slow enough
    // Validates: Requirements 7.3, 7.4, 9.11, 21.6
    Glados3(
      anyProgress,
      anyProgress,
      anyIntBetween(0, 2000),
      ExploreConfig(numRuns: _numRuns),
    ).test('ease is bounded, monotonic and slow enough', (p, q, n) {
      _easeCounter.increment();
      final String why = 'p=$p q=$q n=$n';

      // Bounded and finite for any progress, including NaN and infinity.
      final double e = MoodBlend.ease(p);
      expect(e.isFinite, isTrue, reason: why);
      expect(e, inInclusiveRange(0, 1), reason: why);
      expect(MoodBlend.ease(0), 0, reason: why);
      expect(MoodBlend.ease(1), 1, reason: why);

      // Monotonic for any finite or infinite a <= b (NaN is excluded).
      if (!p.isNaN && !q.isNaN) {
        final double a = p <= q ? p : q;
        final double b = p <= q ? q : p;
        expect(
          MoodBlend.ease(a) <= MoodBlend.ease(b),
          isTrue,
          reason: 'monotonic: $why',
        );
      }

      // One frame (16 ms) never moves the ease by more than 1.5 times its
      // share of the blend.
      final int d = n.isEven ? 500 : 200;
      final double step = 16 / d;
      final double u = (n ~/ 2) / 1000 * (1 - step);
      final double delta = MoodBlend.ease(u + step) - MoodBlend.ease(u);
      expect(
        delta <= 1.5 * step + 1e-9,
        isTrue,
        reason: 'slope: $why d=$d u=$u delta=$delta',
      );
    });

    test('ran every requested run', () {
      expect(_easeCounter.runs > 0 && _easeCounter.runs == _numRuns, isTrue);
    });
  });

  group('MoodBlend endpoints property', () {
    _endpointsCounter.reset();

    // Feature: ghost-moods, Property 5: A blend stays between its endpoints
    // Validates: Requirements 7.2, 7.3, 21.5
    Glados3(
      anyMood,
      anyMood,
      anyProgress,
      ExploreConfig(numRuns: _numRuns),
    ).test('a blend stays between its endpoints', (a, b, progress) {
      _endpointsCounter.increment();
      final String why = 'a=$a b=$b progress=$progress';
      final MoodPose from = MoodPose.rest(a);
      final MoodPose to = MoodPose.rest(b);
      final MoodPose m = MoodBlend.mix(from, to, progress);

      void between(String name, double x, double y, double v) {
        expect(v.isFinite, isTrue, reason: '$name not finite: $why');
        final double lo = x < y ? x : y;
        final double hi = x < y ? y : x;
        expect(v, inInclusiveRange(lo, hi), reason: '$name: $why');
      }

      between('opacity', from.opacity, to.opacity, m.opacity);
      between('lean', from.lean, to.lean, m.lean);
      between('droop', from.droop, to.droop, m.droop);
      between('scale', from.scale, to.scale, m.scale);
      between('lift', from.lift, to.lift, m.lift);
      between(
        'bobAmplitude',
        from.bobAmplitude,
        to.bobAmplitude,
        m.bobAmplitude,
      );
      expect(m.weights.length, from.weights.length, reason: why);
      for (int i = 0; i < from.weights.length; i++) {
        between('weight $i', from.weights[i], to.weights[i], m.weights[i]);
      }

      void same(MoodPose x, MoodPose y, String label) {
        expect(x.opacity, y.opacity, reason: '$label opacity: $why');
        expect(x.lean, y.lean, reason: '$label lean: $why');
        expect(x.droop, y.droop, reason: '$label droop: $why');
        expect(x.scale, y.scale, reason: '$label scale: $why');
        expect(x.lift, y.lift, reason: '$label lift: $why');
        expect(
          x.bobAmplitude,
          y.bobAmplitude,
          reason: '$label bobAmplitude: $why',
        );
        expect(x.weights, y.weights, reason: '$label weights: $why');
      }

      same(MoodBlend.mix(from, to, 0), from, 'progress 0');
      same(MoodBlend.mix(from, to, 1), to, 'progress 1');
      same(MoodBlend.mix(from, to, double.nan), to, 'NaN');
    });

    test('ran every requested run', () {
      expect(
        _endpointsCounter.runs > 0 && _endpointsCounter.runs == _numRuns,
        isTrue,
      );
    });
  });
}
