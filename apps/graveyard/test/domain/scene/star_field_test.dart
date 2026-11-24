import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/star.dart';
import 'package:graveyard/src/domain/scene/star_field.dart';

List<Star> _gen(double width, double height, {int seed = 7}) =>
    StarField.generate(
      seed: seed,
      width: width,
      height: height,
      moonCx: width * 0.8,
      moonCy: height * 0.2,
      moonRadius: 10,
    );

void main() {
  group('StarField', () {
    test('zero and negative sizes give an empty list', () {
      expect(_gen(0, 100), isEmpty);
      expect(_gen(100, 0), isEmpty);
      expect(_gen(0, 0), isEmpty);
      expect(_gen(-5, 100), isEmpty);
      expect(_gen(100, -5), isEmpty);
    });

    test('a fixed small size gives pinned count and positions', () {
      final stars = _gen(100, 100);
      const expected = <List<double>>[
        [11.040538936331911, 48.2765849567039],
        [80.34915287233511, 54.440852493191045],
        [68.7648862341697, 0.34665357385838],
        [71.5822494633485, 54.03543666640974],
        [87.7775355923459, 7.472345632507941],
        [33.01904168822227, 26.653469946027045],
        [35.34029278046701, 42.76495852489457],
        [56.86543782481728, 65.7648217151784],
        [13.766019378913397, 45.72318973710404],
        [72.1587773611631, 50.865220500698115],
        [46.34303781535066, 6.327679390389578],
        [61.704704672874534, 33.073644419589506],
        [85.82667957158635, 42.948908712071926],
        [91.81118429747119, 58.26345228564239],
        [10.73909363695602, 51.29160912838041],
        [32.267574263176, 51.9281966782336],
        [55.47562238470135, 14.812782595730642],
        [20.208530228521404, 55.37932019435409],
        [40.36122512922572, 42.64881596794815],
      ];
      expect(stars, hasLength(19));
      for (var i = 0; i < expected.length; i++) {
        expect(stars[i].dx, closeTo(expected[i][0], 1e-9), reason: 'dx $i');
        expect(stars[i].dy, closeTo(expected[i][1], 1e-9), reason: 'dy $i');
      }
      expect(stars.first.phaseMs, 4125);
      expect(stars.first.periodMs, 5162);
    });

    test('the same arguments give equal lists', () {
      expect(_gen(100, 100), _gen(100, 100));
    });

    test('the count is 12 at the smallest size', () {
      expect(_gen(1, 1), hasLength(12));
    });

    test('the count is 60 at the largest sizes', () {
      expect(_gen(2000, 4000), hasLength(60));
    });
  });
}
