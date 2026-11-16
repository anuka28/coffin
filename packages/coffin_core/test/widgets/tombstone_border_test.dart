import 'package:coffin_core/src/widgets/tombstone_border.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const border = TombstoneBorder();

  group('TombstoneBorder path bounds', () {
    for (final size in const [Size(360, 200), Size(320, 120), Size(10, 10)]) {
      test('${size.width} by ${size.height}', () {
        final rect = Offset.zero & size;
        expect(border.getOuterPath(rect).getBounds(), rect);
      });
    }

    test('is positioned relative to a rect with a non-zero offset', () {
      final rect = const Rect.fromLTWH(10, 20, 360, 200);
      final path = border.getOuterPath(rect);
      expect(path.getBounds(), rect);
      expect(path.contains(rect.bottomCenter - const Offset(0, 1)), isTrue);
      expect(path.contains(const Offset(180, 30)), isTrue);
      expect(path.contains(const Offset(5, 5)), isFalse);
      expect(path.contains(rect.topLeft + const Offset(2, 2)), isFalse);
    });
  });

  group('TombstoneBorder empty rects', () {
    for (final size in const [Size(0, 100), Size(100, 0), Size.zero]) {
      test('empty path for $size', () {
        final path = border.getOuterPath(Offset.zero & size);
        expect(path.getBounds().isEmpty, isTrue);
      });
    }
  });

  group('TombstoneBorder containment', () {
    final rect = const Rect.fromLTWH(0, 0, 360, 200);
    final path = border.getOuterPath(rect);

    test('contains the bottom center point', () {
      expect(path.contains(const Offset(180, 199)), isTrue);
    });

    test('contains the arch center point', () {
      // Just below the top of the arch, on the vertical axis.
      expect(path.contains(const Offset(180, 2)), isTrue);
    });

    test('the default arch is close to a half circle of a 300 px card', () {
      final arch = border.getOuterPath(const Rect.fromLTWH(0, 0, 300, 400));
      expect(border.archRise, greaterThanOrEqualTo(0.9 * 150));
      // The arch is an ellipse 150 wide and 140 high: (20, 40) is outside it.
      expect(arch.contains(const Offset(150, 20)), isTrue);
      expect(arch.contains(const Offset(20, 40)), isFalse);
      expect(arch.contains(const Offset(150, 150)), isTrue);
    });
    test('does not contain a point at the top-left corner', () {
      expect(path.contains(const Offset(2, 2)), isFalse);
    });
  });

  group('TombstoneBorder value semantics', () {
    test('copyWith replaces only the given fields', () {
      const side = BorderSide(width: 3);
      final copy = border.copyWith(side: side, archRise: 20);
      expect(copy.side, side);
      expect(copy.archRise, 20);
      expect(copy.bottomRadius, border.bottomRadius);
      expect(border.copyWith(), border);
    });

    test('equality and hashCode follow the fields', () {
      expect(const TombstoneBorder(), const TombstoneBorder());
      expect(
        const TombstoneBorder().hashCode,
        const TombstoneBorder().hashCode,
      );
      expect(
        const TombstoneBorder(),
        isNot(const TombstoneBorder(archRise: 10)),
      );
      expect(
        const TombstoneBorder(),
        isNot(const TombstoneBorder(bottomRadius: 4)),
      );
      expect(
        const TombstoneBorder(),
        isNot(const TombstoneBorder(side: BorderSide(width: 2))),
      );
    });

    test('scale scales the side', () {
      const scaled = TombstoneBorder(side: BorderSide(width: 4));
      final result = scaled.scale(0.5) as TombstoneBorder;
      expect(result.side.width, 2);
    });

    test('dimensions equal the side width', () {
      const b = TombstoneBorder(side: BorderSide(width: 3));
      expect(b.dimensions, const EdgeInsets.all(3));
    });
  });
}
