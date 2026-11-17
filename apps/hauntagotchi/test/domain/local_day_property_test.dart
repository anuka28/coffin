// Feature: hauntagotchi-core, Property 1: LocalDay round trip
// Validates: Requirements 2.6

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, isNull;
import 'package:glados/glados.dart' hide expect, group;
import 'package:hauntagotchi/src/domain/local_day.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;

final RunCounter _isoRuns = RunCounter();
final RunCounter _epochRuns = RunCounter();
final RunCounter _invalidRuns = RunCounter();

/// Number of mutations in [_breakIso].
const int _mutationCount = 14;

/// Turns the valid text [iso] into text that is not a real `YYYY-MM-DD` date.
String _breakIso(String iso, int kind) {
  final int year = int.parse(iso.substring(0, 4));
  final int month = int.parse(iso.substring(5, 7));
  switch (kind) {
    case 0: // too short
      return iso.substring(0, iso.length - 1);
    case 1: // too long
      return '${iso}0';
    case 2: // wrong separator
      return iso.replaceAll('-', '/');
    case 3: // no separators
      return iso.replaceAll('-', '');
    case 4: // month 00
      return '${iso.substring(0, 5)}00${iso.substring(7)}';
    case 5: // month 13
      return '${iso.substring(0, 5)}13${iso.substring(7)}';
    case 6: // day 00
      return '${iso.substring(0, 8)}00';
    case 7: // day past the end of the month
      // Month length from epoch days: next month's first day minus this one.
      final LocalDay first = LocalDay(year, month, 1);
      final LocalDay nextMonth = month == 12
          ? LocalDay(year + 1, 1, 1)
          : LocalDay(year, month + 1, 1);
      final String dd = (first.daysUntil(nextMonth) + 1).toString().padLeft(
        2,
        '0',
      );
      return '${iso.substring(0, 8)}$dd';
    case 8: // year 0000
      return '0000${iso.substring(4)}';
    case 9: // leading space
      return ' $iso';
    case 10: // trailing newline
      return '$iso\n';
    case 11: // a letter in place of a digit
      return 'x${iso.substring(1)}';
    case 12: // empty
      return '';
    default: // non-ASCII digit (Arabic-Indic zero)
      return '\u0660${iso.substring(1)}';
  }
}

void main() {
  group('LocalDay round trip (Property 1)', () {
    Glados(anyLocalDay, ExploreConfig(numRuns: _numRuns)).test(
      'tryParse(toIso()) equals the day',
      (LocalDay d) {
        _isoRuns.increment();
        expect(LocalDay.tryParse(d.toIso()), equals(d));
      },
    );

    Glados(anyLocalDay, ExploreConfig(numRuns: _numRuns)).test(
      'fromEpochDay(epochDay) equals the day',
      (LocalDay d) {
        _epochRuns.increment();
        expect(LocalDay.fromEpochDay(d.epochDay), equals(d));
      },
    );

    Glados2(
      anyLocalDay,
      anyIntBetween(0, _mutationCount),
      ExploreConfig(numRuns: _numRuns),
    ).test('text that is not a real date parses to null', (
      LocalDay d,
      int kind,
    ) {
      _invalidRuns.increment();
      expect(LocalDay.tryParse(_breakIso(d.toIso(), kind)), isNull);
    });

    test('every property body ran numRuns times', () {
      _isoRuns.expectRuns(_numRuns);
      _epochRuns.expectRuns(_numRuns);
      _invalidRuns.expectRuns(_numRuns);
    });
  });
}
