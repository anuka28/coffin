import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/ghost_state_rules.dart';
import 'package:hauntagotchi/src/domain/recent_history.dart';

void main() {
  const none = RecentHistory(idleDays: 0);

  group('band edges with no idle history', () {
    const expected = <int, GhostState>{
      0: GhostState.dead,
      1: GhostState.fading,
      24: GhostState.fading,
      25: GhostState.hungry,
      49: GhostState.hungry,
      50: GhostState.content,
      79: GhostState.content,
      80: GhostState.thriving,
      100: GhostState.thriving,
    };
    expected.forEach((health, state) {
      test('health $health is ${state.name}', () {
        expect(GhostStateRules.derive(health, none), state);
      });
    });
  });

  group('idle caps', () {
    test('one idle day caps thriving at content', () {
      const h = RecentHistory(idleDays: 1);
      expect(GhostStateRules.derive(100, h), GhostState.content);
      expect(GhostStateRules.derive(80, h), GhostState.content);
      expect(GhostStateRules.derive(50, h), GhostState.content);
    });

    test('three idle days cap at hungry', () {
      const h = RecentHistory(idleDays: 3);
      expect(GhostStateRules.derive(100, h), GhostState.hungry);
      expect(GhostStateRules.derive(50, h), GhostState.hungry);
      expect(GhostStateRules.derive(25, h), GhostState.hungry);
    });

    test('two idle days still cap at content', () {
      const h = RecentHistory(idleDays: 2);
      expect(GhostStateRules.derive(100, h), GhostState.content);
    });

    test('caps never go below hungry', () {
      const h = RecentHistory(idleDays: 10);
      expect(GhostStateRules.derive(24, h), GhostState.fading);
      expect(GhostStateRules.derive(1, h), GhostState.fading);
      expect(GhostStateRules.derive(0, h), GhostState.dead);
    });

    test('caps do not raise lower states', () {
      const h = RecentHistory(idleDays: 1);
      expect(GhostStateRules.derive(30, h), GhostState.hungry);
    });
  });
}
