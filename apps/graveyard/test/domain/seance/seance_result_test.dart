import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/seance/revival_band.dart';
import 'package:graveyard/src/domain/seance/revival_step_kind.dart';
import 'package:graveyard/src/domain/seance/seance_result.dart';

const List<RevivalStepKind> _steps = <RevivalStepKind>[
  RevivalStepKind.skimReadme,
  RevivalStepKind.fixOneThing,
  RevivalStepKind.askAFriend,
];

void main() {
  group('SeanceResult', () {
    test('equal values are equal with equal hash codes', () {
      final SeanceResult a = SeanceResult(
        score: 50,
        band: RevivalBand.stirring,
        steps: List<RevivalStepKind>.of(_steps),
      );
      final SeanceResult b = SeanceResult(
        score: 50,
        band: RevivalBand.stirring,
        steps: List<RevivalStepKind>.of(_steps),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing score or band is unequal', () {
      const SeanceResult a = SeanceResult(
        score: 50,
        band: RevivalBand.stirring,
        steps: _steps,
      );
      expect(
        a,
        isNot(
          const SeanceResult(
            score: 51,
            band: RevivalBand.stirring,
            steps: _steps,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const SeanceResult(
            score: 50,
            band: RevivalBand.restless,
            steps: _steps,
          ),
        ),
      );
    });

    test('steps are compared in order', () {
      const SeanceResult a = SeanceResult(
        score: 50,
        band: RevivalBand.stirring,
        steps: _steps,
      );
      const SeanceResult b = SeanceResult(
        score: 50,
        band: RevivalBand.stirring,
        steps: <RevivalStepKind>[
          RevivalStepKind.fixOneThing,
          RevivalStepKind.skimReadme,
          RevivalStepKind.askAFriend,
        ],
      );
      expect(a, isNot(b));
    });

    test('different step counts are unequal', () {
      const SeanceResult a = SeanceResult(
        score: 50,
        band: RevivalBand.stirring,
        steps: _steps,
      );
      const SeanceResult b = SeanceResult(
        score: 50,
        band: RevivalBand.stirring,
        steps: <RevivalStepKind>[RevivalStepKind.skimReadme],
      );
      expect(a, isNot(b));
    });

    test('is equal to itself and not to other types', () {
      const SeanceResult a = SeanceResult(
        score: 1,
        band: RevivalBand.restless,
        steps: _steps,
      );
      expect(a == a, isTrue);
      // ignore: unrelated_type_equality_checks
      expect(a == 'x', isFalse);
    });
  });
}
