import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'haunt_copy.dart';

/// Invites the user to add a first habit when there is no active habit.
class EmptyHabitsPanel extends StatelessWidget {
  /// Creates the panel. [onAdd] is called when the add button is pressed.
  const EmptyHabitsPanel({super.key, required this.onAdd});

  /// Called when the user asks to add a habit.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: CoffinGlow.decoration(
        color: scheme.primary,
        intensity: 0.3,
        fill: scheme.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                HauntCopy.emptyTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              HauntCopy.emptyInvitation,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: CoffinMetrics.minTapTarget,
                minHeight: CoffinMetrics.minTapTarget,
              ),
              child: Semantics(
                button: true,
                label: HauntCopy.addHabit,
                excludeSemantics: true,
                child: FilledButton(
                  onPressed: onAdd,
                  child: const Text(HauntCopy.addHabit),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
