import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/ui/ghost_panel.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    GhostState state = GhostState.thriving,
    int health = 85,
    int streak = 3,
    bool disableAnimations = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: CoffinTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: Scaffold(
          body: GhostPanel(
            ghostName: 'Wisp',
            health: health,
            state: state,
            streak: streak,
          ),
        ),
      ),
    );
  }

  testWidgets('shows name, health, state word and streak', (tester) async {
    await pump(tester);

    expect(find.byType(GhostLoader), findsOneWidget);
    expect(find.text('Wisp'), findsOneWidget);
    expect(find.text('Health 85 / 100'), findsOneWidget);
    expect(find.text('Thriving'), findsOneWidget);
    expect(find.text('Streak: 3 days'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('exposes one semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(
      find.bySemanticsLabel('Wisp, health 85 of 100, thriving'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Health 85')), findsNothing);
    handle.dispose();
  });

  testWidgets('each state has its own icon', (tester) async {
    final icons = {for (final s in GhostState.values) GhostPanel.iconFor(s)};
    expect(icons.length, GhostState.values.length);

    await pump(tester, state: GhostState.hungry, health: 30);
    expect(find.byIcon(GhostPanel.iconFor(GhostState.hungry)), findsOneWidget);
    expect(find.text('Hungry'), findsOneWidget);
  });

  testWidgets('streak line handles zero and one', (tester) async {
    expect(GhostPanel.streakLine(1), 'Streak: 1 day');
    await pump(tester, streak: 0);
    expect(find.textContaining('No streak yet'), findsOneWidget);
  });

  testWidgets('settles with animations disabled', (tester) async {
    await pump(tester, disableAnimations: true);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
