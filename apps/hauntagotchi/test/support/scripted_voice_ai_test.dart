import 'dart:async';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_voice_ai.dart';

AiRequest _request(int seed) => AiRequest(
  purpose: AiPurpose.ghostMoodLine,
  facts: const <String, Object?>{'ghostMood': 'content'},
  maxLength: 80,
  seed: seed,
);

void main() {
  group('ScriptedVoiceAi', () {
    test('records every request in call order', () async {
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('a')
        ..replyWith('b');
      await ai.ask(_request(1));
      await ai.ask(_request(2));

      expect(ai.callCount, 2);
      expect(ai.requests, <AiRequest>[_request(1), _request(2)]);
      expect(ai.remaining, 0);
    });

    test('answers a text', () async {
      final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Boo.');
      final AiReply reply = await ai.ask(_request(1));

      expect(reply, const AiReply(text: 'Boo.', source: ReplySource.offline));
    });

    test('answers calls from the script in order', () async {
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('one')
        ..failWith(StateError('boom'))
        ..replyWith('three');

      expect((await ai.ask(_request(1))).text, 'one');
      await expectLater(ai.ask(_request(2)), throwsStateError);
      expect((await ai.ask(_request(3))).text, 'three');
    });

    test('a delayed text waits for the test to complete it', () async {
      final ScriptedVoiceAi ai = ScriptedVoiceAi();
      final Completer<String> gate = ai.replyLater();

      AiReply? answer;
      final Future<void> pending = ai.ask(_request(1)).then((AiReply r) {
        answer = r;
      });
      await Future<void>.delayed(Duration.zero);
      expect(answer, isNull);

      gate.complete('late');
      await pending;
      expect(answer?.text, 'late');
    });

    test(
      'a delayed answer can fail when the test completes it with an error',
      () async {
        final ScriptedVoiceAi ai = ScriptedVoiceAi();
        final Completer<String> gate = ai.replyLater();

        final Future<AiReply> call = ai.ask(_request(1));
        gate.completeError(StateError('late boom'));

        await expectLater(call, throwsStateError);
      },
    );

    test('a later call can finish before an earlier delayed one', () async {
      final ScriptedVoiceAi ai = ScriptedVoiceAi();
      final Completer<String> slow = ai.replyLater();
      ai.replyWith('fast');

      final Future<AiReply> first = ai.ask(_request(1));
      final AiReply second = await ai.ask(_request(2));
      expect(second.text, 'fast');

      slow.complete('slow');
      expect((await first).text, 'slow');
    });

    test('a thrown error fails the future, not the call', () async {
      final ScriptedVoiceAi ai = ScriptedVoiceAi()..failWith(StateError('x'));

      late Future<AiReply> call;
      expect(() => call = ai.ask(_request(1)), returnsNormally);
      await expectLater(call, throwsStateError);
    });

    test('a hang never completes', () async {
      final ScriptedVoiceAi ai = ScriptedVoiceAi()..hang();

      bool done = false;
      unawaited(
        ai
            .ask(_request(1))
            .then((_) => done = true, onError: (_) => done = true),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(done, isFalse);
      expect(ai.callCount, 1);
    });

    test('a hang ends with a timeout when the caller sets one', () async {
      final ScriptedVoiceAi ai = ScriptedVoiceAi()..hang();

      await expectLater(
        ai.ask(_request(1)).timeout(const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test(
      'an empty script fails the future and still records the call',
      () async {
        final ScriptedVoiceAi ai = ScriptedVoiceAi();

        await expectLater(ai.ask(_request(1)), throwsStateError);
        expect(ai.callCount, 1);
      },
    );

    test('the requests list cannot be edited', () {
      final ScriptedVoiceAi ai = ScriptedVoiceAi();
      expect(() => ai.requests.add(_request(1)), throwsUnsupportedError);
    });
  });
}
