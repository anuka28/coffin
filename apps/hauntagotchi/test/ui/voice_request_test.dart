import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/voice_seed.dart';
import 'package:hauntagotchi/src/domain/voice_trigger.dart';
import 'package:hauntagotchi/src/ui/voice_request.dart';

AiRequest _build({
  VoiceTrigger trigger = VoiceTrigger.checkedOff,
  GhostState state = GhostState.hungry,
  int streak = 0,
  int completed = 2,
  String name = 'Wisp',
  int day = 20000,
}) => buildVoiceRequest(
  trigger: trigger,
  state: state,
  streak: streak,
  completedToday: completed,
  ghostName: name,
  epochDay: day,
);

void main() {
  group('buildVoiceRequest', () {
    test('purpose and maxLength', () {
      final AiRequest r = _build();
      expect(r.purpose, AiPurpose.ghostMoodLine);
      expect(r.maxLength, 80);
    });

    test('streak 0 has no streakCount', () {
      expect(_build().facts.keys.toSet(), <String>{
        AiFactKeys.ghostMood,
        AiFactKeys.ghostEvent,
        AiFactKeys.ghostName,
      });
    });

    test('streak 1 and a large streak carry streakCount', () {
      for (final int s in <int>[1, 1000000]) {
        final AiRequest r = _build(streak: s);
        expect(r.facts.keys.toSet(), <String>{
          AiFactKeys.ghostMood,
          AiFactKeys.ghostEvent,
          AiFactKeys.streakCount,
          AiFactKeys.ghostName,
        });
        expect(r.facts[AiFactKeys.streakCount], s);
      }
    });

    test('event is the trigger name and name fact is the ghost name', () {
      for (final VoiceTrigger t in VoiceTrigger.values) {
        expect(_build(trigger: t).facts[AiFactKeys.ghostEvent], t.name);
      }
      expect(_build(name: 'Boo').facts[AiFactKeys.ghostName], 'Boo');
      expect(
        _build(state: GhostState.dead).facts[AiFactKeys.ghostMood],
        'dead',
      );
    });

    test('seed equals VoiceSeed.compute of the same inputs', () {
      final AiRequest r = _build(
        trigger: VoiceTrigger.resurrected,
        state: GhostState.fading,
        streak: 3,
        completed: 4,
        day: -5,
      );
      expect(
        r.seed,
        VoiceSeed.compute(
          epochDay: -5,
          state: GhostState.fading,
          trigger: VoiceTrigger.resurrected,
          streak: 3,
          completedToday: 4,
        ),
      );
      expect(r.seed, inInclusiveRange(0, AiRequest.maxSeed));
    });
  });
}
