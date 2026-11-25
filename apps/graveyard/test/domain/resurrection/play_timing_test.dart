import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';

void main() {
  group('PlayTiming', () {
    test('play duration is between 2600 and 3000 ms', () {
      expect(PlayTiming.playDurationMs, greaterThanOrEqualTo(2600));
      expect(PlayTiming.playDurationMs, lessThanOrEqualTo(3000));
    });

    test('milestones are strictly ordered', () {
      expect(PlayTiming.handBurstEndMs, lessThan(PlayTiming.handSinkEndMs));
      expect(
        PlayTiming.handSinkEndMs,
        lessThanOrEqualTo(PlayTiming.risingGhostStartMs),
      );
      expect(
        PlayTiming.risingGhostStartMs,
        lessThan(PlayTiming.ghostRiseEndMs),
      );
      expect(PlayTiming.ghostRiseEndMs, lessThan(PlayTiming.playDurationMs));
    });

    test('the 2200 ms rising reaction fits in the play', () {
      expect(
        PlayTiming.risingGhostStartMs + 2200,
        lessThanOrEqualTo(PlayTiming.playDurationMs),
      );
    });

    test('epitaph fade lasts 300 to 600 ms and ends within the play', () {
      expect(PlayTiming.epitaphFadeMs, inInclusiveRange(300, 600));
      expect(
        PlayTiming.epitaphFadeStartMs + PlayTiming.epitaphFadeMs,
        lessThanOrEqualTo(PlayTiming.playDurationMs),
      );
    });

    test('the ghost rise ends when the epitaph fade starts', () {
      expect(PlayTiming.ghostRiseEndMs, PlayTiming.epitaphFadeStartMs);
    });

    test('the rise window starts when the Hand has sunk back', () {
      expect(PlayTiming.ghostRiseStartMs, PlayTiming.risingGhostStartMs);
      expect(PlayTiming.ghostRiseStartMs, PlayTiming.handSinkEndMs);
    });
  });
}
