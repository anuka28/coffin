// Feature: graveyard-polish, placement of the Ground_Field.
// Validates: Requirements 1.1, 1.2, 1.3, 1.5, 1.6, 2.1, 2.2, 2.3, 2.4, 2.5,
// 2.6, 2.7, 3.1, 3.2, 12.1, 12.2, 12.4, 12.5
import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/scene/scene_layout.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/ground_painter.dart';
import 'package:graveyard/src/ui/living_row.dart';

import '../support/fake_coffin_ai.dart';

const List<double> _widths = <double>[320, 360, 768, 1280];
const List<double> _scales = <double>[1.0, 1.5, 2.0];
const List<int> _counts = <int>[1, 3, 8];
const double _tolerance = 1;
const Key _headerKey = ValueKey<String>('test-header');

final CalendarDate _today = CalendarDate(2026, 5, 10);

final List<(String, ThemeData Function(), CoffinColorTokens)> _themes =
    <(String, ThemeData Function(), CoffinColorTokens)>[
      ('dark', CoffinTheme.dark, CoffinColorTokens.night),
      ('daylight', CoffinTheme.light, CoffinColorTokens.daylight),
    ];

Grave _grave(int i) => Grave.manual(
  id: 'g$i',
  name: i.isEven ? 'Project $i' : 'A long wrapping name of project number $i',
  dateOfDeath: CalendarDate(2025, 1, 1),
);

Grave _risen(int i) => Grave.manual(
  id: 'r$i',
  name: 'Risen $i',
  dateOfDeath: CalendarDate(2025, 1, 1),
  risenOn: CalendarDate(2026, 5, 1),
);

void _setView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double scale,
  required List<Grave> graves,
  required ThemeData theme,
  double height = 700,
  Widget? header,
}) async {
  _setView(tester, width, height);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: GraveyardScene(
          graves: graves,
          today: _today,
          onDelete: (_) {},
          seanceAi: FakeCoffinAI.replying('Boo.'),
          header: header,
        ),
      ),
    ),
  );
  // First frame has no ground; the post-frame measurement places it.
  await tester.pump();
  await tester.pump();
}

Finder get _groundFinder => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is GroundPainter,
);

/// The scroll view that holds the Ground_Field.
Finder get _scroll => find.ancestor(
  of: _groundFinder,
  matching: find.byType(SingleChildScrollView),
);

/// The Stack that is the scroll content: the coordinate system of the rows.
RenderBox _content(WidgetTester tester) => tester.renderObject<RenderBox>(
  find.descendant(of: _scroll, matching: find.byType(Stack)).first,
);

RenderBox _ground(WidgetTester tester) =>
    tester.renderObject<RenderBox>(_groundFinder);

/// Bottoms of the Stone_Boxes (keyed ConstrainedBox, child of the Center),
/// in the coordinates of [ancestor].
List<double> _stoneBases(WidgetTester tester, {RenderBox? ancestor}) {
  final List<double> bases = <double>[];
  for (final Element e in find.byType(GraveTombstone).evaluate()) {
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
    bases.add(
      stone
          .localToGlobal(
            Offset(stone.size.width / 2, stone.size.height),
            ancestor: ancestor,
          )
          .dy,
    );
  }
  return bases;
}

double _groundTop(WidgetTester tester, {RenderBox? ancestor}) =>
    _ground(tester).localToGlobal(Offset.zero, ancestor: ancestor).dy;

double _groundBottom(WidgetTester tester, {RenderBox? ancestor}) =>
    _groundTop(tester, ancestor: ancestor) + _ground(tester).size.height;

double _horizon(WidgetTester tester, {RenderBox? ancestor}) =>
    _groundTop(tester, ancestor: ancestor) +
    math.min(GroundPainter.maxSoftEdge, _ground(tester).size.height / 2);

ScrollableState _scrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find.descendant(of: _scroll, matching: find.byType(Scrollable)).first,
    );

void main() {
  for (final (String, ThemeData Function(), CoffinColorTokens) theme
      in _themes) {
    group('${theme.$1}: Horizon at the First_Row_Base', () {
      for (final double width in _widths) {
        for (final double scale in _scales) {
          for (final int count in _counts) {
            testWidgets('$width wide, scale $scale, $count graves', (
              tester,
            ) async {
              await _pump(
                tester,
                width: width,
                scale: scale,
                graves: <Grave>[for (int i = 0; i < count; i++) _grave(i)],
                theme: theme.$2(),
              );
              expect(tester.takeException(), isNull);
              final RenderBox content = _content(tester);
              final List<double> bases = _stoneBases(tester, ancestor: content);
              final double horizon = _horizon(tester, ancestor: content);
              expect(horizon, closeTo(bases.first, _tolerance));

              // One Ground_Field, inside the one scroll view, full width,
              // in the background color of the active theme.
              expect(_scroll, findsOneWidget);
              expect(_groundFinder, findsOneWidget);
              final Rect scene = tester.getRect(find.byType(GraveyardScene));
              expect(_ground(tester).size.width, closeTo(scene.width, 0.5));
              final CustomPaint paint = tester.widget<CustomPaint>(
                _groundFinder,
              );
              final GroundPainter painter = paint.painter! as GroundPainter;
              expect(painter.tokens.background, theme.$3.background);

              // Several rows: later stones stand below the Horizon, on one
              // continuous ground.
              final int columns = SceneLayout.columnsFor(width);
              for (int i = columns; i < bases.length; i++) {
                expect(bases[i], greaterThan(horizon), reason: 'stone $i');
              }
              expect(
                _groundBottom(tester, ancestor: content),
                greaterThanOrEqualTo(bases.last - 0.5),
              );
              // Ground ends at or below the content and the Scene_Box.
              expect(
                _groundBottom(tester, ancestor: content),
                greaterThanOrEqualTo(content.size.height - 0.5),
              );
              expect(
                _groundBottom(tester),
                greaterThanOrEqualTo(scene.bottom - 0.5),
              );
            });
          }
        }
      }

      for (final double width in <double>[360, 768]) {
        testWidgets('scrolling moves ground and base together at $width', (
          tester,
        ) async {
          await _pump(
            tester,
            width: width,
            scale: 1,
            graves: <Grave>[for (int i = 0; i < 8; i++) _grave(i)],
            theme: theme.$2(),
          );
          final ScrollableState scrollable = _scrollable(tester);
          expect(scrollable.position.maxScrollExtent, greaterThan(150));
          final double topBefore = _groundTop(tester);
          final double baseBefore = _stoneBases(tester).first;
          scrollable.position.jumpTo(150);
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(topBefore - _groundTop(tester), closeTo(150, _tolerance));
          expect(
            baseBefore - _stoneBases(tester).first,
            closeTo(150, _tolerance),
          );
          final RenderBox content = _content(tester);
          expect(
            _horizon(tester, ancestor: content),
            closeTo(_stoneBases(tester, ancestor: content).first, _tolerance),
          );
          final Rect scene = tester.getRect(find.byType(GraveyardScene));
          expect(
            _groundBottom(tester),
            greaterThanOrEqualTo(scene.bottom - 0.5),
          );

          scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
          await tester.pump();
          expect(
            _groundBottom(tester),
            greaterThanOrEqualTo(
              content.localToGlobal(Offset(0, content.size.height)).dy - 0.5,
            ),
          );
          expect(
            _groundBottom(tester),
            greaterThanOrEqualTo(scene.bottom - 0.5),
          );
        });
      }

      testWidgets('a header and a Living_Row stay above the Horizon', (
        tester,
      ) async {
        await _pump(
          tester,
          width: 360,
          scale: 1,
          graves: <Grave>[_risen(1), _grave(0), _grave(1)],
          theme: theme.$2(),
          header: const SizedBox(key: _headerKey, height: 80),
        );
        expect(tester.takeException(), isNull);
        final RenderBox content = _content(tester);
        final double horizon = _horizon(tester, ancestor: content);
        final Rect header = tester.getRect(find.byKey(_headerKey));
        final Rect living = tester.getRect(find.byType(LivingRow));
        final double contentTop = content.localToGlobal(Offset.zero).dy;
        expect(header.bottom - contentTop, lessThan(horizon));
        expect(living.bottom - contentTop, lessThan(horizon));
        expect(
          horizon,
          closeTo(_stoneBases(tester, ancestor: content).first, _tolerance),
        );
      });

      testWidgets('a header alone stays above the Horizon', (tester) async {
        await _pump(
          tester,
          width: 768,
          scale: 2,
          graves: <Grave>[_grave(0), _grave(1)],
          theme: theme.$2(),
          header: const SizedBox(key: _headerKey, height: 120),
        );
        final RenderBox content = _content(tester);
        final double contentTop = content.localToGlobal(Offset.zero).dy;
        expect(
          tester.getRect(find.byKey(_headerKey)).bottom - contentTop,
          lessThan(_horizon(tester, ancestor: content)),
        );
      });

      testWidgets('one grave extends the ground to the Scene_Box bottom', (
        tester,
      ) async {
        await _pump(
          tester,
          width: 1280,
          scale: 1,
          graves: <Grave>[_grave(0)],
          theme: theme.$2(),
          height: 900,
        );
        final Rect scene = tester.getRect(find.byType(GraveyardScene));
        expect(_groundBottom(tester), greaterThanOrEqualTo(scene.bottom - 0.5));
        expect(_scrollable(tester).position.maxScrollExtent, 0);
      });
    });
  }
}
