// Feature: graveyard-polish, the stones of a row share one base line.
// Validates: Requirements 6.2, 6.3, 13.1, 13.2, 13.3, 13.4, 13.6, 12.5
import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/scene/rise_progress.dart';
import 'package:graveyard/src/domain/scene/scene_layout.dart';
import 'package:graveyard/src/domain/scene/weathering.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/ground_painter.dart';

import '../support/fake_coffin_ai.dart';

const List<double> _widths = <double>[320, 360, 768, 1280];
const List<double> _scales = <double>[1.0, 1.5, 2.0];
const double _tolerance = 1;

final CalendarDate _today = CalendarDate(2026, 5, 10);
final ThemeData _theme = CoffinTheme.dark();

/// Even ids get a short name, odd ids a long wrapping one, so neighbours in a
/// row have stones of different heights. The date differs per grave, so the
/// tilt differs too.
Grave _grave(int i) => i.isEven
    ? Grave.manual(
        id: 'g$i',
        name: 'Short $i',
        dateOfDeath: CalendarDate(2025, 1, 1 + i),
      )
    : Grave.github(
        id: 'g$i',
        name: 'A very long wrapping name of the abandoned project number $i',
        dateOfDeath: CalendarDate(2025, 1, 1 + i),
        repo: const RepoInfo(
          fullName: 'someone/a-long-repository-name-for-the-test',
          stars: 1234,
          description:
              'A description that is long enough to wrap over three lines '
              'of the stone, so that this stone is taller than the short one '
              'next to it in the same row of the scene.',
        ),
      );

Widget _host(
  List<Grave> graves, {
  required double scale,
  bool reduced = true,
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
      onDelete: (_) {},
      seanceAi: FakeCoffinAI.replying('Boo.'),
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double scale,
  int count = 8,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _host(<Grave>[for (int i = 0; i < count; i++) _grave(i)], scale: scale),
  );
  // The first frame has no ground; the post-frame measurement places it.
  await tester.pump();
  await tester.pump();
}

Finder get _groundFinder => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is GroundPainter,
);

Finder get _scroll => find.ancestor(
  of: _groundFinder,
  matching: find.byType(SingleChildScrollView),
);

RenderBox _contentBox(WidgetTester tester) => tester.renderObject<RenderBox>(
  find.descendant(of: _scroll, matching: find.byType(Stack)).first,
);

Finder _tombstone(int i) => find.byType(GraveTombstone).at(i);

/// The Stone_Box of stone [i]: the ConstrainedBox that is the child of the
/// Center of its GraveTombstone.
RenderBox _stoneBox(WidgetTester tester, int i) {
  final Finder center = find
      .descendant(of: _tombstone(i), matching: find.byType(Center))
      .first;
  return tester.renderObject<RenderBox>(
    find.descendant(of: center, matching: find.byType(ConstrainedBox)).first,
  );
}

/// Bottom centre of the Stone_Box of stone [i] in the scroll content.
Offset _stoneBase(WidgetTester tester, int i, RenderBox contentBox) {
  final RenderBox box = _stoneBox(tester, i);
  return box.localToGlobal(
    Offset(box.size.width / 2, box.size.height),
    ancestor: contentBox,
  );
}

Finder _controls(int i) =>
    find.descendant(of: _tombstone(i), matching: find.byType(Wrap)).first;

double _controlTop(WidgetTester tester, int i, RenderBox contentBox) => tester
    .renderObject<RenderBox>(_controls(i))
    .localToGlobal(Offset.zero, ancestor: contentBox)
    .dy;

double _horizon(WidgetTester tester, RenderBox contentBox) {
  final RenderBox ground = tester.renderObject<RenderBox>(_groundFinder);
  final double top = ground.localToGlobal(Offset.zero, ancestor: contentBox).dy;
  return top + math.min(GroundPainter.maxSoftEdge, ground.size.height / 2);
}

void main() {
  test('column count is 1 below 720 and 2 to 4 from 720', () {
    for (final double w in <double>[200, 320, 360, 719, 719.9]) {
      expect(SceneLayout.columnsFor(w), 1, reason: 'width $w');
    }
    for (final double w in <double>[720, 768, 1024, 1280, 2000]) {
      expect(
        SceneLayout.columnsFor(w),
        inInclusiveRange(2, 4),
        reason: 'width $w',
      );
    }
  });

  for (final double width in _widths) {
    for (final double scale in _scales) {
      testWidgets('stones share a base line at $width wide, scale $scale', (
        tester,
      ) async {
        await _pump(tester, width: width, scale: scale);
        expect(tester.takeException(), isNull);
        expect(_groundFinder, findsOneWidget);
        final RenderBox content = _contentBox(tester);
        final int columns = SceneLayout.columnsFor(width);
        expect(columns, width < 720 ? 1 : inInclusiveRange(2, 4));

        // The rendered grid has the column count of the layout: the first
        // `columns` stones sit on one row, so they share a top-of-row y and
        // the next stone starts a new, lower row.
        final List<Offset> bases = <Offset>[
          for (int i = 0; i < 8; i++) _stoneBase(tester, i, content),
        ];
        if (columns < 8) {
          expect(
            bases[columns].dy,
            greaterThan(bases[0].dy + 50),
            reason: 'stone $columns starts the second row',
          );
        }
        if (columns > 1) {
          // Every stone of the first row shares the same base, although their
          // heights differ (otherwise this would not tell top from bottom
          // alignment).
          final Set<int> heights = <int>{
            for (int i = 0; i < columns; i++)
              _stoneBox(tester, i).size.height.round(),
          };
          expect(
            heights.length,
            greaterThan(1),
            reason: 'first row has stones of different heights',
          );
          for (int i = 1; i < columns; i++) {
            expect(bases[i].dy, closeTo(bases[0].dy, _tolerance));
          }
          if (scale == 2.0 || scale == 1.0) {
            expect(
              tester.getSize(_controls(0)).height,
              closeTo(tester.getSize(_controls(1)).height, _tolerance),
              reason: 'equal control blocks',
            );
          }
        }

        // The Horizon sits at that base line.
        expect(
          _horizon(tester, content),
          closeTo(bases[0].dy, _tolerance),
          reason: 'Horizon at the first row base',
        );

        // Each stone ends where its own control block starts, whatever the
        // control block height.
        for (int i = 0; i < 8; i++) {
          expect(
            _controlTop(tester, i, content),
            closeTo(bases[i].dy, _tolerance),
            reason: 'stone $i base equals the top of its controls',
          );
        }

        // No clipped stone: every Stone_Box lies inside the scene width, up
        // to the tilt margin.
        final double margin = GraveyardScene.tiltMargin(
          GraveTombstone.maxStoneWidth,
        );
        for (int i = 0; i < 8; i++) {
          final Rect r = tester.getRect(
            find
                .descendant(
                  of: find
                      .descendant(
                        of: _tombstone(i),
                        matching: find.byType(Center),
                      )
                      .first,
                  matching: find.byType(ConstrainedBox),
                )
                .first,
          );
          expect(r.left, greaterThanOrEqualTo(-margin), reason: 'stone $i');
          expect(r.right, lessThanOrEqualTo(width + margin));
        }

        // Tap targets.
        for (int i = 0; i < 8; i++) {
          for (final Finder button in <Finder>[
            find.descendant(
              of: _tombstone(i),
              matching: find.byType(TextButton),
            ),
          ]) {
            expect(button, findsNWidgets(2));
            for (final Element e in button.evaluate()) {
              final Size s = (e.renderObject! as RenderBox).size;
              expect(s.width, greaterThanOrEqualTo(48));
              expect(s.height, greaterThanOrEqualTo(48));
            }
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('one column: stones in a single column keep their own base', (
    tester,
  ) async {
    // At 320 wide every stone is alone in its row, and the Row's end
    // alignment must not move it: the base equals its own control top.
    await _pump(tester, width: 320, scale: 2.0);
    expect(tester.takeException(), isNull);
    final RenderBox content = _contentBox(tester);
    final double tall = _stoneBox(tester, 1).size.height;
    final double small = _stoneBox(tester, 0).size.height;
    expect(tall, greaterThan(small + 1));
    for (int i = 0; i < 8; i++) {
      expect(
        _controlTop(tester, i, content),
        closeTo(_stoneBase(tester, i, content).dy, _tolerance),
      );
    }
  });

  testWidgets('the Rise still runs for a grave added later, tilt unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final List<Grave> first = <Grave>[for (int i = 0; i < 2; i++) _grave(i)];
    await tester.pumpWidget(_host(first, scale: 1, reduced: false));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    double opacityOf(int i) => tester
        .widget<Opacity>(
          find
              .descendant(of: _tombstone(i), matching: find.byType(Opacity))
              .first,
        )
        .opacity;
    double tiltOf(int i) {
      final Transform t = tester.widget<Transform>(
        find
            .descendant(
              of: _tombstone(i),
              matching: find.byWidgetPredicate(
                (w) => w is Transform && w.alignment == Alignment.bottomCenter,
              ),
            )
            .first,
      );
      return math.atan2(t.transform.storage[1], t.transform.storage[0]);
    }

    double expectedTilt(Grave g) => Weathering.of(
      dayCount: math.max(0, g.dateOfDeath.daysUntil(_today)),
      graveId: g.id,
    ).tiltRadians;

    expect(opacityOf(0), 1, reason: 'graves of the first list never rise');
    final List<double> tiltsBefore = <double>[tiltOf(0), tiltOf(1)];

    final Grave added = _grave(2);
    await tester.pumpWidget(
      _host(<Grave>[...first, added], scale: 1, reduced: false),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      opacityOf(2),
      lessThan(1),
      reason: 'the new grave is rising: not yet opaque',
    );
    expect(opacityOf(0), 1);
    expect(tiltOf(2), closeTo(expectedTilt(added), 1e-9));
    expect(tiltOf(0), closeTo(tiltsBefore[0], 1e-9));
    expect(tiltOf(1), closeTo(tiltsBefore[1], 1e-9));

    await tester.pump(
      const Duration(milliseconds: RiseProgress.durationMs + 100),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacityOf(2), 1, reason: 'the rise ends at rest');
    expect(tiltOf(2), closeTo(expectedTilt(added), 1e-9));
    expect(tiltOf(0), closeTo(expectedTilt(first[0]), 1e-9));
    expect(tiltOf(1), closeTo(expectedTilt(first[1]), 1e-9));
    expect(
      <double>[tiltOf(0), tiltOf(1), tiltOf(2)].any((t) => t.abs() > 1e-6),
      isTrue,
      reason: 'at least one stone is tilted, so the tilt check can fail',
    );
    expect(tester.takeException(), isNull);
  });
}
