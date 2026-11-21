import 'package:coffin_core/src/ai/ai_fact_keys.dart';
import 'package:coffin_core/src/ai/clean_facts.dart';
import 'package:flutter_test/flutter_test.dart';

String? _mood(Object? value) =>
    CleanFacts.from(<String, Object?>{AiFactKeys.ghostMood: value}).ghostMood;
String? _event(Object? value) =>
    CleanFacts.from(<String, Object?>{AiFactKeys.ghostEvent: value}).ghostEvent;

const List<Object?> _bad = <Object?>[
  null,
  0,
  1.5,
  true,
  'fed',
  'rising',
  'Thriving',
  'THRIVING',
  ' thriving',
  'thriving ',
  'AppOpened',
  'appopened',
  ' appOpened',
  'appOpened ',
  '',
  <String>['thriving'],
  <String>['appOpened'],
];

void main() {
  test('key constants', () {
    expect(AiFactKeys.ghostMood, 'ghostMood');
    expect(AiFactKeys.ghostEvent, 'ghostEvent');
  });

  test('valid name lists', () {
    expect(CleanFacts.moods, <String>[
      'thriving',
      'content',
      'hungry',
      'fading',
      'dead',
    ]);
    expect(CleanFacts.events, <String>[
      'appOpened',
      'checkedOff',
      'moodChanged',
      'resurrected',
    ]);
  });

  group('ghostMood', () {
    for (final name in CleanFacts.moods) {
      test('accepts $name', () => expect(_mood(name), name));
    }
    test('absent key is null', () {
      expect(CleanFacts.from(const <String, Object?>{}).ghostMood, isNull);
    });
    for (final value in _bad) {
      test('rejects ${value.runtimeType} $value', () {
        expect(_mood(value), isNull);
      });
    }
  });

  group('ghostEvent', () {
    for (final name in CleanFacts.events) {
      test('accepts $name', () => expect(_event(name), name));
    }
    test('absent key is null', () {
      expect(CleanFacts.from(const <String, Object?>{}).ghostEvent, isNull);
    });
    for (final value in _bad) {
      test('rejects ${value.runtimeType} $value', () {
        expect(_event(value), isNull);
      });
    }
  });

  test('existing four fields behave as before with the new ones set', () {
    final facts = CleanFacts.from(<String, Object?>{
      AiFactKeys.streakCount: 5.0,
      AiFactKeys.daysSinceLastCommit: 0,
      AiFactKeys.ghostName: '  Wisp ',
      AiFactKeys.projectName: '',
      AiFactKeys.ghostMood: 'hungry',
      AiFactKeys.ghostEvent: 'checkedOff',
    });
    expect(facts.streakCount, 5);
    expect(facts.daysSinceLastCommit, isNull);
    expect(facts.ghostName, 'Wisp');
    expect(facts.projectName, isNull);
    expect(facts.ghostMood, 'hungry');
    expect(facts.ghostEvent, 'checkedOff');
  });

  test('invalid new facts do not disturb the existing fields', () {
    final facts = CleanFacts.from(<String, Object?>{
      AiFactKeys.streakCount: 3,
      AiFactKeys.ghostMood: 'fed',
      AiFactKeys.ghostEvent: 'x',
    });
    expect(facts.streakCount, 3);
    expect(facts.ghostMood, isNull);
    expect(facts.ghostEvent, isNull);
  });

  test('default constructor has both new fields null', () {
    const facts = CleanFacts();
    expect(facts.ghostMood, isNull);
    expect(facts.ghostEvent, isNull);
  });
}
