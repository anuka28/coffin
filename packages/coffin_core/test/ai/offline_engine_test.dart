import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/compose_path.dart';
import 'package:coffin_core/src/ai/clean_facts.dart';
import 'package:coffin_core/src/ai/composed_text.dart';
import 'package:coffin_core/src/ai/offline_engine.dart';
import 'package:coffin_core/src/ai/template_catalog.dart';
import 'package:coffin_core/src/ai/template_set.dart';
import 'package:coffin_core/src/ai/text_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineEngine on the standard catalog', () {
    test('a known purpose with its fact picks a template that uses it', () {
      for (var seed = 0; seed < 20; seed++) {
        final ComposedText ghost = OfflineEngine.standard.compose(
          AiRequest(
            purpose: AiPurpose.ghostMoodLine,
            facts: const <String, Object?>{'streakCount': 3},
            maxLength: 80,
            seed: seed,
          ),
        );
        expect(ghost.text, contains('3 days'));
        expect(ghost.path, ComposePath.picked);

        final ComposedText verdict = OfflineEngine.standard.compose(
          AiRequest(
            purpose: AiPurpose.seanceVerdict,
            facts: const <String, Object?>{'daysSinceLastCommit': 214},
            maxLength: 120,
            seed: seed,
          ),
        );
        expect(verdict.text, contains('214 days'));
      }
    });

    test('a fact-free request picks a fact-free template', () {
      const factFree = <String>{
        'Floating along.',
        'Your ghost is getting hungry…',
        'Mist, moonlight and good company.',
        'Your ghost drifts by to say boo. 👻',
        'Your ghost waits by the window, glowing softly.',
      };
      for (var seed = 0; seed < 20; seed++) {
        final ComposedText r = OfflineEngine.standard.compose(
          AiRequest(
            purpose: AiPurpose.ghostMoodLine,
            maxLength: 80,
            seed: seed,
          ),
        );
        expect(factFree, contains(r.text));
        expect(r.path, ComposePath.picked);
      }
    });

    test('a custom purpose gets a generic template', () {
      final generic = <String>{
        'Boo. Hello from the mist.',
        'Something spooky this way comes.',
        'Quiet in here.',
        'The pumpkins say hi. 🎃',
        'A friendly ghost says hello.',
        'This one is waiting in the moonlight.',
      };
      for (var seed = 0; seed < 20; seed++) {
        final ComposedText r = OfflineEngine.standard.compose(
          AiRequest(
            purpose: AiPurpose('my_app_hint'),
            maxLength: 80,
            seed: seed,
          ),
        );
        expect(generic, contains(r.text));
      }
    });

    test('maxLength 16 gives a fitting fact-free template, path picked', () {
      for (final purpose in <AiPurpose>[
        AiPurpose.ghostMoodLine,
        AiPurpose.seanceVerdict,
        AiPurpose('custom_one'),
      ]) {
        for (var seed = 0; seed < 10; seed++) {
          final ComposedText r = OfflineEngine.standard.compose(
            AiRequest(purpose: purpose, maxLength: 16, seed: seed),
          );
          expect(r.text.length, lessThanOrEqualTo(16));
          expect(r.path, ComposePath.picked);
        }
      }
    });

    test('the same request gives the same result twice', () {
      final request = AiRequest(
        purpose: AiPurpose.ghostMoodLine,
        facts: const <String, Object?>{'streakCount': 4, 'ghostName': 'Wisp'},
        maxLength: 80,
        seed: 12345,
      );
      final ComposedText a = OfflineEngine.standard.compose(request);
      final ComposedText b = OfflineEngine(TemplateCatalog.standard)
          .compose(request);
      expect(a.text, b.text);
      expect(a.path, b.path);
    });

    test('the purpose id does not change the text of two custom purposes', () {
      final ComposedText a = OfflineEngine.standard.compose(
        AiRequest(purpose: AiPurpose('first_one'), maxLength: 80, seed: 3),
      );
      final ComposedText b = OfflineEngine.standard.compose(
        AiRequest(purpose: AiPurpose('second_one'), maxLength: 80, seed: 3),
      );
      expect(a.text, b.text);
    });

    // Prototype outputs of design.md ("Golden table"), asserted exactly.
    test('reproduces the prototype texts', () {
      String run(
        AiPurpose purpose,
        Map<String, Object?> facts,
        int maxLength,
        int seed,
      ) => OfflineEngine.standard
          .compose(
            AiRequest(
              purpose: purpose,
              facts: facts,
              maxLength: maxLength,
              seed: seed,
            ),
          )
          .text;
      final AiPurpose ghost = AiPurpose.ghostMoodLine;
      final AiPurpose seance = AiPurpose.seanceVerdict;
      expect(
        run(ghost, const {}, 80, 0),
        'Your ghost drifts by to say boo. 👻',
      );
      expect(
        run(ghost, const {'streakCount': 3, 'ghostName': 'Boo'}, 80, 1),
        '3 days so far. Boo is humming.',
      );
      expect(
        run(ghost, const {'streakCount': 1}, 40, 2),
        '1 day so far. Your ghost is humming.',
      );
      expect(
        run(
          ghost,
          const {'streakCount': 5.0, 'ghostName': 'Wisp'},
          80,
          4294967295,
        ),
        '5 days so far. Wisp is humming.',
      );
      expect(
        run(
          seance,
          const {'daysSinceLastCommit': 214, 'projectName': 'Todo Crypt'},
          120,
          42,
        ),
        'Todo Crypt has been dead for 214 days. Not forever, though.',
      );
      expect(
        run(seance, const {'daysSinceLastCommit': 1}, 60, 7),
        'Last commit: 1 day ago. The ghost remembers.',
      );
      expect(
        run(seance, {'projectName': '👻' * 14}, 100, 3),
        '${'👻' * 12} still glows faintly in the dark.',
      );
      expect(
        run(AiPurpose('my_app_hint'), const {'streakCount': 2}, 60, 5),
        '2 days so far. The moon approves.',
      );
      expect(run(ghost, const {}, 16, 9), 'Floating along.');
      expect(
        run(
          ghost,
          const {'streakCount': 0, 'ghostName': 'a\u0000  b\n'},
          80,
          11,
        ),
        '0 days so far. a b is humming.',
      );
      expect(
        run(ghost, const {'streakCount': 4, 'ghostName': 'Murderous'}, 80, 6),
        'Streak: 4 days. The mist is on your side.',
      );
    });
  });

  group('OfflineEngine Recovery and truncation', () {
    TemplateCatalog only(List<String> patterns, String safeLine) {
      TemplateSet set() => TemplateSet(patterns, safeLine: safeLine);
      return TemplateCatalog(
        ghostMoodLine: set(),
        seanceVerdict: set(),
        generic: set(),
      );
    }

    ComposedText run(
      TemplateCatalog catalog,
      Map<String, Object?> facts,
      int maxLength, {
      int seed = 0,
    }) => OfflineEngine(catalog).compose(
      AiRequest(
        purpose: AiPurpose.ghostMoodLine,
        facts: facts,
        maxLength: maxLength,
        seed: seed,
      ),
    );

    final TemplateCatalog boundary = only(const <String>[
      'Hush, a mur{ghostName|!}',
    ], 'Boo. Still here.');

    test('step (a): a word formed across the slot boundary drops the name', () {
      // The name passes the early filter and the combined text is banned.
      expect(CleanFacts.from(const {'ghostName': 'der'}).ghostName, 'der');
      expect(TextRules.containsBanned('Hush, a murder'), isTrue);

      for (final seed in <int>[0, 1, 99]) {
        final ComposedText r = run(
          boundary,
          const {'ghostName': 'der'},
          80,
          seed: seed,
        );
        expect(r.text, 'Hush, a mur!');
        expect(r.path, ComposePath.noNameVariant);
      }
    });

    test('step (a) is not applied without a reason', () {
      final ComposedText r = run(boundary, const {'ghostName': 'Bo'}, 80);
      expect(r.text, 'Hush, a murBo');
      expect(r.path, ComposePath.picked);
    });

    test('step (b): the next template is used when the bare one is banned', () {
      final TemplateCatalog c = only(const <String>[
        'Hush, a mur{ghostName|der}',
        'Calm night.',
      ], 'Boo. Still here.');
      final ComposedText r = run(c, const {'ghostName': 'der'}, 80);
      expect(r.text, 'Calm night.');
      expect(r.path, ComposePath.nextTemplate);
    });

    test('step (c): a catalog banned by its own text gives the Safe_Line', () {
      final TemplateCatalog c = only(const <String>[
        'Gore galore',
        'A bloody mess {ghostName|x}',
      ], 'Boo. Still here.');
      expect(TextRules.containsBanned('Gore galore'), isTrue);
      expect(TextRules.containsBanned('A bloody mess x'), isTrue);
      for (final seed in <int>[0, 1, 7]) {
        final ComposedText r = run(
          c,
          const {'ghostName': 'Wisp'},
          80,
          seed: seed,
        );
        expect(r.text, 'Boo. Still here.');
        expect(r.path, ComposePath.safeLine);
      }
      // Task 8.1 adds the same assertion through the public OfflineCoffinAI.
    });

    test('a recovery candidate that does not fit is skipped, not cut', () {
      final TemplateCatalog c = only(const <String>[
        'Hush, a mur{ghostName|der}',
        'A calm and very quiet night in the old graveyard.',
        'Calm.',
      ], 'Boo. Still here.');
      // Seed 1 starts the rotation at the long template.
      final ComposedText r = run(c, const {'ghostName': 'der'}, 20, seed: 1);
      expect(r.text, 'Calm.');
      expect(r.path, ComposePath.nextTemplate);
    });

    test('an empty eligible pool gives the Safe_Line', () {
      final TemplateCatalog c = only(const <String>[
        'Streak: {streakCount:day/days}.',
      ], 'Boo. Still here.');
      final ComposedText r = run(c, const {}, 80);
      expect(r.text, 'Boo. Still here.');
      expect(r.path, ComposePath.safeLine);
    });

    test('truncation cuts to the limit with an ellipsis', () {
      const String long = 'This is a rather long template for a tiny limit.';
      expect(long.length, 48);
      final ComposedText r = run(
        only(const <String>[long], 'Boo.'),
        const {},
        16,
      );
      expect(r.text, 'This is a rathe…');
      expect(r.text.length, 16);
      expect(r.path, ComposePath.truncated);
    });

    test('truncation does not split a surrogate pair', () {
      const String text = 'abcdefghijklmn👻👻 and more words';
      final ComposedText r = run(
        only(const <String>[text], 'Boo.'),
        const {},
        16,
      );
      expect(r.text, 'abcdefghijklmn…');
      expect(r.text.length, 15);
      expect(r.path, ComposePath.truncated);
      for (var i = 0; i < r.text.length; i++) {
        final int u = r.text.codeUnitAt(i);
        expect(u >= 0xD800 && u <= 0xDFFF, isFalse);
      }
    });
  });
}
