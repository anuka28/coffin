import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_rejection.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/ui/archive_dialog.dart';
import 'package:hauntagotchi/src/ui/habit_tile.dart';
import 'package:hauntagotchi/src/ui/haunt_copy.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';
import 'package:hauntagotchi/src/ui/home_screen.dart';
import 'package:hauntagotchi/src/ui/resurrection_panel.dart';

import '../support/fake_clock.dart';

final DateTime _morning = DateTime(2026, 3, 10, 9);
final LocalDay _today = LocalDay(2026, 3, 10);

Habit _habit(String id, {bool doneToday = false}) => Habit(
  id: id,
  name: 'Habit $id',
  createdDay: LocalDay(2026, 3, 1),
  completedDays: doneToday ? <LocalDay>{_today} : const <LocalDay>{},
);

Ghost _deadGhost() => Ghost(
  name: 'Wisp',
  health: 0,
  lastSettledDay: _today.previous,
  resurrectionCount: 0,
);

Future<HomeController> _load({
  List<Habit> habits = const <Habit>[],
  Ghost? ghost,
}) async {
  final MemoryRecordRepository<Habit> habitRepo = MemoryRecordRepository<Habit>(
    codec: const HabitCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  final MemoryRecordRepository<Ghost> ghostRepo = MemoryRecordRepository<Ghost>(
    codec: const GhostCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  for (final Habit h in habits) {
    await habitRepo.put(h.id, h);
  }
  if (ghost != null) {
    await ghostRepo.put(HauntStorage.ghostKey, ghost);
  }
  final HomeController c = HomeController(
    clock: FakeClock(_morning),
    openStorage: () async =>
        HauntStorage(habits: habitRepo, ghost: ghostRepo, isPersistent: true),
  );
  await c.load();
  return c;
}

Future<void> _pump(WidgetTester tester, HomeController controller) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 1600),
          disableAnimations: true,
        ),
        child: HomeScreen(controller: controller),
      ),
    ),
  );
}

Finder _check(String id) => find.descendant(
  of: find.byKey(ValueKey<String>('habit-$id')),
  matching: find.byKey(const ValueKey<String>('habit-check')),
);

Finder _menu(String id) => find.descendant(
  of: find.byKey(ValueKey<String>('habit-$id')),
  matching: find.byKey(const ValueKey<String>('habit-menu')),
);

int _health(WidgetTester tester) {
  final Text t = tester.widget<Text>(find.textContaining('Health '));
  return int.parse(RegExp(r'Health (\d+)').firstMatch(t.data!)!.group(1)!);
}

Finder _addButton() => find.ancestor(
  of: find.text(HauntCopy.addHabit),
  matching: find.byWidgetPredicate((Widget w) => w is ButtonStyleButton),
);

void main() {
  testWidgets('check-off and undo update health, state and streak', (
    WidgetTester tester,
  ) async {
    final HomeController c = await _load(
      habits: <Habit>[_habit('a'), _habit('b'), _habit('c')],
      ghost: Ghost(
        name: 'Wisp',
        health: 40,
        lastSettledDay: _today,
        resurrectionCount: 0,
      ),
    );
    await _pump(tester, c);
    final int before = _health(tester);
    expect(find.textContaining('No streak yet'), findsOneWidget);
    expect(
      find.bySemanticsLabel(HabitTile.checkLabel('Habit a', false)),
      findsOneWidget,
    );

    await tester.tap(_check('a'));
    await tester.pumpAndSettle();
    expect(_health(tester), greaterThan(before));
    expect(find.text('Streak: 1 day'), findsOneWidget);
    expect(
      find.bySemanticsLabel(HabitTile.checkLabel('Habit a', true)),
      findsOneWidget,
    );

    await tester.tap(_check('a'));
    await tester.pumpAndSettle();
    expect(_health(tester), before);
    expect(find.textContaining('No streak yet'), findsOneWidget);
    expect(
      find.bySemanticsLabel(HabitTile.checkLabel('Habit a', false)),
      findsOneWidget,
    );
  });

  testWidgets('the add control is disabled with a reason at five habits', (
    WidgetTester tester,
  ) async {
    final HomeController c = await _load(
      habits: <Habit>[for (final String id in 'abcde'.split('')) _habit(id)],
    );
    await _pump(tester, c);
    expect(tester.widget<ButtonStyleButton>(_addButton()).onPressed, isNull);
    expect(find.text(HauntCopy.addLimitReason), findsOneWidget);

    await tester.tap(_addButton(), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the add control is enabled with room and adds a habit', (
    WidgetTester tester,
  ) async {
    final HomeController c = await _load(habits: <Habit>[_habit('a')]);
    await _pump(tester, c);
    expect(tester.widget<ButtonStyleButton>(_addButton()).onPressed, isNotNull);
    expect(find.text(HauntCopy.addLimitReason), findsNothing);

    await tester.tap(_addButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Drink water  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Drink water'), findsOneWidget);
    expect(find.byType(HabitTile), findsNWidgets(2));
  });

  testWidgets('an invalid name keeps the text and shows the reason', (
    WidgetTester tester,
  ) async {
    final HomeController c = await _load(habits: <Habit>[_habit('a')]);
    await _pump(tester, c);
    await tester.tap(_addButton());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text(HauntCopy.rejectionReason(HabitRejection.nameEmpty)),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '   ',
    );

    final String tooLong = 'x' * 41;
    await tester.enterText(find.byType(TextField), tooLong);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(
      find.text(HauntCopy.rejectionReason(HabitRejection.nameTooLong)),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      tooLong,
    );
    expect(find.byType(HabitTile), findsOneWidget);
  });

  testWidgets('archiving needs confirmation and keeping leaves the habit', (
    WidgetTester tester,
  ) async {
    final HomeController c = await _load(
      habits: <Habit>[_habit('a'), _habit('b')],
    );
    await _pump(tester, c);

    await tester.tap(_menu('a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveDialog), findsOneWidget);
    expect(find.byType(HabitTile), findsNWidgets(2));

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveDialog), findsNothing);
    expect(find.text('Habit a'), findsOneWidget);

    await tester.tap(_menu('a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveDialog), findsNothing);
    expect(find.text('Habit a'), findsNothing);
    expect(find.byType(HabitTile), findsOneWidget);
  });

  testWidgets('renaming changes the name and refuses an invalid one', (
    WidgetTester tester,
  ) async {
    final HomeController c = await _load(habits: <Habit>[_habit('a')]);
    await _pump(tester, c);

    await tester.tap(_menu('a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Habit a',
    );

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(
      find.text(HauntCopy.rejectionReason(HabitRejection.nameEmpty)),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Stretch');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Habit a'), findsNothing);
  });

  testWidgets('a dead ghost keeps the list usable and check-off resurrects', (
    WidgetTester tester,
  ) async {
    final HomeController c = await _load(
      habits: <Habit>[_habit('a', doneToday: true), _habit('b')],
      ghost: _deadGhost(),
    );
    await _pump(tester, c);
    expect(find.byType(ResurrectionPanel), findsOneWidget);
    expect(find.byType(HabitTile), findsNWidgets(2));
    expect(tester.widget<ButtonStyleButton>(_addButton()).onPressed, isNotNull);

    // Undo and check again: the list answers while the ghost is dead.
    await tester.tap(_check('a'));
    await tester.pumpAndSettle();
    expect(find.text(HauntCopy.candleProgress(0, 2)), findsOneWidget);
    await tester.tap(_check('a'));
    await tester.pumpAndSettle();
    expect(find.text(HauntCopy.candleProgress(1, 2)), findsOneWidget);

    await tester.tap(_check('b'));
    await tester.pumpAndSettle();
    expect(find.byType(ResurrectionPanel), findsNothing);
    expect(find.textContaining('Welcome home'), findsOneWidget);
    expect(_health(tester), greaterThan(0));
  });
}
