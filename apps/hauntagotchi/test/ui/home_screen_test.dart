import 'dart:async';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/ui/empty_habits_panel.dart';
import 'package:hauntagotchi/src/ui/habit_tile.dart';
import 'package:hauntagotchi/src/ui/haunt_copy.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';
import 'package:hauntagotchi/src/ui/home_screen.dart';
import 'package:hauntagotchi/src/ui/load_error_view.dart';
import 'package:hauntagotchi/src/ui/memory_notice.dart';
import 'package:hauntagotchi/src/ui/resurrection_panel.dart';
import 'package:hauntagotchi/src/ui/save_error_banner.dart';

import '../support/fake_clock.dart';
import '../support/throwing_record_repository.dart';

final DateTime _morning = DateTime(2026, 3, 10, 9);
final LocalDay _today = LocalDay(2026, 3, 10);

/// The in-memory repositories behind a test controller, so a test can make
/// reads or writes fail.
class _Rig {
  _Rig({List<Habit> habits = const <Habit>[], Ghost? ghost})
    : habits = ThrowingRecordRepository<Habit>(
        MemoryRecordRepository<Habit>(
          codec: const HabitCodec(),
          currentVersion: HauntStorage.currentVersion,
        ),
      ),
      ghost = ThrowingRecordRepository<Ghost>(
        MemoryRecordRepository<Ghost>(
          codec: const GhostCodec(),
          currentVersion: HauntStorage.currentVersion,
        ),
      ),
      _seedHabits = habits,
      _seedGhost = ghost;

  final ThrowingRecordRepository<Habit> habits;
  final ThrowingRecordRepository<Ghost> ghost;
  final List<Habit> _seedHabits;
  final Ghost? _seedGhost;

  Future<void> seed() async {
    for (final Habit h in _seedHabits) {
      await habits.put(h.id, h);
    }
    final Ghost? g = _seedGhost;
    if (g != null) {
      await ghost.put(HauntStorage.ghostKey, g);
    }
  }

  HomeController controller({bool persistent = true, Completer<void>? gate}) {
    return HomeController(
      clock: FakeClock(_morning),
      openStorage: () async {
        if (gate != null) await gate.future;
        await seed();
        return HauntStorage(
          habits: habits,
          ghost: ghost,
          isPersistent: persistent,
        );
      },
    );
  }
}

Habit _habit(String id, {bool doneToday = false, LocalDay? archivedDay}) =>
    Habit(
      id: id,
      name: 'Habit $id',
      createdDay: LocalDay(2026, 3, 1),
      completedDays: doneToday ? <LocalDay>{_today} : const <LocalDay>{},
      archivedDay: archivedDay,
    );

Ghost _deadGhost({int resurrections = 0}) => Ghost(
  name: 'Wisp',
  health: 0,
  lastSettledDay: _today.previous,
  resurrectionCount: resurrections,
);

Future<void> _pump(WidgetTester tester, HomeController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 1200),
          disableAnimations: true,
        ),
        child: HomeScreen(controller: controller),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a loader while loading', (WidgetTester tester) async {
    final Completer<void> gate = Completer<void>();
    final HomeController c = _Rig().controller(gate: gate);
    unawaited(c.load());
    await _pump(tester, c);
    expect(find.byType(GhostLoader), findsOneWidget);
    expect(find.byType(HabitTile), findsNothing);
    expect(find.byType(MemoryNotice), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(EmptyHabitsPanel), findsOneWidget);
  });

  testWidgets('shows the empty panel with no habits', (
    WidgetTester tester,
  ) async {
    final HomeController c = _Rig().controller();
    await c.load();
    await _pump(tester, c);
    expect(find.byType(EmptyHabitsPanel), findsOneWidget);
    expect(find.text(HauntCopy.emptyTitle), findsOneWidget);
    expect(find.byType(HabitTile), findsNothing);
  });

  testWidgets('shows the empty panel when only archived habits exist', (
    WidgetTester tester,
  ) async {
    final HomeController c = _Rig(
      habits: <Habit>[_habit('a', archivedDay: LocalDay(2026, 3, 5))],
    ).controller();
    await c.load();
    await _pump(tester, c);
    expect(find.byType(EmptyHabitsPanel), findsOneWidget);
    expect(find.byType(HabitTile), findsNothing);
    expect(find.text('Habit a'), findsNothing);
  });

  testWidgets('shows the ghost, habits and add control when normal', (
    WidgetTester tester,
  ) async {
    final HomeController c = _Rig(
      habits: <Habit>[_habit('a'), _habit('b', doneToday: true), _habit('c')],
    ).controller();
    await c.load();
    await _pump(tester, c);
    expect(find.byType(HabitTile), findsNWidgets(3));
    expect(find.text('Habit a'), findsOneWidget);
    expect(find.text(HauntCopy.addHabit), findsOneWidget);
    expect(find.byType(ResurrectionPanel), findsNothing);
    expect(find.byType(EmptyHabitsPanel), findsNothing);
    expect(find.byType(SaveErrorBanner), findsNothing);
    expect(find.textContaining('Health '), findsOneWidget);
  });

  testWidgets('shows the nudge below three habits and hides it at three', (
    WidgetTester tester,
  ) async {
    final HomeController two = _Rig(habits: <Habit>[_habit('a'), _habit('b')])
        .controller();
    await two.load();
    await _pump(tester, two);
    expect(find.text(HauntCopy.nudge(1)), findsOneWidget);

    final HomeController one = _Rig(habits: <Habit>[_habit('a')]).controller();
    await one.load();
    await _pump(tester, one);
    expect(find.text(HauntCopy.nudge(2)), findsOneWidget);

    final HomeController three = _Rig(
      habits: <Habit>[_habit('a'), _habit('b'), _habit('c')],
    ).controller();
    await three.load();
    await _pump(tester, three);
    expect(find.textContaining('more habit'), findsNothing);
  });

  testWidgets('shows the ritual with progress and the resurrection count', (
    WidgetTester tester,
  ) async {
    final HomeController c = _Rig(
      habits: <Habit>[_habit('a', doneToday: true), _habit('b')],
      ghost: _deadGhost(resurrections: 2),
    ).controller();
    await c.load();
    await _pump(tester, c);
    expect(find.byType(ResurrectionPanel), findsOneWidget);
    expect(find.text(HauntCopy.candleProgress(1, 2)), findsOneWidget);
    expect(find.text(HauntCopy.resurrectionCount(2)), findsOneWidget);
    expect(find.text(HauntCopy.stateWord(GhostState.dead)), findsOneWidget);
  });

  testWidgets('shows how to begin the ritual when a dead ghost has no habit', (
    WidgetTester tester,
  ) async {
    final HomeController c = _Rig(ghost: _deadGhost()).controller();
    await c.load();
    await _pump(tester, c);
    expect(find.byType(ResurrectionPanel), findsOneWidget);
    expect(find.text(HauntCopy.addHabitToBeginRitual), findsOneWidget);
    expect(find.byType(EmptyHabitsPanel), findsOneWidget);
  });

  testWidgets('shows a dismissable welcome back after the ritual completes', (
    WidgetTester tester,
  ) async {
    final HomeController c = _Rig(
      habits: <Habit>[_habit('a', doneToday: true), _habit('b')],
      ghost: _deadGhost(),
    ).controller();
    await c.load();
    await _pump(tester, c);
    expect(find.byType(ResurrectionPanel), findsOneWidget);
    expect(find.text(HauntCopy.welcomeBackDismiss), findsNothing);

    await c.toggle('b');
    await tester.pumpAndSettle();
    expect(find.byType(ResurrectionPanel), findsNothing);
    expect(find.textContaining('Welcome home'), findsOneWidget);

    await tester.tap(find.text(HauntCopy.welcomeBackDismiss));
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome home'), findsNothing);
  });

  testWidgets('shows the memory notice only when storage is not persistent', (
    WidgetTester tester,
  ) async {
    final HomeController memory = _Rig().controller(persistent: false);
    await memory.load();
    await _pump(tester, memory);
    expect(find.byType(MemoryNotice), findsOneWidget);
    expect(find.text(HauntCopy.memoryNotice), findsOneWidget);

    final HomeController saved = _Rig().controller();
    await saved.load();
    await _pump(tester, saved);
    expect(find.byType(MemoryNotice), findsNothing);
  });

  testWidgets('shows the save error banner and clears it after a retry', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig(habits: <Habit>[_habit('a')]);
    final HomeController c = rig.controller();
    await c.load();
    await _pump(tester, c);
    expect(find.byType(SaveErrorBanner), findsNothing);

    rig.habits.failPut = true;
    await c.toggle('a');
    await tester.pumpAndSettle();
    expect(find.byType(SaveErrorBanner), findsOneWidget);
    expect(find.text(HauntCopy.saveError), findsOneWidget);
    // The change stays visible while saving fails.
    expect(find.byType(HabitTile), findsOneWidget);

    rig.habits.failPut = false;
    await tester.tap(find.text(HauntCopy.retry));
    await tester.pumpAndSettle();
    expect(find.byType(SaveErrorBanner), findsNothing);
  });

  testWidgets('shows the load error and recovers on retry', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig(habits: <Habit>[_habit('a')]);
    rig.habits.failReads = true;
    final HomeController c = rig.controller();
    await c.load();
    await _pump(tester, c);
    expect(find.byType(LoadErrorView), findsOneWidget);
    expect(find.text(HauntCopy.loadError), findsOneWidget);
    expect(find.byType(HabitTile), findsNothing);

    rig.habits.failReads = false;
    await tester.tap(find.text(HauntCopy.retry));
    await tester.pumpAndSettle();
    expect(find.byType(LoadErrorView), findsNothing);
    expect(find.byType(HabitTile), findsOneWidget);
  });
}
