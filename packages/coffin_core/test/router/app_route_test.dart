import 'package:coffin_core/src/router/app_route.dart';
import 'package:coffin_core/src/router/fog_math.dart';
import 'package:coffin_core/src/router/fog_transition_page.dart';
import 'package:coffin_core/src/theme/coffin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

AppRoute _screen(
  String path, {
  String? name,
  List<AppRoute> routes = const <AppRoute>[],
  Duration duration = FogMath.defaultDuration,
}) => AppRoute(
  path: path,
  name: name,
  duration: duration,
  routes: routes,
  builder: (context, state) => Text('screen $path'),
);

void main() {
  group('toGoRoute', () {
    test('keeps path and name', () {
      final route = _screen('/graves', name: 'graves').toGoRoute();
      expect(route.path, '/graves');
      expect(route.name, 'graves');
    });

    test('routes defaults to empty', () {
      expect(_screen('/').routes, isEmpty);
      expect(_screen('/').toGoRoute().routes, isEmpty);
    });

    test('converts children recursively, two levels deep', () {
      final route = _screen(
        '/a',
        routes: [
          _screen('b', routes: [_screen('c')]),
          _screen('d'),
        ],
      ).toGoRoute();

      expect(route.routes, hasLength(2));
      final b = route.routes.first as GoRoute;
      final d = route.routes.last as GoRoute;
      expect(b.path, 'b');
      expect(d.path, 'd');
      expect(b.routes, hasLength(1));
      expect((b.routes.single as GoRoute).path, 'c');
    });
  });

  group('pages', () {
    Future<GoRouter> pumpRouter(
      WidgetTester tester,
      List<AppRoute> routes, {
      String initialLocation = '/',
    }) async {
      final router = GoRouter(
        routes: [for (final r in routes) r.toGoRoute()],
        initialLocation: initialLocation,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: CoffinTheme.dark(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      return router;
    }

    FogTransitionPage<dynamic> topPage(WidgetTester tester) {
      final navigator = tester.widget<Navigator>(find.byType(Navigator).first);
      return navigator.pages.last as FogTransitionPage<dynamic>;
    }

    testWidgets('parent and child routes both build a FogTransitionPage', (
      tester,
    ) async {
      final router = await pumpRouter(tester, [
        _screen('/', routes: [_screen('child')]),
      ]);

      expect(find.text('screen /'), findsOneWidget);
      expect(topPage(tester), isA<FogTransitionPage<dynamic>>());

      router.go('/child');
      await tester.pumpAndSettle();

      expect(find.text('screen child'), findsOneWidget);
      expect(topPage(tester), isA<FogTransitionPage<dynamic>>());
    });

    testWidgets('normal motion uses the requested clamped duration', (
      tester,
    ) async {
      await pumpRouter(tester, [
        _screen('/', duration: const Duration(milliseconds: 100)),
      ]);

      expect(topPage(tester).transitionDuration, FogMath.minDuration);
    });

    testWidgets('reduced motion gives a zero duration', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await pumpRouter(tester, [_screen('/')]);

      expect(topPage(tester).transitionDuration, Duration.zero);
      expect(topPage(tester).reverseTransitionDuration, Duration.zero);
    });

    testWidgets('the setting is read again for the next navigation', (
      tester,
    ) async {
      final router = await pumpRouter(tester, [_screen('/'), _screen('/next')]);
      expect(topPage(tester).transitionDuration, FogMath.defaultDuration);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();

      router.go('/next');
      await tester.pumpAndSettle();

      expect(find.text('screen /next'), findsOneWidget);
      expect(topPage(tester).transitionDuration, Duration.zero);
    });
  });
}
