import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/arch_epitaph.dart';

Future<void> _pump(
  WidgetTester tester,
  double width,
  double scale, {
  double angle = 0,
}) => tester.pumpWidget(
  MaterialApp(
    theme: CoffinTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 400,
          child: Transform.rotate(angle: angle, child: const ArchEpitaph()),
        ),
      ),
    ),
  ),
);

void main() {
  for (final width in [240.0, 270.0, 300.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('shows R.I.P. inside the stone at $width x $scale', (
        tester,
      ) async {
        await _pump(tester, width, scale);
        expect(tester.takeException(), isNull);
        expect(find.text('R.I.P.'), findsOneWidget);
        final box = tester.getRect(find.byType(ArchEpitaph));
        final text = tester.getRect(find.text('R.I.P.'));
        expect(text.left, greaterThanOrEqualTo(box.left - 0.01));
        expect(text.right, lessThanOrEqualTo(box.right + 0.01));
        expect(text.top, greaterThanOrEqualTo(box.top));
        expect(text.bottom, lessThanOrEqualTo(box.bottom));

        final rect = ArchEpitaph.rectFor(
          width: width,
          textScaler: TextScaler.linear(scale),
        );
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, greaterThan(rect.top));
        expect(find.byType(ExcludeSemantics), findsWidgets);

        // Geometric check mirroring ArchFit: both upper corners of the text
        // lie inside the half-ellipse arch (semi-axes rx and min(140, rx)).
        final rx = width / 2;
        final ry = math.min(ArchEpitaph.archRise, rx);
        for (final x in [text.left - box.left, text.right - box.left]) {
          final nx = (x - rx) / rx;
          final ny = (text.top - box.top - ry) / ry;
          expect(
            nx * nx + ny * ny,
            lessThanOrEqualTo(1.0),
            reason: 'upper corner at x=$x is outside the arch',
          );
        }

        // Not clipped: the paragraph is wide enough for the whole string.
        final widget = tester.widget<Text>(find.text('R.I.P.'));
        expect(widget.data, 'R.I.P.');
        final painter = TextPainter(
          text: TextSpan(text: 'R.I.P.', style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        expect(text.width, greaterThanOrEqualTo(painter.width - 0.01));
        expect(text.height, greaterThanOrEqualTo(painter.height - 0.01));
        painter.dispose();
        final render = tester.renderObject<RenderParagraph>(
          find.text('R.I.P.'),
        );
        expect(render.didExceedMaxLines, isFalse);

        // Not exposed as a semantic node.
        final handle = tester.ensureSemantics();
        expect(find.semantics.byLabel('R.I.P.'), findsNothing);
        handle.dispose();
      });
    }
  }

  testWidgets('never wraps and stays on one line at a tiny width', (
    tester,
  ) async {
    await _pump(tester, 60, 2);
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('rotates with a tilted tombstone', (tester) async {
    await _pump(tester, 270, 1);
    final flatLeft = tester.getTopLeft(find.text('R.I.P.'));
    final flatRight = tester.getTopRight(find.text('R.I.P.'));
    expect((flatRight - flatLeft).direction, closeTo(0, 1e-6));

    const angle = 0.1;
    await _pump(tester, 270, 1, angle: angle);
    final left = tester.getTopLeft(find.text('R.I.P.'));
    final right = tester.getTopRight(find.text('R.I.P.'));
    expect((right - left).direction, closeTo(angle, 1e-6));
    expect(tester.takeException(), isNull);
  });
}
