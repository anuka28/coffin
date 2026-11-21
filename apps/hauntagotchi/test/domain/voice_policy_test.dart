import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/voice_policy.dart';
import 'package:hauntagotchi/src/domain/voice_snapshot.dart';
import 'package:hauntagotchi/src/domain/voice_trigger.dart';

VoiceSnapshot snap(GhostState? state, [int checkOffs = 0, int res = 0]) =>
    VoiceSnapshot(state: state, checkOffs: checkOffs, resurrections: res);

void main() {
  group('VoicePolicy.decide', () {
    test('not ready gives null', () {
      expect(VoicePolicy.decide(null, snap(null)), isNull);
      expect(VoicePolicy.decide(snap(GhostState.hungry), snap(null)), isNull);
      expect(VoicePolicy.decide(snap(null), snap(null)), isNull);
    });

    test('first ready snapshot gives appOpened', () {
      expect(
        VoicePolicy.decide(null, snap(GhostState.content)),
        VoiceTrigger.appOpened,
      );
    });

    test('reload after not ready gives appOpened', () {
      expect(
        VoicePolicy.decide(snap(null), snap(GhostState.content)),
        VoiceTrigger.appOpened,
      );
    });

    test('equal snapshots give null', () {
      expect(
        VoicePolicy.decide(
          snap(GhostState.hungry, 3, 1),
          snap(GhostState.hungry, 3, 1),
        ),
        isNull,
      );
    });

    test('a rising check-off counter gives checkedOff at the same state', () {
      expect(
        VoicePolicy.decide(
          snap(GhostState.thriving, 1),
          snap(GhostState.thriving, 2),
        ),
        VoiceTrigger.checkedOff,
      );
    });

    test('a check-off that leaves a dead ghost dead gives checkedOff', () {
      expect(
        VoicePolicy.decide(snap(GhostState.dead), snap(GhostState.dead, 1)),
        VoiceTrigger.checkedOff,
      );
    });

    test('a rising resurrection counter gives resurrected', () {
      expect(
        VoicePolicy.decide(
          snap(GhostState.dead),
          snap(GhostState.fading, 0, 1),
        ),
        VoiceTrigger.resurrected,
      );
    });

    test('resurrected wins when the check-off counter rose too', () {
      expect(
        VoicePolicy.decide(
          snap(GhostState.dead, 4),
          snap(GhostState.fading, 5, 1),
        ),
        VoiceTrigger.resurrected,
      );
    });

    test('a state change alone gives moodChanged', () {
      expect(
        VoicePolicy.decide(snap(GhostState.content), snap(GhostState.hungry)),
        VoiceTrigger.moodChanged,
      );
    });

    test('a check-off with a state change gives checkedOff', () {
      expect(
        VoicePolicy.decide(
          snap(GhostState.hungry),
          snap(GhostState.content, 1),
        ),
        VoiceTrigger.checkedOff,
      );
    });

    test('dead to a live state without a counter change is moodChanged', () {
      expect(
        VoicePolicy.decide(snap(GhostState.dead), snap(GhostState.fading)),
        VoiceTrigger.moodChanged,
      );
    });

    test('every state pair without counter change follows equality', () {
      for (final from in GhostState.values) {
        for (final to in GhostState.values) {
          final result = VoicePolicy.decide(snap(from, 2, 1), snap(to, 2, 1));
          expect(
            result,
            from == to ? isNull : VoiceTrigger.moodChanged,
            reason: '$from -> $to',
          );
        }
      }
    });
  });
}
