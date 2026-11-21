import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/voice_snapshot.dart';

void main() {
  group('VoiceSnapshot', () {
    const a = VoiceSnapshot(
      state: GhostState.hungry,
      checkOffs: 2,
      resurrections: 1,
    );

    test('equal values are equal and share a hash code', () {
      const b = VoiceSnapshot(
        state: GhostState.hungry,
        checkOffs: 2,
        resurrections: 1,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('each field takes part in equality', () {
      expect(
        a,
        isNot(
          const VoiceSnapshot(
            state: GhostState.fading,
            checkOffs: 2,
            resurrections: 1,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const VoiceSnapshot(
            state: GhostState.hungry,
            checkOffs: 3,
            resurrections: 1,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const VoiceSnapshot(
            state: GhostState.hungry,
            checkOffs: 2,
            resurrections: 0,
          ),
        ),
      );
    });

    test('a null state is allowed and differs from a state', () {
      const idle = VoiceSnapshot(state: null, checkOffs: 0, resurrections: 0);
      expect(idle.state, isNull);
      expect(
        idle,
        isNot(
          const VoiceSnapshot(
            state: GhostState.dead,
            checkOffs: 0,
            resurrections: 0,
          ),
        ),
      );
    });

    test('toString names the fields', () {
      expect(a.toString(), contains('hungry'));
      expect(a.toString(), contains('checkOffs: 2'));
      expect(a.toString(), contains('resurrections: 1'));
    });
  });
}
