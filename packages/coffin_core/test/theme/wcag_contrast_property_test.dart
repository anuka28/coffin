import 'package:coffin_core/src/theme/wcag_contrast.dart';
import 'package:glados/glados.dart' hide expect, test;
import 'package:flutter_test/flutter_test.dart' show expect, test;

/// Opaque colors: full alpha plus any 24-bit RGB value.
Generator<int> get _opaqueColor =>
    any.intInRange(0, 0x1000000).map((rgb) => 0xFF000000 | rgb);

void main() {
  const numRuns = 200;
  var executedRuns = 0;

  // Feature: haunted-theme, Property 2
  // Validates: Requirements 3.6, 3.7
  Glados2(_opaqueColor, _opaqueColor, ExploreConfig(numRuns: numRuns)).test(
    'contrast ratio is symmetric, within [1, 21], and 1 for identical colors',
    (a, b) {
      executedRuns++;
      final ab = WcagContrast.ratio(a, b);
      final ba = WcagContrast.ratio(b, a);

      expect(ab, ba, reason: 'ratio($a, $b) must equal ratio($b, $a)');
      expect(ab, inInclusiveRange(1.0, 21.0));
      expect(WcagContrast.ratio(a, a), 1.0);
      expect(WcagContrast.ratio(b, b), 1.0);
    },
  );

  test('property body executed for every requested run', () {
    expect(executedRuns, numRuns);
  });
}
