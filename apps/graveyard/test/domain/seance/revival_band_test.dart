import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/seance/revival_band.dart';

void main() {
  group('RevivalBand.forScore', () {
    test('maps the band edges', () {
      expect(RevivalBand.forScore(0), RevivalBand.restless);
      expect(RevivalBand.forScore(39), RevivalBand.restless);
      expect(RevivalBand.forScore(40), RevivalBand.stirring);
      expect(RevivalBand.forScore(69), RevivalBand.stirring);
      expect(RevivalBand.forScore(70), RevivalBand.readyToRise);
      expect(RevivalBand.forScore(100), RevivalBand.readyToRise);
    });

    test('clamps scores outside 0..100 without throwing', () {
      expect(RevivalBand.forScore(-1), RevivalBand.restless);
      expect(RevivalBand.forScore(-1000000), RevivalBand.restless);
      expect(RevivalBand.forScore(101), RevivalBand.readyToRise);
      expect(RevivalBand.forScore(1000000), RevivalBand.readyToRise);
    });
  });
}
