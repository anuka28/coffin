import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/ui/empty_habits_panel.dart';
import 'package:hauntagotchi/src/ui/haunt_copy.dart';

void main() {
  testWidgets('shows the invitation and calls onAdd', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoffinTheme.dark(),
        home: Scaffold(body: EmptyHabitsPanel(onAdd: () => taps++)),
      ),
    );
    expect(find.text(HauntCopy.emptyTitle), findsOneWidget);
    expect(find.text(HauntCopy.emptyInvitation), findsOneWidget);
    await tester.tap(find.text(HauntCopy.addHabit));
    expect(taps, 1);
  });

  testWidgets('button is at least 48x48 and labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoffinTheme.dark(),
        home: Scaffold(body: EmptyHabitsPanel(onAdd: () {})),
      ),
    );
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel(HauntCopy.addHabit), findsOneWidget);
    handle.dispose();
  });
}
