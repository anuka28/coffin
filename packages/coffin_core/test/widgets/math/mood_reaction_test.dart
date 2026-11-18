import 'package:coffin_core/src/widgets/ghost_mood.dart';
import 'package:coffin_core/src/widgets/math/mood_blend.dart';
import 'package:coffin_core/src/widgets/math/mood_reaction.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:flutter_test/flutter_test.dart';

const List<GhostMood> _steady = <GhostMood>[
  GhostMood.thriving,
  GhostMood.content,
  GhostMood.hungry,
  GhostMood.fading,
  GhostMood.dead,
];

const List<double> _points = <double>[0, 0.25, 0.5, 0.75, 1];

void main() {
  group('MoodReaction.isReaction and durationMs', () {
    test('only fed and rising are reactions', () {
      expect(MoodReaction.isReaction(GhostMood.fed), isTrue);
      expect(MoodReaction.isReaction(GhostMood.rising), isTrue);
      for (final GhostMood m in _steady) {
        expect(MoodReaction.isReaction(m), isFalse);
      }
    });

    test('durations', () {
      expect(MoodReaction.durationMs(GhostMood.fed), 900);
      expect(MoodReaction.durationMs(GhostMood.rising), 2200);
      for (final GhostMood m in _steady) {
        expect(MoodReaction.durationMs(m), 0);
      }
    });
  });

  group('MoodReaction.progressAt', () {
    test('fed progress over time', () {
      expect(MoodReaction.progressAt(GhostMood.fed, -1), 0);
      expect(MoodReaction.progressAt(GhostMood.fed, 0), 0);
      expect(MoodReaction.progressAt(GhostMood.fed, 450), closeTo(0.5, 1e-12));
      expect(MoodReaction.progressAt(GhostMood.fed, 900), 1);
      expect(MoodReaction.progressAt(GhostMood.fed, 901), 1);
      expect(MoodReaction.progressAt(GhostMood.fed, 1099511627776), 1);
    });

    test('rising progress over time', () {
      expect(MoodReaction.progressAt(GhostMood.rising, -1), 0);
      expect(
        MoodReaction.progressAt(GhostMood.rising, 1100),
        closeTo(0.5, 1e-12),
      );
      expect(MoodReaction.progressAt(GhostMood.rising, 2200), 1);
      expect(MoodReaction.progressAt(GhostMood.rising, 1099511627776), 1);
    });

    test('steady moods are always finished', () {
      for (final GhostMood m in _steady) {
        expect(MoodReaction.progressAt(m, -5), 1);
        expect(MoodReaction.progressAt(m, 0), 1);
        expect(MoodReaction.progressAt(m, 1099511627776), 1);
      }
    });
  });

  group('MoodReaction fed curves', () {
    test('scale at 0, 0.25, 0.5, 0.75, 1', () {
      const List<double> expected = <double>[1.0, 1.05, 1.10, 1.05, 1.0];
      for (int i = 0; i < _points.length; i++) {
        expect(
          MoodReaction.scaleAt(GhostMood.fed, _points[i]),
          closeTo(expected[i], 1e-12),
        );
      }
    });

    test('lift at 0, 0.25, 0.5, 0.75, 1', () {
      const List<double> expected = <double>[0, 3, 6, 3, 0];
      for (int i = 0; i < _points.length; i++) {
        expect(
          MoodReaction.liftAt(GhostMood.fed, _points[i]),
          closeTo(expected[i], 1e-12),
        );
      }
    });

    test('opacity is 1.0 everywhere', () {
      for (final double p in _points) {
        expect(MoodReaction.opacityAt(GhostMood.fed, p), 1.0);
      }
    });
  });

  group('MoodReaction rising curves', () {
    test('lift at 0, 0.25, 0.5, 0.75, 1', () {
      const List<double> expected = <double>[0, 5, 10, 5, 0];
      for (int i = 0; i < _points.length; i++) {
        expect(
          MoodReaction.liftAt(GhostMood.rising, _points[i]),
          closeTo(expected[i], 1e-12),
        );
      }
    });

    test('opacity eases from dead to thriving', () {
      final double dead = MoodTraits.of(GhostMood.dead).opacity;
      final double thriving = MoodTraits.of(GhostMood.thriving).opacity;
      for (final double p in _points) {
        expect(
          MoodReaction.opacityAt(GhostMood.rising, p),
          closeTo(dead + (thriving - dead) * MoodBlend.ease(p), 1e-12),
        );
      }
      expect(MoodReaction.opacityAt(GhostMood.rising, 0), closeTo(dead, 1e-12));
      expect(
        MoodReaction.opacityAt(GhostMood.rising, 1),
        closeTo(thriving, 1e-12),
      );
      expect(
        MoodReaction.opacityAt(GhostMood.rising, 0.5),
        closeTo((dead + thriving) / 2, 1e-12),
      );
    });

    test('scale stays 1', () {
      for (final double p in _points) {
        expect(MoodReaction.scaleAt(GhostMood.rising, p), 1);
      }
    });
  });

  group('MoodReaction out of range progress', () {
    test('NaN counts as 1, below 0 as 0, above 1 as 1', () {
      for (final GhostMood m in <GhostMood>[GhostMood.fed, GhostMood.rising]) {
        expect(MoodReaction.scaleAt(m, double.nan), MoodReaction.scaleAt(m, 1));
        expect(MoodReaction.liftAt(m, double.nan), MoodReaction.liftAt(m, 1));
        expect(
          MoodReaction.opacityAt(m, double.nan),
          MoodReaction.opacityAt(m, 1),
        );
        expect(MoodReaction.scaleAt(m, -1), MoodReaction.scaleAt(m, 0));
        expect(MoodReaction.liftAt(m, -1), MoodReaction.liftAt(m, 0));
        expect(MoodReaction.opacityAt(m, -1), MoodReaction.opacityAt(m, 0));
        expect(MoodReaction.scaleAt(m, 2), MoodReaction.scaleAt(m, 1));
        expect(MoodReaction.liftAt(m, 2), MoodReaction.liftAt(m, 1));
        expect(MoodReaction.opacityAt(m, 2), MoodReaction.opacityAt(m, 1));
      }
    });
  });

  group('MoodReaction steady moods', () {
    test('are neutral', () {
      for (final GhostMood m in _steady) {
        for (final double p in <double>[...(_points), double.nan, -1, 2]) {
          expect(MoodReaction.scaleAt(m, p), 1);
          expect(MoodReaction.liftAt(m, p), 0);
          expect(MoodReaction.opacityAt(m, p), MoodTraits.of(m).opacity);
        }
      }
    });
  });
}
