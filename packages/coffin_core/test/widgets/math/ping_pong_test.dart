import 'package:coffin_core/src/widgets/math/ping_pong.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PingPong.at', () {
    test('starts at 0 for several periods', () {
      for (final period in [1, 2, 10, 3600, 90000]) {
        expect(PingPong.at(0, period), 0);
      }
    });

    test('peaks at exactly 1 at half of an even period', () {
      for (final period in [2, 4, 10, 3600, 90000]) {
        expect(PingPong.at(period ~/ 2, period), 1);
      }
    });

    test('is symmetric around the middle', () {
      for (final (p, period) in [(1, 10), (3, 10), (1234, 3600), (7, 90000)]) {
        expect(PingPong.at(p, period), PingPong.at(period - p, period));
      }
    });

    test('matches the hand-computed value for P = 4, p = 1', () {
      // n = 2, result = 4 * (12 - 4) / 64.
      expect(PingPong.at(1, 4), 0.5);
    });

    test('does not decrease over the first half for P = 10', () {
      var previous = PingPong.at(0, 10);
      for (var p = 1; p <= 5; p++) {
        final value = PingPong.at(p, 10);
        expect(value, greaterThanOrEqualTo(previous));
        previous = value;
      }
    });

    test('stays within [0, 1] for the largest period', () {
      for (var p = 0; p < 90000; p += 7) {
        final value = PingPong.at(p, 90000);
        expect(value.isFinite, isTrue);
        expect(value, inInclusiveRange(0, 1));
      }
    });
  });
}
