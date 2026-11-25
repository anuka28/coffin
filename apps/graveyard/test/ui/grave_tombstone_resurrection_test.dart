import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/domain/scene/crack_generator.dart';
import 'package:graveyard/src/domain/scene/crack.dart';
import 'package:graveyard/src/domain/scene/keep_out_rect.dart';
import 'package:graveyard/src/ui/arch_epitaph.dart';
import 'package:graveyard/src/ui/crack_painter.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/resurrection_play.dart';
import 'package:graveyard/src/ui/seance_ai.dart';
import 'package:graveyard/src/ui/seance_sheet.dart';

final CalendarDate _today = CalendarDate(2024, 1, 10);

/// Dead for more than 3650 days: full tilt (3 degrees) and cracks.
Grave _old([String id = 'b']) => Grave.manual(
  id: id,
  name: 'moth $id',
  dateOfDeath: CalendarDate(2013, 1, 3),
);

Grave _young(String id) => Grave.manual(
  id: id,
  name: 'fly $id',
  dateOfDeath: CalendarDate(2023, 1, 3),
);

Widget _app(
  Grave grave, {
  required bool playing,
  VoidCallback? onDelete,
  ValueChanged<Grave>? onRaise,
}) => MaterialApp(
  theme: CoffinTheme.dark(),
  home: MediaQuery(
    data: const MediaQueryData(),
    child: Scaffold(
      body: SingleChildScrollView(
        child: GraveTombstone(
          grave: grave,
          today: _today,
          onDelete: onDelete ?? () {},
          seanceAi: buildSeanceAi(),
          playing: playing,
          onRaise: onRaise,
        ),
      ),
    ),
  ),
);

Finder get _tilt => find.descendant(
  of: find.byType(GraveTombstone),
  matching: find.byWidgetPredicate(
    (w) => w is Transform && w.alignment == Alignment.bottomCenter,
  ),
);

double _tiltOf(WidgetTester tester) {
  final m = tester.widget<Transform>(_tilt.first).transform;
  return math.atan2(m.storage[1], m.storage[0]);
}

Future<void> _advance(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

List<Crack> _cracksOf(WidgetTester tester, String id) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(ValueKey<String>('cracks-$id')),
  );
  return (paint.painter! as CrackPainter).cracks;
}

List<Crack> _expectedCracks(WidgetTester tester, String id, String text) {
  final size = tester.getSize(find.byKey(ValueKey<String>('cracks-$id')));
  const double inset = 20;
  return CrackGenerator.generate(
    dayCount: _old(id).dateOfDeath.daysUntil(_today),
    graveId: id,
    stoneWidth: size.width,
    stoneHeight: size.height,
    keepOut: <KeepOutRect>[
      KeepOutRect(
        left: inset,
        top: 0,
        right: size.width - inset,
        bottom: size.height - inset,
      ),
      ArchEpitaph.rectFor(
        width: size.width,
        textScaler: TextScaler.noScaling,
        text: text,
      ),
    ],
  );
}

String _stoneLabel(WidgetTester tester) {
  final labels = tester
      .widgetList<Semantics>(
        find.descendant(
          of: find.byType(GraveTombstone),
          matching: find.byType(Semantics),
        ),
      )
      .map((s) => s.properties.label)
      .whereType<String>()
      .where((l) => l.contains('moth'))
      .toList();
  expect(labels, isNotEmpty);
  return labels.first;
}

void main() {
  group('epitaph text during a play', () {
    testWidgets('R.I.P. at the start and at 600 ms, RISEN after the fade', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_young('m'), playing: true));
      expect(find.text(GraveyardCopy.epitaph), findsOneWidget);
      expect(find.text(GraveyardCopy.epitaphRisen), findsNothing);
      await _advance(tester, 600);
      expect(find.text(GraveyardCopy.epitaph), findsOneWidget);
      expect(find.text(GraveyardCopy.epitaphRisen), findsNothing);
      await _advance(
        tester,
        PlayTiming.epitaphFadeStartMs + PlayTiming.epitaphFadeMs - 600 + 100,
      );
      expect(find.text(GraveyardCopy.epitaphRisen), findsOneWidget);
      expect(find.text(GraveyardCopy.epitaph), findsNothing);
      await _teardown(tester);
    });

    testWidgets('the fade lasts 300 to 600 ms', (tester) async {
      expect(PlayTiming.epitaphFadeMs, inInclusiveRange(300, 600));
      await tester.pumpWidget(_app(_young('m'), playing: true));
      final switcher = tester.widget<AnimatedSwitcher>(
        find.descendant(
          of: find.byType(GraveTombstone),
          matching: find.byType(AnimatedSwitcher),
        ),
      );
      expect(
        switcher.duration,
        const Duration(milliseconds: PlayTiming.epitaphFadeMs),
      );
      await _teardown(tester);
    });

    testWidgets('a not playing, not risen stone shows R.I.P. and no play', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_young('m'), playing: false));
      expect(find.text(GraveyardCopy.epitaph), findsOneWidget);
      expect(find.text(GraveyardCopy.epitaphRisen), findsNothing);
      expect(find.byType(ResurrectionPlay), findsNothing);
      await _teardown(tester);
    });

    testWidgets('the crack keep-out area follows the text', (tester) async {
      await tester.pumpWidget(_app(_old(), playing: true));
      expect(
        _cracksOf(tester, 'b'),
        _expectedCracks(tester, 'b', GraveyardCopy.epitaph),
      );
      await _advance(
        tester,
        PlayTiming.epitaphFadeStartMs + PlayTiming.epitaphFadeMs + 100,
      );
      expect(find.text(GraveyardCopy.epitaphRisen), findsOneWidget);
      expect(
        _cracksOf(tester, 'b'),
        _expectedCracks(tester, 'b', GraveyardCopy.epitaphRisen),
      );
      await _teardown(tester);
    });
  });

  group('play layer structure', () {
    testWidgets('inside the tilt, ignoring pointers and semantics, clipped', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_old(), playing: true));
      final play = find.byType(ResurrectionPlay);
      expect(play, findsOneWidget);
      expect(find.descendant(of: _tilt.first, matching: play), findsOneWidget);
      for (final type in <Type>[
        IgnorePointer,
        ExcludeSemantics,
        RepaintBoundary,
        ClipRect,
      ]) {
        expect(
          find.ancestor(
            of: play,
            matching: find.descendant(
              of: _tilt.first,
              matching: find.byType(type),
            ),
          ),
          findsWidgets,
          reason: '$type wraps the play layer',
        );
      }
      expect(
        find.ancestor(of: play, matching: find.byType(ClipRect)),
        findsWidgets,
      );
      await _teardown(tester);
    });
  });

  group('controls during a play', () {
    testWidgets('delete still works', (tester) async {
      var deleted = 0;
      await tester.pumpWidget(
        _app(_young('m'), playing: true, onDelete: () => deleted++),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(GraveyardCopy.delete));
      expect(deleted, 1);
      await _teardown(tester);
    });

    testWidgets('the Seance_Control opens a sheet without Raise_Control', (
      tester,
    ) async {
      final raised = <Grave>[];
      await tester.pumpWidget(
        _app(_young('m'), playing: true, onRaise: raised.add),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(GraveyardCopy.seanceControlText));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SeanceSheet), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('seance-raise')), findsNothing);
      expect(find.text(GraveyardCopy.raiseControlText), findsNothing);
      expect(raised, isEmpty);
      await _teardown(tester);
    });

    testWidgets('a stone that is not playing offers Raise_Control', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_young('m'), playing: false, onRaise: (_) {}),
      );
      await tester.tap(find.text(GraveyardCopy.seanceControlText));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.byKey(const ValueKey<String>('seance-raise')),
        findsOneWidget,
      );
      await _teardown(tester);
    });
  });

  group('layout stays put', () {
    testWidgets('size, width, tilt and label are equal before/during/after, '
        'at the largest tilt', (tester) async {
      final handle = tester.ensureSemantics();
      Future<(Size, Size, double, String)> measure() async => (
        tester.getSize(find.byType(GraveTombstone)),
        tester.getSize(find.byType(TombstoneCard)),
        _tiltOf(tester),
        _stoneLabel(tester),
      );

      await tester.pumpWidget(_app(_old(), playing: false));
      final before = await measure();
      expect(before.$3.abs(), closeTo(3 * math.pi / 180, 1e-9));

      await tester.pumpWidget(_app(_old(), playing: true));
      await tester.pump(const Duration(milliseconds: 700));
      final during = await measure();
      expect(during, before);
      expect(before.$4, isNot(contains('RISEN')));

      await _advance(tester, PlayTiming.playDurationMs + 500);
      await tester.pumpWidget(_app(_old(), playing: false));
      await tester.pump();
      final after = await measure();
      expect(after, before);
      handle.dispose();
      await _teardown(tester);
    });

    testWidgets('columns and neighbors do not move', (tester) async {
      for (final width in <double>[360, 1000]) {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final graves = <Grave>[
          _old('a'),
          _old('b'),
          _old('c'),
          _old('d'),
          _old('e'),
        ];
        Widget host(Set<String> playing) => MaterialApp(
          theme: CoffinTheme.dark(),
          home: Scaffold(
            body: GraveyardScene(
              graves: graves,
              today: _today,
              onDelete: (_) {},
              seanceAi: buildSeanceAi(),
              playingIds: playing,
            ),
          ),
        );
        Finder stone(String id) => find.byWidgetPredicate(
          (w) => w is GraveTombstone && w.grave.id == id,
        );
        Map<String, (Offset, Size)> snapshot() => <String, (Offset, Size)>{
          for (final g in graves)
            g.id: (tester.getTopLeft(stone(g.id)), tester.getSize(stone(g.id))),
        };

        await tester.pumpWidget(host(const <String>{}));
        await _advance(tester, 1500);
        final before = snapshot();
        await tester.pumpWidget(host(const <String>{'b'}));
        await _advance(tester, 1000);
        expect(find.byType(ResurrectionPlay), findsOneWidget);
        expect(snapshot(), before, reason: 'during, width $width');
        await tester.pumpWidget(host(const <String>{}));
        await _advance(tester, 500);
        expect(snapshot(), before, reason: 'after, width $width');
        await _teardown(tester);
      }
    });
  });
}
