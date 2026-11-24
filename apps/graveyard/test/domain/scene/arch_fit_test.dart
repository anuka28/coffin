import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/arch_fit.dart';
import 'package:graveyard/src/domain/scene/arch_fit_result.dart';

// Assumptions: base epitaph size 24, glyph width 0.6 em, line height 1.2 em,
// so "R.I.P." (6 characters) measures 6 * 0.6 * size at any size.
const double _baseSize = 24;
const double _archRise = 140;

double _widthAt(double size, int chars) => chars * 0.6 * size;

void main() {
  group('ArchFit', () {
    test('"R.I.P." never needs truncation at widths 240-300, scales 1-2', () {
      for (final archWidth in [240.0, 270.0, 300.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          final size = _baseSize * scale;
          final result = ArchFit.positionFor(
            archWidth: archWidth,
            archRise: _archRise,
            lineHeight: size * 1.2,
            textWidth: _widthAt(size, 6),
            fontSize: size,
          );
          expect(
            result.truncated,
            isFalse,
            reason: 'width $archWidth scale $scale',
          );
          expect(result.fontSize, greaterThanOrEqualTo(ArchFit.minFontSize));
          expect(result.fontSize, lessThanOrEqualTo(size));
          expect(result.top, greaterThanOrEqualTo(0));
        }
      }
    });

    test('a text wider than the arch shrinks, then truncates', () {
      ArchFitResult fit(int chars) => ArchFit.positionFor(
        archWidth: 240,
        archRise: _archRise,
        lineHeight: _baseSize * 1.2,
        textWidth: _widthAt(_baseSize, chars),
        fontSize: _baseSize,
      );

      // 30 characters is 432 px at 24, wider than the 240 px arch, but fits
      // once shrunk toward 12.
      final shrunk = fit(30);
      expect(shrunk.truncated, isFalse);
      expect(shrunk.fontSize, lessThan(_baseSize));
      expect(shrunk.fontSize, greaterThanOrEqualTo(ArchFit.minFontSize));

      // 100 characters does not fit even at 12.
      final cut = fit(100);
      expect(cut.truncated, isTrue);
      expect(cut.fontSize, ArchFit.minFontSize);
    });

    test('a zero-width arch returns the documented fallback', () {
      final result = ArchFit.positionFor(
        archWidth: 0,
        archRise: _archRise,
        lineHeight: 29,
        textWidth: _widthAt(_baseSize, 6),
        fontSize: _baseSize,
      );
      expect(result.top, 0);
      expect(result.fontSize, 12);
      expect(result.truncated, isTrue);
    });
  });
}
