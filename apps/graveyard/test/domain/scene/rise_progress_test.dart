import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/rise_progress.dart';

void main() {
  group('RiseProgress', () {
    test('is 0 at 0 ms', () {
      expect(RiseProgress.at(0), 0);
    });

    test('is 0.5 at 300 ms', () {
      expect(RiseProgress.at(300), closeTo(0.5, 1e-9));
    });

    test('is 1 at 600 ms and after', () {
      expect(RiseProgress.at(600), 1);
      expect(RiseProgress.at(601), 1);
      expect(RiseProgress.at(100000), 1);
    });

    test('is 0 for negative elapsed time', () {
      expect(RiseProgress.at(-1), 0);
      expect(RiseProgress.at(-5000), 0);
    });
  });
}
