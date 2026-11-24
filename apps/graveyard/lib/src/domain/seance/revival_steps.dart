import 'revival_step_kind.dart';
import 'seance_facts.dart';

/// Chooses the three revival step kinds of a séance.
abstract final class RevivalSteps {
  /// The fixed general kinds, tried in this order to fill remaining places.
  static const List<RevivalStepKind> generalKinds = <RevivalStepKind>[
    RevivalStepKind.skimReadme,
    RevivalStepKind.fixOneThing,
    RevivalStepKind.askAFriend,
    RevivalStepKind.addOneTest,
  ];

  /// Chooses exactly three distinct kinds for [facts]: condition kinds first
  /// (archived, manual, old), then general kinds in fixed order.
  static List<RevivalStepKind> choose(SeanceFacts facts) {
    final List<RevivalStepKind> conditionKinds = <RevivalStepKind>[
      if (facts.archived) RevivalStepKind.forkRepository,
      if (facts.manual) RevivalStepKind.writeDownPurpose,
      if (facts.dayCount > 365) RevivalStepKind.updateDependencies,
    ];
    final List<RevivalStepKind> chosen = conditionKinds.take(3).toList();
    for (final RevivalStepKind kind in generalKinds) {
      if (chosen.length == 3) break;
      if (!chosen.contains(kind)) chosen.add(kind);
    }
    return chosen;
  }
}
