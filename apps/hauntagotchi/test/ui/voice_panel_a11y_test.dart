import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
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
import 'package:hauntagotchi/src/ui/voice_panel.dart';

import '../support/fake_clock.dart';
import '../support/scripted_voice_ai.dart';

final LocalDay _today = LocalDay(2026, 3, 10);

class _Rig {
  _Rig(this.home, this.clock, this.ai, this.voice);

  final HomeController home;
  final FakeClock clock;
  final ScriptedVoiceAi ai;
  final VoiceController voice;
}

Future<_Rig> _rig(
  ScriptedVoiceAi ai, {
  required int habitCount,
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
  final FakeClock clock = FakeClock(DateTime(2026, 3, 10, 9));
  final HomeController home = HomeController(
    clock: clock,
    openStorage: () async =>
        HauntStorage(habits: habits, ghost: ghost, isPersistent: true),
  );
  await home.load();
  final VoiceController voice = VoiceController(home: home, ai: ai);
  addTearDown(() {
    voice.dispose();
    home.dispose();
  });
  return _Rig(home, clock, ai, voice);
}

Future<void> _pumpPanel(
  WidgetTester tester,
  VoiceController voice, {
  ThemeData? theme,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          accessibleNavigation: accessibleNavigation,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: VoicePanel(controller: voice, ghostName: 'Boo'),
      ),
    ),
  );
  await tester.pump();
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

double _luminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('reduced motion', () {
    testWidgets('no AnimatedSwitcher and nothing runs after a change', (
      WidgetTester tester,
    ) async {
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('One.')
        ..replyWith('Two.');
      final _Rig rig = await _rig(ai, habitCount: 2);
      await _pumpPanel(tester, rig.voice, disableAnimations: true);
      await tester.pump();
      expect(find.text('One.'), findsOneWidget);
      await rig.home.toggle('h1');
      await tester.pump();
      expect(find.text('Two.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(VoicePanel),
          matching: find.byType(AnimatedSwitcher),
        ),
        findsNothing,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('motion allowed', () {
    testWidgets('a change fades once over 300 to 600 ms, then nothing runs', (
      WidgetTester tester,
    ) async {
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('One.')
        ..replyWith('Two.');
      final _Rig rig = await _rig(ai, habitCount: 2);
      await _pumpPanel(tester, rig.voice);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);

      final AnimatedSwitcher switcher = tester.widget<AnimatedSwitcher>(
        find.descendant(
          of: find.byType(VoicePanel),
          matching: find.byType(AnimatedSwitcher),
        ),
      );
      expect(switcher.duration.inMilliseconds, inInclusiveRange(300, 600));
      expect(switcher.switchInCurve, Curves.easeInOut);

      await rig.home.toggle('h1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('Two.'), findsOneWidget);
      expect(find.text('One.'), findsNothing);
    });
  });

  group('announcements', () {
    testWidgets('one per check-off over 10 check-offs, none otherwise', (
      WidgetTester tester,
    ) async {
      final List<String> seen = _captureAnnouncements(tester);
      final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Open.');
      final _Rig rig = await _rig(ai, habitCount: 5);
      await _pumpPanel(tester, rig.voice, accessibleNavigation: true);
      await tester.pump(const Duration(seconds: 1));
      expect(seen, isEmpty, reason: 'nothing on open');

      for (int i = 1; i <= 10; i++) {
        if (i == 6) {
          // A new day changes the mood: one line is drawn, none announced.
          final int calls = ai.callCount;
          final int announced = seen.length;
          ai.replyWith('New day.');
          rig.clock.advance(const Duration(days: 1));
          await rig.home.refresh();
          await tester.pump(const Duration(seconds: 1));
          expect(ai.callCount, calls + 1, reason: 'mood change on a new day');
          expect(seen.length, announced);
        }
        final int before = seen.length;
        ai.replyWith('Line $i.');
        await rig.home.toggle('h${(i - 1) % 5 + 1}');
        await tester.pump(const Duration(seconds: 1));
        expect(seen.length - before, lessThanOrEqualTo(1), reason: 'check $i');
      }
      expect(seen, <String>[for (int i = 1; i <= 10; i++) 'Line $i.']);

      // The same text again: nothing new to announce.
      ai.replyWith('Line 10.');
      await rig.home.toggle('h1');
      await tester.pump(const Duration(seconds: 1));
      expect(seen.length, 10, reason: 'unchanged text');

      // A mood change on a new day: a line is drawn, nothing is announced.
      final int calls = ai.callCount;
      ai.replyWith('Mood line.');
      rig.clock.advance(const Duration(days: 4));
      await rig.home.refresh();
      await tester.pump(const Duration(seconds: 1));
      expect(ai.callCount, calls + 1, reason: 'the mood change asked once');
      expect(find.text('Mood line.'), findsOneWidget);
      expect(seen.length, 10, reason: 'mood change');
    });

    testWidgets('none when accessible navigation is off', (
      WidgetTester tester,
    ) async {
      final List<String> seen = _captureAnnouncements(tester);
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('Fed.');
      final _Rig rig = await _rig(ai, habitCount: 2);
      await _pumpPanel(tester, rig.voice);
      await tester.pump(const Duration(seconds: 1));
      await rig.home.toggle('h1');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Fed.'), findsOneWidget);
      expect(seen, isEmpty);
    });

    testWidgets('one for a resurrection', (WidgetTester tester) async {
      final List<String> seen = _captureAnnouncements(tester);
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('The crypt waits.')
        ..replyWith('Back from the mist!');
      final _Rig rig = await _rig(ai, habitCount: 1, health: 0);
      await _pumpPanel(tester, rig.voice, accessibleNavigation: true);
      await tester.pump(const Duration(seconds: 1));
      expect(seen, isEmpty);
      await rig.home.toggle('h1');
      await tester.pump(const Duration(seconds: 1));
      expect(rig.home.resurrectionCount, 1);
      expect(seen, <String>['Back from the mist!']);
    });
  });

  group('contrast', () {
    for (final (String, ThemeData) entry in <(String, ThemeData)>[
      ('night', CoffinTheme.dark()),
      ('daylight', CoffinTheme.light()),
    ]) {
      testWidgets('text on the panel surface is at least 4.5 in ${entry.$1}', (
        WidgetTester tester,
      ) async {
        final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Hello.');
        final _Rig rig = await _rig(ai, habitCount: 1);
        await _pumpPanel(tester, rig.voice, theme: entry.$2);
        await tester.pump(const Duration(seconds: 1));
        final Text text = tester.widget<Text>(
          find.descendant(
            of: find.byType(VoicePanel),
            matching: find.byType(Text),
          ),
        );
        final DecoratedBox box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(VoicePanel),
            matching: find.byType(DecoratedBox),
          ),
        );
        final Color surface = (box.decoration as BoxDecoration).color!;
        final Color ink = text.style!.color!;
        expect(_contrast(ink, surface), greaterThanOrEqualTo(4.5));
      });
    }
  });
}
