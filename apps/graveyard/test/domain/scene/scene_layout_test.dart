import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/scene_layout.dart';

void main() {
  group('SceneLayout.columnsFor', () {
    final expected = <double, int>{
      319: 1,
      320: 1,
      719: 1,
      720: 2,
      1000: 3,
      1280: 4,
      4096: 4,
    };
    expected.forEach((width, columns) {
      test('width $width gives $columns column(s)', () {
        expect(SceneLayout.columnsFor(width), columns);
      });
    });
  });

  group('SceneLayout layouts', () {
    test('empty layout has no content height', () {
      expect(
        SceneLayout.contentHeightFor(
          graveCount: 0,
          availableWidth: 1000,
          tombstoneHeight: 200,
        ),
        0,
      );
    });

    test('single grave at 320 sits in the first cell, padded by 16', () {
      final cell = SceneLayout.cellFor(
        index: 0,
        graveCount: 1,
        availableWidth: 320,
      );
      expect(cell.row, 0);
      expect(cell.column, 0);
      expect(cell.top, 0);
      expect(cell.left, SceneLayout.sidePadding);
      expect(cell.width, 288);
    });

    test('single grave content height is one tombstone', () {
      expect(
        SceneLayout.contentHeightFor(
          graveCount: 1,
          availableWidth: 320,
          tombstoneHeight: 200,
        ),
        200,
      );
    });

    for (final width in <double>[720, 1000, 1280]) {
      test('one grave is centered at width $width', () {
        final cell = SceneLayout.cellFor(
          index: 0,
          graveCount: 1,
          availableWidth: width,
        );
        expect(cell.left + cell.width / 2, closeTo(width / 2, 1e-9));
      });
    }

    test('five graves at 3 columns: last row of two is centered', () {
      const width = 1000.0;
      final cells = [
        for (var i = 0; i < 5; i++)
          SceneLayout.cellFor(index: i, graveCount: 5, availableWidth: width),
      ];
      expect(cells[3].row, 1);
      expect(cells[3].column, 0);
      expect(cells[4].column, 1);
      final left = cells[3].left;
      final right = cells[4].left + cells[4].width;
      expect((left + right) / 2, closeTo(width / 2, 1e-9));
      // Full first row is centered too.
      expect(
        (cells[0].left + cells[2].left + cells[2].width) / 2,
        closeTo(width / 2, 1e-9),
      );
    });
  });

  group('SceneLayout below minimum width', () {
    test('tombstone shrinks to the free space and stays inside padding', () {
      final cell = SceneLayout.cellFor(
        index: 0,
        graveCount: 1,
        availableWidth: 200,
      );
      expect(SceneLayout.columnsFor(200), 1);
      expect(cell.width, 168);
      expect(cell.width, lessThan(SceneLayout.minTombstoneWidth));
      expect(cell.left, SceneLayout.sidePadding);
    });

    test(
      'width smaller than the padding gives a zero width, never negative',
      () {
        expect(SceneLayout.tombstoneWidthFor(20, 1), 0);
      },
    );
  });
}
