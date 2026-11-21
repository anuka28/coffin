import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/voice_seed.dart';
import 'package:hauntagotchi/src/domain/voice_trigger.dart';

int _seed(
  int epochDay,
  GhostState state,
  VoiceTrigger trigger,
  int streak,
  int completedToday,
) => VoiceSeed.compute(
  epochDay: epochDay,
  state: state,
  trigger: trigger,
  streak: streak,
  completedToday: completedToday,
);

void main() {
  const modulus = 4294967291;

  group('VoiceSeed', () {
    test('enum order is pinned because the seed uses index', () {
      expect(GhostState.values, <GhostState>[
        GhostState.dead,
        GhostState.fading,
        GhostState.hungry,
        GhostState.content,
        GhostState.thriving,
      ]);
      expect(VoiceTrigger.values, <VoiceTrigger>[
        VoiceTrigger.appOpened,
        VoiceTrigger.checkedOff,
        VoiceTrigger.moodChanged,
        VoiceTrigger.resurrected,
      ]);
    });

    test('pinned inputs give pinned seeds', () {
      const g = GhostState.values;
      const t = VoiceTrigger.values;
      expect(_seed(0, g[0], t[0], 0, 0), 996577424);
      expect(_seed(19000, g[4], t[0], 0, 0), 2643047420);
      expect(_seed(19000, g[4], t[1], 3, 1), 1924668636);
      expect(_seed(19000, g[4], t[1], 3, 2), 1924668637);
      expect(_seed(19999, g[3], t[2], 7, 2), 110388875);
      expect(_seed(20500, g[1], t[3], 12, 5), 3640682170);
      expect(_seed(19000, g[0], t[3], 0, 0), 2076605708);
      expect(_seed(19000, g[2], t[1], 0, 1), 2720515962);
      expect(_seed(-1, g[2], t[0], 1, 0), 3843856322);
      expect(_seed(-19000, g[4], t[1], 3, 1), 4026273886);
      expect(_seed(19000, g[4], t[1], 1000000, 3), 1197289826);
      expect(_seed(4294967295, g[4], t[3], 1000000, 1000000), 3405699104);
    });

    test('result is in range', () {
      for (final state in GhostState.values) {
        for (final trigger in VoiceTrigger.values) {
          for (final day in <int>[-5000000000, -1, 0, 19000, 4294967295]) {
            final s = _seed(day, state, trigger, 1000000, 7);
            expect(s, inInclusiveRange(0, 4294967290));
          }
        }
      }
    });

    test('negative epochDay equals its fold', () {
      const state = GhostState.content;
      const trigger = VoiceTrigger.appOpened;
      expect(
        _seed(-1, state, trigger, 2, 1),
        _seed(modulus - 1, state, trigger, 2, 1),
      );
      expect(
        _seed(-19000, state, trigger, 2, 1),
        _seed(modulus - 19000, state, trigger, 2, 1),
      );
    });

    test('streak 0 and streak 1000000 work', () {
      final zero = _seed(
        19000,
        GhostState.hungry,
        VoiceTrigger.appOpened,
        0,
        0,
      );
      final big = _seed(
        19000,
        GhostState.hungry,
        VoiceTrigger.appOpened,
        1000000,
        0,
      );
      expect(zero, inInclusiveRange(0, 4294967290));
      expect(big, inInclusiveRange(0, 4294967290));
      expect(zero, isNot(big));
    });

    test('two check-offs on one day differ by completedToday', () {
      final first = _seed(
        19000,
        GhostState.thriving,
        VoiceTrigger.checkedOff,
        3,
        1,
      );
      final second = _seed(
        19000,
        GhostState.thriving,
        VoiceTrigger.checkedOff,
        3,
        2,
      );
      expect(first, isNot(second));
    });

    test('same inputs give the same seed', () {
      expect(
        _seed(19000, GhostState.fading, VoiceTrigger.moodChanged, 4, 2),
        _seed(19000, GhostState.fading, VoiceTrigger.moodChanged, 4, 2),
      );
    });
  });
}
