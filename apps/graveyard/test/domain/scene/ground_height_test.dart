import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/ground_height.dart';

void main() {
  group('GroundHeight.of', () {
    test('short scene: the viewport term wins', () {
      expect(
        GroundHeight.of(
          groundTop: 100,
          contentBottom: 400,
          viewportHeight: 800,
        ),
        700,
      );
    });

    test('tall scene: the content term wins', () {
      expect(
        GroundHeight.of(
          groundTop: 100,
          contentBottom: 1500,
          viewportHeight: 800,
        ),
        1400,
      );
    });

    test('both terms equal', () {
      expect(
        GroundHeight.of(groundTop: 50, contentBottom: 600, viewportHeight: 600),
        550,
      );
    });

    test('groundTop below both bottoms returns 0', () {
      expect(
        GroundHeight.of(
          groundTop: 900,
          contentBottom: 500,
          viewportHeight: 800,
        ),
        0,
      );
    });

    test('groundTop of 0 returns the larger bottom', () {
      expect(
        GroundHeight.of(groundTop: 0, contentBottom: 300, viewportHeight: 800),
        800,
      );
      expect(
        GroundHeight.of(groundTop: 0, contentBottom: 1200, viewportHeight: 800),
        1200,
      );
    });

    test(
      'contentBottom smaller than groundTop gives the viewport term or 0',
      () {
        final withViewport = GroundHeight.of(
          groundTop: 300,
          contentBottom: 200,
          viewportHeight: 800,
        );
        expect(withViewport, 500);

        final none = GroundHeight.of(
          groundTop: 300,
          contentBottom: 200,
          viewportHeight: 250,
        );
        expect(none, 0);
        expect(none, isNot(isNegative));
      },
    );
  });
}
