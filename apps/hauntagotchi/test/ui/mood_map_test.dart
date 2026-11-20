import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/ui/mood_map.dart';

void main() {
  group('moodFor', () {
    test('maps each state to the steady mood with the same name', () {
      for (final state in GhostState.values) {
        expect(moodFor(state).name, state.name, reason: state.name);
      }
    });

    test('never returns a reaction mood', () {
      for (final state in GhostState.values) {
        expect(moodFor(state), isNot(GhostMood.fed), reason: state.name);
        expect(moodFor(state), isNot(GhostMood.rising), reason: state.name);
      }
    });
  });
}
