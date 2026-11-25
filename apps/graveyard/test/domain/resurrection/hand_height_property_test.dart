// Feature: graveyard-resurrection, Property 10: Hand_Height stays in range and is monotonic per phase
// Validates: Requirements 7.7, 7.8
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/resurrection/hand_height.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';

import '../support/grave_generators.dart';

final RunCounter _rangeCounter = RunCounter();
final RunCounter _burstCounter = RunCounter();
final RunCounter _sinkCounter = RunCounter();

void main() {
  group(
    'Property 10: Hand_Height stays in range and is monotonic per phase',
    () {
      // Upper bounds are exclusive in anyIntBetween.
      Glados(
        anyIntBetween(-100000, 100001),
        ExploreConfig(numRuns: numRuns),
      ).test('the height is finite and within 0 to 1 inclusive', (int ms) {
        _rangeCounter.increment();
        final double height = HandHeight.at(ms);
        expect(height.isFinite, isTrue, reason: 'at $ms ms');
        expect(height, inInclusiveRange(0, 1), reason: 'at $ms ms');
      });

      Glados2(
        anyIntBetween(0, PlayTiming.handBurstEndMs + 1),
        anyIntBetween(0, PlayTiming.handBurstEndMs + 1),
        ExploreConfig(numRuns: numRuns),
      ).test('the height does not decrease in the burst phase', (int x, int y) {
        _burstCounter.increment();
        final int a = x <= y ? x : y;
        final int b = x <= y ? y : x;
        expect(
          HandHeight.at(a),
          lessThanOrEqualTo(HandHeight.at(b)),
          reason: 'from $a ms to $b ms',
        );
      });

      Glados2(
        anyIntBetween(PlayTiming.handBurstEndMs, PlayTiming.handSinkEndMs + 1),
        anyIntBetween(PlayTiming.handBurstEndMs, PlayTiming.handSinkEndMs + 1),
        ExploreConfig(numRuns: numRuns),
      ).test('the height does not increase in the sink phase', (int x, int y) {
        _sinkCounter.increment();
        final int a = x <= y ? x : y;
        final int b = x <= y ? y : x;
        expect(
          HandHeight.at(a),
          greaterThanOrEqualTo(HandHeight.at(b)),
          reason: 'from $a ms to $b ms',
        );
      });

      test('ran the configured number of times', () {
        _rangeCounter.expectRuns(numRuns);
        _burstCounter.expectRuns(numRuns);
        _sinkCounter.expectRuns(numRuns);
      });
    },
  );
}
