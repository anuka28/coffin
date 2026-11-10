import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_route.dart';
import 'fog_transition_page.dart';
import 'not_found_page.dart';

/// Builds a [GoRouter] whose pages all use the fog transition.
///
/// Apps declare their own [AppRoute]s and pass them in. This helper ships no
/// routes of its own, and it never sets a URL strategy, so Flutter Web keeps
/// its default hash strategy and works on static hosting.
abstract final class FogRouter {
  /// Creates a router for [routes].
  ///
  /// [initialLocation] defaults to `/`. Locations that match no route show
  /// [notFoundBuilder], or a [NotFoundPage] when none is given. The not-found
  /// page also arrives through the fog transition.
  static GoRouter create({
    required List<AppRoute> routes,
    String initialLocation = '/',
    Widget Function(BuildContext context, GoRouterState state)? notFoundBuilder,
    List<NavigatorObserver>? observers,
    bool debugLogDiagnostics = false,
  }) {
    return GoRouter(
      routes: <RouteBase>[
        for (final AppRoute route in routes) route.toGoRoute(),
      ],
      initialLocation: initialLocation,
      observers: observers,
      debugLogDiagnostics: debugLogDiagnostics,
      errorPageBuilder: (BuildContext context, GoRouterState state) {
        return FogTransitionPage<void>(
          key: state.pageKey,
          reducedMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
          child: notFoundBuilder?.call(context, state) ?? const NotFoundPage(),
        );
      },
    );
  }
}
