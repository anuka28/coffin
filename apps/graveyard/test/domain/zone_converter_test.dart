import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/zone_converter.dart';

void main() {
  group('localZone', () {
    final inputs = <DateTime>[
      DateTime.utc(1970),
      DateTime.utc(2024, 2, 29, 23, 59, 59),
      DateTime.utc(2025, 6, 15, 12, 30),
      DateTime.utc(2025, 12, 31, 23, 59, 59, 999),
    ];

    test('keeps the same instant', () {
      for (final utc in inputs) {
        expect(
          localZone(utc).millisecondsSinceEpoch,
          utc.millisecondsSinceEpoch,
        );
      }
    });

    test('returns a non-UTC DateTime', () {
      for (final utc in inputs) {
        expect(localZone(utc).isUtc, isFalse);
      }
    });
  });
}
