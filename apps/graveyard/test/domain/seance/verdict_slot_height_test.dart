import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/seance/verdict_slot_height.dart';

double _slot({
  double lineHeight = 20,
  double minHeight = 40,
  int maxCodeUnits = 140,
  double charsPerLine = 35,
}) => VerdictSlotHeight.of(
  lineHeight: lineHeight,
  minHeight: minHeight,
  maxCodeUnits: maxCodeUnits,
  charsPerLine: charsPerLine,
);

void main() {
  group('VerdictSlotHeight', () {
    test('140 code units at 35 chars per line is 4 lines of line height', () {
      expect(_slot(), 4 * 20.0);
    });

    test('rounds partial lines up', () {
      expect(_slot(charsPerLine: 50), 3 * 20.0);
    });

    test('never goes below minHeight', () {
      expect(_slot(maxCodeUnits: 10, minHeight: 200), 200);
    });

    test('a narrower width (fewer chars per line) gives a taller slot', () {
      expect(_slot(charsPerLine: 20), greaterThan(_slot(charsPerLine: 35)));
    });

    test('a larger line height gives a taller slot', () {
      expect(_slot(lineHeight: 40), greaterThan(_slot(lineHeight: 20)));
    });

    test('zero code units returns minHeight', () {
      expect(_slot(maxCodeUnits: 0), 40);
    });

    test('unusable input returns minHeight and does not throw', () {
      expect(_slot(lineHeight: double.infinity), 40);
      expect(_slot(charsPerLine: double.nan), 40);
      expect(_slot(charsPerLine: 0), 40);
      expect(_slot(charsPerLine: -5), 40);
      expect(_slot(maxCodeUnits: -1), 40);
    });
  });
}
