import 'package:coffin_core/src/router/not_found_page.dart';
import 'package:coffin_core/src/theme/coffin_color_tokens.dart';
import 'package:coffin_core/src/theme/coffin_theme.dart';
import 'package:coffin_core/src/theme/coffin_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<GoRouter> pumpPage(
    WidgetTester tester, {
    ThemeData? theme,
    NotFoundPage page = const NotFoundPage(),
    Size? size,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final router = GoRouter(
      initialLocation: '/lost',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Text('home')),
        GoRoute(
          path: '/other',
          builder: (context, state) => const Text('other'),
        ),
        GoRoute(path: '/lost', builder: (context, state) => page),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: theme ?? CoffinTheme.dark(),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('copy and style', () {
    testWidgets('shows the heading in the display font', (tester) async {
      await pumpPage(tester);

      final heading = tester.widget<Text>(
        find.text('This page has passed on\u2026'),
      );
      expect(heading.style?.fontFamily, CoffinTypography.displayFamilyName);
    });

    testWidgets('shows default body copy in the body font', (tester) async {
      await pumpPage(tester);

      final body = tester.widget<Text>(find.text(NotFoundPage.defaultMessage));
      expect(body.style?.fontFamily, CoffinTypography.bodyFamilyName);
    });

    testWidgets('a message override replaces the default copy', (tester) async {
      await pumpPage(tester, page: const NotFoundPage(message: 'Boo. Gone.'));

      expect(find.text('Boo. Gone.'), findsOneWidget);
      expect(find.text(NotFoundPage.defaultMessage), findsNothing);
    });

    testWidgets('follows the dark theme', (tester) async {
      await pumpPage(tester, theme: CoffinTheme.dark());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final context = tester.element(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        CoffinColorTokens.night.background,
      );
    });

    testWidgets('follows the daylight theme', (tester) async {
      await pumpPage(tester, theme: CoffinTheme.light());

      final context = tester.element(find.byType(Scaffold));
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        CoffinColorTokens.daylight.background,
      );
      final body = tester.widget<Text>(find.text(NotFoundPage.defaultMessage));
      expect(
        body.style?.color,
        CoffinColorTokens.daylight.muted,
        reason: 'body copy takes onSurfaceVariant from the theme',
      );
    });
  });

  group('button', () {
    testWidgets('is at least 48x48', (tester) async {
      await pumpPage(tester);

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('has a semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);

      expect(find.bySemanticsLabel('Go back to the home page'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('goes home by default', (tester) async {
      final router = await pumpPage(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.byType(NotFoundPage), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
    });

    testWidgets('goes to a custom home location', (tester) async {
      await pumpPage(tester, page: const NotFoundPage(homeLocation: '/other'));

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('other'), findsOneWidget);
    });
  });

  group('accessibility and motion', () {
    testWidgets('the decorative panel is excluded from semantics', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(
        find.ancestor(
          of: find.byIcon(Icons.nightlight_round),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });

    testWidgets('the heading is a semantics header', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);

      expect(
        tester.getSemantics(find.text('This page has passed on\u2026')),
        matchesSemantics(
          label: 'This page has passed on\u2026',
          isHeader: true,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });

    for (final reduced in <bool>[false, true]) {
      testWidgets('has no running animation (reduced motion: $reduced)', (
        tester,
      ) async {
        if (reduced) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        await pumpPage(tester);
        await tester.pump(const Duration(seconds: 2));

        expect(tester.hasRunningAnimations, isFalse);
        expect(find.text('This page has passed on\u2026'), findsOneWidget);
      });
    }
  });

  group('layout', () {
    testWidgets('has no overflow on a 320 px phone', (tester) async {
      await pumpPage(tester, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('has no overflow on a desktop width', (tester) async {
      await pumpPage(tester, size: const Size(1200, 800));
      expect(tester.takeException(), isNull);
      // Content is capped to 480 px wide.
      expect(
        tester.getSize(find.byType(ConstrainedBox).last).width,
        lessThanOrEqualTo(480),
      );
    });

    testWidgets('scrolls to the button in a short viewport', (tester) async {
      await pumpPage(tester, size: const Size(320, 200));
      expect(tester.takeException(), isNull);

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(FilledButton));
      expect(rect.bottom, lessThanOrEqualTo(200));
      expect(rect.top, greaterThanOrEqualTo(0));
    });
  });
}
