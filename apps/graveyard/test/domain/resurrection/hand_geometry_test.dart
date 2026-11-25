import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/hand_geometry.dart';
import 'package:graveyard/src/domain/resurrection/hand_shape.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/domain/resurrection/stone_point.dart';

const HandShape _hidden = HandShape(bones: [], visible: false);

void main() {
  group('HandGeometry', () {
    test('is invisible and empty at 0 ms', () {
      final HandShape s = HandGeometry.at(
        width: 200,
        height: 300,
        elapsedMs: 0,
      );
      expect(s.visible, isFalse);
      expect(s.bones, isEmpty);
    });

    test('is invisible and empty from handSinkEndMs on', () {
      for (final int ms in <int>[
        PlayTiming.handSinkEndMs,
        PlayTiming.handSinkEndMs + 1,
        PlayTiming.playDurationMs,
      ]) {
        final HandShape s = HandGeometry.at(
          width: 200,
          height: 300,
          elapsedMs: ms,
        );
        expect(s.visible, isFalse, reason: '$ms ms');
        expect(s.bones, isEmpty, reason: '$ms ms');
      }
    });

    group('at burst end', () {
      const double width = 200;
      const double height = 300;
      final HandShape s = HandGeometry.at(
        width: width,
        height: height,
        elapsedMs: PlayTiming.handBurstEndMs,
      );
      // Bones: 0-1 forearms, 2-5 index/middle/ring/little, 6 thumb.
      final List<StonePoint> tips = <StonePoint>[
        for (final bone in s.bones.sublist(2)) bone.last,
      ];
      double length(List<StonePoint> b) => b.first.y - b.last.y;

      test('has 7 bones, fingers of 4 points', () {
        expect(s.visible, isTrue);
        expect(s.bones, hasLength(7));
        for (final bone in s.bones.sublist(2)) {
          expect(bone, hasLength(4));
        }
      });

      test('the middle fingertip is the highest point of the shape', () {
        final double top = s.bones
            .expand((b) => b)
            .map((p) => p.y)
            .reduce((a, b) => a < b ? a : b);
        expect(s.bones[3].last.y, top);
        expect(top, lessThan(height));
        for (final i in <int>[2, 4, 5]) {
          expect(s.bones[i].last.y, greaterThan(top));
        }
      });

      test('the thumb tip is lower than every other fingertip', () {
        for (final tip in tips.sublist(0, 4)) {
          expect(tips.last.y, greaterThan(tip.y));
        }
      });

      test('forearm bones start on the ground line and end at the wrist', () {
        for (final i in <int>[0, 1]) {
          expect(s.bones[i].first.y, height);
          expect(s.bones[i].last.y, lessThan(height));
          expect(s.bones[i].last.y, s.bones[2].first.y);
        }
      });

      test('the Hand is centered on the stone', () {
        expect(s.bones[0].first.x + s.bones[1].first.x, closeTo(width, 1e-9));
        expect(s.bones[0].last.x + s.bones[1].last.x, closeTo(width, 1e-9));
        expect(s.bones[2].first.x, closeTo(width / 2, 1e-9));
      });

      test('finger lengths: middle > ring > index > little', () {
        final double index = length(s.bones[2]);
        final double middle = length(s.bones[3]);
        final double ring = length(s.bones[4]);
        final double little = length(s.bones[5]);
        expect(middle, greaterThan(ring));
        expect(ring, greaterThan(index));
        expect(index, greaterThan(little));
      });

      test('the thumb angles outward and the tips curl inward', () {
        final StonePoint thumbStart = s.bones[6].first;
        expect(s.bones[6].last.x, lessThan(thumbStart.x));
        for (final i in <int>[2, 3, 4, 5]) {
          final bone = s.bones[i];
          // Tip is closer to the wrist's x than the middle joint is.
          expect(
            (bone[3].x - bone[0].x).abs(),
            lessThan((bone[2].x - bone[0].x).abs() + 1e-9),
          );
        }
      });
    });

    test('non-finite or non-positive size returns the invisible shape', () {
      final List<(double, double)> sizes = <(double, double)>[
        (double.nan, 300),
        (200, double.nan),
        (double.infinity, 300),
        (200, double.negativeInfinity),
        (0, 300),
        (200, 0),
        (-1, 300),
        (200, -5),
      ];
      for (final (double w, double h) in sizes) {
        expect(
          HandGeometry.at(
            width: w,
            height: h,
            elapsedMs: PlayTiming.handBurstEndMs,
          ),
          _hidden,
          reason: '$w x $h',
        );
      }
    });

    test('shapes with the same inputs are equal', () {
      final HandShape a = HandGeometry.at(
        width: 200,
        height: 300,
        elapsedMs: 150,
      );
      final HandShape b = HandGeometry.at(
        width: 200,
        height: 300,
        elapsedMs: 150,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(HandGeometry.at(width: 200, height: 300, elapsedMs: 200)),
      );
    });
  });
}
