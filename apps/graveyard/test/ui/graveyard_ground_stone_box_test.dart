// Feature: graveyard-polish, the Horizon equals the Stone_Box bottom.
// Validates: Requirements 1.8, 12.2, 12.3
import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/ground_painter.dart';

import '../support/fake_coffin_ai.dart';

const List<double> _widths = <double>[360, 768];
const List<double> _scales = <double>[1.0, 2.0];
const double _tolerance = 1;
const double _scrollDistance = 120;

final CalendarDate _today = CalendarDate(2026, 5, 10);

/// Stones of different heights: a short name, then a long wrapping one.
Grave _grave(int i) => Grave.manual(
  id: 'g$i',
  name: i.isEven
      ? 'Short $i'
      : 'A very long wrapping name of the abandoned project number $i',
  dateOfDeath: CalendarDate(2025, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double scale,
}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: GraveyardScene(
          graves: <Grave>[for (int i = 0; i < 8; i++) _grave(i)],
          today: _today,
          onDelete: (_) {},
          seanceAi: FakeCoffinAI.replying('Boo.'),
        ),
      ),
    ),
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

/// The scroll content that holds the Ground_Field and the rows: the common
/// coordinate system of the Horizon and the Stone_Box bottom.
RenderBox _contentBox(WidgetTester tester) => tester.renderObject<RenderBox>(
  find.descendant(of: _scroll, matching: find.byType(Stack)).first,
);

Finder _firstTombstone() => find.byType(GraveTombstone).first;

/// The Stone_Box of the first stone: the keyed ConstrainedBox that is the
/// child of the Center of the first GraveTombstone. Measured here, not read
/// from the scene.
double _stoneBoxBottom(WidgetTester tester, RenderBox contentBox) {
  final RenderBox box = tester.renderObject<RenderBox>(
    find
        .descendant(
          of: _firstTombstone(),
          matching: find.byWidgetPredicate(
            (w) =>
                w is ConstrainedBox &&
                w.key != null &&
                w.constraints.maxWidth == GraveTombstone.maxStoneWidth,
          ),
        )
        .first,
  );
  return box
      .localToGlobal(
        Offset(box.size.width / 2, box.size.height),
        ancestor: contentBox,
      )
      .dy;
}

double _horizon(WidgetTester tester, RenderBox contentBox) {
  final RenderBox ground = tester.renderObject<RenderBox>(_groundFinder);
  final double top = ground.localToGlobal(Offset.zero, ancestor: contentBox).dy;
  return top + math.min(GroundPainter.maxSoftEdge, ground.size.height / 2);
}

/// Height of the control block (the Wrap) of the first tombstone.
double _controlBlockHeight(WidgetTester tester) => tester
    .getSize(
      find.descendant(of: _firstTombstone(), matching: find.byType(Wrap)),
    )
    .height;

void main() {
  for (final double width in _widths) {
    group('Horizon equals the Stone_Box bottom at $width wide', () {
      testWidgets('at text scale 1.0 and 2.0, before and after a scroll', (
        tester,
      ) async {
        final Map<double, double> blockHeights = <double, double>{};
        for (final double scale in _scales) {
          // A fresh tree, so each scale starts at scroll offset 0.
          await tester.pumpWidget(const SizedBox.shrink());
          await _pump(tester, width: width, scale: scale);
          expect(tester.takeException(), isNull);
          expect(_groundFinder, findsOneWidget);

          RenderBox contentBox = _contentBox(tester);
          expect(
            _horizon(tester, contentBox),
            closeTo(_stoneBoxBottom(tester, contentBox), _tolerance),
            reason: 'scale $scale',
          );
          blockHeights[scale] = _controlBlockHeight(tester);

          final ScrollableState scrollable = tester.state<ScrollableState>(
            find
                .descendant(of: _scroll, matching: find.byType(Scrollable))
                .first,
          );
          expect(
            scrollable.position.maxScrollExtent,
            greaterThan(_scrollDistance),
          );
          final double before = tester.getBottomLeft(_firstTombstone()).dy;
          scrollable.position.jumpTo(_scrollDistance);
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(
            before - tester.getBottomLeft(_firstTombstone()).dy,
            closeTo(_scrollDistance, _tolerance),
            reason: 'the scroll moved the stone',
          );
          contentBox = _contentBox(tester);
          expect(
            _horizon(tester, contentBox),
            closeTo(_stoneBoxBottom(tester, contentBox), _tolerance),
            reason: 'scale $scale after scrolling',
          );
        }
        // The control block grows with the text scale, so a Horizon that
        // follows the Stone_Box bottom does not follow the control block.
        expect(blockHeights[1.0], isNot(closeTo(blockHeights[2.0]!, 1)));
        expect(blockHeights[2.0]!, greaterThan(blockHeights[1.0]!));
      });
    });
  }
}
