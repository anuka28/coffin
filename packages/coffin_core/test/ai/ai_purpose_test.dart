import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiPurpose', () {
    test('known constants have stable ids', () {
      expect(AiPurpose.ghostMoodLine.id, 'ghost_mood_line');
      expect(AiPurpose.seanceVerdict.id, 'seance_verdict');
      expect(AiPurpose.maxIdLength, 64);
    });

    test('constants are const values', () {
      const AiPurpose a = AiPurpose.ghostMoodLine;
      const List<AiPurpose> list = <AiPurpose>[a, AiPurpose.seanceVerdict];
      expect(identical(list.first, AiPurpose.ghostMoodLine), isTrue);
    });

    test('accepts valid custom ids, including 1 and 64 units', () {
      expect(AiPurpose('a').id, 'a');
      expect(AiPurpose('custom_9').id, 'custom_9');
      expect(AiPurpose('a' * 64).id, 'a' * 64);
    });

    test('rejects invalid ids with ArgumentError', () {
      for (final String id in <String>[
        '',
        'a' * 65,
        '1abc',
        'Ghost',
        'ghost mood',
        'ghost-mood',
        'caf\u00e9',
        'séance verdict',
      ]) {
        expect(() => AiPurpose(id), throwsArgumentError, reason: id);
        expect(AiPurpose.violation(id), isNotNull, reason: id);
      }
    });

    test('violation is null for valid ids', () {
      expect(AiPurpose.violation('seance_verdict'), isNull);
    });

    test('error message states a length and never the rejected text', () {
      const String bad = 'Zq Wx-Yy';
      try {
        AiPurpose(bad);
        fail('should throw');
      } on ArgumentError catch (e) {
        expect(e.toString().contains(bad), isFalse);
        expect(e.toString(), contains('index'));
      }
      try {
        AiPurpose('b' * 65);
        fail('should throw');
      } on ArgumentError catch (e) {
        expect(e.toString(), contains('65'));
        expect(e.toString().contains('b' * 65), isFalse);
      }
    });

    test('a custom purpose reusing a known id equals the constant', () {
      final AiPurpose custom = AiPurpose('ghost_mood_line');
      expect(custom, AiPurpose.ghostMoodLine);
      expect(custom.hashCode, AiPurpose.ghostMoodLine.hashCode);
      expect(AiPurpose('seance_verdict'), AiPurpose.seanceVerdict);
    });

    test('different ids are not equal', () {
      expect(AiPurpose.ghostMoodLine == AiPurpose.seanceVerdict, isFalse);
      expect(AiPurpose('other') == AiPurpose.ghostMoodLine, isFalse);
    });

    test('toString is stable and readable', () {
      expect(AiPurpose.ghostMoodLine.toString(), 'AiPurpose(ghost_mood_line)');
      expect(AiPurpose('abc').toString(), 'AiPurpose(abc)');
    });
  });
}
