import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/ritual_progress.dart';
import 'haunt_copy.dart';

/// Explains the resurrection ritual for a dead ghost and shows its progress.
class ResurrectionPanel extends StatelessWidget {
  /// Creates the panel.
  ///
  /// [ritual] is null when no habit is active. [resurrectionCount] is how
  /// many times the ghost has been brought back.
  const ResurrectionPanel({
    super.key,
    required this.ghostName,
    required this.ritual,
    required this.resurrectionCount,
  });

  /// The ghost's name.
  final String ghostName;

  /// Candles lit so far, or null when there is no active habit.
  final RitualProgress? ritual;

  /// How many times the ghost has been resurrected.
  final int resurrectionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = ritual;
    final status = progress == null
        ? HauntCopy.addHabitToBeginRitual
        : HauntCopy.candleProgress(progress.done, progress.needed);
    final count = HauntCopy.resurrectionCount(resurrectionCount);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Semantics(
      container: true,
      label: '$ghostName. $status. $count',
      child: DecoratedBox(
        decoration: CoffinGlow.decoration(
          color: scheme.primary,
          intensity: 0.3,
          fill: scheme.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ghostName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  HauntCopy.ritualText(ghostName, progress?.needed ?? 1),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(count, textAlign: TextAlign.center, style: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
