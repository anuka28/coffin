import 'package:coffin_core/src/widgets/ghost_mood.dart';
import 'package:coffin_core/src/widgets/math/mood_blend.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:coffin_core/src/widgets/math/mood_reaction.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';

/// Pose reached by a chain of blends, starting at `rest(thriving)`.
///
/// Each pair mixes the pose reached so far toward the rest pose of its mood at
/// its progress. A reaction mood then carries the reaction overlay (scale,
/// lift and opacity) at the same progress.
MoodPose applyChain(List<(GhostMood, double)> chain) {
  MoodPose pose = MoodPose.rest(GhostMood.thriving);
  for (final (GhostMood mood, double progress) in chain) {
    pose = MoodBlend.mix(pose, MoodPose.rest(mood), progress);
    if (MoodReaction.isReaction(mood)) {
      pose = pose.copyWith(
        scale: MoodReaction.scaleAt(mood, progress),
        lift: MoodReaction.liftAt(mood, progress),
        opacity: MoodReaction.opacityAt(mood, progress),
      );
    }
  }
  return pose;
}

/// Smallest and largest table value of one pose number.
///
/// [field] is one of `opacity`, `lean`, `droop`, `scale`, `lift` or
/// `bobAmplitude`. Scale and lift include the reaction ranges (scale 1 to
/// 1.10, lift 0 to 10).
(double, double) tableRange(String field) {
  switch (field) {
    case 'scale':
      return (1, MoodTraits.fedMaxScale);
    case 'lift':
      return (0, MoodTraits.risingMaxLift);
    case 'opacity':
      return _range((MoodTraits t) => t.opacity);
    case 'lean':
      return _range((MoodTraits t) => t.lean);
    case 'droop':
      return _range((MoodTraits t) => t.droop);
    case 'bobAmplitude':
      return _range((MoodTraits t) => t.bobAmplitude);
  }
  throw ArgumentError.value(field, 'field', 'unknown pose number');
}

/// Value of the pose number named [field] in [pose].
double poseField(MoodPose pose, String field) {
  switch (field) {
    case 'scale':
      return pose.scale;
    case 'lift':
      return pose.lift;
    case 'opacity':
      return pose.opacity;
    case 'lean':
      return pose.lean;
    case 'droop':
      return pose.droop;
    case 'bobAmplitude':
      return pose.bobAmplitude;
  }
  throw ArgumentError.value(field, 'field', 'unknown pose number');
}

/// Names of every pose number [tableRange] knows.
const List<String> poseFields = <String>[
  'opacity',
  'lean',
  'droop',
  'scale',
  'lift',
  'bobAmplitude',
];

(double, double) _range(double Function(MoodTraits) pick) {
  double lo = pick(MoodTraits.of(GhostMood.values.first));
  double hi = lo;
  for (final GhostMood mood in GhostMood.values) {
    final double v = pick(MoodTraits.of(mood));
    if (v < lo) {
      lo = v;
    }
    if (v > hi) {
      hi = v;
    }
  }
  return (lo, hi);
}
