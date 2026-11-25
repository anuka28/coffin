import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/hand_height.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/domain/scene/rise_progress.dart';

void main() {
  group('HandHeight', () {
    test('is 0 at the start', () {
      expect(HandHeight.at(0), 0);
    });

    test('peaks at 1 at the end of the burst', () {
      expect(HandHeight.at(PlayTiming.handBurstEndMs), 1);
      expect(HandHeight.at(300), 1);
    });

    test('is 0 again at the end of the sink', () {
      expect(HandHeight.at(600), 0);
      expect(HandHeight.at(PlayTiming.handSinkEndMs), 0);
    });

    test('is 0 from the play duration on and for very large input', () {
      expect(HandHeight.at(PlayTiming.playDurationMs), 0);
      expect(HandHeight.at(PlayTiming.playDurationMs + 1), 0);
      expect(HandHeight.at(1000000000), 0);
    });

    test('is 0 for negative input', () {
      expect(HandHeight.at(-1), 0);
      expect(HandHeight.at(-1000000000), 0);
    });

    test('is 0.5 at the midpoint of the burst', () {
      expect(HandHeight.at(PlayTiming.handBurstEndMs ~/ 2), closeTo(0.5, 1e-9));
    });

    test('is 0.5 at the midpoint of the sink', () {
      const mid = (PlayTiming.handBurstEndMs + PlayTiming.handSinkEndMs) ~/ 2;
      expect(HandHeight.at(mid), closeTo(0.5, 1e-9));
    });

    test('burst uses the same curve values as RiseProgress', () {
      const scale = RiseProgress.durationMs / PlayTiming.handBurstEndMs;
      for (var ms = 0; ms <= PlayTiming.handBurstEndMs; ms += 10) {
        expect(
          HandHeight.at(ms),
          RiseProgress.at((ms * scale).round()),
          reason: 'burst at $ms ms',
        );
      }
    });

    test('values stay within 0 and 1', () {
      for (var ms = -50; ms <= PlayTiming.playDurationMs; ms += 7) {
        expect(HandHeight.at(ms), inInclusiveRange(0, 1));
      }
    });
  });
}
