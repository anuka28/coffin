import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, inInclusiveRange, isFalse, isTrue, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/voice_trigger.dart';
import 'package:hauntagotchi/src/ui/mood_fact.dart';
import 'package:hauntagotchi/src/ui/voice_request.dart';

import '../domain/support/haunt_generators.dart';

const int _numRuns = 300;
const List<String> _names = <String>['Wisp', 'Boo', 'Casper the Kind', 'Mist'];
const Set<String> _accepted = <String>{
  'thriving',
  'content',
  'hungry',
  'fading',
  'dead',
};
const Set<String> _allowedKeys = <String>{
  AiFactKeys.ghostMood,
  AiFactKeys.ghostEvent,
  AiFactKeys.streakCount,
  AiFactKeys.ghostName,
};

final RunCounter _shapeRuns = RunCounter();
final RunCounter _totalRuns = RunCounter();

typedef _Inputs = (int, int, int, int, int, int);

Generator<_Inputs> get _anyInputs =>
    any.combine6<int, int, int, int, int, int, _Inputs>(
      anyIntBetween(-100000, 100001),
      anyIntBetween(0, GhostState.values.length),
      anyIntBetween(0, VoiceTrigger.values.length),
      anyIntBetween(0, 1000001),
      anyIntBetween(0, 13),
      anyIntBetween(0, _names.length),
      (int a, int b, int c, int d, int e, int f) => (a, b, c, d, e, f),
    );

void main() {
  group('buildVoiceRequest shape (Property 12)', () {
    // Feature: ghost-voice, Property 12: Request shape
    // Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 12.2
    Glados(_anyInputs, ExploreConfig(numRuns: _numRuns)).test(
      'allowed keys only, maxLength 80, seed in range, streak rule',
      (_Inputs input) {
        final (day, state, trigger, streak, completed, name) = input;
        _shapeRuns.increment();
        final AiRequest r = buildVoiceRequest(
          trigger: VoiceTrigger.values[trigger],
          state: GhostState.values[state],
          streak: streak,
          completedToday: completed,
          ghostName: _names[name],
          epochDay: day,
        );
        expect(r.purpose, equals(AiPurpose.ghostMoodLine));
        expect(r.maxLength, 80);
        expect(r.seed, inInclusiveRange(0, AiRequest.maxSeed));
        expect(_allowedKeys.containsAll(r.facts.keys), isTrue);
        expect(r.facts.containsKey(AiFactKeys.streakCount), streak >= 1);
        if (streak == 0) {
          expect(r.facts.containsKey(AiFactKeys.streakCount), isFalse);
        }
      },
    );

    test('every property body ran numRuns times', () {
      _shapeRuns.expectRuns(_numRuns);
    });
  });

  group('moodFactFor totality (Property 11)', () {
    // Feature: ghost-voice, Property 11: Mood mapping totality
    // Validates: Requirements 8.1, 8.7, 12.2
    Glados(
      anyIntBetween(0, GhostState.values.length),
      ExploreConfig(numRuns: _numRuns),
    ).test('every state maps to an accepted name', (int index) {
      _totalRuns.increment();
      final String fact = moodFactFor(GhostState.values[index]);
      expect(_accepted.contains(fact), isTrue);
      expect(
        GhostState.values.map(moodFactFor).toSet().length,
        GhostState.values.length,
      );
    });

    test('every property body ran numRuns times', () {
      _totalRuns.expectRuns(_numRuns);
    });
  });
}
