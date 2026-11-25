import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/epitaph_footprint.dart';
import 'package:graveyard/src/domain/scene/arch_fit.dart';
import 'package:graveyard/src/domain/scene/keep_out_rect.dart';

const KeepOutRect _zero = KeepOutRect(left: 0, top: 0, right: 0, bottom: 0);

/// Per-text rectangle built from the footprint's public constants and the
/// real [ArchFit], mirroring the footprint's own model.
KeepOutRect _textRect(
  double stoneWidth,
  double scale,
  double advance,
  double floor,
  int glyphs,
) {
  final double base = EpitaphFootprint.baseFontSize * scale;
  final double spacing = glyphs * EpitaphFootprint.letterSpacing;
  final double textWidth = advance * base + spacing;
  final double lineHeight = EpitaphFootprint.lineHeightPerFontPx * base;
  final fit = ArchFit.positionFor(
    archWidth: stoneWidth,
    archRise: EpitaphFootprint.archRise,
    lineHeight: lineHeight,
    textWidth: textWidth,
    fontSize: base,
  );
  final low = ArchFit.positionFor(
    archWidth: stoneWidth,
    archRise: EpitaphFootprint.archRise,
    lineHeight: lineHeight,
    textWidth: floor * base + spacing,
    fontSize: base,
  );
  final double k = fit.fontSize / base;
  final double w =
      (fit.truncated ? stoneWidth - 2 * ArchFit.margin : textWidth * k).clamp(
        0.0,
        stoneWidth,
      );
  final double left = (stoneWidth - w) / 2;
  return KeepOutRect(
    left: left,
    top: low.top < fit.top ? low.top : fit.top,
    right: left + w,
    bottom: fit.top + lineHeight * k,
  );
}

void main() {
  group('EpitaphFootprint constants', () {
    test('are positive and finite', () {
      for (final double c in <double>[
        EpitaphFootprint.archRise,
        EpitaphFootprint.baseFontSize,
        EpitaphFootprint.letterSpacing,
        EpitaphFootprint.lineHeightPerFontPx,
        EpitaphFootprint.ripAdvancePerFontPx,
        EpitaphFootprint.risenAdvancePerFontPx,
      ]) {
        expect(c.isFinite, isTrue);
        expect(c, greaterThan(0));
      }
    });
  });

  group('EpitaphFootprint.forStone', () {
    test('stays inside the stone with a positive height', () {
      for (double w = 120; w <= 400; w += 20) {
        for (double s = 1.0; s <= 2.0; s += 0.25) {
          final KeepOutRect r = EpitaphFootprint.forStone(
            stoneWidth: w,
            textScale: s,
          );
          expect(r.left, greaterThanOrEqualTo(0), reason: 'w=$w s=$s');
          expect(r.right, lessThanOrEqualTo(w), reason: 'w=$w s=$s');
          expect(r.left, lessThanOrEqualTo(r.right), reason: 'w=$w s=$s');
          expect(r.top, lessThanOrEqualTo(r.bottom), reason: 'w=$w s=$s');
          expect(r.bottom - r.top, greaterThan(0), reason: 'w=$w s=$s');
          expect(r.left.isFinite && r.right.isFinite, isTrue);
          expect(r.top.isFinite && r.bottom.isFinite, isTrue);
        }
      }
    });

    test('pins the calibrated rectangle for a 120x160 stone', () {
      final KeepOutRect one = EpitaphFootprint.forStone(
        stoneWidth: 120,
        textScale: 1,
      );
      expect(one.left, closeTo(33.00, 0.005));
      expect(one.top, closeTo(9.46, 0.005));
      expect(one.right, closeTo(87.00, 0.005));
      expect(one.bottom, closeTo(36.63, 0.005));

      final KeepOutRect two = EpitaphFootprint.forStone(
        stoneWidth: 120,
        textScale: 2,
      );
      expect(two.left, closeTo(11.00, 0.005));
      expect(two.top, closeTo(19.28, 0.005));
      expect(two.right, closeTo(109.00, 0.005));
      expect(two.bottom, closeTo(83.88, 0.005));
    });

    test('never leaves [0, stoneWidth] horizontally', () {
      for (final double w in <double>[1, 40, 120, 250, 400]) {
        for (final double s in <double>[0.5, 1, 1.5, 2, 4]) {
          final KeepOutRect r = EpitaphFootprint.forStone(
            stoneWidth: w,
            textScale: s,
          );
          expect(r.left, greaterThanOrEqualTo(0), reason: 'w=$w s=$s');
          expect(r.right, lessThanOrEqualTo(w), reason: 'w=$w s=$s');
        }
      }
    });

    test('contains both per-text rectangles', () {
      for (final double w in <double>[120, 200, 300, 400]) {
        for (final double s in <double>[1, 1.5, 2]) {
          final KeepOutRect u = EpitaphFootprint.forStone(
            stoneWidth: w,
            textScale: s,
          );
          final List<KeepOutRect> parts = <KeepOutRect>[
            _textRect(
              w,
              s,
              EpitaphFootprint.ripAdvancePerFontPx,
              EpitaphFootprint.ripAdvanceFloorPerFontPx,
              6,
            ),
            _textRect(
              w,
              s,
              EpitaphFootprint.risenAdvancePerFontPx,
              EpitaphFootprint.risenAdvanceFloorPerFontPx,
              5,
            ),
          ];
          for (final KeepOutRect p in parts) {
            expect(u.left, lessThanOrEqualTo(p.left), reason: 'w=$w s=$s');
            expect(u.top, lessThanOrEqualTo(p.top), reason: 'w=$w s=$s');
            expect(u.right, greaterThanOrEqualTo(p.right), reason: 'w=$w s=$s');
            expect(
              u.bottom,
              greaterThanOrEqualTo(p.bottom),
              reason: 'w=$w s=$s',
            );
          }
        }
      }
    });

    test('returns the zero rectangle for unusable input', () {
      const List<double> bad = <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        0,
        -1,
        -200,
      ];
      for (final double v in bad) {
        expect(
          EpitaphFootprint.forStone(stoneWidth: v, textScale: 1),
          _zero,
          reason: 'stoneWidth=$v',
        );
        expect(
          EpitaphFootprint.forStone(stoneWidth: 200, textScale: v),
          _zero,
          reason: 'textScale=$v',
        );
      }
    });

    test('is deterministic', () {
      final KeepOutRect a = EpitaphFootprint.forStone(
        stoneWidth: 240,
        textScale: 1.5,
      );
      final KeepOutRect b = EpitaphFootprint.forStone(
        stoneWidth: 240,
        textScale: 1.5,
      );
      expect(a, b);
    });
  });
}
