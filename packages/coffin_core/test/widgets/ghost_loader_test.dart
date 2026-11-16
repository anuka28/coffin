import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/theme/coffin_glow.dart';
import 'package:coffin_core/src/theme/wcag_contrast.dart';
import 'package:coffin_core/src/widgets/ghost_loader.dart';
import 'package:coffin_core/src/widgets/ghost_painter.dart';
import 'package:coffin_core/src/widgets/math/ghost_bob.dart';
import 'package:coffin_core/src/widgets/motion_loop.dart';
import 'package:coffin_core/src/widgets/spooky_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsHandle, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

Finder get _paintFinder => find.descendant(
  of: find.byType(GhostLoader),
  matching: find.byType(CustomPaint),
);

CustomPaint _paint(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paintFinder);

GhostPainter _painter(WidgetTester tester) =>
    _paint(tester).painter! as GhostPainter;

MotionLoop<GhostLoader> _loop(WidgetTester tester) =>
    tester.state(find.byType(GhostLoader)) as MotionLoop<GhostLoader>;

Widget _centered(Widget child) => Center(child: child);

const Duration _settle = Duration(milliseconds: 300);

void main() {
  group('ghost contrast (decision N3)', () {
    for (final CoffinColorTokens tokens in <CoffinColorTokens>[
      CoffinColorTokens.night,
      CoffinColorTokens.daylight,
    ]) {
      test('${tokens.name}: body and eyes are at least 3.0 apart', () {
        final int body = SpookyTokens.ghostBody(tokens).toARGB32();
        final int background = tokens.background.toARGB32();
        final double bodyOnBackground = WcagContrast.ratio(body, background);
        final double eyesOnBody = WcagContrast.ratio(background, body);
        expect(bodyOnBackground, greaterThanOrEqualTo(3.0));
        expect(eyesOnBody, greaterThanOrEqualTo(3.0));
      });
    }
  });

  group('painter colors', () {
    testWidgets('dark theme: body is text, eyes background, glow primary', (
      tester,
    ) async {
      await pumpSpooky(tester, _centered(const GhostLoader()));
      final GhostPainter painter = _painter(tester);
      const CoffinColorTokens t = CoffinColorTokens.night;
      expect(painter.bodyColor, t.text);
      expect(painter.eyeColor, t.background);
      expect(
        painter.glow,
        CoffinGlow.decoration(color: t.primary, intensity: 0.5).boxShadow,
      );
      for (final BoxShadow s in painter.glow) {
        expect(s.color.toARGB32() & 0xFFFFFF, t.primary.toARGB32() & 0xFFFFFF);
      }
    });

    testWidgets('light theme: body is primary, eyes background, glow primary', (
      tester,
    ) async {
      await pumpSpooky(
        tester,
        _centered(const GhostLoader()),
        brightness: Brightness.light,
      );
      final GhostPainter painter = _painter(tester);
      const CoffinColorTokens t = CoffinColorTokens.daylight;
      expect(painter.bodyColor, t.primary);
      expect(painter.eyeColor, t.background);
      expect(
        painter.glow,
        CoffinGlow.decoration(color: t.primary, intensity: 0.5).boxShadow,
      );
      for (final BoxShadow s in painter.glow) {
        expect(s.color.toARGB32() & 0xFFFFFF, t.primary.toARGB32() & 0xFFFFFF);
      }
    });
  });

  group('motion', () {
    testWidgets('reduced motion: static frame, caption shown, no ticks', (
      tester,
    ) async {
      await pumpSpooky(
        tester,
        _centered(const GhostLoader(caption: 'Summoning…')),
        reducedMotion: true,
      );
      await tester.pump(_settle);
      expect(tester.binding.transientCallbackCount, 0);
      expect(_painter(tester).bobOffset, GhostBob.staticOffset);
      expect(find.text('Summoning…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_painter(tester).bobOffset, GhostBob.staticOffset);
    });

    testWidgets('normal motion: one ticker and the bob offset moves', (
      tester,
    ) async {
      await pumpSpooky(tester, _centered(const GhostLoader()));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.binding.transientCallbackCount, 1);
      final double first = _painter(tester).bobOffset;
      await tester.pump(const Duration(milliseconds: 800));
      final double second = _painter(tester).bobOffset;
      expect(second, isNot(first));
    });

    testWidgets('leaves no ticker after being replaced by a SizedBox', (
      tester,
    ) async {
      await pumpSpooky(tester, _centered(const GhostLoader()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));
      await pumpSpooky(tester, const SizedBox());
      await tester.pump(_settle);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('follows disableAnimations while mounted', (tester) async {
      await pumpSpooky(tester, _centered(const GhostLoader()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));

      await pumpSpooky(
        tester,
        _centered(const GhostLoader()),
        reducedMotion: true,
      );
      await tester.pump(_settle);
      expect(tester.binding.transientCallbackCount, 0);
      expect(_painter(tester).bobOffset, GhostBob.staticOffset);

      await pumpSpooky(tester, _centered(const GhostLoader()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));
      expect(_loop(tester).loopController.isAnimating, isTrue);
    });

    testWidgets('keeps the controller running when bob settings change', (
      tester,
    ) async {
      await pumpSpooky(tester, _centered(const GhostLoader()));
      await tester.pump(const Duration(milliseconds: 500));
      final int before = _loop(tester).elapsedMs;
      expect(before, greaterThan(0));

      await pumpSpooky(
        tester,
        _centered(const GhostLoader(bobPeriodMs: 5000, bobAmplitude: 10)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_loop(tester).loopController.isAnimating, isTrue);
      final int mid = _loop(tester).elapsedMs;
      expect(mid, greaterThan(before));
      expect(_painter(tester).headroom, 10);

      await pumpSpooky(
        tester,
        _centered(const GhostLoader(bobPeriodMs: 2500, bobAmplitude: 3)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_loop(tester).elapsedMs, greaterThan(mid));
      expect(_painter(tester).headroom, 3);
    });
  });

  group('semantics', () {
    for (final String? caption in <String?>[null, 'Summoning your ghost…']) {
      testWidgets('one live-region node labelled ${caption ?? 'Loading'}', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpSpooky(tester, _centered(GhostLoader(caption: caption)));
        await tester.pump(const Duration(milliseconds: 100));

        final SemanticsNode node = tester.getSemantics(
          find.byType(GhostLoader),
        );
        expect(
          node,
          matchesSemantics(
            label: caption ?? 'Loading',
            isLiveRegion: true,
            hasEnabledState: false,
          ),
        );
        int children = 0;
        node.visitChildren((SemanticsNode child) {
          children++;
          return true;
        });
        expect(children, 0);
        expect(find.bySemanticsLabel(caption ?? 'Loading'), findsOneWidget);
        handle.dispose();
      });
    }
  });

  group('layout', () {
    testWidgets('no caption reserves no space', (tester) async {
      await pumpSpooky(tester, _centered(const GhostLoader()));
      expect(
        tester.getSize(find.byType(GhostLoader)).height,
        tester.getSize(_paintFinder).height,
      );
    });

    testWidgets('caption sits 8 px below the ghost box', (tester) async {
      await pumpSpooky(tester, _centered(const GhostLoader(caption: 'Boo')));
      final double ghostBottom = tester.getBottomLeft(_paintFinder).dy;
      final double textTop = tester.getTopLeft(find.text('Boo')).dy;
      expect(textTop - ghostBottom, 8);
    });

    testWidgets('render size is constant and the bob stays in headroom', (
      tester,
    ) async {
      await pumpSpooky(tester, _centered(const GhostLoader(caption: 'Boo')));
      final Size first = tester.getSize(find.byType(GhostLoader));
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.getSize(find.byType(GhostLoader)), first);
        final GhostPainter painter = _painter(tester);
        expect(painter.bobOffset.abs(), lessThanOrEqualTo(painter.headroom));
      }
    });

    final Map<String, (double, double)> sizes = <String, (double, double)>{
      '10': (10, 24),
      '24': (24, 24),
      '256': (256, 256),
      '400': (400, 256),
      'NaN': (double.nan, 64),
    };
    sizes.forEach((String name, (double, double) pair) {
      testWidgets('size $name is clamped to ${pair.$2}', (tester) async {
        await pumpSpooky(
          tester,
          _centered(GhostLoader(size: pair.$1)),
          height: 1000,
        );
        final Size box = tester.getSize(_paintFinder);
        expect(box.width, closeTo(0.8 * pair.$2, 1e-9));
        expect(box.height, pair.$2 + 2 * GhostBob.defaultAmplitude);
        expect(tester.takeException(), isNull);
      });
    });

    for (final Brightness brightness in Brightness.values) {
      for (final double width in testWidths) {
        for (final double scale in testTextScales) {
          for (final String? caption in <String?>[
            null,
            'Summoning your ghost from the deepest, dampest crypt of the '
                'forgotten graveyard, please wait a little longer…',
          ]) {
            testWidgets('no overflow: ${brightness.name} w$width x$scale '
                '${caption == null ? 'no caption' : 'long caption'}', (
              tester,
            ) async {
              await pumpSpooky(
                tester,
                _centered(GhostLoader(caption: caption)),
                brightness: brightness,
                width: width,
                textScale: scale,
              );
              await tester.pump(const Duration(milliseconds: 400));
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }
  });
}
