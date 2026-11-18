import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

/// One habit row: a check-off control, the name and an options menu.
class HabitTile extends StatelessWidget {
  /// Creates a habit tile.
  const HabitTile({
    super.key,
    required this.name,
    required this.done,
    required this.onToggle,
    required this.onRename,
    required this.onArchive,
  });

  /// The habit name.
  final String name;

  /// Whether the habit is completed today.
  final bool done;

  /// Called when the check-off control is activated.
  final VoidCallback onToggle;

  /// Called when Rename is chosen.
  final VoidCallback onRename;

  /// Called when Archive is chosen.
  final VoidCallback onArchive;

  /// Semantics label of the check-off control.
  static String checkLabel(String name, bool done) =>
      done ? '$name, done today' : '$name, not done yet';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const radius = BorderRadius.all(
      Radius.circular(CoffinMetrics.cornerRadius),
    );

    return Row(
      children: [
        Semantics(
          button: true,
          label: checkLabel(name, done),
          excludeSemantics: true,
          onTap: onToggle,
          child: SizedBox(
            width: CoffinMetrics.minTapTarget,
            height: CoffinMetrics.minTapTarget,
            child: InkResponse(
              key: const ValueKey('habit-check'),
              onTap: onToggle,
              radius: CoffinMetrics.minTapTarget / 2,
              borderRadius: radius,
              hoverColor: scheme.primary.withValues(alpha: 0.12),
              highlightColor: scheme.primary.withValues(alpha: 0.24),
              splashColor: scheme.primary.withValues(alpha: 0.24),
              child: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? scheme.tertiary : scheme.outline,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: theme.textTheme.bodyLarge)),
        PopupMenuButton<VoidCallback>(
          key: const ValueKey('habit-menu'),
          tooltip: '$name, options',
          iconSize: 24,
          constraints: const BoxConstraints(minWidth: 140),
          style: IconButton.styleFrom(
            minimumSize: const Size.square(CoffinMetrics.minTapTarget),
          ),
          onSelected: (action) => action(),
          itemBuilder: (context) => [
            PopupMenuItem(value: onRename, child: const Text('Rename')),
            PopupMenuItem(value: onArchive, child: const Text('Archive')),
          ],
        ),
      ],
    );
  }
}
