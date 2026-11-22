import 'dart:async';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/haunting.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/domain/voice_seed.dart';
import 'package:hauntagotchi/src/domain/voice_trigger.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';
import 'package:hauntagotchi/src/ui/voice_announcement.dart';
import 'package:hauntagotchi/src/ui/voice_controller.dart';
import 'package:hauntagotchi/src/ui/voice_copy.dart';

import '../support/fake_clock.dart';
import '../support/scripted_voice_ai.dart';
import '../support/throwing_record_repository.dart';

final DateTime _morning = DateTime(2026, 3, 10, 9);
final LocalDay _today = LocalDay(2026, 3, 10);
const Duration _timeout = Duration(milliseconds: 40);

class _Rig {
  _Rig() : clock = FakeClock(_morning) {
    habits = ThrowingRecordRepository<Habit>(
      MemoryRecordRepository<Habit>(
        codec: const HabitCodec(),
        currentVersion: HauntStorage.currentVersion,
      ),
    );
    ghost = MemoryRecordRepository<Ghost>(
      codec: const GhostCodec(),
      currentVersion: HauntStorage.currentVersion,
    );
    home = HomeController(
      clock: clock,
      openStorage: () async =>
          HauntStorage(habits: habits, ghost: ghost, isPersistent: true),
    );
  }

  final FakeClock clock;
  late final ThrowingRecordRepository<Habit> habits;
  late final MemoryRecordRepository<Ghost> ghost;
  late final HomeController home;

  /// Seeds storage with habits `h1..hN` and a ghost of [health], then loads.
  Future<void> seedAndLoad(int habitCount, int health) async {
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
        lastSettledDay: _today.previous,
        resurrectionCount: 1,
      ),
    );
    await home.load();
  }
}

Future<void> _settle() => pumpEventQueue();

/// Seeds, builds a voice over [ai] and waits for the opening line.
Future<VoiceController> _open(
  _Rig rig,
  ScriptedVoiceAi ai, {
  required int habitCount,
  required int health,
}) async {
  final VoiceController voice = VoiceController(
    home: rig.home,
    ai: ai,
    askTimeout: _timeout,
  );
  addTearDown(voice.dispose);
  await rig.seedAndLoad(habitCount, health);
  await _settle();
  return voice;
}

String _event(ScriptedVoiceAi ai, int index) =>
    ai.requests[index].facts[AiFactKeys.ghostEvent]! as String;

void main() {
  group('one AI call and the right trigger', () {
    test('first ready asks for appOpened', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Open line.');
      final VoiceController voice = await _open(
        rig,
        ai,
        habitCount: 1,
        health: 50,
      );
      expect(ai.callCount, 1);
      expect(_event(ai, 0), 'appOpened');
      expect(voice.line, 'Open line.');
    });

    test('a controller built on a ready home asks once', () async {
      final _Rig rig = _Rig();
      await rig.seedAndLoad(1, 50);
      final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Hello.');
      final VoiceController voice = VoiceController(
        home: rig.home,
        ai: ai,
        askTimeout: _timeout,
      );
      addTearDown(voice.dispose);
      await _settle();
      expect(ai.callCount, 1);
      expect(_event(ai, 0), 'appOpened');
      expect(voice.line, 'Hello.');
    });

    test('a check-off asks for checkedOff', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('Yum.');
      final VoiceController voice = await _open(
        rig,
        ai,
        habitCount: 1,
        health: 50,
      );
      await rig.home.toggle('h1');
      await _settle();
      expect(ai.callCount, 2);
      expect(_event(ai, 1), 'checkedOff');
      expect(voice.line, 'Yum.');
    });

    test('a check-off at full health asks for checkedOff', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('Yum.');
      await _open(rig, ai, habitCount: 2, health: 100);
      await rig.home.toggle('h1');
      await _settle();
      expect(ai.callCount, 2);
      expect(_event(ai, 1), 'checkedOff');
    });

    test('a check-off that leaves the ghost dead asks once', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('One step.');
      await _open(rig, ai, habitCount: 2, health: 0);
      await rig.home.toggle('h1');
      await _settle();
      expect(rig.home.haunting!.ghost.isDead, isTrue);
      expect(ai.callCount, 2);
      expect(_event(ai, 1), 'checkedOff');
      expect(ai.requests[1].facts[AiFactKeys.ghostMood], GhostState.dead.name);
    });

    test('a resurrecting check-off asks once for resurrected', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('Back!');
      await _open(rig, ai, habitCount: 1, health: 0);
      await rig.home.toggle('h1');
      await _settle();
      expect(ai.callCount, 2);
      expect(_event(ai, 1), 'resurrected');
    });

    test('a day change that changes the mood asks for moodChanged', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('Hungry.');
      await _open(rig, ai, habitCount: 1, health: 60);
      rig.clock.advance(const Duration(days: 1));
      await rig.home.refresh();
      await _settle();
      expect(ai.callCount, 2);
      expect(_event(ai, 1), 'moodChanged');
      expect(
        ai.requests[1].facts[AiFactKeys.ghostMood],
        GhostState.hungry.name,
      );
    });

    test('an undo that changes the mood asks for moodChanged', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('Yum.')
        ..replyWith('Hungry again.');
      await _open(rig, ai, habitCount: 1, health: 40);
      await rig.home.toggle('h1');
      await _settle();
      await rig.home.toggle('h1');
      await _settle();
      expect(ai.callCount, 3);
      expect(_event(ai, 2), 'moodChanged');
    });
  });

  group('no AI call and an unchanged line', () {
    Future<(_Rig, ScriptedVoiceAi, VoiceController)> opened({
      int habitCount = 2,
      int health = 50,
    }) async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Open.');
      final VoiceController voice = await _open(
        rig,
        ai,
        habitCount: habitCount,
        health: health,
      );
      expect(ai.callCount, 1);
      return (rig, ai, voice);
    }

    void expectQuiet(ScriptedVoiceAi ai, VoiceController voice) {
      expect(ai.callCount, 1);
      expect(voice.line, 'Open.');
      expect(voice.announcement, isNull);
    }

    test('listeners added and removed on the controllers', () async {
      final (_Rig rig, ScriptedVoiceAi ai, VoiceController voice) =
          await opened();
      void noop() {}
      voice.addListener(noop);
      rig.home.addListener(noop);
      rig.home.removeListener(noop);
      voice.removeListener(noop);
      rig.home.dismissWelcome();
      await _settle();
      expectQuiet(ai, voice);
    });

    test('a save and a save retry', () async {
      final (_Rig rig, ScriptedVoiceAi ai, VoiceController voice) =
          await opened();
      rig.habits.failPut = true;
      await rig.home.addHabit('Stretch');
      await _settle();
      expect(rig.home.saveStatus.name, 'saveError');
      rig.habits.failPut = false;
      await rig.home.retrySave();
      await _settle();
      expectQuiet(ai, voice);
    });

    test('a rename', () async {
      final (_Rig rig, ScriptedVoiceAi ai, VoiceController voice) =
          await opened();
      await rig.home.renameHabit('h2', 'Read');
      await _settle();
      expectQuiet(ai, voice);
    });

    test('an archive', () async {
      final (_Rig rig, ScriptedVoiceAi ai, VoiceController voice) =
          await opened();
      await rig.home.archiveHabit('h2');
      await _settle();
      expectQuiet(ai, voice);
    });

    test('an add', () async {
      final (_Rig rig, ScriptedVoiceAi ai, VoiceController voice) =
          await opened();
      await rig.home.addHabit('Stretch');
      await _settle();
      expectQuiet(ai, voice);
    });

    test('a no-op refresh', () async {
      final (_Rig rig, ScriptedVoiceAi ai, VoiceController voice) =
          await opened();
      await rig.home.refresh();
      await _settle();
      expectQuiet(ai, voice);
    });

    test('an undo that keeps the mood', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('Yum.');
      final VoiceController voice = await _open(
        rig,
        ai,
        habitCount: 1,
        health: 50,
      );
      await rig.home.toggle('h1'); // content to content
      await _settle();
      expect(ai.callCount, 2);
      await rig.home.toggle('h1'); // undo, content again
      await _settle();
      expect(ai.callCount, 2);
      expect(voice.line, 'Yum.');
    });

    test('a day change that keeps the mood', () async {
      final (_Rig rig, ScriptedVoiceAi ai, VoiceController voice) =
          await opened(habitCount: 1, health: 70);
      rig.clock.advance(const Duration(days: 1));
      await rig.home.refresh();
      await _settle();
      expect(rig.home.haunting!.state, GhostState.content);
      expectQuiet(ai, voice);
    });
  });

  group('the request', () {
    test('holds the right facts and seed', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('Yum.');
      await _open(rig, ai, habitCount: 2, health: 50);
      await rig.home.toggle('h1');
      await _settle();

      final AiRequest open = ai.requests[0];
      expect(open.purpose, AiPurpose.ghostMoodLine);
      expect(open.maxLength, 80);
      expect(open.facts, <String, Object?>{
        AiFactKeys.ghostMood: 'content',
        AiFactKeys.ghostEvent: 'appOpened',
        AiFactKeys.ghostName: 'Boo',
      });
      expect(
        open.seed,
        VoiceSeed.compute(
          epochDay: _today.epochDay,
          state: GhostState.content,
          trigger: VoiceTrigger.appOpened,
          streak: 0,
          completedToday: 0,
        ),
      );

      final AiRequest checked = ai.requests[1];
      final int streak = rig.home.haunting!.streak;
      expect(checked.facts[AiFactKeys.ghostEvent], 'checkedOff');
      expect(checked.facts[AiFactKeys.ghostName], 'Boo');
      expect(checked.facts[AiFactKeys.streakCount], streak);
      expect(
        checked.seed,
        VoiceSeed.compute(
          epochDay: _today.epochDay,
          state: rig.home.haunting!.state,
          trigger: VoiceTrigger.checkedOff,
          streak: streak,
          completedToday: 1,
        ),
      );
    });
  });

  group('slow and failing AI', () {
    test('a slow AI shows the previous line, then the answer', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()..replyWith('Open.');
      final VoiceController voice = await _open(
        rig,
        ai,
        habitCount: 1,
        health: 50,
      );
      final Completer<String> slow = ai.replyLater();
      await rig.home.toggle('h1');
      await _settle();
      expect(voice.line, 'Open.');
      slow.complete('Yum.');
      await _settle();
      expect(voice.line, 'Yum.');
    });

    test('a slow first answer shows null before it arrives', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi();
      final Completer<String> slow = ai.replyLater();
      final VoiceController voice = VoiceController(
        home: rig.home,
        ai: ai,
        askTimeout: const Duration(seconds: 5),
      );
      addTearDown(voice.dispose);
      await rig.seedAndLoad(1, 50);
      await _settle();
      expect(voice.line, isNull);
      slow.complete('Late hello.');
      await _settle();
      expect(voice.line, 'Late hello.');
    });

    test('a slower first answer after a second trigger is dropped', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi();
      final Completer<String> first = ai.replyLater();
      ai.replyWith('Yum.');
      final VoiceController voice = VoiceController(
        home: rig.home,
        ai: ai,
        askTimeout: const Duration(seconds: 5),
      );
      addTearDown(voice.dispose);
      await rig.seedAndLoad(1, 50);
      await rig.home.toggle('h1');
      await _settle();
      expect(voice.line, 'Yum.');
      first.complete('Stale.');
      await _settle();
      expect(voice.line, 'Yum.');
    });

    Future<void> expectSafe(ScriptedVoiceAi ai) async {
      final _Rig rig = _Rig();
      final VoiceController voice = await _open(
        rig,
        ai,
        habitCount: 1,
        health: 50,
      );
      if (ai.callCount > 0 && voice.line == null) {
        await Future<void>.delayed(_timeout * 3);
      }
      expect(voice.line, VoiceCopy.safeLine);
    }

    test('a throwing AI gives the safe line', () async {
      await expectSafe(ScriptedVoiceAi()..failWith(StateError('boom')));
    });

    test('a blank answer gives the safe line', () async {
      await expectSafe(ScriptedVoiceAi()..replyWith('   '));
    });

    test('an over-long answer gives the safe line', () async {
      await expectSafe(ScriptedVoiceAi()..replyWith('x' * 81));
    });

    test(
      'a never-completing AI gives the safe line after askTimeout',
      () async {
        await expectSafe(ScriptedVoiceAi()..hang());
      },
    );
  });

  group('dispose', () {
    test(
      'with a request in flight causes no notification and no error',
      () async {
        final _Rig rig = _Rig();
        final ScriptedVoiceAi ai = ScriptedVoiceAi();
        final Completer<String> pending = ai.replyLater();
        final VoiceController voice = VoiceController(
          home: rig.home,
          ai: ai,
          askTimeout: const Duration(seconds: 5),
        );
        int notifications = 0;
        voice.addListener(() => notifications++);
        await rig.seedAndLoad(1, 50);
        await _settle();
        expect(ai.callCount, 1);

        voice.dispose();
        pending.complete('Too late.');
        await rig.home.toggle('h1');
        await _settle();

        expect(notifications, 0);
        expect(ai.callCount, 1);
      },
    );
  });

  group('announcement', () {
    test('is set for check-off and resurrection with a changed text', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('Yum.')
        ..replyWith('Back!');
      final VoiceController voice = await _open(
        rig,
        ai,
        habitCount: 1,
        health: 0,
      );
      expect(voice.announcement, isNull);
      // Resurrect (check-off of the only habit at health 0).
      await rig.home.toggle('h1');
      await _settle();
      expect(voice.announcement, const VoiceAnnouncement(key: 1, text: 'Yum.'));
      // Undo drops the mood back, and nothing is announced for it.
      await rig.home.toggle('h1');
      await _settle();
      expect(ai.callCount, 3);
      expect(voice.line, 'Back!');
      expect(voice.announcement!.key, 1);
    });

    test('is not set for open, and not for an unchanged text', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Same.')
        ..replyWith('Same.');
      final VoiceController voice = await _open(
        rig,
        ai,
        habitCount: 1,
        health: 50,
      );
      expect(voice.announcement, isNull);
      int notifications = 0;
      voice.addListener(() => notifications++);
      await rig.home.toggle('h1');
      await _settle();
      expect(ai.callCount, 2);
      expect(voice.line, 'Same.');
      expect(voice.announcement, isNull);
      expect(notifications, 0);
    });

    test('is not set for a mood change', () async {
      final _Rig rig = _Rig();
      final ScriptedVoiceAi ai = ScriptedVoiceAi()
        ..replyWith('Open.')
        ..replyWith('Hungry.');
      final VoiceController voice = await _open(
        rig,
        ai,
        habitCount: 1,
        health: 60,
      );
      rig.clock.advance(const Duration(days: 1));
      await rig.home.refresh();
      await _settle();
      expect(voice.line, 'Hungry.');
      expect(voice.announcement, isNull);
    });
  });

  group('the voice does not touch the home controller', () {
    Future<(Object, Object, Object, Object)> runSession({
      required bool withVoice,
    }) async {
      final _Rig rig = _Rig();
      VoiceController? voice;
      if (withVoice) {
        final ScriptedVoiceAi ai = ScriptedVoiceAi();
        for (int i = 0; i < 12; i++) {
          ai.replyWith('Line $i.');
        }
        voice = VoiceController(home: rig.home, ai: ai, askTimeout: _timeout);
      }
      await rig.seedAndLoad(2, 30);
      await rig.home.toggle('h1');
      await rig.home.toggle('h1');
      await rig.home.toggle('h1');
      await rig.home.toggle('h2');
      await rig.home.addHabit('Stretch');
      await rig.home.renameHabit('h2', 'Read');
      rig.clock.advance(const Duration(days: 1));
      await rig.home.refresh();
      await rig.home.toggle('h1');
      await rig.home.archiveHabit('h2');
      await rig.home.retrySave();
      await _settle();
      voice?.dispose();

      final List<Habit> stored = await rig.habits.getAll()
        ..sort((Habit a, Habit b) => a.id.compareTo(b.id));
      final Ghost? storedGhost = await rig.ghost.get(HauntStorage.ghostKey);
      final Haunting h = rig.home.haunting!;
      return (
        stored,
        storedGhost!,
        <Habit>[...h.book.all]
          ..sort((Habit a, Habit b) => a.id.compareTo(b.id)),
        (
          rig.home.status,
          rig.home.saveStatus,
          rig.home.welcomeBack,
          rig.home.checkOffCount,
          rig.home.resurrectionCount,
          rig.home.reaction?.kind,
          h.ghost,
          h.today,
          h.state,
          h.streak,
        ),
      );
    }

    test('storage writes and state match with and without a voice', () async {
      final (Object a1, Object a2, Object a3, Object a4) = await runSession(
        withVoice: false,
      );
      final (Object b1, Object b2, Object b3, Object b4) = await runSession(
        withVoice: true,
      );
      expect(b1, a1);
      expect(b2, a2);
      expect(b3, a3);
      expect(b4, a4);
    });
  });
}
