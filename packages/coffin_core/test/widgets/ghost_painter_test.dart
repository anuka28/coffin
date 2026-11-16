import 'package:coffin_core/src/widgets/ghost_painter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _body = Color(0xFFFFFFFF);
const Color _eye = Color(0xFF000000);
const BoxShadow _shadowA = BoxShadow(
  color: Color(0xFF9B6BFF),
  blurRadius: 12,
  spreadRadius: 2,
);
const BoxShadow _shadowB = BoxShadow(
  color: Color(0xFF7CFFB2),
  blurRadius: 24,
  offset: Offset(0, 2),
);

GhostPainter _painter({
  Color body = _body,
  Color eye = _eye,
  List<BoxShadow> glow = const <BoxShadow>[],
  double bob = 0,
  double headroom = 0,
}) {
  return GhostPainter(
    bodyColor: body,
    eyeColor: eye,
    glow: glow,
    bobOffset: bob,
    headroom: headroom,
  );
}

Future<RenderObject> _pump(
  WidgetTester tester,
  GhostPainter painter, {
  double width = 80,
  double height = 100,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(key: const Key('ghost'), painter: painter),
        ),
      ),
    ),
  );
  return tester.renderObject(find.byKey(const Key('ghost')));
}

void main() {
  group('GhostPainter.shouldRepaint', () {
    final GhostPainter base = _painter(
      glow: const <BoxShadow>[_shadowA],
      bob: 2,
      headroom: 4,
    );

    test('is false for equal inputs', () {
      final GhostPainter same = _painter(
        glow: const <BoxShadow>[_shadowA],
        bob: 2,
        headroom: 4,
      );
      expect(same.shouldRepaint(base), isFalse);
    });

    test('is true for each changed field', () {
      final List<GhostPainter> changed = <GhostPainter>[
        _painter(
          body: const Color(0xFF123456),
          glow: const <BoxShadow>[_shadowA],
          bob: 2,
          headroom: 4,
        ),
        _painter(
          eye: const Color(0xFF123456),
          glow: const <BoxShadow>[_shadowA],
          bob: 2,
          headroom: 4,
        ),
        _painter(glow: const <BoxShadow>[_shadowA], bob: 3, headroom: 4),
        _painter(glow: const <BoxShadow>[_shadowA], bob: 2, headroom: 5),
        _painter(glow: const <BoxShadow>[_shadowB], bob: 2, headroom: 4),
        _painter(bob: 2, headroom: 4),
      ];
      for (final GhostPainter painter in changed) {
        expect(painter.shouldRepaint(base), isTrue);
      }
    });
  });

  group('GhostPainter.paint', () {
    testWidgets('draws body path and two eyes at a normal size', (
      WidgetTester tester,
    ) async {
      final RenderObject box = await _pump(
        tester,
        _painter(headroom: 6, bob: 3),
      );
      expect(
        box,
        paints
          ..path(color: _body)
          ..circle(color: _eye)
          ..circle(color: _eye),
      );
    });

    testWidgets('draws one extra path per glow shadow', (
      WidgetTester tester,
    ) async {
      final RenderObject box = await _pump(
        tester,
        _painter(glow: const <BoxShadow>[_shadowA, _shadowB], headroom: 6),
      );
      expect(
        box,
        paints
          ..path()
          ..path()
          ..path(color: _body)
          ..circle()
          ..circle(),
      );
    });

    testWidgets('draws nothing for Size.zero', (WidgetTester tester) async {
      final RenderObject box = await _pump(
        tester,
        _painter(headroom: 6),
        width: 0,
        height: 0,
      );
      expect(box, paintsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws nothing for a zero width', (WidgetTester tester) async {
      final RenderObject box = await _pump(
        tester,
        _painter(glow: const <BoxShadow>[_shadowA]),
        width: 0,
      );
      expect(box, paintsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws nothing for a zero height', (WidgetTester tester) async {
      final RenderObject box = await _pump(
        tester,
        _painter(glow: const <BoxShadow>[_shadowA]),
        height: 0,
      );
      expect(box, paintsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws nothing when headroom leaves no room', (
      WidgetTester tester,
    ) async {
      final RenderObject box = await _pump(
        tester,
        _painter(headroom: 50),
        height: 100,
      );
      expect(box, paintsNothing);
    });

    testWidgets('does not throw for a NaN bob offset', (
      WidgetTester tester,
    ) async {
      final RenderObject box = await _pump(
        tester,
        _painter(bob: double.nan, headroom: 6),
      );
      expect(tester.takeException(), isNull);
      expect(
        box,
        paints
          ..path()
          ..circle()
          ..circle(),
      );
    });

    testWidgets('does not throw for a bob offset far beyond headroom', (
      WidgetTester tester,
    ) async {
      final RenderObject box = await _pump(
        tester,
        _painter(bob: 1e9, headroom: 6),
      );
      expect(tester.takeException(), isNull);
      expect(
        box,
        paints
          ..path()
          ..circle()
          ..circle(),
      );
      await _pump(tester, _painter(bob: -1e9, headroom: 6));
      expect(tester.takeException(), isNull);
    });
  });
}
