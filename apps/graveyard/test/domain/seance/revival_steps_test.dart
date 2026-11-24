import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/seance/revival_step_kind.dart';
import 'package:graveyard/src/domain/seance/revival_steps.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';

SeanceFacts _facts({
  int dayCount = 0,
  bool archived = false,
  bool manual = false,
}) => SeanceFacts(
  dayCount: dayCount,
  archived: archived,
  stars: 0,
  hasDescription: false,
  manual: manual,
);

void main() {
  group('RevivalSteps.repositoryOnlyKinds', () {
    test('is exactly skimReadme and forkRepository', () {
      expect(RevivalSteps.repositoryOnlyKinds, <RevivalStepKind>{
        RevivalStepKind.skimReadme,
        RevivalStepKind.forkRepository,
      });
    });
  });

  group('RevivalSteps.choose', () {
    test('no conditions gives the first three general kinds', () {
      expect(RevivalSteps.choose(_facts()), <RevivalStepKind>[
        RevivalStepKind.skimReadme,
        RevivalStepKind.fixOneThing,
        RevivalStepKind.askAFriend,
      ]);
      expect(
        RevivalSteps.choose(_facts()),
        RevivalSteps.generalKinds.take(3).toList(),
      );
    });

    test('archived comes first', () {
      expect(RevivalSteps.choose(_facts(archived: true)), <RevivalStepKind>[
        RevivalStepKind.forkRepository,
        RevivalStepKind.skimReadme,
        RevivalStepKind.fixOneThing,
      ]);
    });

    test('manual comes first and skips the repository-only fill', () {
      expect(RevivalSteps.choose(_facts(manual: true)), <RevivalStepKind>[
        RevivalStepKind.writeDownPurpose,
        RevivalStepKind.fixOneThing,
        RevivalStepKind.askAFriend,
      ]);
    });

    test('old comes first', () {
      expect(RevivalSteps.choose(_facts(dayCount: 1000)), <RevivalStepKind>[
        RevivalStepKind.updateDependencies,
        RevivalStepKind.skimReadme,
        RevivalStepKind.fixOneThing,
      ]);
    });

    test('archived and manual: a manual Grave never gets forkRepository', () {
      expect(
        RevivalSteps.choose(_facts(archived: true, manual: true)),
        <RevivalStepKind>[
          RevivalStepKind.writeDownPurpose,
          RevivalStepKind.fixOneThing,
          RevivalStepKind.askAFriend,
        ],
      );
    });

    test('archived and old keep priority order, then fill', () {
      expect(
        RevivalSteps.choose(_facts(archived: true, dayCount: 1000)),
        <RevivalStepKind>[
          RevivalStepKind.forkRepository,
          RevivalStepKind.updateDependencies,
          RevivalStepKind.skimReadme,
        ],
      );
    });

    test('manual and old keep priority order, then fill', () {
      expect(
        RevivalSteps.choose(_facts(manual: true, dayCount: 1000)),
        <RevivalStepKind>[
          RevivalStepKind.writeDownPurpose,
          RevivalStepKind.updateDependencies,
          RevivalStepKind.fixOneThing,
        ],
      );
    });

    test('two calls give equal lists', () {
      final SeanceFacts facts = _facts(dayCount: 400, archived: true);
      expect(RevivalSteps.choose(facts), RevivalSteps.choose(facts));
    });

    test('archived, manual and old: manual drops forkRepository', () {
      expect(
        RevivalSteps.choose(
          _facts(dayCount: 1000, archived: true, manual: true),
        ),
        <RevivalStepKind>[
          RevivalStepKind.writeDownPurpose,
          RevivalStepKind.updateDependencies,
          RevivalStepKind.fixOneThing,
        ],
      );
    });

    test('non-manual archived and old keeps all repository kinds', () {
      expect(
        RevivalSteps.choose(_facts(dayCount: 1000, archived: true)),
        <RevivalStepKind>[
          RevivalStepKind.forkRepository,
          RevivalStepKind.updateDependencies,
          RevivalStepKind.skimReadme,
        ],
      );
    });

    test('a manual Grave never gets a repository-only kind', () {
      for (final bool a in <bool>[false, true]) {
        for (final int d in <int>[0, 365, 366, 4015]) {
          final List<RevivalStepKind> steps = RevivalSteps.choose(
            _facts(dayCount: d, archived: a, manual: true),
          );
          expect(steps, isNot(contains(RevivalStepKind.skimReadme)));
          expect(steps, isNot(contains(RevivalStepKind.forkRepository)));
        }
      }
    });

    test('dayCount 365 is not old, 366 is', () {
      expect(
        RevivalSteps.choose(_facts(dayCount: 365)),
        isNot(contains(RevivalStepKind.updateDependencies)),
      );
      expect(
        RevivalSteps.choose(_facts(dayCount: 366)).first,
        RevivalStepKind.updateDependencies,
      );
    });

    test('always three distinct kinds', () {
      for (final bool a in <bool>[false, true]) {
        for (final bool m in <bool>[false, true]) {
          for (final int d in <int>[0, 365, 366]) {
            final List<RevivalStepKind> steps = RevivalSteps.choose(
              _facts(dayCount: d, archived: a, manual: m),
            );
            expect(steps, hasLength(3));
            expect(steps.toSet(), hasLength(3));
          }
        }
      }
    });
  });
}
