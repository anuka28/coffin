import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/ghost_box.dart';

void main() {
  group('GhostBox', () {
    const base = GhostBox(left: 1, top: 2, width: 3, height: 4, visible: true);

    test('equal values are equal and share a hash code', () {
      const same = GhostBox(
        left: 1,
        top: 2,
        width: 3,
        height: 4,
        visible: true,
      );
      expect(base, same);
      expect(base.hashCode, same.hashCode);
    });

    test('any differing field makes boxes unequal', () {
      expect(
        base,
        isNot(
          const GhostBox(left: 9, top: 2, width: 3, height: 4, visible: true),
        ),
      );
      expect(
        base,
        isNot(
          const GhostBox(left: 1, top: 9, width: 3, height: 4, visible: true),
        ),
      );
      expect(
        base,
        isNot(
          const GhostBox(left: 1, top: 2, width: 9, height: 4, visible: true),
        ),
      );
      expect(
        base,
        isNot(
          const GhostBox(left: 1, top: 2, width: 3, height: 9, visible: true),
        ),
      );
      expect(
        base,
        isNot(
          const GhostBox(left: 1, top: 2, width: 3, height: 4, visible: false),
        ),
      );
    });

    test('toString names the fields', () {
      expect(base.toString(), contains('left: 1.0'));
      expect(base.toString(), contains('visible: true'));
    });
  });
}
