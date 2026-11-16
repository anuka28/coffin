import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/template_catalog.dart';
import 'package:coffin_core/src/ai/template_set.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TemplateSet', () {
    test('parses patterns in order and keeps the safe line', () {
      final set = TemplateSet(const <String>[
        'One.',
        'Two {ghostName|ghost}.',
      ], safeLine: 'Safe.');
      expect(set.templates, hasLength(2));
      expect(set.safeLine, 'Safe.');
    });

    test('throws StateError for a bad pattern', () {
      expect(
        () => TemplateSet(const <String>['{nope|x}'], safeLine: 'Safe.'),
        throwsStateError,
      );
    });
  });

  group('TemplateCatalog.standard', () {
    final catalog = TemplateCatalog.standard;

    test('has eight templates per set', () {
      expect(catalog.ghostMoodLine.templates, hasLength(8));
      expect(catalog.seanceVerdict.templates, hasLength(8));
      expect(catalog.generic.templates, hasLength(8));
    });

    test('has the three safe lines', () {
      expect(catalog.ghostMoodLine.safeLine, 'Boo. Still here.');
      expect(catalog.seanceVerdict.safeLine, 'Rest, then rise.');
      expect(catalog.generic.safeLine, 'Still here.');
    });

    test('forPurpose maps both known constants to their sets', () {
      expect(
        identical(
          catalog.forPurpose(AiPurpose.ghostMoodLine),
          catalog.ghostMoodLine,
        ),
        isTrue,
      );
      expect(
        identical(
          catalog.forPurpose(AiPurpose.seanceVerdict),
          catalog.seanceVerdict,
        ),
        isTrue,
      );
    });

    test('forPurpose maps a custom purpose to the generic set', () {
      expect(
        identical(
          catalog.forPurpose(AiPurpose('shop_greeting')),
          catalog.generic,
        ),
        isTrue,
      );
    });

    test('forPurpose maps a custom purpose with a known id to that set', () {
      expect(
        identical(
          catalog.forPurpose(AiPurpose('ghost_mood_line')),
          catalog.ghostMoodLine,
        ),
        isTrue,
      );
      expect(
        identical(
          catalog.forPurpose(AiPurpose('seance_verdict')),
          catalog.seanceVerdict,
        ),
        isTrue,
      );
    });
  });
}
