import 'dart:async';

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
import 'package:hauntagotchi/src/ui/home_controller.dart';
import 'package:hauntagotchi/src/ui/home_screen.dart';
import 'package:hauntagotchi/src/ui/mood_map.dart';

import '../support/fake_clock.dart';

final DateTime _morning = DateTime(2026, 3, 10, 9);
final LocalDay _today = LocalDay(2026, 3, 10);

Habit _habit(String id, {bool doneToday = false}) => Habit(
  id: id,
  name: 'Habit $id',
  createdDay: LocalDay(2026, 3, 1),
  completedDays: doneToday ? <LocalDay>{_today} : const <LocalDay>{},
);

Ghost _aliveGhost() => Ghost(
  name: 'Wisp',
  health: 40,
  lastSettledDay: _today,
  resurrectionCount: 0,
);

Ghost _deadGhost() => Ghost(
  name: 'Wisp',
  health: 0,
  lastSettledDay: _today.previous,
  resurrectionCount: 0,
);

HomeController _controller(
  List<Habit> habits,
  Ghost? ghost, {
  Completer<void>? gate,
}) {
  final MemoryRecordRepository<Habit> habitRepo = MemoryRecordRepository<Habit>(
    codec: const HabitCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  final MemoryRecordRepository<Ghost> ghostRepo = MemoryRecordRepository<Ghost>(
    codec: const GhostCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  return HomeController(
    clock: FakeClock(_morning),
    openStorage: () async {
      if (gate != null) await gate.future;
      for (final Habit h in habits) {
        await habitRepo.put(h.id, h);
      }
      if (ghost != null) {
        await ghostRepo.put(HauntStorage.ghostKey, ghost);
      }
      return HauntStorage(
        habits: habitRepo,
        ghost: ghostRepo,
        isPersistent: true,
      );
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  HomeController controller, {
  bool reduced = false,
}) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: HomeScreen(controller: controller),
    ),
  );
}

Finder _check(String id) => find.descendant(
  of: find.byKey(ValueKey<String>('habit-$id')),
  matching: find.byKey(const ValueKey<String>('habit-check')),
);

GhostLoader _loader(WidgetTester tester) =>
    tester.widget<GhostLoader>(find.byType(GhostLoader));

GhostMood? _mood(WidgetTester tester) => _loader(tester).mood;

GhostMood _steady(WidgetTester tester) =>
    moodFor(tester.widget<GhostPanel>(find.byType(GhostPanel)).state);

/// Pumps [totalMs] in 100 ms steps and returns every mood the loader had.
Future<Set<GhostMood?>> _run(WidgetTester tester, int totalMs) async {
  final Set<GhostMood?> seen = <GhostMood?>{_mood(tester)};
  for (int t = 0; t < totalMs; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
    seen.add(_mood(tester));
  }
  return seen;
}

void main() {
  testWidgets('a stored ghost opens in the steady mood with no reaction', (
    WidgetTester tester,
  ) async {
    final HomeController c = _controller(<Habit>[_habit('a')], _aliveGhost());
    await c.load();
    await _pump(tester, c);
    expect(_mood(tester), _steady(tester));
    expect(_mood(tester), isNot(GhostMood.fed));
    expect(_mood(tester), isNot(GhostMood.rising));
    expect(_loader(tester).reactionKey, 0);
    expect(_loader(tester).onReactionEnd, isNull);
    expect(c.reaction, isNull);

    final HomeController dead = _controller(<Habit>[_habit('a')], _deadGhost());
    await dead.load();
    await _pump(tester, dead);
    expect(_mood(tester), GhostMood.dead);
    expect(_loader(tester).reactionKey, 0);
  });

  testWidgets('a check-off plays fed and then the steady mood returns', (
    WidgetTester tester,
  ) async {
    final HomeController c = _controller(<Habit>[
      _habit('a'),
      _habit('b'),
    ], _aliveGhost());
    await c.load();
    await _pump(tester, c);

    await tester.tap(_check('a'));
    await tester.pump();
    expect(_mood(tester), GhostMood.fed);
    expect(_loader(tester).reactionKey, 1);

    final Set<GhostMood?> seen = await _run(tester, 1500);
    expect(seen, contains(GhostMood.fed));
    expect(_mood(tester), _steady(tester));
  });

  testWidgets('a ritual plays rising once and shows the welcome at once', (
    WidgetTester tester,
  ) async {
    final HomeController c = _controller(<Habit>[
      _habit('a', doneToday: true),
      _habit('b'),
    ], _deadGhost());
    await c.load();
    await _pump(tester, c);
    expect(_mood(tester), GhostMood.dead);

    await tester.tap(_check('b'));
    await tester.pump();
    expect(_mood(tester), GhostMood.rising);
    expect(find.textContaining('Welcome home'), findsOneWidget);

    final Set<GhostMood?> seen = await _run(tester, 2600);
    expect(seen, contains(GhostMood.rising));
    expect(_mood(tester), _steady(tester));
    expect(_mood(tester), isNot(GhostMood.dead));
    expect(find.textContaining('Welcome home'), findsOneWidget);

    // A rebuild with the same controller does not replay.
    await _pump(tester, c);
    await _run(tester, 300);
    expect(_mood(tester), _steady(tester));

    // A foreground refresh does not replay.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect((await _run(tester, 300)), isNot(contains(GhostMood.rising)));

    // A reload does not replay.
    final int keyBeforeLoad = _loader(tester).reactionKey;
    await c.load();
    await tester.pump();
    final Set<GhostMood?> afterLoad = await _run(tester, 600);
    expect(afterLoad, isNot(contains(GhostMood.rising)));
    expect(afterLoad, isNot(contains(GhostMood.fed)));
    expect(_mood(tester), _steady(tester));
    expect(_loader(tester).reactionKey, keyBeforeLoad);
  });

  testWidgets('reduced motion keeps the steady mood in every frame', (
    WidgetTester tester,
  ) async {
    final HomeController feed = _controller(<Habit>[
      _habit('a'),
      _habit('b'),
    ], _aliveGhost());
    await feed.load();
    await _pump(tester, feed, reduced: true);
    final GhostMood before = _steady(tester);
    await tester.tap(_check('a'));
    await tester.pump();
    final GhostMood after = _steady(tester);
    expect(_mood(tester), after);
    final Set<GhostMood?> fedSeen = await _run(tester, 1500);
    expect(fedSeen, <GhostMood?>{after});
    expect(fedSeen, isNot(contains(GhostMood.fed)));
    expect(after, isNotNull);
    expect(before, isNotNull);
    expect(_loader(tester).reactionKey, 0);

    final HomeController ritual = _controller(<Habit>[
      _habit('a', doneToday: true),
      _habit('b'),
    ], _deadGhost());
    await ritual.load();
    await _pump(tester, ritual, reduced: true);
    expect(_mood(tester), GhostMood.dead);
    await tester.tap(_check('b'));
    await tester.pump();
    expect(_mood(tester), _steady(tester));
    expect(find.textContaining('Welcome home'), findsOneWidget);
    final Set<GhostMood?> risingSeen = await _run(tester, 2600);
    expect(risingSeen, <GhostMood?>{_steady(tester)});
    expect(risingSeen, isNot(contains(GhostMood.rising)));
    expect(_loader(tester).reactionKey, 0);
  });

  testWidgets('the panel semantics label is unchanged by reactions', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final HomeController c = _controller(<Habit>[
      _habit('a'),
      _habit('b'),
    ], _aliveGhost());
    await c.load();
    await _pump(tester, c);

    String label() {
      final GhostPanel p = tester.widget<GhostPanel>(find.byType(GhostPanel));
      return GhostPanel.semanticLabel(
        p.ghostName,
        p.health.clamp(0, 100),
        p.state,
      );
    }

    expect(find.bySemanticsLabel(label()), findsOneWidget);
    await tester.tap(_check('a'));
    await tester.pump();
    expect(_mood(tester), GhostMood.fed);
    expect(find.bySemanticsLabel(label()), findsOneWidget);
    await _run(tester, 1500);
    expect(find.bySemanticsLabel(label()), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the loading state shows a loader without a mood', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    final HomeController c = _controller(
      <Habit>[_habit('a')],
      null,
      gate: gate,
    );
    unawaited(c.load());
    await _pump(tester, c);
    expect(find.byType(GhostLoader), findsOneWidget);
    expect(_mood(tester), isNull);
    expect(find.byType(GhostPanel), findsNothing);
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byType(GhostPanel), findsOneWidget);
  });
}
