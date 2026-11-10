import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/coffin_glow.dart';
import '../theme/coffin_metrics.dart';

/// A spooky page for locations that match no route.
///
/// It shows a glowing tombstone, the heading "This page has passed on…", a
/// short line of copy and a button that goes back home. Colors and text
/// styles come from [Theme], so it follows the dark and daylight themes. The
/// page has no looping or moving decoration.
class NotFoundPage extends StatelessWidget {
  /// Creates the not-found page.
  ///
  /// [homeLocation] is where the button goes. [message] replaces the default
  /// body copy.
  const NotFoundPage({super.key, this.homeLocation = '/', this.message});

  /// The location the button navigates to.
  final String homeLocation;

  /// Optional body copy that replaces the default line.
  final String? message;

  /// The default body copy.
  static const String defaultMessage =
      'The link you followed is a ghost now. '
      'Let\u2019s get you back to the living.';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: CoffinGlow.decoration(
                        color: scheme.primary,
                        intensity: 0.6,
                        fill: scheme.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(48),
                          bottom: Radius.circular(CoffinMetrics.cornerRadius),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 28,
                        ),
                        child: Icon(
                          Icons.nightlight_round,
                          size: 64,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Semantics(
                    header: true,
                    child: Text(
                      'This page has passed on\u2026',
                      textAlign: TextAlign.center,
                      style: textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message ?? defaultMessage,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => context.go(homeLocation),
                    child: const Text(
                      'Back to the land of the living',
                      semanticsLabel: 'Go back to the home page',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
