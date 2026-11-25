import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/hand_shape.dart';
import 'package:graveyard/src/domain/resurrection/stone_point.dart';

void main() {
  group('HandShape', () {
    test('equal bones and visible are equal with the same hashCode', () {
      const HandShape a = HandShape(
        bones: <List<StonePoint>>[
          <StonePoint>[StonePoint(1, 2), StonePoint(3, 4)],
        ],
        visible: true,
      );
      const HandShape b = HandShape(
        bones: <List<StonePoint>>[
          <StonePoint>[StonePoint(1, 2), StonePoint(3, 4)],
        ],
        visible: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test(
      'compares bones element-wise, including order, length and bone count',
      () {
        const HandShape a = HandShape(
          bones: <List<StonePoint>>[
            <StonePoint>[StonePoint(1, 2), StonePoint(3, 4)],
          ],
          visible: true,
        );
        const HandShape swapped = HandShape(
          bones: <List<StonePoint>>[
            <StonePoint>[StonePoint(3, 4), StonePoint(1, 2)],
          ],
          visible: true,
        );
        const HandShape shorter = HandShape(
          bones: <List<StonePoint>>[
            <StonePoint>[StonePoint(1, 2)],
          ],
          visible: true,
        );
        const HandShape changed = HandShape(
          bones: <List<StonePoint>>[
            <StonePoint>[StonePoint(1, 2), StonePoint(3, 5)],
          ],
          visible: true,
        );
        expect(a, isNot(swapped));
        expect(a, isNot(shorter));
        expect(a, isNot(changed));
        const HandShape split = HandShape(
          bones: <List<StonePoint>>[
            <StonePoint>[StonePoint(1, 2)],
            <StonePoint>[StonePoint(3, 4)],
          ],
          visible: true,
        );
        expect(a, isNot(split));
      },
    );

    test('differs when only the visible flag differs', () {
      const HandShape a = HandShape(bones: <List<StonePoint>>[], visible: true);
      const HandShape b = HandShape(
        bones: <List<StonePoint>>[],
        visible: false,
      );
      expect(a, isNot(b));
    });

    test('is not equal to other types', () {
      const HandShape a = HandShape(
        bones: <List<StonePoint>>[],
        visible: false,
      );
      expect(a == Object(), isFalse);
    });
  });
}
