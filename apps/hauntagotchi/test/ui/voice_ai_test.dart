import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/voice_trigger.dart';
import 'package:hauntagotchi/src/ui/voice_ai.dart';
import 'package:hauntagotchi/src/ui/voice_request.dart';

AiRequest _request() => buildVoiceRequest(
  trigger: VoiceTrigger.checkedOff,
  state: GhostState.hungry,
  streak: 3,
  completedToday: 1,
  ghostName: 'Wisp',
  epochDay: 20000,
);

void main() {
  group('defaultVoiceAi', () {
    test('answers a mood request offline with a short line', () async {
      final AiReply reply = await defaultVoiceAi().ask(_request());
      expect(reply.source, ReplySource.offline);
      expect(reply.text.trim(), isNotEmpty);
      expect(reply.text.length, lessThanOrEqualTo(80));
    });

    test('gives the same text for the same request', () async {
      final CoffinAI ai = defaultVoiceAi();
      final AiReply a = await ai.ask(_request());
      final AiReply b = await ai.ask(_request());
      expect(a.text, b.text);
    });
  });
}
