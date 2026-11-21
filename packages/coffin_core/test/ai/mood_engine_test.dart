import 'package:coffin_core/src/ai/ai_fact_keys.dart';
import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/clean_facts.dart';
import 'package:coffin_core/src/ai/mood_templates.dart';
import 'package:coffin_core/src/ai/offline_engine.dart';
import 'package:coffin_core/src/ai/template.dart';
import 'package:coffin_core/src/ai/template_catalog.dart';
import 'package:coffin_core/src/ai/template_set.dart';
import 'package:flutter_test/flutter_test.dart';

const List<int> _seeds = <int>[0, 1, 7, 42, 1000, 65535, 4294967295];

AiRequest _request({
  Object? mood,
  Object? event,
  Object? streak,
  Object? name,
  int maxLength = 80,
  int seed = 0,
  AiPurpose purpose = AiPurpose.ghostMoodLine,
}) {
  return AiRequest(
    purpose: purpose,
    facts: <String, Object?>{
      AiFactKeys.ghostMood: ?mood,
      AiFactKeys.ghostEvent: ?event,
      AiFactKeys.streakCount: ?streak,
      AiFactKeys.ghostName: ?name,
    },
    maxLength: maxLength,
    seed: seed,
  );
}

String _text(AiRequest request) => OfflineEngine.standard.compose(request).text;

/// Every text the set can give for [facts]: eligible templates and the safe
/// line.
Set<String> _allowed(TemplateSet set, CleanFacts facts) {
  return <String>{
    set.safeLine,
    for (final Template t in set.templates)
      if (t.isEligible(facts)) t.render(facts),
  };
}

void main() {
  const CleanFacts withBoth = CleanFacts(streakCount: 3, ghostName: 'Wisp');
  const CleanFacts none = CleanFacts();

  group('mood and event', () {
    test('a valid mood picks from that mood base set or its safe line', () {
      for (final String mood in CleanFacts.moods) {
        final TemplateSet set = MoodTemplates.standard.setFor(mood, null);
        final Set<String> allowed = _allowed(set, withBoth);
        for (final int seed in _seeds) {
          final String text = _text(
            _request(mood: mood, streak: 3, name: 'Wisp', seed: seed),
          );
          expect(allowed, contains(text), reason: '$mood seed $seed');
        }
      }
    });

    test('a valid event picks from the event subset', () {
      for (final String mood in CleanFacts.moods) {
        for (final String event in CleanFacts.events) {
          final TemplateSet set = MoodTemplates.standard.setFor(mood, event);
          expect(
            identical(set, MoodTemplates.standard.sets['$mood/$event']),
            isTrue,
            reason: '$mood/$event has its own set',
          );
          final Set<String> allowed = _allowed(set, withBoth);
          for (final int seed in _seeds) {
            final String text = _text(
              _request(
                mood: mood,
                event: event,
                streak: 3,
                name: 'Wisp',
                seed: seed,
              ),
            );
            expect(allowed, contains(text), reason: '$mood/$event seed $seed');
          }
        }
      }
    });

    test('a mood without an event uses the base set', () {
      for (final String mood in CleanFacts.moods) {
        final Set<String> allowed = _allowed(
          MoodTemplates.standard.sets[mood]!,
          none,
        );
        for (final int seed in _seeds) {
          expect(allowed, contains(_text(_request(mood: mood, seed: seed))));
        }
      }
    });

    test('an invalid mood behaves as absent', () {
      const List<Object?> bad = <Object?>[
        'fed',
        'rising',
        'Hungry',
        ' hungry',
        '',
        5,
        true,
        <String>['hungry'],
      ];
      for (final Object? mood in bad) {
        for (final int seed in _seeds) {
          expect(
            _text(_request(mood: mood, event: 'checkedOff', seed: seed)),
            _text(_request(event: 'checkedOff', seed: seed)),
            reason: '$mood seed $seed',
          );
        }
      }
    });

    test('an invalid event behaves as absent', () {
      const List<Object?> bad = <Object?>[
        'opened',
        'CheckedOff',
        'checkedOff ',
        '',
        3,
        false,
      ];
      for (final Object? event in bad) {
        for (final int seed in _seeds) {
          expect(
            _text(_request(mood: 'hungry', event: event, seed: seed)),
            _text(_request(mood: 'hungry', seed: seed)),
            reason: '$event seed $seed',
          );
        }
      }
    });

    test('an event without a valid mood uses the legacy set', () {
      final Set<String> legacy = _allowed(
        TemplateCatalog.standard.ghostMoodLine,
        none,
      );
      for (final int seed in _seeds) {
        expect(
          legacy,
          contains(_text(_request(event: 'checkedOff', seed: seed))),
        );
      }
    });

    test('the streak and the name appear when valid and eligible', () {
      for (final String mood in <String>['thriving', 'content']) {
        bool sawStreak = false;
        bool sawName = false;
        for (int seed = 0; seed < 200; seed++) {
          final String text = _text(
            _request(mood: mood, streak: 5, name: 'Wisp', seed: seed),
          );
          if (text.contains('5 days')) sawStreak = true;
          if (text.contains('Wisp')) sawName = true;
        }
        expect(sawStreak, isTrue, reason: '$mood streak');
        expect(sawName, isTrue, reason: '$mood name');
      }
    });

    test('a bad streak or name is left out', () {
      for (final int seed in _seeds) {
        final String text = _text(
          _request(mood: 'thriving', streak: 0, name: 'blood', seed: seed),
        );
        expect(text.contains('blood'), isFalse);
        expect(text.contains('0 days'), isFalse);
      }
    });

    test('maxLength 16 still gives a non-empty line of at most 16', () {
      for (final String mood in CleanFacts.moods) {
        for (final String? event in <String?>[null, ...CleanFacts.events]) {
          for (final int seed in _seeds) {
            final String text = _text(
              _request(
                mood: mood,
                event: event,
                streak: 1000000,
                name: 'Wisp',
                maxLength: 16,
                seed: seed,
              ),
            );
            expect(text, isNotEmpty, reason: '$mood/$event');
            expect(text.length, lessThanOrEqualTo(16), reason: '$mood/$event');
          }
        }
      }
    });

    test('the same request twice gives the same text', () {
      for (final String mood in CleanFacts.moods) {
        for (final int seed in _seeds) {
          final AiRequest a = _request(
            mood: mood,
            event: 'checkedOff',
            streak: 4,
            name: 'Wisp',
            seed: seed,
          );
          expect(_text(a), _text(a));
        }
      }
    });
  });

  group('catalog without mood lines', () {
    test('behaves as before even with a valid mood', () {
      final TemplateCatalog plain = TemplateCatalog(
        ghostMoodLine: TemplateCatalog.standard.ghostMoodLine,
        seanceVerdict: TemplateCatalog.standard.seanceVerdict,
        generic: TemplateCatalog.standard.generic,
      );
      expect(plain.moodLines, isNull);
      final OfflineEngine engine = OfflineEngine(plain);
      for (final int seed in _seeds) {
        final AiRequest withMood = _request(
          mood: 'hungry',
          event: 'checkedOff',
          streak: 2,
          seed: seed,
        );
        final AiRequest without = _request(streak: 2, seed: seed);
        expect(engine.compose(withMood).text, engine.compose(without).text);
      }
    });

    test('the standard catalog carries the shipped mood copy', () {
      expect(TemplateCatalog.standard.moodLines, MoodTemplates.standard);
    });

    test('the legacy ghostMoodLine safe line is unchanged', () {
      expect(
        TemplateCatalog.standard.ghostMoodLine.safeLine,
        'Boo. Still here.',
      );
      expect(
        TemplateCatalog.standard.setFor(AiPurpose.ghostMoodLine, none).safeLine,
        'Boo. Still here.',
      );
    });

    test('other purposes ignore a valid mood', () {
      final CleanFacts moody = CleanFacts.from(<String, Object?>{
        AiFactKeys.ghostMood: 'dead',
      });
      expect(
        TemplateCatalog.standard.setFor(AiPurpose.seanceVerdict, moody),
        same(TemplateCatalog.standard.seanceVerdict),
      );
    });
  });
}
