import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/ui/seance_ai.dart';

Grave _grave(String id, [String name = 'Moth Tracker']) =>
    Grave.manual(id: id, name: name, dateOfDeath: CalendarDate(2024, 1, 1));

SeanceFacts _facts(int days) => SeanceFacts(
  dayCount: days,
  archived: false,
  stars: 0,
  hasDescription: false,
  manual: true,
);

void main() {
  group('buildVerdictRequest', () {
    test('uses the seance verdict purpose', () {
      final AiRequest request = buildVerdictRequest(
        grave: _grave('a'),
        facts: _facts(10),
      );
      expect(request.purpose, AiPurpose.seanceVerdict);
    });

    test('carries exactly the name and the day count', () {
      final AiRequest request = buildVerdictRequest(
        grave: _grave('a', 'Moth Tracker'),
        facts: _facts(214),
      );
      expect(request.facts, <String, Object?>{
        AiFactKeys.projectName: 'Moth Tracker',
        AiFactKeys.daysSinceLastCommit: 214,
      });
      expect(request.facts.keys.toSet(), <String>{
        AiFactKeys.projectName,
        AiFactKeys.daysSinceLastCommit,
      });
    });

    test('maxLength is between 16 and 140', () {
      final AiRequest request = buildVerdictRequest(
        grave: _grave('a'),
        facts: _facts(1),
      );
      expect(request.maxLength, inInclusiveRange(16, 140));
    });

    test('seed is within 0 and maxSeed', () {
      for (final String id in <String>['a', 'grave-a', 'grave-b', '']) {
        final AiRequest request = buildVerdictRequest(
          grave: _grave(id),
          facts: _facts(1),
        );
        expect(request.seed, inInclusiveRange(0, AiRequest.maxSeed));
      }
    });

    test('same id gives the same seed with different facts', () {
      final AiRequest first = buildVerdictRequest(
        grave: _grave('same'),
        facts: _facts(5),
      );
      final AiRequest second = buildVerdictRequest(
        grave: _grave('same', 'Other Name'),
        facts: _facts(9000),
      );
      expect(second.seed, first.seed);
    });

    test('two ids give their pinned seeds', () {
      expect(
        buildVerdictRequest(grave: _grave('grave-a'), facts: _facts(1)).seed,
        1742771378,
      );
      expect(
        buildVerdictRequest(grave: _grave('grave-b'), facts: _facts(1)).seed,
        1742771379,
      );
    });
  });

  group('buildSeanceAi', () {
    test('wraps the offline generator twice with a short timeout', () {
      final FallbackCoffinAI ai = buildSeanceAi();
      expect(ai.primary, isA<OfflineCoffinAI>());
      expect(ai.secondary, isA<OfflineCoffinAI>());
      expect(ai.timeout, greaterThan(Duration.zero));
      expect(ai.timeout, lessThanOrEqualTo(const Duration(seconds: 3)));
    });

    test('answers a verdict request with a non-blank reply', () async {
      final AiReply reply = await buildSeanceAi().ask(
        buildVerdictRequest(grave: _grave('grave-a'), facts: _facts(214)),
      );
      expect(reply.text.trim(), isNotEmpty);
      expect(reply.text.length, lessThanOrEqualTo(verdictMaxLength));
    });
  });
}
