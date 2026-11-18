import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/ghost_state.dart';
import 'haunt_copy.dart';

/// The ghost area of the home screen.
///
/// Shows a [GhostLoader] captioned with [ghostName], the health as a number
/// and a bar, the state in words with its own icon, and the streak line.
/// The whole area is one semantics node, such as
/// `Wisp, health 85 of 100, thriving`.
class GhostPanel extends StatelessWidget {
  /// Creates a ghost panel.
  const GhostPanel({
    super.key,
    required this.ghostName,
    required this.health,
    required this.state,
    required this.streak,
  });

  /// The ghost's name.
  final String ghostName;

  /// Live health from 0 to 100.
  final int health;

  /// The ghost's state.
  final GhostState state;

  /// Current streak in days.
  final int streak;

  /// The icon that stands for [state], so state never rests on color alone.
  static IconData iconFor(GhostState state) => switch (state) {
    GhostState.dead => Icons.sentiment_very_dissatisfied_outlined,
    GhostState.fading => Icons.cloud_outlined,
    GhostState.hungry => Icons.restaurant_outlined,
    GhostState.content => Icons.sentiment_satisfied_outlined,
    GhostState.thriving => Icons.auto_awesome,
  };

  /// The streak line, such as `Streak: 3 days`.
  static String streakLine(int streak) {
    if (streak == 0) return 'No streak yet. Today is a fine day to start.';
    return 'Streak: $streak ${streak == 1 ? 'day' : 'days'}';
  }

  /// The single semantics label of the panel.
  static String semanticLabel(String name, int health, GhostState state) =>
      '$name, health $health of 100, ${HauntCopy.stateWord(state).toLowerCase()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = health.clamp(0, 100);
    final barColor = switch (state) {
      GhostState.dead || GhostState.fading => scheme.error,
      GhostState.hungry => scheme.secondary,
      GhostState.content || GhostState.thriving => scheme.tertiary,
    };

    return Semantics(
      container: true,
      label: semanticLabel(ghostName, value, state),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GhostLoader(size: 96, caption: ghostName),
            const SizedBox(height: 12),
            Text('Health $value / 100', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(CoffinMetrics.cornerRadius),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 12,
                color: barColor,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iconFor(state), color: barColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    HauntCopy.stateWord(state),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              streakLine(streak),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
