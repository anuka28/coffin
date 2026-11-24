// Feature: graveyard-seance, Property 9: Revival_Step text obeys the copy
// rules for every kind
// Validates: Requirements 4.9, 12.6, 14.10

import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/seance/revival_step_kind.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';

bool _isAllowed(int rune) =>
    (rune >= 0x20 && rune <= 0x7E) || rune == 0xE9 || rune == 0x2026;

void main() {
  group('GraveyardCopy.revivalStepText', () {
    test('every kind has non-empty text of at most 48 characters', () {
      for (final RevivalStepKind kind in RevivalStepKind.values) {
        final String text = GraveyardCopy.revivalStepText(kind);
        expect(text, isNotEmpty, reason: '$kind');
        expect(text.length, lessThanOrEqualTo(48), reason: '$kind: "$text"');
      }
    });

    test('every kind uses only Allowed_Characters', () {
      for (final RevivalStepKind kind in RevivalStepKind.values) {
        final String text = GraveyardCopy.revivalStepText(kind);
        for (final int rune in text.runes) {
          expect(
            _isAllowed(rune),
            isTrue,
            reason:
                '$kind: U+${rune.toRadixString(16).toUpperCase()} in "$text"',
          );
        }
      }
    });

    test('no two kinds share the same text', () {
      final Set<String> texts = <String>{
        for (final RevivalStepKind kind in RevivalStepKind.values)
          GraveyardCopy.revivalStepText(kind),
      };
      expect(texts.length, RevivalStepKind.values.length);
    });
  });
}
