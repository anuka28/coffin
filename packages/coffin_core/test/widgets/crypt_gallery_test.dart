import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/theme/coffin_theme.dart';
import 'package:coffin_core/src/widgets/crypt_gallery.dart';
import 'package:coffin_core/src/widgets/crypt_gallery_panel.dart';
import 'package:coffin_core/src/widgets/flicker_text.dart';
import 'package:coffin_core/src/widgets/fog_background.dart';
import 'package:coffin_core/src/widgets/ghost_loader.dart';
import 'package:coffin_core/src/widgets/tombstone_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

const Duration _settle = Duration(milliseconds: 400);

Finder get _panels => find.byType(CryptGalleryPanel);
Finder get _night => _panels.at(0);
Finder get _daylight => _panels.at(1);

/// Lets the theme animation and the 300 ms card tweens finish.
Future<void> _settleAll(WidgetTester tester) async {
  for (int i = 0; i < 2; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(_settle);
  }
}

Color? _panelColor(WidgetTester tester, Finder panel) {
  final Finder material = find
      .descendant(of: panel, matching: find.byType(Material))
      .first;
  return tester.widget<Material>(material).color;
}

/// An element below the panel's own [Theme].
BuildContext _innerElement(WidgetTester tester, Finder panel) => tester.element(
  find.descendant(of: panel, matching: find.byType(Material)).first,
);

class _PushCounter extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  group('CryptGallery', () {
    testWidgets('shows a night panel and a daylight panel', (tester) async {
      await pumpSpooky(tester, const CryptGallery());
      await _settleAll(tester);

      expect(_panels, findsNWidgets(2));
      expect(_panelColor(tester, _night), CoffinColorTokens.night.background);
      expect(
        _panelColor(tester, _daylight),
        CoffinColorTokens.daylight.background,
      );
      expect(
        Theme.of(_innerElement(tester, _night)).brightness,
        Brightness.dark,
      );
      expect(
        Theme.of(_innerElement(tester, _daylight)).brightness,
        Brightness.light,
      );
    });

    testWidgets('daylight panel stays daylight inside a dark app', (
      tester,
    ) async {
      await pumpSpooky(
        tester,
        const CryptGallery(),
        brightness: Brightness.dark,
      );
      await _settleAll(tester);
      expect(
        _panelColor(tester, _daylight),
        CoffinColorTokens.daylight.background,
      );

      await pumpSpooky(
        tester,
        const CryptGallery(),
        brightness: Brightness.light,
      );
      await _settleAll(tester);
      expect(_panelColor(tester, _night), CoffinColorTokens.night.background);
    });

    testWidgets('stacks panels below 900 and places them side by side', (
      tester,
    ) async {
      await pumpSpooky(tester, const CryptGallery(), width: 899);
      await _settleAll(tester);
      final Offset stackedNight = tester.getTopLeft(_night);
      final Offset stackedDay = tester.getTopLeft(_daylight);
      expect(stackedDay.dx, stackedNight.dx);
      expect(stackedDay.dy, greaterThan(stackedNight.dy));

      for (final double width in <double>[900, 1280]) {
        await pumpSpooky(tester, const CryptGallery(), width: width);
        await _settleAll(tester);
        final Offset nightPos = tester.getTopLeft(_night);
        final Offset dayPos = tester.getTopLeft(_daylight);
        expect(dayPos.dy, nightPos.dy, reason: 'width $width');
        expect(dayPos.dx, greaterThan(nightPos.dx), reason: 'width $width');
      }
    });

    testWidgets('page title and both panel headings are semantic headers', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSpooky(tester, const CryptGallery());
      await _settleAll(tester);

      for (final String label in <String>[
        'Crypt gallery',
        'Night',
        'Daylight',
      ]) {
        expect(
          tester.getSemantics(find.text(label)),
          isSemantics(isHeader: true),
          reason: label,
        );
      }
      handle.dispose();
    });

    testWidgets('every sample appears in each panel', (tester) async {
      await pumpSpooky(tester, const CryptGallery());
      await _settleAll(tester);

      for (final Finder panel in <Finder>[_night, _daylight]) {
        Finder inPanel(Finder matching) =>
            find.descendant(of: panel, matching: matching);
        expect(inPanel(find.byType(GhostLoader)), findsNWidgets(2));
        expect(inPanel(find.text('Summoning your ghost…')), findsOneWidget);
        expect(inPanel(find.text('Old Todo App')), findsOneWidget);
        expect(inPanel(find.text('Died 214 days ago')), findsOneWidget);
        expect(
          inPanel(find.text('This project has been dead for 214 days')),
          findsOneWidget,
        );
        expect(inPanel(find.text('Weather Widget')), findsOneWidget);
        expect(inPanel(find.text('Abandoned last March')), findsOneWidget);
        expect(inPanel(find.byType(TombstoneCard)), findsNWidgets(2));
        expect(inPanel(find.byType(FlickerText)), findsOneWidget);
        expect(inPanel(find.byType(FogBackground)), findsOneWidget);
      }
    });

    testWidgets('both panels use the same seeds', (tester) async {
      await pumpSpooky(tester, const CryptGallery());
      await _settleAll(tester);

      for (final Finder panel in <Finder>[_night, _daylight]) {
        final FlickerText flicker = tester.widget<FlickerText>(
          find.descendant(of: panel, matching: find.byType(FlickerText)),
        );
        final FogBackground fog = tester.widget<FogBackground>(
          find.descendant(of: panel, matching: find.byType(FogBackground)),
        );
        expect(flicker.seed, 7);
        expect(fog.seed, 13);
      }
    });

    testWidgets(
      'the interactive card shows a snack bar and does not navigate',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1280, 800);
        addTearDown(tester.view.reset);
        final _PushCounter observer = _PushCounter();
        await tester.pumpWidget(
          MaterialApp(
            theme: CoffinTheme.dark(),
            navigatorObservers: <NavigatorObserver>[observer],
            home: const CryptGallery(),
          ),
        );
        await _settleAll(tester);
        final int pushesAtStart = observer.pushes;

        final Finder grave = find.text('Weather Widget').first;
        await tester.ensureVisible(grave);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(grave);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.text('The grave stirs, but nothing rises. Yet.'),
          findsOneWidget,
        );
        expect(observer.pushes, pushesAtStart);
        expect(find.byType(CryptGallery), findsOneWidget);
      },
    );

    testWidgets('Back to the crypt calls onBack once and is 48 by 48', (
      tester,
    ) async {
      int calls = 0;
      await pumpSpooky(tester, CryptGallery(onBack: () => calls++));
      await _settleAll(tester);

      final Finder button = find.widgetWithText(
        FilledButton,
        'Back to the crypt',
      );
      expect(button, findsOneWidget);
      final Size size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, 1);
    });

    testWidgets('no back button without onBack', (tester) async {
      await pumpSpooky(tester, const CryptGallery());
      await _settleAll(tester);
      expect(find.text('Back to the crypt'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('reduced motion leaves no running ticker', (tester) async {
      await pumpSpooky(tester, const CryptGallery(), reducedMotion: true);
      await _settleAll(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('no ticker survives removal of the page', (tester) async {
      await pumpSpooky(tester, const CryptGallery());
      await tester.pump(const Duration(milliseconds: 400));
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));

      await pumpSpooky(tester, const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('does not overflow at any width, scale or theme', (
      tester,
    ) async {
      for (final Brightness brightness in Brightness.values) {
        for (final double width in testWidths) {
          for (final double scale in testTextScales) {
            await pumpSpooky(
              tester,
              const CryptGallery(),
              brightness: brightness,
              width: width,
              textScale: scale,
            );
            await tester.pump(const Duration(milliseconds: 400));
            expect(
              tester.takeException(),
              isNull,
              reason: '$brightness $width x$scale',
            );
          }
        }
      }
    });

    testWidgets('scrolls vertically when taller than the viewport', (
      tester,
    ) async {
      await pumpSpooky(tester, const CryptGallery());
      await _settleAll(tester);

      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(scrollable.position.pixels, 0);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(scrollable.position.pixels, greaterThan(0));
    });
  });
}
