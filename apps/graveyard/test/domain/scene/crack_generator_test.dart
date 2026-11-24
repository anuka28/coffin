import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/crack.dart';
import 'package:graveyard/src/domain/scene/crack_generator.dart';
import 'package:graveyard/src/domain/scene/crack_point.dart';
import 'package:graveyard/src/domain/scene/keep_out_rect.dart';

const _id = 'octocat/hello-world';

List<Crack> _gen({
  int dayCount = 1826,
  String id = _id,
  double width = 270,
  double height = 480,
  List<KeepOutRect> keepOut = const <KeepOutRect>[],
}) => CrackGenerator.generate(
  dayCount: dayCount,
  graveId: id,
  stoneWidth: width,
  stoneHeight: height,
  keepOut: keepOut,
);

Crack _crack(List<(int, int)> points) =>
    Crack([for (final p in points) CrackPoint(p.$1, p.$2)]);

void main() {
  group('CrackGenerator age threshold', () {
    test('1824 and 1825 days give no cracks', () {
      expect(_gen(dayCount: 1824), isEmpty);
      expect(_gen(dayCount: 1825), isEmpty);
    });

    test('1826 days gives 1 to 3 cracks', () {
      final cracks = _gen(dayCount: 1826);
      expect(cracks.length, inInclusiveRange(1, 3));
    });

    test('zero and negative day counts give no cracks', () {
      expect(_gen(dayCount: 0), isEmpty);
      expect(_gen(dayCount: -5), isEmpty);
    });
  });

  group('CrackGenerator determinism', () {
    test('pinned cracks for one id on a 270x480 stone', () {
      // Checked by hand against the design: minX 20, maxX 250, bandTop 464,
      // minY 464, maxY 474, then the MINSTD draws of steps 4 and 5.
      expect(_gen(), [
        _crack([(150, 473), (155, 469), (159, 467), (162, 464), (163, 464)]),
        _crack([(167, 474), (174, 472), (177, 467), (185, 464), (189, 464)]),
      ]);
    });

    test('at least 8 of 10 fixed ids give different lists', () {
      final lists = {
        for (var i = 0; i < 10; i++) _gen(id: 'grave-$i').toString(),
      };
      expect(lists.length, greaterThanOrEqualTo(8));
    });

    test('same id at 1826 and 3650 days gives equal lists', () {
      expect(_gen(dayCount: 1826), _gen(dayCount: 3650));
    });

    test('every point is integer valued and sits in the band', () {
      for (var i = 0; i < 10; i++) {
        for (final crack in _gen(id: 'grave-$i')) {
          expect(crack.points.length, inInclusiveRange(3, 5));
          for (final p in crack.points) {
            expect(p.x, inInclusiveRange(20, 250));
            expect(p.y, inInclusiveRange(464, 474));
            // ignore: unnecessary_type_check
            expect(p.x is int && p.y is int, isTrue);
          }
        }
      }
    });
  });

  group('CrackGenerator keep-out', () {
    test('empty keep-out list uses the bottom 16 px band', () {
      final ys = [
        for (var i = 0; i < 10; i++)
          for (final crack in _gen(id: 'grave-$i'))
            for (final p in crack.points) p.y,
      ];
      expect(ys, isNotEmpty);
      expect(ys.every((y) => y >= 480 - 16 && y <= 480 - 6), isTrue);
    });

    test('keep-out list that leaves no band gives no cracks', () {
      const rect = KeepOutRect(left: 0, top: 0, right: 270, bottom: 470);
      expect(_gen(keepOut: [rect]), isEmpty);
    });

    test('cracks stay below a keep-out rectangle', () {
      const rect = KeepOutRect(left: 0, top: 0, right: 270, bottom: 460);
      final cracks = _gen(keepOut: [rect]);
      expect(cracks, isNotEmpty);
      for (final crack in cracks) {
        for (final p in crack.points) {
          expect(p.y, greaterThanOrEqualTo(462));
        }
      }
    });
  });

  group('CrackGenerator invalid sizes', () {
    test('zero, negative, NaN and infinite sizes give no cracks', () {
      final bad = <double>[0, -1, -270, double.nan, double.infinity];
      for (final v in bad) {
        expect(_gen(width: v), isEmpty, reason: 'width $v');
        expect(_gen(height: v), isEmpty, reason: 'height $v');
      }
      expect(_gen(width: double.negativeInfinity), isEmpty);
      expect(_gen(height: double.negativeInfinity), isEmpty);
    });
  });
}
