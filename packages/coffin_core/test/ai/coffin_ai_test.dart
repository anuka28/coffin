import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_reply.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/coffin_ai.dart';
import 'package:coffin_core/src/ai/reply_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Implements only `ask`, so the test fails to compile if the interface
/// gains another abstract member.
class _EchoAi implements CoffinAI {
  @override
  Future<AiReply> ask(AiRequest request) async =>
      const AiReply(text: 'Boo.', source: ReplySource.offline);
}

void main() {
  group('CoffinAI', () {
    test('a class implementing only ask is a CoffinAI', () async {
      final CoffinAI ai = _EchoAi();
      final request = AiRequest(
        purpose: AiPurpose.ghostMoodLine,
        maxLength: 80,
      );
      final reply = await ai.ask(request);
      expect(reply.text, 'Boo.');
      expect(reply.source, ReplySource.offline);
    });

    test('ask returns a Future<AiReply>', () {
      final CoffinAI ai = _EchoAi();
      final request = AiRequest(
        purpose: AiPurpose.ghostMoodLine,
        maxLength: 80,
      );
      expect(ai.ask(request), isA<Future<AiReply>>());
    });
  });
}
