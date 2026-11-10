import 'package:coffin_core/src/router/app_route.dart';
import 'package:coffin_core/src/router/fog_router.dart';
import 'package:coffin_core/src/router/fog_transition.dart';
import 'package:coffin_core/src/router/not_found_page.dart';
import 'package:coffin_core/src/theme/coffin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

AppRoute _screen(
  String path,
  String label, {
  List<AppRoute> routes = const <AppRoute>[],
}) => AppRoute(
  path: path,
  routes: routes,
  builder: (context, state) => Text(label),
);

void main() {
  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    List<AppRoute>? routes,
    String initialLocation = '/',
    Widget Function(BuildContext, GoRouterState)? notFoundBuilder,
    bool settle = true,
  }) async {
    final router = FogRouter.create(
      routes: routes ?? [_screen('/', 'home'), _screen('/two', 'two')],
      initialLocation: initialLocation,
      notFoundBuilder: notFoundBuilder,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: CoffinTheme.dark(), routerConfig: router),
    );
    if (settle) await tester.pumpAndSettle();
    return router;
  }

  /// Vertical translation of every fog transition currently drifting.
  List<double> drifts(WidgetTester tester) => tester
      .widgetList<Transform>(
        find.descendant(
          of: find.byType(FogTransition),
          matching: find.byType(Transform),
        ),
      )
      .map((t) => t.transform.getTranslation().y)
      .toList();

  void setReducedMotion(WidgetTester tester, bool value) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: value);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  group('locations', () {
    testWidgets('starts at / by default', (tester) async {
      await pumpApp(tester);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('starts at a custom initial location', (tester) async {
      await pumpApp(tester, initialLocation: '/two');
      expect(find.text('two'), findsOneWidget);
      expect(find.text('home'), findsNothing);
    });

    testWidgets('go replaces, push stacks, pop returns', (tester) async {
      final router = await pumpApp(tester);

      router.push('/two');
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.text('two'), findsNothing);

      router.go('/two');
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
    });

    testWidgets('context.go works from inside a screen', (tester) async {
      await pumpApp(
        tester,
        routes: [
          AppRoute(
            path: '/',
            builder: (context, state) => TextButton(
              onPressed: () => context.go('/two'),
              child: const Text('open two'),
            ),
          ),
          _screen('/two', 'two'),
        ],
      );

      await tester.tap(find.text('open two'));
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
    });

    testWidgets('resolves a nested child route', (tester) async {
      await pumpApp(
        tester,
        routes: [
          _screen('/', 'home', routes: [_screen('child', 'child page')]),
        ],
        initialLocation: '/child',
      );
      expect(find.text('child page'), findsOneWidget);
    });
  });

  group('not found', () {
    testWidgets('an unknown location shows NotFoundPage', (tester) async {
      await pumpApp(tester, initialLocation: '/nowhere');
      expect(find.byType(NotFoundPage), findsOneWidget);
      expect(find.text('This page has passed on\u2026'), findsOneWidget);
    });

    testWidgets('the button returns to /', (tester) async {
      await pumpApp(tester, initialLocation: '/nowhere');

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.byType(NotFoundPage), findsNothing);
    });

    testWidgets('a custom notFoundBuilder replaces the default', (
      tester,
    ) async {
      await pumpApp(
        tester,
        initialLocation: '/nowhere',
        notFoundBuilder: (context, state) => Text('lost: ${state.uri}'),
      );
      expect(find.text('lost: /nowhere'), findsOneWidget);
      expect(find.byType(NotFoundPage), findsNothing);
    });

    testWidgets('an empty route list shows the not-found page', (tester) async {
      await pumpApp(tester, routes: const <AppRoute>[]);

      expect(tester.takeException(), isNull);
      expect(find.byType(NotFoundPage), findsOneWidget);
    });

    testWidgets('the not-found page uses the fog transition', (tester) async {
      await pumpApp(tester, initialLocation: '/nowhere');
      expect(
        find.ancestor(
          of: find.byType(NotFoundPage),
          matching: find.byType(FogTransition),
        ),
        findsOneWidget,
      );
    });
  });

  group('motion', () {
    testWidgets('normal motion drifts mid-transition and then settles', (
      tester,
    ) async {
      final router = await pumpApp(tester);

      router.go('/two');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('two'), findsOneWidget);
      expect(drifts(tester), isNotEmpty);
      expect(drifts(tester).every((y) => y > 0), isTrue);
      final fades = tester
          .widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(FogTransition),
              matching: find.byType(FadeTransition),
            ),
          )
          .map((f) => f.opacity.value);
      expect(fades.any((v) => v > 0 && v < 1), isTrue);

      await tester.pumpAndSettle();
      expect(drifts(tester), isEmpty);
    });

    testWidgets('reduced motion never translates and finishes at once', (
      tester,
    ) async {
      setReducedMotion(tester, true);
      final router = await pumpApp(tester);

      router.go('/two');
      await tester.pump();
      expect(drifts(tester), isEmpty);
      await tester.pump(const Duration(milliseconds: 16));
      expect(drifts(tester), isEmpty);

      expect(find.text('two'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
