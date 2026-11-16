import 'package:flutter_test/flutter_test.dart';

import 'color_blend.dart';

void main() {
  group('blendOver', () {
    test('alpha 0 gives the background', () {
      expect(blendOver(0xFFFF0000, 0xFF102030, 0), 0xFF102030);
    });

    test('alpha 1 gives the foreground', () {
      expect(blendOver(0xFFFF8040, 0xFF102030, 1), 0xFFFF8040);
    });

    test('a known blend, worked by hand', () {
      // White over black at 0.5: round(127.5) = 128 per channel.
      expect(blendOver(0xFFFFFFFF, 0xFF000000, 0.5), 0xFF808080);
      // 200 * 0.25 + 100 * 0.75 = 125 (0x7D); 0 * 0.25 + 40 * 0.75 = 30 (0x1E).
      expect(blendOver(0xFFC80000, 0xFF640028, 0.25), 0xFF7D001E);
    });
  });

  group('blendRepeated', () {
    test('one layer equals blendOver', () {
      expect(
        blendRepeated(0xFF9B6BFF, 0xFF0E0B16, 0.2, 1),
        blendOver(0xFF9B6BFF, 0xFF0E0B16, 0.2),
      );
    });

    test('zero layers return the base', () {
      expect(blendRepeated(0xFF9B6BFF, 0xFF0E0B16, 0.2, 0), 0xFF0E0B16);
    });

    test('two layers blend the first result again', () {
      final int once = blendOver(0xFF9B6BFF, 0xFF0E0B16, 0.2);
      expect(
        blendRepeated(0xFF9B6BFF, 0xFF0E0B16, 0.2, 2),
        blendOver(0xFF9B6BFF, once, 0.2),
      );
    });
  });
}
