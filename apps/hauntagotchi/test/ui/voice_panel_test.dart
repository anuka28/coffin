import 'dart:async';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';
import 'package:hauntagotchi/src/ui/voice_controller.dart';
import 'package:hauntagotchi/src/ui/voice_copy.dart';
import 'package:hauntagotchi/src/ui/voice_panel.dart';

import '../support/fake_clock.dart';
import '../support/scripted_voice_ai.dart';

final LocalDay _today = LocalDay(2026, 3, 10);

/// An 80-character line.
final String _longLine = '${List<String>.filled(8, 'moonlight').join(' ')}!';

class _Rig {
  _Rig(this.home, this.ai, this.voice);

  final HomeController home;
  final ScriptedVoiceAi ai;
  final VoiceController voice;
}

/// A loaded home with [habitCount] habits, a ghost with [health], and a
/// voice on a scripted AI. The caller queues the opening answer first.
Future<_Rig> _rig(
  ScriptedVoiceAi ai, {
  int habitCount = 3,
  int health = 60,
}) async {
  final MemoryRecordRepository<Habit> habits = MemoryRecordRepository<Habit>(
    codec: const HabitCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  final MemoryRecordRepository<Ghost> ghost = MemoryRecordRepository<Ghost>(
    codec: const GhostCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  for (int i = 1; i <= habitCount; i++) {
    await habits.put(
      'h$i',
      Habit(id: 'h$i', name: 'Habit $i', createdDay: _today),
    );
  }
  await ghost.put(
    HauntStorage.ghostKey,
    Ghost(
      name: 'Boo',
      health: health,
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
  return _Rig(home, ai, voice);
}

Future<void> _pumpPanel(
  WidgetTester tester,
  VoiceController voice, {
  String name = 'Boo',
  double width = 360,
  double textScale = 1,
  bool accessibleNavigation = false,
  Widget Function(Widget panel)? wrap,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final Widget panel = VoicePanel(controller: voice, ghostName: name);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          accessibleNavigation: accessibleNavigation,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(child: wrap == null ? panel : wrap(panel)),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

List<String> _captureAnnouncements(WidgetTester tester) {
  final List<String> seen = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (dynamic message) async {
      if (message is Map && message['type'] == 'announce') {
        seen.add((message['data'] as Map)['message'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return seen;
}

void main() {
  testWidgets('shows the line as Text', (WidgetTester tester) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Hello there.');
    final _Rig rig = await _rig(ai);
    await _pumpPanel(tester, rig.voice);
    await _settle(tester);
    expect(find.text('Hello there.'), findsOneWidget);
  });

  testWidgets('shows the safe line before the first answer', (
    WidgetTester tester,
  ) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi();
    final Completer<String> first = ai.replyLater();
    final _Rig rig = await _rig(ai);
    await _pumpPanel(tester, rig.voice);
    expect(find.text(VoiceCopy.safeLine), findsOneWidget);
    first.complete('First light.');
    await _settle(tester);
    expect(find.text('First light.'), findsOneWidget);
    expect(find.text(VoiceCopy.safeLine), findsNothing);
  });

  testWidgets('shows the previous line while a new one is pending', (
    WidgetTester tester,
  ) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Before.');
    final Completer<String> next = ai.replyLater();
    final _Rig rig = await _rig(ai);
    await _pumpPanel(tester, rig.voice);
    await _settle(tester);
    await rig.home.toggle('h1');
    await tester.pump();
    expect(ai.callCount, 2);
    expect(find.text('Before.'), findsOneWidget);
    next.complete('After.');
    await _settle(tester);
    expect(find.text('After.'), findsOneWidget);
    expect(find.text('Before.'), findsNothing);
  });

  testWidgets('shows one line only', (WidgetTester tester) async {
    final ScriptedVoiceAi ai = ScriptedVoiceAi()
      ..replyWith('One.')
      ..replyWith('Two.');
    final _Rig rig = await _rig(ai);
    await _pumpPanel(tester, rig.voice);
    await _settle(tester);
    await rig.home.toggle('h1');
    await _settle(tester);
    expect(
      find.descendant(of: find.byType(VoicePanel), matching: find.byType(Text)),
      findsOneWidget,
    );
  });

  testWidgets('labels the line with the ghost name', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Hello there.');
    final _Rig rig = await _rig(ai);
    await _pumpPanel(tester, rig.voice);
    await _settle(tester);
    expect(find.bySemanticsLabel('Boo says: Hello there.'), findsOneWidget);
    expect(find.bySemanticsLabel('Hello there.'), findsNothing);
    handle.dispose();
  });

  testWidgets('labels the line with the fallback name when the name is empty', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Hello there.');
    final _Rig rig = await _rig(ai);
    await _pumpPanel(tester, rig.voice, name: '');
    await _settle(tester);
    expect(
      find.bySemanticsLabel('${VoiceCopy.fallbackName} says: Hello there.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  group('layout', () {
    for (final double width in <double>[320, 360, 1280]) {
      for (final double scale in <double>[1, 2]) {
        testWidgets('no overflow at $width px and scale $scale', (
          WidgetTester tester,
        ) async {
          expect(_longLine.length, 80);
          final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith(_longLine);
          final _Rig rig = await _rig(ai);
          await _pumpPanel(tester, rig.voice, width: width, textScale: scale);
          await _settle(tester);
          expect(find.text(_longLine), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('announcements', () {
    testWidgets('a rebuild or a route change does not repeat one', (
      WidgetTester tester,
    ) async {
      final List<String> seen = _captureAnnouncements(tester);
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('Fed.');
      final _Rig rig = await _rig(ai);
      await _pumpPanel(tester, rig.voice, accessibleNavigation: true);
      await _settle(tester);
      await rig.home.toggle('h1');
      await _settle(tester);
      expect(seen, <String>['Fed.']);

      // A rebuild with the same controller.
      await _pumpPanel(tester, rig.voice, accessibleNavigation: true);
      await _settle(tester);
      // A route change: the panel moves under a pushed route and back.
      await _pumpPanel(
        tester,
        rig.voice,
        accessibleNavigation: true,
        wrap: (Widget panel) => Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: <Widget>[panel]),
        ),
      );
      await _settle(tester);
      expect(seen, <String>['Fed.']);
    });
  });

  testWidgets('the panel has no tap target and takes no focus', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Hello there.');
    final _Rig rig = await _rig(ai);
    await _pumpPanel(tester, rig.voice);
    await _settle(tester);
    for (final Type type in <Type>[
      InkWell,
      GestureDetector,
      Focus,
      TextButton,
      IconButton,
    ]) {
      expect(
        find.descendant(
          of: find.byType(VoicePanel),
          matching: find.byType(type),
        ),
        findsNothing,
        reason: '$type inside the panel',
      );
    }
    final node = tester.getSemantics(find.byType(VoicePanel));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(node.getSemanticsData().hasAction(SemanticsAction.focus), isFalse);
    handle.dispose();
  });
}
