import 'dart:ui' show Color;

import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/theme/contrast_pair.dart';
import 'package:coffin_core/src/theme/wcag_contrast.dart';
import 'package:flutter_test/flutter_test.dart' show expect, test, contains;
import 'package:glados/glados.dart' hide expect, test, contains;

/// A pair tagged with the variant it belongs to.
typedef _NamedPair = (String, ContrastPair);

final List<_NamedPair> _allPairs = [
  for (final variant in CoffinColorTokens.variants)
    for (final pair in variant.contrastPairs) (variant.name, pair),
];

/// Failure text naming the variant, pair label and measured ratio (Req 3.8).
String _failureReason(String variant, ContrastPair pair) =>
    '$variant: ${pair.label} has contrast ${pair.ratio.toStringAsFixed(2)}:1, '
    'below ${WcagContrast.aaNormalText}:1';

void main() {
  const numRuns = 200;
  var executedRuns = 0;

  // Feature: haunted-theme, Property 1
  // Validates: Requirements 1.2, 2.4, 3.1, 3.2, 3.5, 3.6, 3.8
  Glados(any.choose(_allPairs), ExploreConfig(numRuns: numRuns)).test(
    'every declared token pair meets WCAG AA and is symmetric',
    (entry) {
      executedRuns++;
      final (variant, pair) = entry;
      final ratio = pair.ratio;

      expect(
        ratio >= WcagContrast.aaNormalText,
        isTrue,
        reason: _failureReason(variant, pair),
      );

      final swapped = WcagContrast.ratio(
        pair.background.toARGB32(),
        pair.foreground.toARGB32(),
      );
      expect(swapped, ratio, reason: '$variant: ${pair.label} not symmetric');
    },
  );

  test('property body executed for every requested run', () {
    expect(executedRuns, numRuns);
  });

  test('all pairs of every variant meet AA exhaustively', () {
    expect(_allPairs, isNotEmpty);
    for (final (variant, pair) in _allPairs) {
      expect(
        pair.ratio >= WcagContrast.aaNormalText,
        isTrue,
        reason: _failureReason(variant, pair),
      );
    }
  });

  test('failure message names variant, label and measured ratio', () {
    const fake = ContrastPair(
      foregroundName: 'ghost',
      backgroundName: 'fog',
      foreground: Color(0xFF777777),
      background: Color(0xFF808080),
    );
    final message = _failureReason('night', fake);

    expect(fake.ratio, lessThan(WcagContrast.aaNormalText));
    expect(message, contains('night'));
    expect(message, contains('ghost on fog'));
    expect(message, contains(fake.ratio.toStringAsFixed(2)));
  });
}
