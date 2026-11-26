// Feature: graveyard-polish, Property 2: Verdict slot height is monotone and bounded below
// Validates: Requirements 8.1, 8.5
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/seance/verdict_slot_height.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// The inputs of one reading: a code unit count, how many more to add, and
/// the measured text metrics.
final class _Inputs {
  const _Inputs({
    required this.maxCodeUnits,
    required this.extraCodeUnits,
    required this.charsPerLine,
    required this.lineHeight,
    required this.minHeight,
  });

  final int maxCodeUnits;
  final int extraCodeUnits;
  final double charsPerLine;
  final double lineHeight;
  final double minHeight;

  @override
  String toString() =>
      '_Inputs(maxCodeUnits: $maxCodeUnits, extra: $extraCodeUnits, '
      'charsPerLine: $charsPerLine, lineHeight: $lineHeight, '
      'minHeight: $minHeight)';
}

Generator<_Inputs> get _anyInputs => any.simple<_Inputs>(
  generate: (math.Random random, int size) => _Inputs(
    maxCodeUnits: anyIntBetween(0, 100000)(random, size).value,
    extraCodeUnits: anyIntBetween(0, 100000)(random, size).value,
    charsPerLine: anyDoubleBetween(0.001, 200)(random, size).value,
    lineHeight: anyDoubleBetween(0.001, 100)(random, size).value,
    minHeight: anyDoubleBetween(0, 1000)(random, size).value,
  ),
  shrink: (_Inputs i) sync* {
    if (i.maxCodeUnits > 0 || i.extraCodeUnits > 0) {
      yield _Inputs(
        maxCodeUnits: i.maxCodeUnits ~/ 2,
        extraCodeUnits: i.extraCodeUnits ~/ 2,
        charsPerLine: i.charsPerLine,
        lineHeight: i.lineHeight,
        minHeight: i.minHeight,
      );
    }
  },
);

void main() {
  group('Property 2: Verdict slot height is monotone and bounded below', () {
    Glados(_anyInputs, ExploreConfig(numRuns: numRuns)).test(
      'never below minHeight and never shrinks as maxCodeUnits grows',
      (_Inputs input) {
        final int maxCodeUnits = input.maxCodeUnits;
        final int extraCodeUnits = input.extraCodeUnits;
        final double charsPerLine = input.charsPerLine;
        final double lineHeight = input.lineHeight;
        final double minHeight = input.minHeight;
        _counter.increment();
        final double smaller = VerdictSlotHeight.of(
          lineHeight: lineHeight,
          minHeight: minHeight,
          maxCodeUnits: maxCodeUnits,
          charsPerLine: charsPerLine,
        );
        final double larger = VerdictSlotHeight.of(
          lineHeight: lineHeight,
          minHeight: minHeight,
          maxCodeUnits: maxCodeUnits + extraCodeUnits,
          charsPerLine: charsPerLine,
        );
        expect(smaller, greaterThanOrEqualTo(minHeight));
        expect(larger, greaterThanOrEqualTo(minHeight));
        expect(larger, greaterThanOrEqualTo(smaller));
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
