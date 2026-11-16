import 'dart:async';

import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_reply.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/reply_source.dart';
import 'package:coffin_core/src/ai/text_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_ai.dart';

AiRequest _request({int maxLength = 40, int seed = 0}) => AiRequest(
  purpose: AiPurpose.ghostMoodLine,
  maxLength: maxLength,
  seed: seed,
);

Future<void> _pump() async {
  for (int i = 0; i < 20; i++) {
    await Future<void>.value();
  }
}

void main() {
  group('ScriptedCoffinAI', () {
    test('a usable reply carries the given source', () async {
      final ReplySource remote = ReplySource('remote');
      final ScriptedCoffinAI ai = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.reply('Boo.', source: remote),
        ScriptedOutcome.reply('Hi.'),
      ]);
      final AiReply first = await ai.ask(_request());
      expect(first.text, 'Boo.');
      expect(first.source, remote);
      final AiReply second = await ai.ask(_request());
      expect(second.source, scriptedSource);
      expect(first.isUsableFor(_request()), isTrue);
    });

    test('syncThrow throws inside ask, not in the future', () {
      final ScriptedCoffinAI ai = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.syncThrow(StateError('boom')),
      ]);
      expect(() => ai.ask(_request()), throwsStateError);
      expect(ai.callCount, 1);
    });

    test('asyncError returns a failed future without throwing in ask', () {
      final ScriptedCoffinAI ai = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.asyncError(),
      ]);
      final Future<AiReply> future = ai.ask(_request());
      expect(future, throwsA(isA<Exception>()));
    });

    test('never returns a future that does not complete', () async {
      final ScriptedCoffinAI ai = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.never(),
      ]);
      bool done = false;
      unawaited(
        ai
            .ask(_request())
            .then((_) => done = true, onError: (_) => done = true),
      );
      await _pump();
      expect(done, isFalse);
    });

    test('lateReply completes only when the test completes it', () async {
      final Completer<AiReply> completer = Completer<AiReply>();
      final ScriptedCoffinAI ai = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.lateReply(completer),
      ]);
      AiReply? got;
      unawaited(ai.ask(_request()).then((AiReply r) => got = r));
      await _pump();
      expect(got, isNull);
      final AiReply reply = AiReply(text: 'Late.', source: scriptedSource);
      completer.complete(reply);
      await _pump();
      expect(got, same(reply));
    });

    test('lateError fails only when the test fails it', () async {
      final Completer<AiReply> completer = Completer<AiReply>();
      final ScriptedCoffinAI ai = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.lateError(completer),
      ]);
      Object? caught;
      bool done = false;
      unawaited(
        ai
            .ask(_request())
            .then(
              (_) => done = true,
              onError: (Object e) {
                caught = e;
                done = true;
              },
            ),
      );
      await _pump();
      expect(done, isFalse);
      completer.completeError(StateError('late'));
      await _pump();
      expect(caught, isA<StateError>());
    });

    test('blank outcomes give empty or whitespace-only text', () async {
      final ScriptedCoffinAI ai = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.blank(),
        ScriptedOutcome.blank(' \t\n '),
      ]);
      final AiReply empty = await ai.ask(_request());
      final AiReply spaces = await ai.ask(_request());
      expect(empty.text, '');
      expect(TextRules.isBlank(spaces.text), isTrue);
      expect(spaces.text, isNotEmpty);
      expect(empty.isUsableFor(_request()), isFalse);
      expect(spaces.isUsableFor(_request()), isFalse);
    });

    test('overlong is one unit over the request limit', () async {
      final ScriptedCoffinAI ai = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.overlong(),
        ScriptedOutcome.overlong(),
      ]);
      final AiReply a = await ai.ask(_request(maxLength: 16));
      final AiReply b = await ai.ask(_request(maxLength: 200));
      expect(a.text.length, 17);
      expect(b.text.length, 201);
      expect(TextRules.isBlank(a.text), isFalse);
      expect(a.isUsableFor(_request(maxLength: 16)), isFalse);
    });

    test('counts calls and records the same request objects', () async {
      final ScriptedCoffinAI ai = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.reply('a'),
        ScriptedOutcome.asyncError(),
        ScriptedOutcome.syncThrow(),
      ]);
      expect(ai.callCount, 0);
      expect(ai.requests, isEmpty);
      final AiRequest r1 = _request(seed: 1);
      final AiRequest r2 = _request(seed: 2);
      final AiRequest r3 = _request(seed: 3);
      await ai.ask(r1);
      await ai.ask(r2).then((_) {}, onError: (_) {});
      expect(() => ai.ask(r3), throwsA(anything));
      expect(ai.callCount, 3);
      expect(ai.requests, hasLength(3));
      expect(identical(ai.requests[0], r1), isTrue);
      expect(identical(ai.requests[1], r2), isTrue);
      expect(identical(ai.requests[2], r3), isTrue);
    });

    test('a call beyond the script throws a StateError', () {
      final ScriptedCoffinAI ai = ScriptedCoffinAI(<ScriptedOutcome>[]);
      expect(() => ai.ask(_request()), throwsStateError);
      expect(ai.callCount, 1);
    });
  });

  group('ScriptedSecondary', () {
    test('throws asynchronously by default', () {
      final ScriptedSecondary s = ScriptedSecondary.throws();
      final Future<AiReply> f = s.ask(_request());
      expect(f, throwsA(isA<Exception>()));
      expect(s.callCount, 1);
    });

    test('throws synchronously on request', () {
      final ScriptedSecondary s = ScriptedSecondary.throws(synchronously: true);
      expect(() => s.ask(_request()), throwsA(isA<Exception>()));
      expect(s.callCount, 1);
    });

    test('empty gives an empty reply', () async {
      final ScriptedSecondary s = ScriptedSecondary.empty();
      final AiReply reply = await s.ask(_request());
      expect(reply.text, '');
    });

    test(
      'overlong gives a reply over the limit and records requests',
      () async {
        final ScriptedSecondary s = ScriptedSecondary.overlong();
        final AiRequest r = _request(maxLength: 20);
        final AiReply reply = await s.ask(r);
        expect(reply.text.length, 21);
        expect(s.requests.single, same(r));
        expect(s.mode, SecondaryMode.overlong);
      },
    );
  });
}
