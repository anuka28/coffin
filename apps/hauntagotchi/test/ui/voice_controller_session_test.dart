import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/domain/voice_policy.dart';
import 'package:hauntagotchi/src/domain/voice_snapshot.dart';
import 'package:hauntagotchi/src/domain/voice_trigger.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';
import 'package:hauntagotchi/src/ui/home_status.dart';
import 'package:hauntagotchi/src/ui/voice_ai.dart';
import 'package:hauntagotchi/src/ui/voice_controller.dart';

import '../support/fake_clock.dart';

/// Shame words that no line after a missed day may hold (test-owned list).
const List<String> _shameWords = <String>[
  'failed',
  'fail',
  'lazy',
  'worthless',
  'abandoned',
  'neglected',
  'guilty',
  'shame',
  'blame',
  'missed',
  'forgot',
  'gore',
  'blood',
  'corpse',
  'rotting',
];

/// Wraps the default offline AI and records each request and its reply text.
final class _RecordingAi implements CoffinAI {
  _RecordingAi() : _inner = defaultVoiceAi();

  final CoffinAI _inner;
  final List<AiRequest> requests = <AiRequest>[];
  final List<String> lines = <String>[];

  @override
  Future<AiReply> ask(AiRequest request) async {
    requests.add(request);
    final AiReply reply = await _inner.ask(request);
    lines.add(reply.text);
    return reply;
  }
}

/// What one scripted session produced.
final class _Session {
  _Session(this.requests, this.lines, this.triggers, this.missedDayLines);

  final List<AiRequest> requests;
  final List<String> lines;
  final int triggers;
  final List<String> missedDayLines;
}

Future<void> _settle() => pumpEventQueue();

Future<_Session> _runSession() async {
  final LocalDay today = LocalDay(2026, 3, 10);
  final FakeClock clock = FakeClock(DateTime(2026, 3, 10, 9));
  final MemoryRecordRepository<Habit> habits = MemoryRecordRepository<Habit>(
    codec: const HabitCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  final MemoryRecordRepository<Ghost> ghost = MemoryRecordRepository<Ghost>(
    codec: const GhostCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  for (int i = 1; i <= 5; i++) {
    await habits.put(
      'h$i',
      Habit(id: 'h$i', name: 'Habit $i', createdDay: today),
    );
  }
  await ghost.put(
    HauntStorage.ghostKey,
    Ghost(
      name: 'Boo',
      health: 60,
      lastSettledDay: today.previous,
      resurrectionCount: 0,
    ),
  );
  final HomeController home = HomeController(
    clock: clock,
    openStorage: () async =>
        HauntStorage(habits: habits, ghost: ghost, isPersistent: true),
  );
  addTearDown(home.dispose);

  // Independent trigger count, from the same pure policy.
  int triggers = 0;
  VoiceSnapshot? last;
  void count() {
    final VoiceSnapshot next = VoiceSnapshot(
      state: home.status == HomeStatus.ready ? home.haunting?.state : null,
      checkOffs: home.checkOffCount,
      resurrections: home.resurrectionCount,
    );
    if (VoicePolicy.decide(last, next) != null) {
      triggers++;
    }
    last = next;
  }

  home.addListener(count);

  final _RecordingAi ai = _RecordingAi();
  final VoiceController voice = VoiceController(home: home, ai: ai);
  addTearDown(voice.dispose);

  // Open the app.
  await home.load();
  await _settle();

  // Four check-offs, then one undo.
  for (final String id in <String>['h1', 'h2', 'h3', 'h4']) {
    await home.toggle(id);
    await _settle();
  }
  await home.toggle('h4');
  await _settle();

  // A new day (a mood change), then missed days until the ghost dies.
  final int beforeMissed = ai.lines.length;
  clock.advance(const Duration(days: 1));
  await home.refresh();
  await _settle();
  for (int day = 0; day < 15 && !home.haunting!.ghost.isDead; day++) {
    clock.advance(const Duration(days: 1));
    await home.refresh();
    await _settle();
  }
  expect(home.haunting!.ghost.isDead, isTrue, reason: 'ghost should die');
  final List<String> missedDayLines = ai.lines.sublist(beforeMissed);

  // The ritual: two candles resurrect the ghost.
  final int resurrections = home.resurrectionCount;
  await home.toggle('h1');
  await _settle();
  await home.toggle('h2');
  await _settle();
  expect(home.resurrectionCount, resurrections + 1);
  expect(voice.line, ai.lines.last);

  return _Session(
    List<AiRequest>.of(ai.requests),
    List<String>.of(ai.lines),
    triggers,
    missedDayLines,
  );
}

/// Every text the offline AI can give for [request]'s mood and event facts,
/// found by sweeping seeds.
Future<Set<String>> _allowedTexts(AiRequest request) async {
  const OfflineCoffinAI offline = OfflineCoffinAI();
  final Set<String> texts = <String>{};
  for (int seed = 0; seed < 400; seed++) {
    final AiReply reply = await offline.ask(
      AiRequest(
        purpose: request.purpose,
        facts: request.facts,
        maxLength: request.maxLength,
        seed: seed,
      ),
    );
    texts.add(reply.text);
  }
  return texts;
}

bool _plain(String line) =>
    line.runes.every((int r) => (r >= 0x20 && r <= 0x7E) || r == 0x2026);

String _event(AiRequest r) => r.facts[AiFactKeys.ghostEvent]! as String;

void main() {
  late _Session session;

  Future<_Session> run() async => session = await _runSession();

  test('one AI call per trigger, one line per call', () async {
    await run();
    expect(session.requests.length, session.triggers);
    expect(session.lines.length, session.requests.length);
    expect(session.requests.first.facts[AiFactKeys.ghostEvent], 'appOpened');
    final Set<String> events = session.requests.map(_event).toSet();
    expect(
      events,
      containsAll(<String>[
        VoiceTrigger.appOpened.name,
        VoiceTrigger.checkedOff.name,
        VoiceTrigger.moodChanged.name,
        VoiceTrigger.resurrected.name,
      ]),
    );
  });

  test('each check-off of the first batch carries a different seed', () async {
    await run();
    final List<AiRequest> checkOffs = session.requests
        .where((AiRequest r) => _event(r) == 'checkedOff')
        .take(4)
        .toList();
    expect(checkOffs.length, 4);
    expect(checkOffs.map((AiRequest r) => r.seed).toSet().length, 4);
  });

  test('the same session replayed gives the same requests and lines', () async {
    final _Session first = await _runSession();
    final _Session second = await _runSession();
    expect(second.lines, first.lines);
    expect(second.requests, first.requests);
  });

  test(
    'every line belongs to the allowed texts of its mood and event',
    () async {
      await run();
      for (int i = 0; i < session.requests.length; i++) {
        final Set<String> allowed = await _allowedTexts(session.requests[i]);
        expect(
          allowed,
          contains(session.lines[i]),
          reason:
              'call $i (${session.requests[i].facts[AiFactKeys.ghostMood]}/'
              '${_event(session.requests[i])})',
        );
      }
    },
  );

  test('every line is one short line of plain characters', () async {
    await run();
    for (final String line in session.lines) {
      expect(line, isNotEmpty);
      expect(line.length, lessThanOrEqualTo(80));
      expect(line.contains('\n') || line.contains('\r'), isFalse);
      expect(_plain(line), isTrue, reason: line);
    }
  });

  test('lines after a missed day hold no shame word', () async {
    await run();
    expect(session.missedDayLines, isNotEmpty);
    for (final String line in session.missedDayLines) {
      final String lower = line.toLowerCase();
      for (final String word in _shameWords) {
        expect(lower.contains(word), isFalse, reason: '"$line" has "$word"');
      }
    }
  });
}
