import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ritual_progress.dart';
import 'package:hauntagotchi/src/ui/haunt_copy.dart';
import 'package:hauntagotchi/src/ui/resurrection_panel.dart';

Widget _wrap(RitualProgress? ritual, int count) => MaterialApp(
  theme: CoffinTheme.dark(),
  home: Scaffold(
    body: ResurrectionPanel(
      ghostName: 'Boo',
      ritual: ritual,
      resurrectionCount: count,
    ),
  ),
);

void main() {
  testWidgets('names the ghost, shows progress and count', (tester) async {
    await tester.pumpWidget(_wrap(const RitualProgress(done: 1, needed: 2), 3));
    expect(find.text('Boo'), findsOneWidget);
    expect(find.text(HauntCopy.ritualText('Boo', 2)), findsOneWidget);
    expect(find.text('1 of 2 candles lit'), findsOneWidget);
    expect(find.text(HauntCopy.resurrectionCount(3)), findsOneWidget);
  });

  testWidgets('asks for a habit when ritual progress is null', (tester) async {
    await tester.pumpWidget(_wrap(null, 0));
    expect(find.text(HauntCopy.addHabitToBeginRitual), findsOneWidget);
    expect(find.textContaining('candles lit'), findsNothing);
    expect(find.text(HauntCopy.resurrectionCount(0)), findsOneWidget);
  });

  testWidgets('exposes one semantic label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const RitualProgress(done: 0, needed: 1), 1));
    expect(
      find.bySemanticsLabel(
        'Boo. ${HauntCopy.candleProgress(0, 1)}. '
        '${HauntCopy.resurrectionCount(1)}',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
