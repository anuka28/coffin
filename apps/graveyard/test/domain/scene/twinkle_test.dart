import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/twinkle.dart';

void main() {
  group('Twinkle', () {
    test('opacity at phase 0 and elapsed 0 is 0.625', () {
      expect(
        Twinkle.opacityAt(phaseMs: 0, elapsedMs: 0, periodMs: 4000),
        closeTo(0.625, 1e-12),
      );
    });

    test('the maximum 1.0 is reached a quarter period in', () {
      expect(
        Twinkle.opacityAt(phaseMs: 0, elapsedMs: 1000, periodMs: 4000),
        closeTo(1.0, 1e-12),
      );
    });

    test('the minimum 0.25 is reached three quarters of a period in', () {
      expect(
        Twinkle.opacityAt(phaseMs: 0, elapsedMs: 3000, periodMs: 4000),
        closeTo(0.25, 1e-12),
      );
    });
  });
}
