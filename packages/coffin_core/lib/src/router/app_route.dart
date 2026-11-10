import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'fog_math.dart';
import 'fog_transition_page.dart';

/// A route declared by an app and converted to a go_router [GoRoute].
///
/// Every route, including nested [routes], is shown with the fog transition.
/// `coffin_core` ships no routes of its own. Each app owns its list.
@immutable
class AppRoute {
  /// Creates a route.
  const AppRoute({
    required this.path,
    required this.builder,
    this.name,
    this.routes = const <AppRoute>[],
    this.duration = FogMath.defaultDuration,
  });

  /// The route path.
  ///
  /// go_router rules apply: a top-level path starts with `/` (for example
  /// `/graves`), and a child path does not (for example `details`).
  final String path;

  /// An optional unique name, usable with `context.goNamed`.
  final String? name;

  /// Builds the screen for this route.
  final Widget Function(BuildContext context, GoRouterState state) builder;

  /// Child routes, converted to nested [GoRoute]s that also use the fog
  /// transition.
  final List<AppRoute> routes;

  /// The requested transition duration.
  ///
  /// It is clamped into 300 to 600 ms with normal motion and is zero with
  /// reduced motion. See [FogMath.resolveDuration].
  final Duration duration;

  /// Converts this route, and recursively its children, to a [GoRoute].
  GoRoute toGoRoute() {
    return GoRoute(
      path: path,
      name: name,
      pageBuilder: (BuildContext context, GoRouterState state) {
        return FogTransitionPage<void>(
          key: state.pageKey,
          name: state.name,
          duration: duration,
          reducedMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
          child: builder(context, state),
        );
      },
      routes: <RouteBase>[
        for (final AppRoute child in routes) child.toGoRoute(),
      ],
    );
  }
}
