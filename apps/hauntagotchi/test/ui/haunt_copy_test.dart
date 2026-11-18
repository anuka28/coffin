import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/habit_rejection.dart';
import 'package:hauntagotchi/src/ui/haunt_copy.dart';

void main() {
  final strings = <String>[
    for (final state in GhostState.values) HauntCopy.stateWord(state),
    for (final rejection in HabitRejection.values)
      HauntCopy.rejectionReason(rejection),
    for (final n in [0, 1, 2, 5]) ...[
      HauntCopy.nudge(n),
      HauntCopy.ritualText('Boo', n),
      HauntCopy.candleProgress(n, n),
      HauntCopy.resurrectionCount(n),
    ],
    HauntCopy.welcomeBack('Boo'),
    HauntCopy.memoryNotice,
    HauntCopy.saveError,
    HauntCopy.loadError,
    HauntCopy.retry,
    HauntCopy.addHabitToBeginRitual,
    HauntCopy.welcomeBackDismiss,
    HauntCopy.emptyTitle,
    HauntCopy.emptyInvitation,
    HauntCopy.addHabit,
    HauntCopy.addLimitReason,
  ];

  test('no HauntCopy string blames the user', () {
    for (final s in strings) {
      final lower = s.toLowerCase();
      expect(lower.contains('failed'), isFalse, reason: s);
      expect(lower.contains('your fault'), isFalse, reason: s);
    }
  });
}
