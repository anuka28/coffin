import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/ui/mood_fact.dart';

const List<String> _accepted = <String>[
  'thriving',
  'content',
  'hungry',
  'fading',
  'dead',
];

void main() {
  group('moodFactFor', () {
    test('each state maps to its expected name', () {
      expect(moodFactFor(GhostState.thriving), 'thriving');
      expect(moodFactFor(GhostState.content), 'content');
      expect(moodFactFor(GhostState.hungry), 'hungry');
      expect(moodFactFor(GhostState.fading), 'fading');
      expect(moodFactFor(GhostState.dead), 'dead');
    });

    test('the five names are distinct', () {
      final Set<String> names = GhostState.values.map(moodFactFor).toSet();
      expect(names, hasLength(5));
    });

    test('every name is one coffin_core accepts', () {
      for (final GhostState s in GhostState.values) {
        expect(_accepted, contains(moodFactFor(s)));
      }
    });

    test('never fed or rising', () {
      for (final GhostState s in GhostState.values) {
        expect(moodFactFor(s), isNot('fed'));
        expect(moodFactFor(s), isNot('rising'));
      }
    });
  });
}
