import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/ui/voice_copy.dart';

const List<String> _banned = <String>[
  'failed',
  'lazy',
  'worthless',
  'abandoned',
  'neglected',
  'guilty',
  'shame',
  'gore',
  'blood',
  'corpse',
  'rotting',
  'kill',
  'murder',
  'dead',
  'die',
];

void main() {
  group('VoiceCopy.safeLine', () {
    test('is short, one line and plain ASCII', () {
      const String line = VoiceCopy.safeLine;
      expect(line.trim(), isNotEmpty);
      expect(line.length, lessThanOrEqualTo(80));
      expect(line.contains('\n') || line.contains('\r'), isFalse);
      expect(line.codeUnits.every((int c) => c >= 0x20 && c <= 0x7E), isTrue);
    });

    test('has no banned word', () {
      final Iterable<String> words = VoiceCopy.safeLine.toLowerCase().split(
        RegExp(r'[^a-z]+'),
      );
      for (final String banned in _banned) {
        expect(words, isNot(contains(banned)));
      }
    });
  });

  group('VoiceCopy.label', () {
    test('uses the ghost name', () {
      expect(VoiceCopy.label('Boo', 'Hello.'), 'Boo says: Hello.');
    });

    test('falls back to Wisp for an empty name', () {
      expect(VoiceCopy.label('', 'Hello.'), 'Wisp says: Hello.');
    });
  });
}
