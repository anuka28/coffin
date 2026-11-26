// Feature: graveyard-polish, the Horizon while the first stone rises.
// Validates: Requirements 1.4, 12.7
import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/scene/rise_progress.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/ground_painter.dart';

import '../support/fake_coffin_ai.dart';

const double _tolerance = 0.5;

/// One instance, so the second pump does not animate a theme change.
final ThemeData _theme = CoffinTheme.dark();

final CalendarDate _today = CalendarDate(2026, 5, 10);

Grave _grave(int i) => Grave.manual(
  id: 'g$i',
  name: i.isEven ? 'Project $i' : 'A long wrapping name of project number $i',
  dateOfDeath: CalendarDate(2025, 1, 1),
);

Future<void> _pumpScene(
  WidgetTester tester, {
  required List<Grave> graves,
  required bool reduced,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(1),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: GraveyardScene(
          graves: graves,
          today: _today,
          onDelete: (_) {},
          seanceAi: FakeCoffinAI.replying('Boo.'),
        ),
      ),
    ),
  );
}

Finder get _groundFinder => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is GroundPainter,
);

/// The Stack that is the scroll content: the coordinate system of the rows.
RenderBox _content(WidgetTester tester) => tester.renderObject<RenderBox>(
  find
      .descendant(
        of: find.ancestor(
          of: _groundFinder,
          matching: find.byType(SingleChildScrollView),
        ),
        matching: find.byType(Stack),
      )
      .first,
);

RenderBox _ground(WidgetTester tester) =>
    tester.renderObject<RenderBox>(_groundFinder);

/// Ground_Field rect in the coordinates of the rows Column.
Rect _groundRect(WidgetTester tester) {
  final RenderBox ground = _ground(tester);
  final Offset top = ground.localToGlobal(
    Offset.zero,
    ancestor: _content(tester),
  );
  return top & ground.size;
}

double _horizon(WidgetTester tester) {
  final Rect rect = _groundRect(tester);
  return rect.top + math.min(GroundPainter.maxSoftEdge, rect.height / 2);
}

Finder get _firstStone => find.byType(GraveTombstone).first;

/// Painted top of the first stone: its Opacity ancestor, which includes the
/// rise translate.
double _paintedTop(WidgetTester tester) => tester
    .getRect(
      find.descendant(of: _firstStone, matching: find.byType(Opacity)).first,
    )
    .top;

/// Layout top of the keyed Stone_Box of the first stone, without the translate.
double _restingTop(WidgetTester tester) => tester
    .getRect(
      find
          .descendant(
            of: _firstStone,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is ConstrainedBox &&
                  w.constraints.maxWidth == GraveTombstone.maxStoneWidth,
            ),
          )
          .first,
    )
    .top;

void main() {
  for (final double width in <double>[360, 768]) {
    testWidgets('Horizon does not move while the first stone rises at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final List<Grave> first = <Grave>[_grave(1), _grave(2)];
      await _pumpScene(tester, graves: first, reduced: false);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // A new grave arrives at the front: a rising stone in the first row.
      await _pumpScene(
        tester,
        graves: <Grave>[_grave(0), ...first],
        reduced: false,
      );
      // Post-frame measurement of the new first row.
      await tester.pump();
      expect(tester.takeException(), isNull);

      final double horizon = _horizon(tester);
      final Rect ground = _groundRect(tester);
      expect(ground.height, greaterThan(GroundPainter.maxSoftEdge));

      // Rising: painted below the resting place by about riseDistance.
      final double startPainted = _paintedTop(tester);
      expect(
        startPainted - _restingTop(tester),
        closeTo(GraveTombstone.riseDistance, 1),
      );

      final List<double> painted = <double>[startPainted];
      void check(String label) {
        expect(tester.takeException(), isNull, reason: label);
        expect(_horizon(tester), closeTo(horizon, _tolerance), reason: label);
        expect(
          _groundRect(tester).top,
          closeTo(ground.top, _tolerance),
          reason: label,
        );
      }

      check('0%');
      final int risingTickers = tester.binding.transientCallbackCount;
      const int step = RiseProgress.durationMs ~/ 4;
      for (final int percent in <int>[25, 50, 75, 100]) {
        await tester.pump(const Duration(milliseconds: step));
        check('$percent%');
        painted.add(_paintedTop(tester));
      }
      // The stone really moved up while the ground did not.
      expect(
        painted.first - painted.last,
        closeTo(GraveTombstone.riseDistance, 1),
      );
      expect(painted[2], lessThan(painted[0]));
      expect(painted[2], greaterThan(painted[4]));

      // After the rise and a settle.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      check('settled');
      expect(_paintedTop(tester), closeTo(_restingTop(tester), 0.5));
      // The scene's own twinkle loop keeps a frame scheduled while motion is
      // on, so `hasScheduledFrame` cannot be false here. The rise ticker has
      // ended, so only the twinkle is left, and it is the same set of ticks as
      // before the new grave arrived. The reduced-motion test below asserts
      // `hasScheduledFrame` is false, which covers a measurement loop.
      expect(tester.binding.transientCallbackCount, lessThan(risingTickers));
    });

    testWidgets('Horizon is the same before and after with reduced motion '
        'at $width', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final List<Grave> first = <Grave>[_grave(1), _grave(2)];
      await _pumpScene(tester, graves: first, reduced: true);
      await tester.pump();
      await tester.pump();

      await _pumpScene(
        tester,
        graves: <Grave>[_grave(0), ...first],
        reduced: true,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      final double horizon = _horizon(tester);
      final Rect ground = _groundRect(tester);
      expect(ground.height, greaterThan(GroundPainter.maxSoftEdge));
      // No rise: the stone is painted at rest at once.
      expect(_paintedTop(tester), closeTo(_restingTop(tester), 0.5));

      await tester.pump(const Duration(milliseconds: RiseProgress.durationMs));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_horizon(tester), closeTo(horizon, _tolerance));
      expect(_groundRect(tester).top, closeTo(ground.top, _tolerance));
      expect(_paintedTop(tester), closeTo(_restingTop(tester), 0.5));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }
}
