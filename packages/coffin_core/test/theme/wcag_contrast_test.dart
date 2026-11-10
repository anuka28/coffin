import 'package:coffin_core/src/theme/wcag_contrast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WcagContrast', () {
    test('black on white is 21', () {
      expect(WcagContrast.ratio(0xFF000000, 0xFFFFFFFF), closeTo(21, 1e-9));
    });

    test('is symmetric', () {
      expect(
        WcagContrast.ratio(0xFF9B6BFF, 0xFF0E0B16),
        WcagContrast.ratio(0xFF0E0B16, 0xFF9B6BFF),
      );
    });

    test('identical colors give 1', () {
      expect(WcagContrast.ratio(0xFF9B6BFF, 0xFF9B6BFF), closeTo(1, 1e-9));
    });

    test('alpha byte is ignored', () {
      expect(
        WcagContrast.relativeLuminance(0x00FF8A3D),
        WcagContrast.relativeLuminance(0xFFFF8A3D),
      );
      expect(WcagContrast.ratio(0x00000000, 0x80FFFFFF), closeTo(21, 1e-9));
    });

    test('luminance of black is 0 and white is 1', () {
      expect(WcagContrast.relativeLuminance(0xFF000000), 0);
      expect(WcagContrast.relativeLuminance(0xFFFFFFFF), closeTo(1, 1e-9));
    });

    test('known values on ghost-glow purple', () {
      expect(WcagContrast.ratio(0xFF9B6BFF, 0xFFFFFFFF), closeTo(3.53, 0.01));
      expect(WcagContrast.ratio(0xFF9B6BFF, 0xFFEDE6F5), closeTo(2.90, 0.01));
    });

    test('AA threshold constant is 4.5', () {
      expect(WcagContrast.aaNormalText, 4.5);
    });
  });
}
