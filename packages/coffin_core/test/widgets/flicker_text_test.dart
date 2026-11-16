import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/theme/coffin_typography.dart';
import 'package:coffin_core/src/widgets/flicker_text.dart';
import 'package:coffin_core/src/widgets/math/flicker_schedule.dart';
import 'package:coffin_core/src/widgets/motion_loop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsHandle, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

Finder _opacityOf(Finder flicker) =>
    find.descendant(of: flicker, matching: find.byType(Opacity));

double _opacity(WidgetTester tester, [Finder? flicker]) => tester
    .widget<Opacity>(_opacityOf(flicker ?? find.byType(FlickerText)))
    .opacity;

MotionLoop<FlickerText> _loop(WidgetTester tester) =>
    tester.state(find.byType(FlickerText)) as MotionLoop<FlickerText>;

Widget _centered(Widget child) => Center(child: child);

const Duration _settle = Duration(milliseconds: 300);

const String _longText =
    'The candle is not out yet, though the wind has been trying all night '
    'to blow it out, again and again, across the whole forgotten graveyard…';

void main() {
  group('motion', () {
    testWidgets('reduced motion: full opacity and no ticks', (tester) async {
      await pumpSpooky(
        tester,
        _centered(const FlickerText('Boo', seed: 3)),
        reducedMotion: true,
      );
      await tester.pump(_settle);
      expect(tester.binding.transientCallbackCount, 0);
      expect(_opacityOf(find.byType(FlickerText)), findsNothing);
      expect(find.text('Boo'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.binding.transientCallbackCount, 0);
      expect(_opacityOf(find.byType(FlickerText)), findsNothing);
    });

    testWidgets('normal motion: opacity changes and stays in 0.75..1.0', (
      tester,
    ) async {
      await pumpSpooky(tester, _centered(const FlickerText('Boo', seed: 5)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 1);
      final Set<double> seen = <double>{};
      for (int i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        final double o = _opacity(tester);
        expect(o, inInclusiveRange(0.75, 1.0));
        expect(o, FlickerSchedule(5).opacityAt(_loop(tester).elapsedMs));
        seen.add(o);
      }
      expect(seen.length, greaterThan(1));
    });

    testWidgets('render size is identical at every pumped opacity', (
      tester,
    ) async {
      await pumpSpooky(tester, _centered(const FlickerText('Boo', seed: 9)));
      final Size first = tester.getSize(find.byType(FlickerText));
      final Set<double> seen = <double>{};
      for (int i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.getSize(find.byType(FlickerText)), first);
        seen.add(_opacity(tester));
      }
      expect(seen.length, greaterThan(1));
    });

    testWidgets('same seed and same elapsed time give the same opacity', (
      tester,
    ) async {
      await pumpSpooky(
        tester,
        const Column(
          children: <Widget>[
            FlickerText('One', key: ValueKey<String>('a'), seed: 4),
            FlickerText('Two', key: ValueKey<String>('b'), seed: 4),
          ],
        ),
      );
      final Finder a = find.byKey(const ValueKey<String>('a'));
      final Finder b = find.byKey(const ValueKey<String>('b'));
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 450));
        expect(_opacity(tester, a), _opacity(tester, b));
      }
    });

    testWidgets('changing the seed keeps the controller running', (
      tester,
    ) async {
      await pumpSpooky(tester, _centered(const FlickerText('Boo', seed: 1)));
      await tester.pump(const Duration(milliseconds: 500));
      final int before = _loop(tester).elapsedMs;
      expect(before, greaterThan(0));

      await pumpSpooky(tester, _centered(const FlickerText('Boo', seed: 2)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_loop(tester).loopController.isAnimating, isTrue);
      final int after = _loop(tester).elapsedMs;
      expect(after, greaterThan(before));
      expect(_opacity(tester), FlickerSchedule(2).opacityAt(after));
    });

    testWidgets('leaves no ticker after removal', (tester) async {
      await pumpSpooky(tester, _centered(const FlickerText('Boo')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));
      await pumpSpooky(tester, const SizedBox());
      await tester.pump(_settle);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('follows disableAnimations while mounted', (tester) async {
      await pumpSpooky(tester, _centered(const FlickerText('Boo')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));

      await pumpSpooky(
        tester,
        _centered(const FlickerText('Boo')),
        reducedMotion: true,
      );
      await tester.pump(_settle);
      expect(tester.binding.transientCallbackCount, 0);
      expect(_opacityOf(find.byType(FlickerText)), findsNothing);

      await pumpSpooky(tester, _centered(const FlickerText('Boo')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));
      expect(_loop(tester).loopController.isAnimating, isTrue);
      expect(_opacityOf(find.byType(FlickerText)), findsOneWidget);
    });
  });

  group('style', () {
    for (final (Brightness, CoffinColorTokens) pair
        in <(Brightness, CoffinColorTokens)>[
          (Brightness.dark, CoffinColorTokens.night),
          (Brightness.light, CoffinColorTokens.daylight),
        ]) {
      testWidgets('default style is bodyLarge of ${pair.$2.name}', (
        tester,
      ) async {
        await pumpSpooky(
          tester,
          _centered(const FlickerText('Boo')),
          brightness: pair.$1,
        );
        final Text text = tester.widget<Text>(find.text('Boo'));
        expect(text.style, CoffinTypography.textTheme(pair.$2).bodyLarge);
      });
    }

    testWidgets('passes style, alignment, maxLines and overflow through', (
      tester,
    ) async {
      const TextStyle style = TextStyle(fontSize: 31);
      await pumpSpooky(
        tester,
        _centered(
          const FlickerText(
            'Boo',
            style: style,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      final Text text = tester.widget<Text>(find.text('Boo'));
      expect(text.style, style);
      expect(text.textAlign, TextAlign.end);
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('semantics', () {
    for (final bool reduced in <bool>[false, true]) {
      for (final int seed in <int>[0, 7]) {
        testWidgets('one node labelled with the text (seed $seed, '
            'reduced $reduced)', (tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          await pumpSpooky(
            tester,
            _centered(FlickerText('The candle', seed: seed)),
            reducedMotion: reduced,
          );
          for (int i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            final SemanticsNode node = tester.getSemantics(
              find.byType(FlickerText),
            );
            expect(node.label, 'The candle');
            int children = 0;
            node.visitChildren((SemanticsNode child) {
              children++;
              return true;
            });
            expect(children, 0);
            expect(find.bySemanticsLabel('The candle'), findsOneWidget);
          }
          handle.dispose();
        });
      }
    }
  });

  group('layout', () {
    for (final Brightness brightness in Brightness.values) {
      for (final double width in testWidths) {
        for (final double scale in testTextScales) {
          testWidgets('no overflow: ${brightness.name} w$width x$scale', (
            tester,
          ) async {
            await pumpSpooky(
              tester,
              _centered(const FlickerText(_longText, seed: 11)),
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
