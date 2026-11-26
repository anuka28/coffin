// Feature: graveyard-polish, post-frame measurement of the Ground_Field.
// Validates: Requirements 1.2, 1.4, 1.6, 3.3, 3.4, 4.6, 12.2
import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/ground_painter.dart';
import 'package:graveyard/src/ui/living_row.dart';

import '../support/fake_coffin_ai.dart';

const double _tolerance = 1;

final CalendarDate _today = CalendarDate(2026, 5, 10);

// One ThemeData for the whole file, so Material runs no theme tween.
final ThemeData _theme = CoffinTheme.dark();

Grave _grave(int i) => Grave.manual(
  id: 'g$i',
  name: i.isEven ? 'Project $i' : 'A long wrapping name of project number $i',
  dateOfDeath: CalendarDate(2025, 1, 1),
);

void _setView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(
  List<Grave> graves, {
  double scale = 1,
  bool reduced = true,
  ValueChanged<Grave>? onDelete,
}) => MaterialApp(
  theme: _theme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
    ),
    child: child!,
  ),
  home: Scaffold(
    body: GraveyardScene(
      graves: graves,
      today: _today,
      onDelete: onDelete ?? (_) {},
      seanceAi: FakeCoffinAI.replying('Boo.'),
    ),
  ),
);

Finder get _groundFinder => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is GroundPainter,
);

Finder get _scroll => find.byType(SingleChildScrollView);

RenderBox _ground(WidgetTester tester) =>
    tester.renderObject<RenderBox>(_groundFinder);

/// The Stack that is the scroll content: the coordinate system of the rows.
RenderBox _content(WidgetTester tester) => tester.renderObject<RenderBox>(
  find.descendant(of: _scroll, matching: find.byType(Stack)).first,
);

/// Ground rect in the coordinates of the scroll content.
Rect _groundRect(WidgetTester tester) {
  final RenderBox ground = _ground(tester);
  final Offset origin = ground.localToGlobal(
    Offset.zero,
    ancestor: _content(tester),
  );
  return origin & ground.size;
}

double _horizon(WidgetTester tester) {
  final Rect rect = _groundRect(tester);
  return rect.top + math.min(GroundPainter.maxSoftEdge, rect.height / 2);
}

/// Bottom of the first Stone_Box in the coordinates of the scroll content.
double _firstBase(WidgetTester tester) {
  final Element e = find.byType(GraveTombstone).evaluate().first;
  final Finder box = find
      .descendant(
        of: find.byElementPredicate((x) => x == e),
        matching: find.byWidgetPredicate(
          (w) =>
              w is ConstrainedBox &&
              w.constraints.maxWidth == GraveTombstone.maxStoneWidth,
        ),
      )
      .first;
  final RenderBox stone = tester.renderObject<RenderBox>(box);
  return stone
      .localToGlobal(
        Offset(stone.size.width / 2, stone.size.height),
        ancestor: _content(tester),
      )
      .dy;
}

void _expectHorizonAtBase(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(_horizon(tester), closeTo(_firstBase(tester), _tolerance));
}

/// Pumps twice: one frame to apply the measurement, one to confirm it.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

List<Grave> get _eight => <Grave>[for (int i = 0; i < 8; i++) _grave(i)];

void main() {
  group('first frame and first measurement', () {
    testWidgets('the first frame has an empty ground that paints nothing', (
      tester,
    ) async {
      _setView(tester, 400, 700);
      await tester.pumpWidget(_host(_eight));
      expect(tester.takeException(), isNull);
      expect(_groundFinder, findsOneWidget);
      expect(_ground(tester).size.height, 0);
      expect(_ground(tester), paintsNothing);
    });

    testWidgets('one pump puts the ground at its measured place', (
      tester,
    ) async {
      _setView(tester, 400, 700);
      await tester.pumpWidget(_host(_eight));
      expect(_ground(tester).size.height, 0);
      final Rect fallback = _groundRect(tester);

      await tester.pump();
      expect(tester.takeException(), isNull);
      final Rect rect = _groundRect(tester);
      expect(rect.height, greaterThan(0));
      expect(
        rect.width,
        closeTo(tester.getSize(find.byType(GraveyardScene)).width, 0.5),
      );
      _expectHorizonAtBase(tester);
      // The fallback was not a visible position: it had no height.
      expect(fallback.height, 0);
      expect(
        rect.top,
        closeTo(_firstBase(tester) - GroundPainter.maxSoftEdge, 1),
      );
    });

    testWidgets('a further pump leaves the ground and schedules no frame', (
      tester,
    ) async {
      _setView(tester, 400, 700);
      await tester.pumpWidget(_host(_eight));
      await tester.pump();
      final Rect first = _groundRect(tester);

      await tester.pump();
      final Rect second = _groundRect(tester);
      expect((second.top - first.top).abs(), lessThanOrEqualTo(0.5));
      expect((second.height - first.height).abs(), lessThanOrEqualTo(0.5));
      expect(second.left, first.left);
      expect(second.width, first.width);
      expect(tester.binding.hasScheduledFrame, isFalse);
      _expectHorizonAtBase(tester);
    });
  });

  group('re-measure on change', () {
    testWidgets('a resize that changes the column count', (tester) async {
      _setView(tester, 400, 700);
      await tester.pumpWidget(_host(_eight));
      await _settle(tester);
      _expectHorizonAtBase(tester);
      final double narrow = _horizon(tester);

      tester.view.physicalSize = const Size(768, 700);
      await _settle(tester);
      _expectHorizonAtBase(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);

      tester.view.physicalSize = const Size(400, 700);
      await _settle(tester);
      _expectHorizonAtBase(tester);
      expect(_horizon(tester), closeTo(narrow, _tolerance));
    });

    testWidgets('a text scale change', (tester) async {
      _setView(tester, 360, 700);
      await tester.pumpWidget(_host(_eight));
      await _settle(tester);
      _expectHorizonAtBase(tester);

      await tester.pumpWidget(_host(_eight, scale: 2));
      await _settle(tester);
      _expectHorizonAtBase(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the base really moves: a raised grave opens the Living_Row', (
      tester,
    ) async {
      _setView(tester, 400, 700);
      final List<Grave> resting = _eight;
      // Raise the last grave: the first row keeps its stone, and the new
      // Living_Row above the rows pushes every row down.
      final List<Grave> raised = <Grave>[
        ...resting.sublist(0, 7),
        resting[7].copyWithRisenOn(CalendarDate(2026, 5, 9)),
      ];

      await tester.pumpWidget(_host(resting));
      await _settle(tester);
      _expectHorizonAtBase(tester);
      final double before = _horizon(tester);
      final double baseBefore = _firstBase(tester);

      await tester.pumpWidget(_host(raised));
      await _settle(tester);
      expect(find.byType(LivingRow), findsOneWidget);
      final double moved = _horizon(tester);
      final double baseMoved = _firstBase(tester);
      expect(baseMoved - baseBefore, greaterThanOrEqualTo(20));
      expect(moved - before, greaterThanOrEqualTo(20));
      _expectHorizonAtBase(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(_host(resting));
      await _settle(tester);
      expect(find.byType(LivingRow), findsNothing);
      final double back = _horizon(tester);
      expect(moved - back, greaterThanOrEqualTo(20));
      _expectHorizonAtBase(tester);
      expect(back, closeTo(before, _tolerance));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('deleting the first grave', (tester) async {
      _setView(tester, 360, 700);
      await tester.pumpWidget(_host(_eight));
      await _settle(tester);

      await tester.pumpWidget(_host(_eight.sublist(1)));
      await _settle(tester);
      _expectHorizonAtBase(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('no extra measurement', () {
    testWidgets('a scroll alone schedules no measurement', (tester) async {
      _setView(tester, 360, 500);
      await tester.pumpWidget(_host(_eight));
      await _settle(tester);
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.descendant(of: _scroll, matching: find.byType(Scrollable)).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(200));
      final Rect before = _groundRect(tester);

      scrollable.position.jumpTo(200);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
      final Rect after = _groundRect(tester);
      expect((after.top - before.top).abs(), lessThanOrEqualTo(0.5));
      expect((after.height - before.height).abs(), lessThanOrEqualTo(0.5));
      _expectHorizonAtBase(tester);
    });
  });

  group('deleting while a grave rises', () {
    testWidgets('deleting the last grave mid-rise throws nothing', (
      tester,
    ) async {
      _setView(tester, 400, 700);
      final List<Grave> start = <Grave>[_grave(0), _grave(2), _grave(4)];
      await tester.pumpWidget(_host(start, reduced: false));
      await _settle(tester);

      // A new grave rises at the top.
      await tester.pumpWidget(
        _host(<Grave>[_grave(1), ...start], reduced: false),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isTrue);

      // The last grave of the list goes while the other still rises.
      await tester.pumpWidget(
        _host(<Grave>[_grave(1), _grave(0), _grave(2)], reduced: false),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // Everything goes while it still rises.
      await tester.pumpWidget(_host(const <Grave>[], reduced: false));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(GraveTombstone), findsNothing);
    });

    testWidgets('deleting the only other grave leaves the riser measured', (
      tester,
    ) async {
      _setView(tester, 400, 700);
      await tester.pumpWidget(_host(<Grave>[_grave(0)], reduced: false));
      await _settle(tester);
      await tester.pumpWidget(
        _host(<Grave>[_grave(0), _grave(1)], reduced: false),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(_host(<Grave>[_grave(1)], reduced: false));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      _expectHorizonAtBase(tester);
    });
  });
}
