import 'package:coffin_core/src/ai/ai_fact_keys.dart';
import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_reply.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/coffin_ai.dart';
import 'package:coffin_core/src/ai/offline_coffin_ai.dart';
import 'package:coffin_core/src/ai/offline_engine.dart';
import 'package:coffin_core/src/ai/reply_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_texts.dart';

AiRequest _request(
  AiPurpose purpose, {
  Map<String, Object?> facts = const <String, Object?>{},
  int maxLength = 80,
  int seed = 0,
}) =>
    AiRequest(purpose: purpose, facts: facts, maxLength: maxLength, seed: seed);

/// Checks the rules every offline reply must meet.
void _expectGoodReply(AiReply reply, AiRequest request) {
  expect(reply.source, ReplySource.offline);
  expect(reply.isUsableFor(request), isTrue);
  expect(reply.text.length, lessThanOrEqualTo(request.maxLength));
  expect(hasEdgeWhitespace(reply.text), isFalse);
  expect(hasLoneSurrogate(reply.text), isFalse);
  expect(hasTestBannedWord(reply.text), isFalse);
  expect(hasTestInsultWord(reply.text), isFalse);
  expect(reply.text.codeUnits.any((int u) => u < 0x20 || u == 0x7F), isFalse);
}

/// Pumps a fixed number of microtasks. Never starts a timer.
Future<void> _pump([int times = 5]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.value();
  }
}

void main() {
  const CoffinAI ai = OfflineCoffinAI();

  group('OfflineCoffinAI golden table', () {
    // Exact texts, written out as literals. Never computed in the test.
    // Changing a template, the order of a set or the generator changes them.
    final golden = <(String, AiRequest, String)>[
      (
        '1 ghost mood, no facts',
        _request(AiPurpose.ghostMoodLine),
        'Your ghost drifts by to say boo. \u{1F47B}',
      ),
      (
        '2 ghost mood, streak 3, Boo',
        _request(
          AiPurpose.ghostMoodLine,
          facts: const <String, Object?>{'streakCount': 3, 'ghostName': 'Boo'},
          seed: 1,
        ),
        '3 days so far. Boo is humming.',
      ),
      (
        '3 ghost mood, streak 1, max 40',
        _request(
          AiPurpose.ghostMoodLine,
          facts: const <String, Object?>{'streakCount': 1},
          maxLength: 40,
          seed: 2,
        ),
        '1 day so far. Your ghost is humming.',
      ),
      (
        '4 ghost mood, streak 5.0, Wisp, top seed',
        _request(
          AiPurpose.ghostMoodLine,
          facts: const <String, Object?>{
            'streakCount': 5.0,
            'ghostName': 'Wisp',
          },
          seed: 4294967295,
        ),
        '5 days so far. Wisp is humming.',
      ),
      (
        '5 seance, 214 days, Todo Crypt',
        _request(
          AiPurpose.seanceVerdict,
          facts: const <String, Object?>{
            'daysSinceLastCommit': 214,
            'projectName': 'Todo Crypt',
          },
          maxLength: 120,
          seed: 42,
        ),
        'Todo Crypt has been dead for 214 days. Not forever, though.',
      ),
      (
        '6 seance, 1 day, max 60',
        _request(
          AiPurpose.seanceVerdict,
          facts: const <String, Object?>{'daysSinceLastCommit': 1},
          maxLength: 60,
          seed: 7,
        ),
        'Last commit: 1 day ago. The ghost remembers.',
      ),
      (
        '7 seance, 14 ghost emoji name',
        _request(
          AiPurpose.seanceVerdict,
          facts: <String, Object?>{'projectName': '\u{1F47B}' * 14},
          maxLength: 100,
          seed: 3,
        ),
        '\u{1F47B}\u{1F47B}\u{1F47B}\u{1F47B}\u{1F47B}\u{1F47B}'
            '\u{1F47B}\u{1F47B}\u{1F47B}\u{1F47B}\u{1F47B}\u{1F47B}'
            ' still glows faintly in the dark.',
      ),
      (
        '8 custom purpose, streak 2, max 60',
        _request(
          AiPurpose('my_app_hint'),
          facts: const <String, Object?>{'streakCount': 2},
          maxLength: 60,
          seed: 5,
        ),
        '2 days so far. The moon approves.',
      ),
      (
        '9 ghost mood, no facts, max 16',
        _request(AiPurpose.ghostMoodLine, maxLength: 16, seed: 9),
        'Floating along.',
      ),
      (
        '10 ghost mood, streak 0, messy name',
        _request(
          AiPurpose.ghostMoodLine,
          facts: const <String, Object?>{
            'streakCount': 0,
            'ghostName': 'a\u0000  b\n',
          },
          seed: 11,
        ),
        'a b waits by the window, glowing softly.',
      ),
      (
        '11 ghost mood, streak 4, banned name',
        _request(
          AiPurpose.ghostMoodLine,
          facts: const <String, Object?>{
            'streakCount': 4,
            'ghostName': 'Murderous',
          },
          seed: 6,
        ),
        'Streak: 4 days. The mist is on your side.',
      ),
    ];

    for (final (String name, AiRequest request, String expected) in golden) {
      test('golden $name', () async {
        final reply = await ai.ask(request);
        expect(reply.text, expected);
        expect(reply.source, ReplySource.offline);
        if (name.startsWith('10 ')) {
          expect(reply.text, isNot(contains('0 day')));
        }
      });
    }
  });

  group('OfflineCoffinAI purposes', () {
    test('ghost_mood_line gives a fitting offline reply', () async {
      for (var seed = 0; seed < 10; seed++) {
        final r = _request(AiPurpose.ghostMoodLine, seed: seed);
        _expectGoodReply(await ai.ask(r), r);
      }
    });

    test('seance_verdict gives a fitting offline reply', () async {
      for (var seed = 0; seed < 10; seed++) {
        final r = _request(AiPurpose.seanceVerdict, maxLength: 120, seed: seed);
        _expectGoodReply(await ai.ask(r), r);
      }
    });

    test('an app-defined purpose gives a fitting offline reply', () async {
      final purpose = AiPurpose('app_custom_line');
      for (var seed = 0; seed < 10; seed++) {
        final r = _request(purpose, seed: seed);
        _expectGoodReply(await ai.ask(r), r);
      }
    });

    test(
      'an app purpose that reuses ghost_mood_line matches the known one',
      () async {
        final reused = AiPurpose('ghost_mood_line');
        for (var seed = 0; seed < 10; seed++) {
          const facts = <String, Object?>{'streakCount': 4};
          final known = await ai.ask(
            _request(AiPurpose.ghostMoodLine, facts: facts, seed: seed),
          );
          final custom = await ai.ask(
            _request(reused, facts: facts, seed: seed),
          );
          expect(custom, known);
        }
      },
    );

    test('the purpose identifier never appears in the reply', () async {
      final purposes = <AiPurpose>[
        AiPurpose.ghostMoodLine,
        AiPurpose.seanceVerdict,
        AiPurpose('app_custom_line'),
      ];
      for (final purpose in purposes) {
        for (var seed = 0; seed < 10; seed++) {
          final reply = await ai.ask(_request(purpose, seed: seed));
          expect(reply.text, isNot(contains(purpose.id)));
        }
      }
    });
  });

  group('OfflineCoffinAI facts', () {
    test('a fact-using reply holds the count', () async {
      for (var seed = 0; seed < 20; seed++) {
        final r = _request(
          AiPurpose.ghostMoodLine,
          facts: const <String, Object?>{AiFactKeys.streakCount: 3},
          seed: seed,
        );
        final reply = await ai.ask(r);
        _expectGoodReply(reply, r);
        expect(reply.text, contains('3 days'));
      }
    });

    test('a count of 1 is singular', () async {
      final r = _request(
        AiPurpose.seanceVerdict,
        facts: const <String, Object?>{AiFactKeys.daysSinceLastCommit: 1},
        maxLength: 120,
      );
      final reply = await ai.ask(r);
      expect(reply.text, contains('1 day'));
      expect(reply.text, isNot(contains('1 days')));
    });

    test('missing facts still give a good reply', () async {
      for (final purpose in <AiPurpose>[
        AiPurpose.ghostMoodLine,
        AiPurpose.seanceVerdict,
      ]) {
        final r = _request(purpose);
        _expectGoodReply(await ai.ask(r), r);
      }
    });

    test('wrong-type facts are ignored', () async {
      const facts = <String, Object?>{
        AiFactKeys.streakCount: 'seven',
        AiFactKeys.daysSinceLastCommit: true,
        AiFactKeys.ghostName: 42,
        AiFactKeys.projectName: <String>['x'],
      };
      for (var seed = 0; seed < 10; seed++) {
        final r = _request(AiPurpose.ghostMoodLine, facts: facts, seed: seed);
        final reply = await ai.ask(r);
        _expectGoodReply(reply, r);
        expect(reply.text, isNot(contains('seven')));
        expect(reply.text, isNot(contains('42')));
      }
    });

    test('out-of-range counts are ignored', () async {
      final bad = <Object?>[
        -5,
        1000001,
        2.5,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ];
      for (final value in bad) {
        for (var seed = 0; seed < 5; seed++) {
          final r = _request(
            AiPurpose.ghostMoodLine,
            facts: <String, Object?>{AiFactKeys.streakCount: value},
            seed: seed,
          );
          final reply = await ai.ask(r);
          _expectGoodReply(reply, r);
          expect(reply.text, isNot(contains('day')));
        }
      }
    });

    test('a zero count never shows up as 0 day', () async {
      final zeros = <(String, Object?)>[
        (AiFactKeys.streakCount, 0),
        (AiFactKeys.streakCount, 0.0),
        (AiFactKeys.streakCount, -0.0),
        (AiFactKeys.daysSinceLastCommit, 0),
      ];
      for (final purpose in <AiPurpose>[
        AiPurpose.ghostMoodLine,
        AiPurpose.seanceVerdict,
      ]) {
        for (final z in zeros) {
          for (var seed = 0; seed <= 50; seed++) {
            final r = _request(
              purpose,
              facts: <String, Object?>{z.$1: z.$2},
              seed: seed,
            );
            final reply = await ai.ask(r);
            expect(
              reply.text.contains('0 day'),
              isFalse,
              reason: '${purpose.id} ${z.$1}=${z.$2} seed $seed: ${reply.text}',
            );
          }
        }
      }
    });

    test('the largest count and one are accepted', () async {
      for (final count in <int>[1, 1000000]) {
        var seen = false;
        for (var seed = 0; seed < 20; seed++) {
          final r = _request(
            AiPurpose.ghostMoodLine,
            facts: <String, Object?>{AiFactKeys.streakCount: count},
            seed: seed,
          );
          final reply = await ai.ask(r);
          _expectGoodReply(reply, r);
          if (reply.text.contains('$count day')) seen = true;
        }
        expect(seen, isTrue);
      }
    });

    test('extra facts never appear in the reply', () async {
      const facts = <String, Object?>{
        'streakCount': 2,
        'favouriteColour': 'chartreuse',
        'extraNumber': 987654,
      };
      for (var seed = 0; seed < 20; seed++) {
        final r = _request(AiPurpose.ghostMoodLine, facts: facts, seed: seed);
        final reply = await ai.ask(r);
        _expectGoodReply(reply, r);
        expect(reply.text, isNot(contains('chartreuse')));
        expect(reply.text, isNot(contains('987654')));
        expect(reply.text, isNot(contains('favouriteColour')));
      }
    });

    test('a name with emoji and accents can appear whole', () async {
      var seen = false;
      for (var seed = 0; seed < 30; seed++) {
        final r = _request(
          AiPurpose.ghostMoodLine,
          facts: const <String, Object?>{AiFactKeys.ghostName: 'Mörg👻'},
          seed: seed,
        );
        final reply = await ai.ask(r);
        _expectGoodReply(reply, r);
        if (reply.text.contains('Mörg👻')) seen = true;
      }
      expect(seen, isTrue);
    });

    test('control characters in a name never reach the reply', () async {
      for (var seed = 0; seed < 30; seed++) {
        final r = _request(
          AiPurpose.ghostMoodLine,
          facts: const <String, Object?>{
            AiFactKeys.ghostName: 'Bo\u0000o\n\t\u007F!',
          },
          seed: seed,
        );
        _expectGoodReply(await ai.ask(r), r);
      }
    });

    test('a name over 24 units never appears in full', () async {
      final long = 'Wraith${'x' * 40}';
      for (var seed = 0; seed < 30; seed++) {
        final r = _request(
          AiPurpose.ghostMoodLine,
          facts: <String, Object?>{AiFactKeys.ghostName: long},
          seed: seed,
        );
        final reply = await ai.ask(r);
        _expectGoodReply(reply, r);
        expect(reply.text, isNot(contains(long)));
      }
    });

    test('a banned word in a name never reaches the reply', () async {
      for (var seed = 0; seed < 30; seed++) {
        final r = _request(
          AiPurpose.seanceVerdict,
          facts: const <String, Object?>{AiFactKeys.projectName: 'Bloodhound'},
          maxLength: 120,
          seed: seed,
        );
        final reply = await ai.ask(r);
        _expectGoodReply(reply, r);
        expect(reply.text.toLowerCase(), isNot(contains('blood')));
      }
    });
  });

  group('OfflineCoffinAI length', () {
    test('maxLength 16 and 17 give fitting replies', () async {
      for (final max in <int>[16, 17]) {
        for (final purpose in <AiPurpose>[
          AiPurpose.ghostMoodLine,
          AiPurpose.seanceVerdict,
          AiPurpose('app_custom_line'),
        ]) {
          for (var seed = 0; seed < 20; seed++) {
            final r = _request(
              purpose,
              facts: const <String, Object?>{
                AiFactKeys.streakCount: 123,
                AiFactKeys.daysSinceLastCommit: 214,
                AiFactKeys.ghostName: 'Casper the Friendly',
                AiFactKeys.projectName: 'Old Side Project',
              },
              maxLength: max,
              seed: seed,
            );
            _expectGoodReply(await ai.ask(r), r);
          }
        }
      }
    });
  });

  group('OfflineCoffinAI behaviour', () {
    test('the future completes in the next microtask, with no timer', () async {
      final r = _request(AiPurpose.ghostMoodLine);
      var done = false;
      AiReply? got;
      final future = ai.ask(r).then((AiReply v) {
        done = true;
        got = v;
      });
      // Not complete synchronously.
      expect(done, isFalse);
      // A small fixed number of microtask turns, never an event-loop turn.
      await _pump(3);
      expect(done, isTrue);
      expect(got, isNotNull);
      await future;
    });

    test('a const OfflineCoffinAI is usable', () async {
      const a = OfflineCoffinAI();
      const b = OfflineCoffinAI();
      final r = _request(AiPurpose.ghostMoodLine);
      expect(await a.ask(r), await b.ask(r));
    });

    test('call order does not change a reply', () async {
      final requests = <AiRequest>[
        for (var seed = 0; seed < 6; seed++)
          _request(
            seed.isEven ? AiPurpose.ghostMoodLine : AiPurpose.seanceVerdict,
            facts: <String, Object?>{AiFactKeys.streakCount: seed},
            maxLength: 40 + seed,
            seed: seed,
          ),
      ];
      final forward = <AiReply>[for (final r in requests) await ai.ask(r)];
      final backward = <AiReply>[
        for (final r in requests.reversed) await ai.ask(r),
      ].reversed.toList();
      expect(backward, forward);
      // A repeated call gives the same reply too.
      expect(await ai.ask(requests.first), forward.first);
    });

    test('the public class is a thin shell over the standard engine', () async {
      final requests = <AiRequest>[
        _request(AiPurpose.ghostMoodLine, seed: 3),
        _request(
          AiPurpose.seanceVerdict,
          facts: const <String, Object?>{AiFactKeys.daysSinceLastCommit: 9},
          maxLength: 60,
          seed: 7,
        ),
        _request(AiPurpose('app_custom_line'), maxLength: 16, seed: 11),
      ];
      for (final r in requests) {
        expect(
          await ai.ask(r),
          AiReply(
            text: OfflineEngine.standard.compose(r).text,
            source: ReplySource.offline,
          ),
        );
      }
    });
  });
}
