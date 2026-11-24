import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/seance/revival_band.dart';
import 'package:graveyard/src/domain/seance/revival_step_kind.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_result.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';

SeanceFacts _repo({
  required int dayCount,
  int stars = 10,
  bool described = true,
  bool archived = false,
}) => SeanceFacts(
  dayCount: dayCount,
  archived: archived,
  stars: stars,
  hasDescription: described,
  manual: false,
);

SeanceFacts _manual(int dayCount) => SeanceFacts(
  dayCount: dayCount,
  archived: false,
  stars: 0,
  hasDescription: false,
  manual: true,
);

void _expectResult(
  SeanceFacts facts,
  int score,
  RevivalBand band,
  List<RevivalStepKind> steps,
) {
  final SeanceResult result = SeanceRules.evaluate(facts);
  expect(result.score, score, reason: '$facts');
  expect(result.band, band, reason: '$facts');
  expect(result.steps, steps, reason: '$facts');
}

const List<RevivalStepKind> _skimFixAsk = <RevivalStepKind>[
  RevivalStepKind.skimReadme,
  RevivalStepKind.fixOneThing,
  RevivalStepKind.askAFriend,
];

const List<RevivalStepKind> _updateSkimFix = <RevivalStepKind>[
  RevivalStepKind.updateDependencies,
  RevivalStepKind.skimReadme,
  RevivalStepKind.fixOneThing,
];

void main() {
  group('Worked examples', () {
    test('row 1: 10 stars, described, 30 days', () {
      _expectResult(
        _repo(dayCount: 30),
        80,
        RevivalBand.readyToRise,
        _skimFixAsk,
      );
    });

    test('row 2: 10 stars, described, 182 days', () {
      _expectResult(
        _repo(dayCount: 182),
        56,
        RevivalBand.stirring,
        _skimFixAsk,
      );
    });

    test('row 3: manual grave, 60 days', () {
      _expectResult(_manual(60), 72, RevivalBand.readyToRise, <RevivalStepKind>[
        RevivalStepKind.writeDownPurpose,
        RevivalStepKind.skimReadme,
        RevivalStepKind.fixOneThing,
      ]);
    });

    test('row 4: manual grave, 4,015 days', () {
      _expectResult(_manual(4015), 6, RevivalBand.restless, <RevivalStepKind>[
        RevivalStepKind.writeDownPurpose,
        RevivalStepKind.updateDependencies,
        RevivalStepKind.skimReadme,
      ]);
    });

    test('row 5: flutter/flutter, 0 days, 181,400 stars', () {
      _expectResult(
        _repo(dayCount: 0, stars: 181400),
        86,
        RevivalBand.readyToRise,
        _skimFixAsk,
      );
    });

    test('row 6: atom/atom, archived, 1,095 days, 60,680 stars', () {
      _expectResult(
        _repo(dayCount: 1095, stars: 60680, archived: true),
        15,
        RevivalBand.restless,
        <RevivalStepKind>[
          RevivalStepKind.forkRepository,
          RevivalStepKind.updateDependencies,
          RevivalStepKind.skimReadme,
        ],
      );
    });

    test('row 7: mojombo/grit, 1,095 days, 2,000 stars', () {
      _expectResult(
        _repo(dayCount: 1095, stars: 2000),
        40,
        RevivalBand.stirring,
        _updateSkimFix,
      );
    });

    test('row 8: octocat/Hello-World, no description, 730 days', () {
      _expectResult(
        _repo(dayCount: 730, stars: 4000, described: false),
        44,
        RevivalBand.stirring,
        _updateSkimFix,
      );
    });
  });

  group('Worked example stability', () {
    test('row 1 stays Ready to rise from 28 to 31 days', () {
      for (int days = 28; days <= 31; days++) {
        final SeanceResult result = SeanceRules.evaluate(_repo(dayCount: days));
        expect(result.band, RevivalBand.readyToRise, reason: '$days days');
        expect(result.steps, _skimFixAsk, reason: '$days days');
      }
    });

    test('row 2 stays Stirring from 180 to 184 days', () {
      for (int days = 180; days <= 184; days++) {
        final SeanceResult result = SeanceRules.evaluate(_repo(dayCount: days));
        expect(result.band, RevivalBand.stirring, reason: '$days days');
        expect(result.steps, _skimFixAsk, reason: '$days days');
      }
    });

    test('row 3 stays Ready to rise from 59 to 62 days', () {
      for (int days = 59; days <= 62; days++) {
        final SeanceResult result = SeanceRules.evaluate(_manual(days));
        expect(result.score, 72, reason: '$days days');
        expect(result.band, RevivalBand.readyToRise, reason: '$days days');
      }
    });
  });
}
