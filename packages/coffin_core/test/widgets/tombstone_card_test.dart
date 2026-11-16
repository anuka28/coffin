import 'dart:ui' show PointerDeviceKind;

import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/theme/coffin_metrics.dart';
import 'package:coffin_core/src/widgets/tombstone_border.dart';
import 'package:coffin_core/src/widgets/tombstone_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

const Duration _settle = Duration(milliseconds: 400);

Finder get _decoratedFinder => find
    .descendant(
      of: find.byType(TombstoneCard),
      matching: find.byWidgetPredicate(
        (Widget w) => w is DecoratedBox && w.decoration is ShapeDecoration,
      ),
    )
    .first;

ShapeDecoration _decoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(_decoratedFinder).decoration as ShapeDecoration;

/// Glow intensity recovered from the blur radius of the inner shadow
/// (`8 + 16 * intensity`).
double _intensity(WidgetTester tester) =>
    (_decoration(tester).shadows!.first.blurRadius - 8) / 16;

Color _fill(WidgetTester tester) => _decoration(tester).color!;

BorderSide _side(WidgetTester tester) =>
    (_decoration(tester).shape as TombstoneBorder).side;

Finder get _clickRegion => find.descendant(
  of: find.byType(TombstoneCard),
  matching: find.byWidgetPredicate(
    (Widget w) => w is MouseRegion && w.cursor == SystemMouseCursors.click,
  ),
);

/// Pumps until every 300 ms animation, including one started by a theme
/// change or by another animation ending, has finished.
Future<void> _settleAll(WidgetTester tester) async {
  for (int i = 0; i < 2; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(_settle);
  }
}

/// Hovers the card with a mouse.
///
/// The test binding starts in touch highlight mode (the host platform is
/// Android) and a mouse hover without a press does not switch it, so the
/// traditional mode of a desktop or web browser with a mouse is set here.
Future<TestGesture> _hover(WidgetTester tester) async {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: const Offset(1, 1));
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(_decoratedFinder));
  await tester.pump();
  return gesture;
}

Future<void> _focusByTab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

double _textHeight(WidgetTester tester, Finder finder) =>
    tester.getSize(finder).height;

void main() {
  const CoffinColorTokens night = CoffinColorTokens.night;

  group('content and layout', () {
    testWidgets('title, date line and child are ordered top to bottom', (
      tester,
    ) async {
      await pumpSpooky(
        tester,
        const TombstoneCard(
          title: 'Old Todo App',
          dateLine: 'Died 214 days ago',
          child: Text('Body'),
        ),
      );
      final double title = tester.getTopLeft(find.text('Old Todo App')).dy;
      final double date = tester.getTopLeft(find.text('Died 214 days ago')).dy;
      final double body = tester.getTopLeft(find.text('Body')).dy;
      expect(title, lessThan(date));
      expect(date, lessThan(body));
      expect(
        body - tester.getBottomLeft(find.text('Died 214 days ago')).dy,
        12,
      );
    });

    testWidgets('a missing date line and child reserve no space', (
      tester,
    ) async {
      await pumpSpooky(tester, const TombstoneCard(title: 'Only title'));
      final double titleHeight = _textHeight(tester, find.text('Only title'));
      expect(tester.getSize(_decoratedFinder).height, 56 + titleHeight + 20);

      await pumpSpooky(
        tester,
        const TombstoneCard(title: 'Only title', dateLine: 'Date'),
      );
      final double dateHeight = _textHeight(tester, find.text('Date'));
      expect(
        tester.getSize(_decoratedFinder).height,
        56 + titleHeight + dateHeight + 20,
      );

      await pumpSpooky(
        tester,
        const TombstoneCard(
          title: 'Only title',
          child: SizedBox(height: 30, width: 30),
        ),
      );
      expect(
        tester.getSize(_decoratedFinder).height,
        56 + titleHeight + 12 + 30 + 20,
      );
    });

    testWidgets('a long title keeps 3 lines and a long date 2, with ellipsis', (
      tester,
    ) async {
      final String longTitle = List<String>.filled(40, 'Grave').join(' ');
      final String longDate = List<String>.filled(40, 'Ancient').join(' ');
      await pumpSpooky(
        tester,
        TombstoneCard(title: longTitle, dateLine: longDate),
      );
      final RenderParagraph title = tester.renderObject<RenderParagraph>(
        find.text(longTitle),
      );
      final RenderParagraph date = tester.renderObject<RenderParagraph>(
        find.text(longDate),
      );
      expect(title.maxLines, 3);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(title.didExceedMaxLines, isTrue);
      expect(date.maxLines, 2);
      expect(date.overflow, TextOverflow.ellipsis);
      expect(date.didExceedMaxLines, isTrue);

      await pumpSpooky(tester, const TombstoneCard(title: 'One'));
      final double oneLine = _textHeight(tester, find.text('One'));
      await pumpSpooky(
        tester,
        TombstoneCard(title: longTitle, dateLine: longDate),
      );
      expect(
        _textHeight(tester, find.text(longTitle)),
        closeTo(3 * oneLine, 0.5),
      );
    });

    testWidgets('is at most 360 wide and centered in a wider parent', (
      tester,
    ) async {
      await pumpSpooky(tester, const TombstoneCard(title: 'Wide'), width: 1280);
      final Rect rect = tester.getRect(_decoratedFinder);
      expect(rect.width, lessThanOrEqualTo(360));
      expect(rect.center.dx, closeTo(640, 0.5));

      await pumpSpooky(
        tester,
        const TombstoneCard(title: 'Narrow'),
        width: 320,
      );
      expect(tester.getRect(_decoratedFinder).width, 320);
    });

    testWidgets('survives a 60 px high parent and stays scrollable', (
      tester,
    ) async {
      await pumpSpooky(
        tester,
        const Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 60,
            child: TombstoneCard(
              title: 'Squeezed',
              dateLine: 'Tight',
              child: Text('More'),
            ),
          ),
        ),
      );
      await _settleAll(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_decoratedFinder).height, 60);
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(TombstoneCard),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
    });

    for (final Brightness brightness in Brightness.values) {
      for (final double width in testWidths) {
        for (final double scale in testTextScales) {
          testWidgets('no overflow: ${brightness.name} w$width x$scale', (
            tester,
          ) async {
            await pumpSpooky(
              tester,
              TombstoneCard(
                title: List<String>.filled(30, 'Haunted').join(' '),
                dateLine: List<String>.filled(30, 'Forgotten').join(' '),
                onTap: () {},
                child: const Text('A long line of text for the grave body'),
              ),
              brightness: brightness,
              width: width,
              textScale: scale,
            );
            await _settleAll(tester);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('visual states', () {
    testWidgets('resting uses surface, 1 px muted outline and glow 0.30', (
      tester,
    ) async {
      await pumpSpooky(tester, TombstoneCard(title: 'Rest', onTap: () {}));
      await _settleAll(tester);
      expect(_intensity(tester), closeTo(0.30, 1e-9));
      expect(_fill(tester), night.surface);
      expect(_side(tester).color, night.muted);
      expect(_side(tester).width, 1);
    });

    testWidgets('hover raises the glow and shows the click cursor', (
      tester,
    ) async {
      await pumpSpooky(tester, TombstoneCard(title: 'Hover', onTap: () {}));
      await _settleAll(tester);
      expect(_clickRegion, findsOneWidget);
      final double resting = _intensity(tester);

      final TestGesture gesture = await _hover(tester);
      await _settleAll(tester);
      expect(_intensity(tester), closeTo(0.55, 1e-9));
      expect(_intensity(tester), greaterThan(resting));
      expect(_fill(tester), night.surface);
      expect(
        tester.binding.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );

      await gesture.moveTo(const Offset(1, 1));
      await _settleAll(tester);
      expect(_intensity(tester), closeTo(0.30, 1e-9));
    });

    testWidgets('pressed uses raised and a higher glow than hover', (
      tester,
    ) async {
      await pumpSpooky(tester, TombstoneCard(title: 'Press', onTap: () {}));
      await _settleAll(tester);
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(_decoratedFinder),
      );
      await tester.pump();
      await _settleAll(tester);
      expect(_fill(tester), night.raised);
      expect(_intensity(tester), closeTo(0.80, 1e-9));
      expect(_intensity(tester), greaterThan(0.55));
      await gesture.up();
      await _settleAll(tester);
      expect(_fill(tester), night.surface);
    });

    testWidgets('keyboard focus shows a primary ring of the focus width', (
      tester,
    ) async {
      await pumpSpooky(tester, TombstoneCard(title: 'Focus', onTap: () {}));
      await _settleAll(tester);
      await _focusByTab(tester);
      await _settleAll(tester);
      expect(_side(tester).width, CoffinMetrics.focusRingWidth);
      expect(_side(tester).color, night.primary);
    });

    testWidgets('a non-interactive card has no cursor, focus or states', (
      tester,
    ) async {
      await pumpSpooky(tester, const TombstoneCard(title: 'Plain'));
      await _settleAll(tester);
      expect(_clickRegion, findsNothing);
      expect(
        find.descendant(
          of: find.byType(TombstoneCard),
          matching: find.byType(FocusableActionDetector),
        ),
        findsNothing,
      );
      await _hover(tester);
      await _settleAll(tester);
      expect(_intensity(tester), closeTo(0.30, 1e-9));
    });

    testWidgets('both themes use the matching token colors', (tester) async {
      for (final (Brightness, CoffinColorTokens) pair
          in <(Brightness, CoffinColorTokens)>[
            (Brightness.dark, CoffinColorTokens.night),
            (Brightness.light, CoffinColorTokens.daylight),
          ]) {
        await pumpSpooky(
          tester,
          TombstoneCard(title: 'Theme', onTap: () {}),
          brightness: pair.$1,
        );
        await _settleAll(tester);
        expect(_fill(tester), pair.$2.surface);
        expect(_side(tester).color, pair.$2.muted);
        final Color glow = _decoration(tester).shadows!.first.color;
        expect(
          glow.toARGB32() & 0xFFFFFF,
          pair.$2.primary.toARGB32() & 0xFFFFFF,
        );

        final TestGesture g = await tester.startGesture(
          tester.getCenter(_decoratedFinder),
        );
        await tester.pump();
        await _settleAll(tester);
        expect(_fill(tester), pair.$2.raised);
        await g.up();
        await _settleAll(tester);
      }
    });
  });

  group('activation', () {
    testWidgets('tap calls onTap once', (tester) async {
      int taps = 0;
      await pumpSpooky(
        tester,
        TombstoneCard(title: 'Tap', onTap: () => taps++),
      );
      await tester.tap(_decoratedFinder);
      await _settleAll(tester);
      expect(taps, 1);
    });

    for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
    ]) {
      testWidgets('${key.keyLabel.isEmpty ? key.debugName : key.keyLabel} '
          'calls onTap once per press and ignores repeats', (tester) async {
        int taps = 0;
        await pumpSpooky(
          tester,
          TombstoneCard(title: 'Key', onTap: () => taps++),
        );
        await _focusByTab(tester);

        await tester.sendKeyDownEvent(key);
        await tester.pump();
        await tester.sendKeyRepeatEvent(key);
        await tester.sendKeyRepeatEvent(key);
        await _settleAll(tester);
        expect(taps, 0, reason: 'activation happens on key up');
        expect(_fill(tester), night.raised);
        await tester.sendKeyUpEvent(key);
        await _settleAll(tester);
        expect(taps, 1);
        expect(_fill(tester), night.surface);

        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(taps, 2);
      });
    }

    testWidgets('other keys do not activate', (tester) async {
      int taps = 0;
      await pumpSpooky(
        tester,
        TombstoneCard(title: 'Key', onTap: () => taps++),
      );
      await _focusByTab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(taps, 0);
    });
  });

  group('hit area', () {
    testWidgets('interactive card is at least 48 x 48 with a tiny child', (
      tester,
    ) async {
      await pumpSpooky(
        tester,
        TombstoneCard(title: '', onTap: () {}, child: const SizedBox.shrink()),
      );
      final Size size = tester.getSize(_decoratedFinder);
      expect(size.width, greaterThanOrEqualTo(CoffinMetrics.minTapTarget));
      expect(size.height, greaterThanOrEqualTo(CoffinMetrics.minTapTarget));
      final ConstrainedBox box = tester.widget<ConstrainedBox>(
        find
            .descendant(
              of: find.byType(TombstoneCard),
              matching: find.byWidgetPredicate(
                (Widget w) =>
                    w is ConstrainedBox && w.constraints.maxWidth == 360,
              ),
            )
            .first,
      );
      expect(box.constraints.minWidth, CoffinMetrics.minTapTarget);
      expect(box.constraints.minHeight, CoffinMetrics.minTapTarget);
    });

    testWidgets('a non-interactive card does not constrain to 48', (
      tester,
    ) async {
      await pumpSpooky(tester, const TombstoneCard(title: 'Plain'));
      final ConstrainedBox box = tester.widget<ConstrainedBox>(
        find
            .descendant(
              of: find.byType(TombstoneCard),
              matching: find.byWidgetPredicate(
                (Widget w) =>
                    w is ConstrainedBox && w.constraints.maxWidth == 360,
              ),
            )
            .first,
      );
      expect(box.constraints.minWidth, 0);
      expect(box.constraints.minHeight, 0);
    });
  });

  group('semantics', () {
    testWidgets('interactive: button, focusable, tap action, joined label', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSpooky(
        tester,
        TombstoneCard(
          title: 'Weather Widget',
          dateLine: 'Abandoned last March',
          onTap: () {},
        ),
      );
      await _settleAll(tester);
      final SemanticsNode node = tester.getSemantics(
        find.byType(TombstoneCard),
      );
      expect(
        node,
        matchesSemantics(
          label: 'Weather Widget, Abandoned last March',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('label is the title alone without a date line', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSpooky(tester, TombstoneCard(title: 'Solo', onTap: () {}));
      await _settleAll(tester);
      expect(
        tester.getSemantics(find.byType(TombstoneCard)),
        matchesSemantics(
          label: 'Solo',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('semanticLabel overrides the default label', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSpooky(
        tester,
        TombstoneCard(
          title: 'Title',
          dateLine: 'Date',
          semanticLabel: 'Open the grave',
          onTap: () {},
        ),
      );
      await _settleAll(tester);
      expect(
        tester.getSemantics(find.byType(TombstoneCard)),
        matchesSemantics(
          label: 'Open the grave',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('non-interactive: no button flag and no tap action', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSpooky(
        tester,
        const TombstoneCard(title: 'Plain title', dateLine: 'Plain date'),
      );
      await _settleAll(tester);
      for (final String text in <String>['Plain title', 'Plain date']) {
        final data = tester.getSemantics(find.text(text)).getSemanticsData();
        expect(data.flagsCollection.isButton, isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
      }
      expect(find.bySemanticsLabel('Plain title'), findsOneWidget);
      handle.dispose();
    });
  });

  group('onTap becomes null', () {
    testWidgets('while hovered, returns to the plain resting state', (
      tester,
    ) async {
      await pumpSpooky(tester, TombstoneCard(title: 'Gone', onTap: () {}));
      await _hover(tester);
      await _settleAll(tester);
      expect(_intensity(tester), closeTo(0.55, 1e-9));

      await pumpSpooky(tester, const TombstoneCard(title: 'Gone'));
      await _settleAll(tester);
      expect(tester.takeException(), isNull);
      expect(_intensity(tester), closeTo(0.30, 1e-9));
      expect(_fill(tester), night.surface);
      expect(_side(tester).width, 1);
      expect(_clickRegion, findsNothing);
    });

    testWidgets('while pressed, returns to the plain resting state', (
      tester,
    ) async {
      await pumpSpooky(tester, TombstoneCard(title: 'Gone', onTap: () {}));
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(_decoratedFinder),
      );
      await _settleAll(tester);
      expect(_fill(tester), night.raised);

      await pumpSpooky(tester, const TombstoneCard(title: 'Gone'));
      await _settleAll(tester);
      expect(_fill(tester), night.surface);
      expect(_intensity(tester), closeTo(0.30, 1e-9));
      await gesture.up();
      await _settleAll(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('while focused, the ring disappears', (tester) async {
      await pumpSpooky(tester, TombstoneCard(title: 'Gone', onTap: () {}));
      await _focusByTab(tester);
      await _settleAll(tester);
      expect(_side(tester).width, CoffinMetrics.focusRingWidth);

      await pumpSpooky(tester, const TombstoneCard(title: 'Gone'));
      await _settleAll(tester);
      expect(_side(tester).width, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('motion', () {
    testWidgets('reduced motion switches states at once and still shows them', (
      tester,
    ) async {
      await pumpSpooky(
        tester,
        TombstoneCard(title: 'Calm', onTap: () {}),
        reducedMotion: true,
      );
      await _settleAll(tester);
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(_decoratedFinder),
      );
      await tester.pump();
      expect(_fill(tester), night.raised);
      expect(_intensity(tester), closeTo(0.80, 1e-9));
      await gesture.up();
      await tester.pump();
      expect(_fill(tester), night.surface);
      expect(_intensity(tester), closeTo(0.30, 1e-9));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('normal motion eases over 300 ms', (tester) async {
      await pumpSpooky(tester, TombstoneCard(title: 'Ease', onTap: () {}));
      await _settleAll(tester);
      await _hover(tester);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 150));
      final double mid = _intensity(tester);
      expect(mid, greaterThan(0.30));
      expect(mid, lessThan(0.55));
      await tester.pump(const Duration(milliseconds: 160));
      expect(_intensity(tester), closeTo(0.55, 1e-9));
    });

    testWidgets('a resting card leaves no ticker running', (tester) async {
      await pumpSpooky(
        tester,
        TombstoneCard(title: 'Still', dateLine: 'Quiet', onTap: () {}),
      );
      await _settleAll(tester);
      expect(tester.binding.transientCallbackCount, 0);
      await pumpSpooky(tester, const TombstoneCard(title: 'Still'));
      await _settleAll(tester);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
