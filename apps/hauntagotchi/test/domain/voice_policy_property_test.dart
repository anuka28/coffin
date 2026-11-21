import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, isNull;
import 'package:glados/glados.dart' hide expect, group;
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/voice_policy.dart';
import 'package:hauntagotchi/src/domain/voice_snapshot.dart';
import 'package:hauntagotchi/src/domain/voice_trigger.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 300;

/// Step codes: 0..4 is a ready ghost state, 5 is "not ready".
const int _notReadyCode = 5;

/// Codes per step: 6 states, 3 check-off rises (0 to 2), 3 resurrection rises.
const int _stepCodes = 6 * 3 * 3;

final RunCounter _countRuns = RunCounter();
final RunCounter _priorityRuns = RunCounter();
final RunCounter _pairRuns = RunCounter();

/// One step of a generated sequence, decoded from an integer code.
final class _Step {
  const _Step(this.state, this.checkRise, this.resurrectionRise);

  factory _Step.decode(int code) {
    final int stateCode = code % 6;
    final int checkRise = (code ~/ 6) % 3;
    final int resurrectionRise = code ~/ 18;
    return _Step(
      stateCode == _notReadyCode ? null : GhostState.values[stateCode],
      checkRise,
      resurrectionRise,
    );
  }

  final GhostState? state;
  final int checkRise;
  final int resurrectionRise;
}

/// Turns step codes into snapshots whose counters never fall.
List<VoiceSnapshot> _snapshots(List<int> codes) {
  int checks = 0;
  int resurrections = 0;
  return <VoiceSnapshot>[
    for (final int code in codes)
      () {
        final _Step step = _Step.decode(code);
        checks += step.checkRise;
        resurrections += step.resurrectionRise;
        return VoiceSnapshot(
          state: step.state,
          checkOffs: checks,
          resurrections: resurrections,
        );
      }(),
  ];
}

/// The trigger the rules of Requirements 6.1 to 6.6 name, written without
/// reusing the `VoicePolicy` code path.
VoiceTrigger? _expected(VoiceSnapshot? previous, VoiceSnapshot next) {
  if (next.state == null) return null;
  if (previous == null || previous.state == null) {
    return VoiceTrigger.appOpened;
  }
  if (next.resurrections != previous.resurrections) {
    return VoiceTrigger.resurrected;
  }
  if (next.checkOffs != previous.checkOffs) return VoiceTrigger.checkedOff;
  if (next.state != previous.state) return VoiceTrigger.moodChanged;
  return null;
}

/// Whether [next] is a transition that must speak.
bool _isTransition(VoiceSnapshot? previous, VoiceSnapshot next) {
  if (next.state == null) return false;
  if (previous == null || previous.state == null) return true;
  return next.resurrections > previous.resurrections ||
      next.checkOffs > previous.checkOffs ||
      next.state != previous.state;
}

Generator<List<int>> get _anySequence =>
    anyListBetween<int>(1, 31, anyIntBetween(0, _stepCodes));

void main() {
  group('VoicePolicy trigger count (Property 9)', () {
    // Feature: ghost-voice, Property 9: Trigger count
    // Validates: Requirements 6.6, 6.7, 6.9, 12.2
    Glados(_anySequence, ExploreConfig(numRuns: _numRuns)).test(
      'triggers happen exactly on transitions and are counted by them',
      (List<int> codes) {
        _countRuns.increment();
        final List<VoiceSnapshot> snaps = _snapshots(codes);
        int triggers = 0;
        int transitions = 0;
        VoiceSnapshot? previous;
        for (final VoiceSnapshot next in snaps) {
          final VoiceTrigger? got = VoicePolicy.decide(previous, next);
          final bool transition = _isTransition(previous, next);
          expect(got != null, equals(transition));
          if (previous != null && previous == next) {
            expect(got, isNull);
          }
          if (got != null) triggers++;
          if (transition) transitions++;
          previous = next;
        }
        expect(triggers, equals(transitions));
      },
    );

    test('every property body ran numRuns times', () {
      _countRuns.expectRuns(_numRuns);
    });
  });

  group('VoicePolicy priority (Property 10)', () {
    // Feature: ghost-voice, Property 10: Priority
    // Validates: Requirements 6.6, 6.7, 12.2
    Glados(_anySequence, ExploreConfig(numRuns: _numRuns)).test(
      'resurrected beats checkedOff beats moodChanged along a sequence',
      (List<int> codes) {
        _priorityRuns.increment();
        VoiceSnapshot? previous;
        for (final VoiceSnapshot next in _snapshots(codes)) {
          expect(
            VoicePolicy.decide(previous, next),
            equals(_expected(previous, next)),
          );
          previous = next;
        }
      },
    );

    Glados3(
      anyIntBetween(0, 5),
      anyIntBetween(0, 5),
      anyIntBetween(0, 4),
      ExploreConfig(numRuns: _numRuns),
    ).test('with all three changes at once the priority holds', (
      int fromIndex,
      int toIndex,
      int mask,
    ) {
      _pairRuns.increment();
      final GhostState from = GhostState.values[fromIndex];
      final GhostState to = GhostState.values[toIndex];
      final bool checked = mask & 1 == 1;
      final bool resurrected = mask & 2 == 2;
      final VoiceSnapshot before = VoiceSnapshot(
        state: from,
        checkOffs: 3,
        resurrections: 1,
      );
      final VoiceSnapshot after = VoiceSnapshot(
        state: to,
        checkOffs: checked ? 4 : 3,
        resurrections: resurrected ? 2 : 1,
      );
      final VoiceTrigger? got = VoicePolicy.decide(before, after);
      if (resurrected) {
        expect(got, equals(VoiceTrigger.resurrected));
      } else if (checked) {
        expect(got, equals(VoiceTrigger.checkedOff));
      } else if (from != to) {
        expect(got, equals(VoiceTrigger.moodChanged));
      } else {
        expect(got, isNull);
      }
    });

    test('every property body ran numRuns times', () {
      _priorityRuns.expectRuns(_numRuns);
      _pairRuns.expectRuns(_numRuns);
    });
  });
}
