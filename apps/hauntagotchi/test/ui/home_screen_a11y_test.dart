import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/ui/ghost_panel.dart';
import 'package:hauntagotchi/src/ui/habit_tile.dart';
import 'package:hauntagotchi/src/ui/haunt_copy.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';
import 'package:hauntagotchi/src/ui/home_screen.dart';

import '../support/fake_clock.dart';

final DateTime _morning = DateTime(2026, 3, 10, 9);
final LocalDay _today = LocalDay(2026, 3, 10);

Habit _habit(String id, {String? name}) => Habit(
  id: id,
  name: name ?? 'Habit $id',
  createdDay: LocalDay(2026, 3, 1),
  completedDays: const <LocalDay>{},
);

Future<HomeController> _load({
  required List<Habit> habits,
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

Future<void> _pump(
  WidgetTester tester,
  HomeController controller, {
  double width = 360,
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = Size(width, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: HomeScreen(controller: controller),
    ),
  );
  await tester.pump();
}

Ghost _ghost(int health) => Ghost(
  name: 'Wisp',
  health: health,
  lastSettledDay: _today,
  resurrectionCount: 0,
);

List<Habit> _fiveHabits() => <Habit>[
  for (final String id in 'abcde'.split(''))
    _habit(id, name: 'A rather long habit name no. $id to wrap'),
];

void main() {
  group('layout', () {
    testWidgets('no overflow at 360 px and text scale 1.5', (
      WidgetTester tester,
    ) async {
      final HomeController c = await _load(
        habits: _fiveHabits(),
        ghost: _ghost(60),
      );
      await _pump(tester, c, textScale: 1.5);
      expect(tester.takeException(), isNull);
      expect(find.byType(HabitTile), findsWidgets);
    });

    testWidgets('no overflow in the dead state at 360 px and scale 1.5', (
      WidgetTester tester,
    ) async {
      final HomeController c = await _load(
        habits: _fiveHabits(),
        ghost: _ghost(0),
      );
      await _pump(tester, c, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow with no habits at 360 px and scale 1.5', (
      WidgetTester tester,
    ) async {
      final HomeController c = await _load(habits: const <Habit>[]);
      await _pump(tester, c, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });
  });

  group('tap targets', () {
    testWidgets('check, menu and add controls are at least 48 by 48', (
      WidgetTester tester,
    ) async {
      final HomeController c = await _load(
        habits: <Habit>[_habit('a'), _habit('b')],
        ghost: _ghost(60),
      );
      await _pump(tester, c);

      final List<Finder> targets = <Finder>[
        for (final String id in <String>['a', 'b']) ...<Finder>[
          find.descendant(
            of: find.byKey(ValueKey<String>('habit-$id')),
            matching: find.byKey(const ValueKey<String>('habit-check')),
          ),
          find.descendant(
            of: find.byKey(ValueKey<String>('habit-$id')),
            matching: find.byKey(const ValueKey<String>('habit-menu')),
          ),
        ],
        find.ancestor(
          of: find.text(HauntCopy.addHabit),
          matching: find.byWidgetPredicate(
            (Widget w) => w is ButtonStyleButton,
          ),
        ),
      ];
      for (final Finder f in targets) {
        expect(f, findsOneWidget);
        final Size size = tester.getSize(f);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('semantics', () {
    testWidgets('check-off controls and the ghost area carry labels', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final HomeController c = await _load(
        habits: <Habit>[_habit('a')],
        ghost: _ghost(60),
      );
      await _pump(tester, c);

      expect(
        find.bySemanticsLabel(HabitTile.checkLabel('Habit a', false)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Wisp, health \d+ of 100, \w+$')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('state without color', () {
    testWidgets('the state shows as a word and an icon', (
      WidgetTester tester,
    ) async {
      final HomeController c = await _load(
        habits: <Habit>[_habit('a')],
        ghost: _ghost(60),
      );
      await _pump(tester, c);

      final GhostPanel panel = tester.widget<GhostPanel>(
        find.byType(GhostPanel),
      );
      expect(find.text(HauntCopy.stateWord(panel.state)), findsOneWidget);
      expect(find.byIcon(GhostPanel.iconFor(panel.state)), findsOneWidget);
    });
  });

  group('reduced motion', () {
    testWidgets('disableAnimations gives the still GhostLoader frame', (
      WidgetTester tester,
    ) async {
      final HomeController c = await _load(
        habits: <Habit>[_habit('a')],
        ghost: _ghost(60),
      );
      await _pump(tester, c, disableAnimations: true);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GhostLoader), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GhostLoader),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('with motion allowed the GhostLoader animates', (
      WidgetTester tester,
    ) async {
      final HomeController c = await _load(
        habits: <Habit>[_habit('a')],
        ghost: _ghost(60),
      );
      await _pump(tester, c);

      expect(
        find.descendant(
          of: find.byType(GhostLoader),
          matching: find.byType(AnimatedBuilder),
        ),
        findsWidgets,
      );
    });
  });
}
