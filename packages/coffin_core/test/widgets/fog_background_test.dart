import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/widgets/fog_background.dart';
import 'package:coffin_core/src/widgets/math/fog_disc.dart';
import 'package:coffin_core/src/widgets/math/fog_field.dart';
import 'package:coffin_core/src/widgets/math/fog_particle.dart';
import 'package:coffin_core/src/widgets/motion_loop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsHandle, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

const Duration _settle = Duration(milliseconds: 300);

const String _longText =
    'Here lies a side project, mourned by nobody, haunting the corners of '
    'a forgotten repository, still waiting for one more commit…';

MotionLoop<FogBackground> _loop(WidgetTester tester) =>
    tester.state(find.byType(FogBackground)) as MotionLoop<FogBackground>;

Finder get _fogPaint => find
    .descendant(
      of: find.byType(FogBackground),
      matching: find.byType(CustomPaint),
    )
    .first;

RenderObject _fogRender(WidgetTester tester) => tester.renderObject(_fogPaint);

/// A pattern of [n] circles of any position.
PaintPattern _anyCircles(int n) {
  PaintPattern pattern = paints;
  for (int i = 0; i < n; i++) {
    pattern = pattern..circle();
  }
  return pattern;
}

/// The circles the fog must paint for [field] at [elapsedMs] in [size].
PaintPattern _expectedCircles(FogField field, int elapsedMs, Size size) {
  PaintPattern pattern = paints;
  for (final FogParticle p in field.particlesAt(elapsedMs)) {
    final FogDisc d = FogField.toBounds(p, size.width, size.height);
    pattern = pattern..circle(x: d.x, y: d.y, radius: d.radius);
  }
  return pattern;
}

Widget _sample({int seed = 0, int count = FogField.defaultCount}) =>
    FogBackground(
      seed: seed,
      particleCount: count,
      child: const SizedBox(width: 200, height: 120),
    );

Widget _centered(Widget child) => Center(child: child);

void main() {
  group('motion', () {
    testWidgets('reduced motion: static frame and no ticks', (tester) async {
      await pumpSpooky(
        tester,
        _centered(_sample(seed: 13)),
        reducedMotion: true,
      );
      await tester.pump(_settle);
      expect(tester.binding.transientCallbackCount, 0);
      final FogField field = FogField(seed: 13);
      const Size size = Size(200, 120);
      expect(_fogRender(tester), _expectedCircles(field, 0, size));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.binding.transientCallbackCount, 0);
      expect(_fogRender(tester), _expectedCircles(field, 0, size));
    });

    testWidgets('normal motion: the painted particles move', (tester) async {
      await pumpSpooky(tester, _centered(_sample(seed: 13)));
      await tester.pump(_settle);
      expect(tester.binding.transientCallbackCount, 1);
      final FogField field = FogField(seed: 13);
      const Size size = Size(200, 120);

      final int first = _loop(tester).elapsedMs;
      expect(_fogRender(tester), _expectedCircles(field, first, size));

      await tester.pump(const Duration(milliseconds: 4000));
      final int second = _loop(tester).elapsedMs;
      expect(second, greaterThan(first));
      expect(_fogRender(tester), _expectedCircles(field, second, size));
      expect(field.particlesAt(first), isNot(field.particlesAt(second)));
    });

    testWidgets('leaves no ticker after removal', (tester) async {
      await pumpSpooky(tester, _centered(_sample()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));
      await pumpSpooky(tester, const SizedBox());
      await tester.pump(_settle);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('follows disableAnimations while mounted', (tester) async {
      await pumpSpooky(tester, _centered(_sample()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));

      await pumpSpooky(tester, _centered(_sample()), reducedMotion: true);
      await tester.pump(_settle);
      expect(tester.binding.transientCallbackCount, 0);
      expect(_loop(tester).loopController.isAnimating, isFalse);

      await pumpSpooky(tester, _centered(_sample()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));
      expect(_loop(tester).loopController.isAnimating, isTrue);
    });

    testWidgets('changing the seed or the count keeps the controller running', (
      tester,
    ) async {
      await pumpSpooky(tester, _centered(_sample(seed: 1)));
      await tester.pump(const Duration(milliseconds: 500));
      final int before = _loop(tester).elapsedMs;
      expect(before, greaterThan(0));

      await pumpSpooky(tester, _centered(_sample(seed: 2)));
      await tester.pump(const Duration(milliseconds: 500));
      final int afterSeed = _loop(tester).elapsedMs;
      expect(_loop(tester).loopController.isAnimating, isTrue);
      expect(afterSeed, greaterThan(before));
      expect(
        _fogRender(tester),
        _expectedCircles(FogField(seed: 2), afterSeed, const Size(200, 120)),
      );

      await pumpSpooky(tester, _centered(_sample(seed: 2, count: 5)));
      await tester.pump(const Duration(milliseconds: 500));
      final int afterCount = _loop(tester).elapsedMs;
      expect(_loop(tester).loopController.isAnimating, isTrue);
      expect(afterCount, greaterThan(afterSeed));
      expect(
        _fogRender(tester),
        _expectedCircles(
          FogField(seed: 2, count: 5),
          afterCount,
          const Size(200, 120),
        ),
      );
    });
  });

  group('layout and input', () {
    testWidgets('child has the same size with and without the fog', (
      tester,
    ) async {
      const Widget text = Text('Boo');
      await pumpSpooky(tester, _centered(text));
      final Size bare = tester.getSize(find.text('Boo'));
      await pumpSpooky(tester, _centered(const FogBackground(child: text)));
      expect(tester.getSize(find.text('Boo')), bare);
      expect(tester.getSize(find.byType(FogBackground)), bare);
    });

    testWidgets('a tap reaches the child through the fog', (tester) async {
      int taps = 0;
      await pumpSpooky(
        tester,
        _centered(
          FogBackground(
            child: GestureDetector(
              key: const ValueKey<String>('child'),
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(width: 200, height: 120),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('child')));
      expect(taps, 1);
    });

    testWidgets('the fog adds no semantics node', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSpooky(
        tester,
        _centered(const FogBackground(child: Text('Boo'))),
      );
      await tester.pump(_settle);
      final SemanticsNode node = tester.getSemantics(find.text('Boo'));
      expect(node.label, 'Boo');
      int children = 0;
      node.visitChildren((SemanticsNode child) {
        children++;
        return true;
      });
      expect(children, 0);
      expect(find.bySemanticsLabel('Boo'), findsOneWidget);
      int siblings = 0;
      node.parent!.visitChildren((SemanticsNode child) {
        siblings++;
        return true;
      });
      expect(siblings, 1);
      handle.dispose();
    });

    testWidgets('the fog layer has its own RepaintBoundary', (tester) async {
      await pumpSpooky(
        tester,
        _centered(
          const FogBackground(
            child: SizedBox(key: ValueKey<String>('child'), width: 50),
          ),
        ),
      );
      final Finder boundary = find.ancestor(
        of: _fogPaint,
        matching: find.byType(RepaintBoundary),
      );
      final Finder inside = find.descendant(
        of: find.byType(FogBackground),
        matching: boundary,
      );
      expect(inside, findsOneWidget);
      expect(
        find.descendant(
          of: inside,
          matching: find.byKey(const ValueKey<String>('child')),
        ),
        findsNothing,
      );
    });

    for (final (double, double) box in <(double, double)>[(0, 100), (100, 0)]) {
      testWidgets('zero size ${box.$1} x ${box.$2} paints nothing', (
        tester,
      ) async {
        await pumpSpooky(
          tester,
          Center(
            child: SizedBox(
              width: box.$1,
              height: box.$2,
              child: const FogBackground(child: SizedBox.expand()),
            ),
          ),
        );
        await tester.pump(_settle);
        expect(tester.takeException(), isNull);
        expect(_fogRender(tester), isNot(_anyCircles(1)));
      });
    }

    testWidgets('negative particleCount paints none', (tester) async {
      await pumpSpooky(tester, _centered(_sample(count: -3)));
      await tester.pump(_settle);
      expect(tester.takeException(), isNull);
      expect(_fogRender(tester), isNot(_anyCircles(1)));
    });

    testWidgets('particleCount 30 paints 24', (tester) async {
      await pumpSpooky(tester, _centered(_sample(count: 30)));
      await tester.pump(_settle);
      expect(_fogRender(tester), _anyCircles(FogField.maxCount));
      expect(_fogRender(tester), isNot(_anyCircles(FogField.maxCount + 1)));
    });

    testWidgets('unbounded height and a 40 px parent do not throw', (
      tester,
    ) async {
      await pumpSpooky(
        tester,
        ListView(
          children: const <Widget>[
            FogBackground(child: SizedBox(height: 50, child: Text('Boo'))),
          ],
        ),
      );
      await tester.pump(_settle);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(FogBackground)).height, 50);

      await pumpSpooky(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(height: 40, child: FogBackground(child: Text('Boo'))),
        ),
      );
      await tester.pump(_settle);
      expect(tester.takeException(), isNull);
    });
  });

  group('theme', () {
    for (final (Brightness, CoffinColorTokens) pair
        in <(Brightness, CoffinColorTokens)>[
          (Brightness.dark, CoffinColorTokens.night),
          (Brightness.light, CoffinColorTokens.daylight),
        ]) {
      testWidgets('uses primary of ${pair.$2.name}', (tester) async {
        await pumpSpooky(tester, _centered(_sample()), brightness: pair.$1);
        final CustomPaint paint = tester.widget<CustomPaint>(_fogPaint);
        expect((paint.painter as dynamic).color, pair.$2.primary);
      });
    }
  });

  group('layout matrix', () {
    for (final Brightness brightness in Brightness.values) {
      for (final double width in testWidths) {
        for (final double scale in testTextScales) {
          testWidgets('no overflow: ${brightness.name} w$width x$scale', (
            tester,
          ) async {
            await pumpSpooky(
              tester,
              _centered(const FogBackground(seed: 5, child: Text(_longText))),
              brightness: brightness,
              width: width,
              textScale: scale,
            );
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
