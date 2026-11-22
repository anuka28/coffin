import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/main.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';
import 'package:hauntagotchi/src/ui/home_screen.dart';
import 'package:hauntagotchi/src/ui/voice_panel.dart';

import '../support/fake_clock.dart';
import '../support/scripted_voice_ai.dart';

final LocalDay _today = LocalDay(2026, 3, 10);

Future<HomeController> _home() async {
  final MemoryRecordRepository<Habit> habits = MemoryRecordRepository<Habit>(
    codec: const HabitCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  final MemoryRecordRepository<Ghost> ghost = MemoryRecordRepository<Ghost>(
    codec: const GhostCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  await habits.put(
    'a',
    Habit(id: 'a', name: 'Habit a', createdDay: LocalDay(2026, 3, 1)),
  );
  await ghost.put(
    HauntStorage.ghostKey,
    Ghost(
      name: 'Wisp',
      health: 60,
      lastSettledDay: _today,
      resurrectionCount: 0,
    ),
  );
  return HomeController(
    clock: FakeClock(DateTime(2026, 3, 10, 9)),
    openStorage: () async =>
        HauntStorage(habits: habits, ghost: ghost, isPersistent: true),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpApp(
  WidgetTester tester,
  HomeController home,
  CoffinAI? ai,
) async {
  tester.view.physicalSize = const Size(360, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(
        size: Size(360, 3000),
        disableAnimations: true,
      ),
      child: HauntagotchiApp(controller: home, ai: ai),
    ),
  );
  await _settle(tester);
}

Finder get _check => find.descendant(
  of: find.byKey(const ValueKey<String>('habit-a')),
  matching: find.byKey(const ValueKey<String>('habit-check')),
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });

  testWidgets('the opening line shows after load and a check-off changes it', (
    WidgetTester tester,
  ) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi()
        .replyWith('Opening line.')
        .replyWith('Fed line.');
    final HomeController home = await _home();
    await _pumpApp(tester, home, ai);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(VoicePanel), findsOneWidget);
    expect(find.text('Opening line.'), findsOneWidget);
    expect(ai.callCount, 1);

    await tester.tap(_check);
    await _settle(tester);

    expect(find.text('Fed line.'), findsOneWidget);
    expect(find.text('Opening line.'), findsNothing);
    expect(ai.callCount, 2);
  });

  testWidgets('the app works with the default AI', (WidgetTester tester) async {
    final HomeController home = await _home();
    await _pumpApp(tester, home, null);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(VoicePanel), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(_check);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(VoicePanel), findsOneWidget);
  });

  testWidgets('the app works with a throwing AI', (WidgetTester tester) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi()
        .failWith(StateError('boom'))
        .failWith(ArgumentError('bang'));
    final HomeController home = await _home();
    await _pumpApp(tester, home, ai);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(VoicePanel), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(_check);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(VoicePanel), findsOneWidget);
  });

  testWidgets('disposing the app with a request in flight causes no error', (
    WidgetTester tester,
  ) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi().hang();
    final HomeController home = await _home();
    await _pumpApp(tester, home, ai);
    expect(ai.callCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));

    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing with a delayed answer pending causes no error', (
    WidgetTester tester,
  ) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi();
    final completer = ai.replyLater();
    final HomeController home = await _home();
    await _pumpApp(tester, home, ai);

    await tester.pumpWidget(const SizedBox.shrink());
    completer.complete('Too late.');
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
