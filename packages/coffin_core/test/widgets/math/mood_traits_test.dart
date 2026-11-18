import 'package:coffin_core/src/widgets/ghost_mood.dart';
import 'package:coffin_core/src/widgets/math/eye_style.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:coffin_core/src/widgets/math/mouth_style.dart';
import 'package:flutter_test/flutter_test.dart';

void _row(
  GhostMood mood,
  EyeStyle eyes,
  MouthStyle mouth,
  double lean,
  double droop,
  double opacity,
  int periodMs,
  double amplitude,
) {
  final MoodTraits t = MoodTraits.of(mood);
  expect(t.eyes, eyes, reason: '$mood eyes');
  expect(t.mouth, mouth, reason: '$mood mouth');
  expect(t.lean, lean, reason: '$mood lean');
  expect(t.droop, droop, reason: '$mood droop');
  expect(t.opacity, opacity, reason: '$mood opacity');
  expect(t.bobPeriodMs, periodMs, reason: '$mood period');
  expect(t.bobAmplitude, amplitude, reason: '$mood amplitude');
}

void main() {
  group('MoodTraits table', () {
    test('thriving', () {
      _row(
        GhostMood.thriving,
        EyeStyle.wide,
        MouthStyle.smile,
        0,
        0,
        1.00,
        3000,
        8,
      );
    });
    test('content', () {
      _row(
        GhostMood.content,
        EyeStyle.round,
        MouthStyle.gentleSmile,
        0,
        0,
        0.92,
        3600,
        6,
      );
    });
    test('hungry', () {
      _row(
        GhostMood.hungry,
        EyeStyle.droopy,
        MouthStyle.smallOpen,
        0.04,
        0.03,
        0.85,
        4400,
        4,
      );
    });
    test('fading', () {
      _row(
        GhostMood.fading,
        EyeStyle.halfClosed,
        MouthStyle.flat,
        0.06,
        0.07,
        0.78,
        5000,
        2,
      );
    });
    test('dead', () {
      _row(
        GhostMood.dead,
        EyeStyle.cross,
        MouthStyle.none,
        0.15,
        0.10,
        0.72,
        5000,
        0,
      );
    });
    test('fed', () {
      _row(
        GhostMood.fed,
        EyeStyle.happyArc,
        MouthStyle.wideSmile,
        0,
        0,
        1.00,
        3000,
        8,
      );
    });
    test('rising', () {
      _row(
        GhostMood.rising,
        EyeStyle.wide,
        MouthStyle.smallOpen,
        0,
        -0.06,
        1.00,
        3000,
        8,
      );
    });

    test('no two rows are equal', () {
      for (final GhostMood a in GhostMood.values) {
        for (final GhostMood b in GhostMood.values) {
          if (a.index >= b.index) continue;
          final MoodTraits x = MoodTraits.of(a);
          final MoodTraits y = MoodTraits.of(b);
          final bool same =
              x.eyes == y.eyes &&
              x.mouth == y.mouth &&
              x.lean == y.lean &&
              x.droop == y.droop;
          expect(same, isFalse, reason: '$a and $b');
        }
      }
    });
  });

  group('MoodTraits constants', () {
    test('values', () {
      expect(MoodTraits.maxBobAmplitude, 8);
      expect(MoodTraits.fedMaxScale, 1.10);
      expect(MoodTraits.fedMaxLift, 6);
      expect(MoodTraits.risingMaxLift, 10);
      expect(MoodTraits.maxLean, 0.15);
      expect(MoodTraits.popReserve, 0.05);
      expect(MoodTraits.stretchReserve, 0.06);
    });
  });

  group('MoodTraits.reserveFor', () {
    test('pinned sizes', () {
      expect(MoodTraits.reserveFor(24), 20);
      expect(MoodTraits.reserveFor(64), 22);
      expect(MoodTraits.reserveFor(96), 24);
      expect(MoodTraits.reserveFor(256), 34);
    });

    test('clamps like the loader', () {
      expect(MoodTraits.reserveFor(0), 20);
      expect(MoodTraits.reserveFor(10), 20);
      expect(MoodTraits.reserveFor(4000), 34);
      expect(MoodTraits.reserveFor(double.nan), 22);
    });
  });
}
