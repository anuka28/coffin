@TestOn('vm')
library;

import 'package:coffin_core/src/storage/key_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'support/hive_test_box.dart';
import 'support/storage_generators.dart' show BoundaryKeys;

/// Validator-vs-real-box agreement (Requirement 3.8, reworded):
///  - every key the validator accepts works in a real box;
///  - every key the real box rejects is also rejected by the validator.
/// The validator MAY reject keys Hive accepts (B1, B7).
///
/// Rows B8, B9 and B10 are validator-only: they are never written to a real
/// box because the expected effect is corruption.
///
/// Observed with hive_ce 2.23.3, VM, debug asserts on: B4 (256 units) throws
/// a synchronous HiveError from Box.put (Frame.assertKey inside an assert).

/// What a real box does with a key.
enum _Hive { works, hiveError }

class _Row {
  const _Row(this.id, this.key, {required this.coffin, this.hive});

  final String id;
  final String key;
  final bool coffin;

  /// Null means the row is validator-only (never written to a real box).
  final _Hive? hive;
}

final List<_Row> _rows = <_Row>[
  _Row('B1', BoundaryKeys.b1, coffin: false, hive: _Hive.works),
  _Row('B2', BoundaryKeys.b2, coffin: true, hive: _Hive.works),
  _Row('B3', BoundaryKeys.b3, coffin: true, hive: _Hive.works),
  _Row('B4', BoundaryKeys.b4, coffin: false, hive: _Hive.hiveError),
  _Row('B5', BoundaryKeys.b5, coffin: true, hive: _Hive.works),
  _Row('B6', BoundaryKeys.b6, coffin: true, hive: _Hive.works),
  _Row('B7', BoundaryKeys.b7, coffin: false, hive: _Hive.works),
  _Row('B8', BoundaryKeys.b8, coffin: false),
  _Row('B9', BoundaryKeys.b9, coffin: false),
  _Row('B10', BoundaryKeys.b10, coffin: false),
  _Row('B11', BoundaryKeys.b11, coffin: true, hive: _Hive.works),
];

Future<HiveTestBox> _open() async {
  final HiveTestBox helper = await openHiveTestBox();
  addTearDown(helper.dispose);
  return helper;
}

/// Puts [key] and checks put, get and box.keys agree.
Future<void> _expectWorks(Box<dynamic> box, String key) async {
  final String record = 'record-for-${key.length}';
  await box.put(key, record);
  expect(box.get(key), record);
  expect(box.keys.toList(), <dynamic>[key]);
  expect(box.keys.single, key);
}

void main() {
  test('debug asserts are on, so B4 HiveError expectation is meaningful', () {
    var on = false;
    assert(on = true);
    expect(on, isTrue);
  });

  test('the table matches the design verdicts for the coffin validator', () {
    for (final _Row row in _rows) {
      expect(KeyValidator.isValid(row.key), row.coffin, reason: row.id);
    }
  });

  group('per row: coffin verdict and real-box outcome', () {
    for (final _Row row in _rows) {
      final _Hive? hive = row.hive;
      if (hive == null) {
        test('${row.id}: validator-only, rejected and never written', () {
          expect(KeyValidator.isValid(row.key), isFalse);
          expect(() => KeyValidator.check(row.key), throwsArgumentError);
        });
      } else if (hive == _Hive.works && row.coffin) {
        test(
          '${row.id}: accepted by coffin, put/get/keys agree in a box',
          () async {
            expect(KeyValidator.isValid(row.key), isTrue);
            final HiveTestBox helper = await _open();
            await _expectWorks(helper.box, row.key);
          },
        );
      } else if (hive == _Hive.hiveError) {
        test(
          '${row.id}: rejected by coffin and by the real box (HiveError)',
          () async {
            expect(KeyValidator.isValid(row.key), isFalse);
            final HiveTestBox helper = await _open();
            await expectLater(
              () => helper.box.put(row.key, 'x'),
              throwsA(isA<HiveError>()),
            );
            expect(helper.box.keys, isEmpty);
          },
        );
      }
    }
  });

  group('characterization: Hive accepts keys that coffin rejects', () {
    test('B1 (empty key): coffin rejects, hive_ce 2.23.3 accepts', () async {
      expect(KeyValidator.isValid(BoundaryKeys.b1), isFalse);
      final HiveTestBox helper = await _open();
      await _expectWorks(helper.box, BoundaryKeys.b1);
    });

    test("B7 ('x\\u0080'): coffin rejects, hive_ce 2.23.3 accepts", () async {
      expect(KeyValidator.isValid(BoundaryKeys.b7), isFalse);
      final HiveTestBox helper = await _open();
      await _expectWorks(helper.box, BoundaryKeys.b7);
    });
  });

  group('Req 3.8 both directions', () {
    test('every key the validator accepts works in a real box', () async {
      for (final _Row row in _rows.where((_Row r) => r.coffin)) {
        expect(row.hive, _Hive.works, reason: row.id);
        final HiveTestBox helper = await _open();
        await _expectWorks(helper.box, row.key);
      }
    });

    test(
      'every key the real box rejects is rejected by the validator',
      () async {
        for (final _Row row in _rows.where((_Row r) => r.hive != null)) {
          final HiveTestBox helper = await _open();
          Object? failure;
          try {
            await helper.box.put(row.key, 'x');
          } catch (e) {
            failure = e;
          }
          if (failure != null) {
            expect(failure, isA<HiveError>(), reason: row.id);
            expect(KeyValidator.isValid(row.key), isFalse, reason: row.id);
          }
        }
      },
    );
  });
}
