import 'package:coffin_core/src/widgets/ghost_mood.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:coffin_core/src/widgets/math/mood_reaction.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mood_chain.dart';

void main() {
  group('applyChain', () {
    test('one steady mood at progress 1 equals its rest pose', () {
      for (final GhostMood mood in <GhostMood>[
        GhostMood.thriving,
        GhostMood.content,
        GhostMood.hungry,
        GhostMood.fading,
        GhostMood.dead,
      ]) {
        expect(
          applyChain(<(GhostMood, double)>[(mood, 1)]),
          MoodPose.rest(mood),
        );
      }
    });

    test('an empty chain is the thriving rest pose', () {
      expect(
        applyChain(const <(GhostMood, double)>[]),
        MoodPose.rest(GhostMood.thriving),
      );
    });

    test('a reaction mood at progress 0.5 carries the overlay', () {
      final MoodPose fed = applyChain(<(GhostMood, double)>[
        (GhostMood.fed, 0.5),
      ]);
      expect(fed.scale, MoodReaction.scaleAt(GhostMood.fed, 0.5));
      expect(fed.lift, MoodReaction.liftAt(GhostMood.fed, 0.5));
      expect(fed.opacity, MoodReaction.opacityAt(GhostMood.fed, 0.5));
      expect(fed.scale, closeTo(1.10, 1e-12));
      expect(fed.lift, closeTo(6, 1e-12));

      final MoodPose rising = applyChain(<(GhostMood, double)>[
        (GhostMood.rising, 0.5),
      ]);
      expect(rising.lift, closeTo(10, 1e-12));
      expect(rising.opacity, closeTo(0.86, 1e-12));
    });
  });

  group('tableRange', () {
    test('pins the table ranges', () {
      expect(tableRange('opacity'), (0.72, 1.0));
      expect(tableRange('lean'), (0.0, 0.15));
      expect(tableRange('droop'), (-0.06, 0.10));
      expect(tableRange('scale'), (1.0, 1.10));
      expect(tableRange('lift'), (0.0, 10.0));
      expect(tableRange('bobAmplitude'), (0.0, 8.0));
    });

    test('rejects an unknown field', () {
      expect(() => tableRange('nope'), throwsArgumentError);
    });

    test('every number of fixed chains lies inside the range', () {
      final List<List<(GhostMood, double)>> chains =
          <List<(GhostMood, double)>>[
            <(GhostMood, double)>[
              (GhostMood.dead, 0.3),
              (GhostMood.rising, 0.5),
              (GhostMood.fed, 0.7),
            ],
            <(GhostMood, double)>[
              (GhostMood.fed, 0.5),
              (GhostMood.hungry, 2),
              (GhostMood.rising, double.nan),
              (GhostMood.fading, -1),
            ],
            <(GhostMood, double)>[
              (GhostMood.rising, 0.5),
              (GhostMood.fed, 0.5),
              (GhostMood.content, 0.25),
              (GhostMood.dead, double.infinity),
              (GhostMood.thriving, 0.5),
            ],
          ];
      for (final List<(GhostMood, double)> chain in chains) {
        final MoodPose pose = applyChain(chain);
        for (final String field in poseFields) {
          final (double lo, double hi) = tableRange(field);
          final double v = poseField(pose, field);
          expect(
            v,
            inInclusiveRange(lo - 1e-9, hi + 1e-9),
            reason: '$field of $chain',
          );
        }
      }
    });
  });
}
