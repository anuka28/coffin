import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

/// Temporary home screen that proves the app consumes `coffin_core`.
class PlaceholderScreen extends StatelessWidget {
  /// Creates the placeholder screen.
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: CoffinGlow.decoration(
                  color: scheme.primary,
                  intensity: 0.6,
                  fill: scheme.surface,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: CoffinMark(),
                ),
              ),
              const SizedBox(height: 32),
              Text('Graveyard', style: textTheme.displayMedium),
              const SizedBox(height: 12),
              Text(
                'This project has been dead for 214 days',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
