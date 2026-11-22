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
import 'package:hauntagotchi/src/ui/habit_tile.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';
import 'package:hauntagotchi/src/ui/home_screen.dart';
import 'package:hauntagotchi/src/ui/voice_controller.dart';
import 'package:hauntagotchi/src/ui/voice_copy.dart';
import 'package:hauntagotchi/src/ui/voice_panel.dart';

import '../support/fake_clock.dart';
import '../support/scripted_voice_ai.dart';

final LocalDay _today = LocalDay(2026, 3, 10);

class _Rig {
  _Rig(this.home, this.voice, this.habits);

  final HomeController home;
  final VoiceController voice;
  final MemoryRecordRepository<Habit> habits;
}

Future<_Rig> _rig(ScriptedVoiceAi ai) async {
  final MemoryRecordRepository<Habit> habits = MemoryRecordRepository<Habit>(
    codec: const HabitCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  final MemoryRecordRepository<Ghost> ghost = MemoryRecordRepository<Ghost>(
    codec: const GhostCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  for (final String id in <String>['a', 'b']) {
    await habits.put(
      id,
      Habit(id: id, name: 'Habit $id', createdDay: LocalDay(2026, 3, 1)),
    );
  }
  await ghost.put(
    HauntStorage.ghostKey,
    Ghost(
      name: 'Wisp',
      health: 60,
      lastSettledDay: _today,
      resurrectionCount: 0,
    ),
  );
  final HomeController home = HomeController(
    clock: FakeClock(DateTime(2026, 3, 10, 9)),
    openStorage: () async =>
        HauntStorage(habits: habits, ghost: ghost, isPersistent: true),
  );
  await home.load();
  final VoiceController voice = VoiceController(home: home, ai: ai);
  addTearDown(() {
    voice.dispose();
    home.dispose();
  });
  return _Rig(home, voice, habits);
}

Future<void> _pump(
  WidgetTester tester,
  HomeController home,
  VoiceController? voice, {
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: HomeScreen(controller: home, voice: voice),
    ),
  );
  await _settle(tester);
}

/// Lets scripted answers and saves finish, with explicit pumps only.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _check(String id) => find.descendant(
  of: find.byKey(ValueKey<String>('habit-$id')),
  matching: find.byKey(const ValueKey<String>('habit-check')),
);

Future<bool> _savedDone(_Rig rig, String id) async {
  final Habit? habit = await rig.habits.get(id);
  return habit!.isCompletedOn(_today);
}

void main() {
  testWidgets('the panel sits under the ghost panel and above the habits', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _rig(ScriptedVoiceAi().replyWith('Hello there.'));
    await _pump(tester, rig.home, rig.voice);

    expect(find.byType(VoicePanel), findsOneWidget);
    expect(find.text('Hello there.'), findsOneWidget);
    final double ghostBottom = tester
        .getBottomLeft(find.byKey(const ValueKey<String>('ghost-panel')))
        .dy;
    final double panelTop = tester.getTopLeft(find.byType(VoicePanel)).dy;
    final double panelBottom = tester.getBottomLeft(find.byType(VoicePanel)).dy;
    final double habitTop = tester
        .getTopLeft(find.byKey(const ValueKey<String>('habit-a')))
        .dy;
    expect(panelTop, greaterThanOrEqualTo(ghostBottom));
    expect(habitTop, greaterThanOrEqualTo(panelBottom));
  });

  testWidgets('without a voice there is no panel', (WidgetTester tester) async {
    final _Rig rig = await _rig(ScriptedVoiceAi().replyWith('Hello there.'));
    await _pump(tester, rig.home, null);

    expect(find.byType(VoicePanel), findsNothing);
    expect(find.text('Hello there.'), findsNothing);
    expect(find.byKey(const ValueKey<String>('habit-a')), findsOneWidget);
  });

  testWidgets('a check-off updates the line and saves', (
    WidgetTester tester,
  ) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi()
        .replyWith('Hello there.')
        .replyWith('Tasty.');
    final _Rig rig = await _rig(ai);
    await _pump(tester, rig.home, rig.voice);

    await tester.tap(_check('a'));
    await _settle(tester);

    expect(ai.callCount, 2);
    expect(find.text('Tasty.'), findsOneWidget);
    expect(find.text('Hello there.'), findsNothing);
    expect(await _savedDone(rig, 'a'), isTrue);
  });

  testWidgets('habits stay usable while the AI is pending', (
    WidgetTester tester,
  ) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi().replyWith('Hello there.');
    final Completer<String> slow = ai.replyLater();
    ai.replyWith('Second.');
    final _Rig rig = await _rig(ai);
    await _pump(tester, rig.home, rig.voice);

    await tester.tap(_check('a'));
    await _settle(tester);
    expect(find.text('Hello there.'), findsOneWidget);
    expect(await _savedDone(rig, 'a'), isTrue);

    await tester.tap(_check('b'));
    await _settle(tester);
    expect(await _savedDone(rig, 'b'), isTrue);
    expect(find.text('Second.'), findsOneWidget);

    slow.complete('Too late.');
    await _settle(tester);
    expect(find.text('Too late.'), findsNothing);
    expect(find.text('Second.'), findsOneWidget);
  });

  testWidgets('a throwing AI shows the safe line and keeps habits usable', (
    WidgetTester tester,
  ) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi()
        .replyWith('Hello there.')
        .failWith(StateError('boom'))
        .failWith(StateError('boom again'));
    final _Rig rig = await _rig(ai);
    await _pump(tester, rig.home, rig.voice);

    await tester.tap(_check('a'));
    await _settle(tester);
    expect(find.text(VoiceCopy.safeLine), findsOneWidget);
    expect(await _savedDone(rig, 'a'), isTrue);

    await tester.tap(_check('b'));
    await _settle(tester);
    expect(await _savedDone(rig, 'b'), isTrue);
    expect(find.text(VoiceCopy.safeLine), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rebuild, rename, archive and add leave the line alone', (
    WidgetTester tester,
  ) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi().replyWith('Hello there.');
    final _Rig rig = await _rig(ai);
    await _pump(tester, rig.home, rig.voice);
    expect(ai.callCount, 1);

    await _pump(tester, rig.home, rig.voice, width: 400);
    expect(ai.callCount, 1);
    expect(find.text('Hello there.'), findsOneWidget);

    await rig.home.renameHabit('a', 'Stretch');
    await _settle(tester);
    await rig.home.addHabit('Read a page');
    await _settle(tester);
    await rig.home.archiveHabit('b');
    await _settle(tester);

    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Read a page'), findsOneWidget);
    expect(find.text('Habit b'), findsNothing);
    expect(ai.callCount, 1);
    expect(rig.voice.line, 'Hello there.');
    expect(find.text('Hello there.'), findsOneWidget);
  });

  testWidgets('the ghost panel semantics are unchanged', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final _Rig rig = await _rig(ScriptedVoiceAi().replyWith('Hello there.'));
    await _pump(tester, rig.home, rig.voice);

    expect(
      find.bySemanticsLabel(RegExp(r'^Wisp, health \d+ of 100, \w+$')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(HabitTile.checkLabel('Habit a', false)),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final double width in <double>[320, 360, 1280]) {
    testWidgets('no overflow at ${width.toInt()} px', (
      WidgetTester tester,
    ) async {
      final String longLine = '${'A' * 40} ${'b' * 39}';
      final _Rig rig = await _rig(ScriptedVoiceAi().replyWith(longLine));
      await _pump(tester, rig.home, rig.voice, width: width);

      expect(find.text(longLine), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
