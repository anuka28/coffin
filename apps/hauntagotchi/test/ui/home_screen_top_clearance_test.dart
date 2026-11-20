import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';
import 'package:hauntagotchi/src/ui/home_screen.dart';

import '../support/fake_clock.dart';
import '../support/throwing_record_repository.dart';

/// The least space in logical pixels between the top of the safe area and the
/// first row of the ghost body.
const int _minClearance = 24;

final LocalDay _today = LocalDay(2026, 3, 10);

Habit _habit(String id, {bool doneToday = false}) => Habit(
  id: id,
  name: 'Habit $id',
  createdDay: LocalDay(2026, 3, 1),
  completedDays: doneToday ? <LocalDay>{_today} : const <LocalDay>{},
);

final Finder _ghostPaint = find.byWidgetPredicate(
  (Widget w) => w is CustomPaint && w.painter is GhostPainter,
);

/// Renders [source] alone, without glow, and returns the first row that holds
/// a body pixel, or null when nothing is drawn.
Future<int?> _firstBodyRow(
  WidgetTester tester,
  GhostPainter source,
  Size size,
) async {
  final GhostPainter bare = GhostPainter(
    bodyColor: source.bodyColor,
    eyeColor: source.eyeColor,
    bobOffset: source.bobOffset,
    headroom: source.headroom,
    pose: source.pose,
  );
  return tester.runAsync<int?>(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    bare.paint(ui.Canvas(recorder), size);
    final ui.Image image = await recorder.endRecording().toImage(
      size.width.ceil(),
      size.height.ceil(),
    );
    final ByteData data = (await image.toByteData())!;
    final int w = image.width;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < w; x++) {
        if (data.getUint8((y * w + x) * 4 + 3) > 0) {
          image.dispose();
          return y;
        }
      }
    }
    image.dispose();
    return null;
  });
}

Future<void> _pumpLoader(
  WidgetTester tester,
  GhostMood mood, {
  int reactionKey = 0,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      home: Scaffold(
        body: Center(
          child: GhostLoader(
            key: const ValueKey<String>('probe'),
            size: 96,
            mood: mood,
            reactionKey: reactionKey,
          ),
        ),
      ),
    ),
  );
}

/// The smallest first-body row over [fromMs] to [toMs] in 100 ms steps.
Future<int> _minRowOver(WidgetTester tester, int fromMs, int toMs) async {
  int minRow = 1 << 30;
  int at = 0;
  while (at <= toMs) {
    if (at >= fromMs) {
      final GhostPainter painter =
          tester.widget<CustomPaint>(_ghostPaint).painter! as GhostPainter;
      final int? row = await _firstBodyRow(
        tester,
        painter,
        tester.getSize(_ghostPaint),
      );
      expect(row, isNotNull, reason: 'a body is drawn at $at ms');
      if (row! < minRow) minRow = row;
    }
    await tester.pump(const Duration(milliseconds: 100));
    at += 100;
  }
  return minRow;
}

final Map<GhostMood, int> _minRows = <GhostMood, int>{};

/// First body row, minimum over samples, for the five steady moods (one bob
/// period of 5000 ms covers every period in the table) and `rising` around
/// its lift peak at 1100 ms.
Future<Map<GhostMood, int>> _sampledRows(WidgetTester tester) async {
  if (_minRows.isNotEmpty) return _minRows;
  for (final GhostMood mood in <GhostMood>[
    GhostMood.thriving,
    GhostMood.content,
    GhostMood.hungry,
    GhostMood.fading,
    GhostMood.dead,
  ]) {
    await _pumpLoader(tester, mood);
    await tester.pump();
    _minRows[mood] = await _minRowOver(tester, 0, 5000);
  }
  await _pumpLoader(tester, GhostMood.thriving);
  await tester.pump(const Duration(milliseconds: 100));
  await _pumpLoader(tester, GhostMood.rising, reactionKey: 1);
  await tester.pump();
  _minRows[GhostMood.rising] = await _minRowOver(tester, 900, 1300);
  return _minRows;
}

/// Opens the home screen at [width] with the requested extra rows and returns
/// the distance from the top of the safe area to the top of the loader box.
Future<double> _openHome(
  WidgetTester tester, {
  required double width,
  required double scale,
  required bool welcome,
  required bool memory,
  required bool banner,
}) async {
  final ThrowingRecordRepository<Habit> habits =
      ThrowingRecordRepository<Habit>(
        MemoryRecordRepository<Habit>(
          codec: const HabitCodec(),
          currentVersion: HauntStorage.currentVersion,
        ),
      );
  final MemoryRecordRepository<Ghost> ghosts = MemoryRecordRepository<Ghost>(
    codec: const GhostCodec(),
    currentVersion: HauntStorage.currentVersion,
  );
  final List<Habit> seed = <Habit>[
    _habit('a', doneToday: welcome),
    _habit('b'),
    _habit('c'),
  ];
  for (final Habit h in seed) {
    await habits.put(h.id, h);
  }
  if (welcome) {
    await ghosts.put(
      HauntStorage.ghostKey,
      Ghost(
        name: 'Wisp',
        health: 0,
        lastSettledDay: _today.previous,
        resurrectionCount: 0,
      ),
    );
  }
  final HomeController c = HomeController(
    clock: FakeClock(DateTime(2026, 3, 10, 9)),
    openStorage: () async =>
        HauntStorage(habits: habits, ghost: ghosts, isPersistent: !memory),
  );
  await c.load();

  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: HomeScreen(controller: c),
    ),
  );
  await tester.pumpAndSettle();

  if (welcome || banner) {
    habits.failPut = banner;
    await c.toggle(welcome ? 'b' : 'a');
    await tester.pumpAndSettle();
  }
  return tester.getTopLeft(_ghostPaint).dy -
      tester.getTopLeft(find.byType(SafeArea)).dy;
}

void main() {
  for (final double width in <double>[320, 360, 1280]) {
    for (final double scale in <double>[1.0, 1.5]) {
      for (final bool welcome in <bool>[false, true]) {
        for (final bool memory in <bool>[false, true]) {
          for (final bool banner in <bool>[false, true]) {
            testWidgets(
              'ghost keeps $_minClearance px from the top: width $width, '
              'scale $scale, welcome $welcome, memory $memory, '
              'banner $banner',
              (WidgetTester tester) async {
                final Map<GhostMood, int> rows = await _sampledRows(tester);
                expect(rows.keys.toSet(), <GhostMood>{
                  GhostMood.thriving,
                  GhostMood.content,
                  GhostMood.hungry,
                  GhostMood.fading,
                  GhostMood.dead,
                  GhostMood.rising,
                });

                final double boxTop = await _openHome(
                  tester,
                  width: width,
                  scale: scale,
                  welcome: welcome,
                  memory: memory,
                  banner: banner,
                );
                for (final MapEntry<GhostMood, int> e in rows.entries) {
                  expect(
                    boxTop + e.value,
                    greaterThanOrEqualTo(_minClearance),
                    reason: '${e.key} body row ${e.value}, box top $boxTop',
                  );
                }
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  }

  testWidgets('the first habit tile is reachable by scrolling at width 320', (
    WidgetTester tester,
  ) async {
    await _openHome(
      tester,
      width: 320,
      scale: 1.5,
      welcome: true,
      memory: true,
      banner: true,
    );
    final Finder tile = find.byKey(const ValueKey<String>('habit-a'));
    await tester.scrollUntilVisible(
      tile,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    final Rect rect = tester.getRect(tile);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(700));
    expect(tester.takeException(), isNull);
  });
}
