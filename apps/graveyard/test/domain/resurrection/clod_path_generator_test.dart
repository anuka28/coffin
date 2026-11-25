import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/clod.dart';
import 'package:graveyard/src/domain/resurrection/clod_path_generator.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';

const _alphaFirst = Clod(
  launchAngleRadians: 0.489,
  launchMs: 279,
  flightMs: 265,
  peakHeightFraction: 0.26,
  sizePx: 8,
);

const _betaFirst = Clod(
  launchAngleRadians: 0.257,
  launchMs: 182,
  flightMs: 221,
  peakHeightFraction: 0.42,
  sizePx: 4,
);

List<List<Clod>> _sample() => [
  for (var i = 0; i < 200; i++) ClodPathGenerator.generate('grave-$i'),
];

void main() {
  group('ClodPathGenerator', () {
    test('pinned id "grave-alpha" is stable', () {
      final clods = ClodPathGenerator.generate('grave-alpha');
      expect(clods, hasLength(4));
      expect(clods.first, _alphaFirst);
      expect(ClodPathGenerator.generate('grave-alpha'), clods);
    });

    test('pinned id "grave-beta" is stable', () {
      final clods = ClodPathGenerator.generate('grave-beta');
      expect(clods, hasLength(6));
      expect(clods.first, _betaFirst);
      expect(ClodPathGenerator.generate('grave-beta'), clods);
    });

    test('two different ids give two different lists', () {
      expect(
        ClodPathGenerator.generate('grave-alpha'),
        isNot(ClodPathGenerator.generate('grave-beta')),
      );
    });

    test('count is 4 to 7 across 200 ids', () {
      for (final clods in _sample()) {
        expect(clods.length, inInclusiveRange(4, 7));
      }
    });

    test('every Clod lands at or before the Hand has sunk', () {
      for (final clods in _sample()) {
        for (final clod in clods) {
          expect(clod.flightMs, greaterThan(0));
          expect(
            clod.launchMs + clod.flightMs,
            lessThanOrEqualTo(PlayTiming.handSinkEndMs),
          );
        }
      }
    });

    test('peakHeightFraction is 0.10 to 0.45 across 200 ids', () {
      for (final clods in _sample()) {
        for (final clod in clods) {
          expect(clod.peakHeightFraction, inInclusiveRange(0.10, 0.45));
        }
      }
    });

    test('launchMs is inside the burst', () {
      for (final clods in _sample()) {
        for (final clod in clods) {
          expect(clod.launchMs, inInclusiveRange(0, PlayTiming.handBurstEndMs));
        }
      }
    });

    test('Clod has value equality', () {
      const a = _alphaFirst;
      const same = Clod(
        launchAngleRadians: 0.489,
        launchMs: 279,
        flightMs: 265,
        peakHeightFraction: 0.26,
        sizePx: 8,
      );
      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(_betaFirst));
    });
  });
}
