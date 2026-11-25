import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/arch_epitaph.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const width = 270.0;
  const scaler = TextScaler.linear(1);

  test('omitting text matches passing GraveyardCopy.epitaph', () {
    final omitted = ArchEpitaph.rectFor(width: width, textScaler: scaler);
    final explicit = ArchEpitaph.rectFor(
      width: width,
      textScaler: scaler,
      text: GraveyardCopy.epitaph,
    );
    expect(GraveyardCopy.epitaph, 'R.I.P.');
    expect(explicit.left, omitted.left);
    expect(explicit.top, omitted.top);
    expect(explicit.right, omitted.right);
    expect(explicit.bottom, omitted.bottom);
  });

  test('custom text yields a finite, non-empty rect inside the stone', () {
    final rect = ArchEpitaph.rectFor(
      width: width,
      textScaler: scaler,
      text: 'RISEN',
    );
    for (final v in [rect.left, rect.top, rect.right, rect.bottom]) {
      expect(v.isFinite, isTrue);
    }
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(width));
    expect(rect.right, greaterThan(rect.left));
    expect(rect.bottom, greaterThan(rect.top));
  });

  Future<void> pumpEpitaph(WidgetTester tester, {String? text}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: CoffinTheme.dark(),
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 300,
              child: ArchEpitaph(text: text),
            ),
          ),
        ),
      );

  testWidgets('without text the widget draws R.I.P.', (tester) async {
    await pumpEpitaph(tester);
    expect(find.text('R.I.P.'), findsOneWidget);
  });

  testWidgets('with text the widget draws it inside rectFor', (tester) async {
    await pumpEpitaph(tester, text: 'RISEN');
    expect(find.text('R.I.P.'), findsNothing);
    expect(find.text('RISEN'), findsOneWidget);
    final box = tester.getRect(find.byType(ArchEpitaph));
    final drawn = tester.getRect(find.text('RISEN'));
    final rect = ArchEpitaph.rectFor(
      width: width,
      textScaler: scaler,
      text: 'RISEN',
    );
    expect(drawn.left - box.left, closeTo(rect.left, 0.01));
    expect(drawn.top - box.top, closeTo(rect.top, 0.01));
    expect(drawn.width, closeTo(rect.right - rect.left, 0.01));
  });

  Future<void> pumpRisen(WidgetTester tester, double w, double scale) =>
      tester.pumpWidget(
        MaterialApp(
          theme: CoffinTheme.dark(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: w,
                height: 400,
                child: const ArchEpitaph(text: 'RISEN'),
              ),
            ),
          ),
        ),
      );

  void expectOneLineInside(WidgetTester tester, double w) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text('RISEN'));
    expect(paragraph.didExceedMaxLines, isFalse);
    final box = tester.getRect(find.byType(ArchEpitaph));
    final drawn = tester.getRect(find.text('RISEN'));
    expect(drawn.left, greaterThanOrEqualTo(box.left - 0.01));
    expect(drawn.right, lessThanOrEqualTo(box.right + 0.01));
    final lines = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    expect(lines.length, 1);
  }

  testWidgets('RISEN fits on one line for widths 120 to 400', (tester) async {
    for (var w = 120.0; w <= 400; w += 20) {
      await pumpRisen(tester, w, 1);
      expectOneLineInside(tester, w);
    }
  });

  testWidgets('RISEN stays on one line up to text scale 2.0', (tester) async {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final w in [160.0, 270.0, 400.0]) {
        await pumpRisen(tester, w, scale);
        expect(
          tester.renderObject<RenderParagraph>(find.text('RISEN')).size.height,
          lessThan(80),
        );
        expectOneLineInside(tester, w);
      }
    }
  });
}
