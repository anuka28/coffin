import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/ghost_state.dart';
import 'ghost_reaction.dart';
import 'ghost_reaction_kind.dart';
import 'haunt_copy.dart';
import 'mood_map.dart';

/// The ghost area of the home screen.
///
/// Shows a [GhostLoader] captioned with [ghostName], the health as a number
/// and a bar, the state in words with its own icon, and the streak line.
/// The whole area is one semantics node, such as
/// `Wisp, health 85 of 100, thriving`.
///
/// The ghost wears the mood of its [state]. A new [reaction] plays once on
/// the same loader, then the steady mood returns. An event that already
/// exists when the panel is built is never replayed.
class GhostPanel extends StatefulWidget {
  /// Creates a ghost panel.
  const GhostPanel({
    super.key,
    required this.ghostName,
    required this.health,
    required this.state,
    required this.streak,
    this.reaction,
  });

  /// The ghost's name.
  final String ghostName;

  /// Live health from 0 to 100.
  final int health;

  /// The ghost's state.
  final GhostState state;

  /// Current streak in days.
  final int streak;

  /// The latest reaction event, or null. A new key means a new event.
  final GhostReaction? reaction;

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
  State<GhostPanel> createState() => _GhostPanelState();
}

class _GhostPanelState extends State<GhostPanel> {
  int? _handledKey;
  GhostReaction? _active;
  int _shownKey = 0;

  @override
  void initState() {
    super.initState();
    _handledKey = widget.reaction?.key;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _active = null;
  }

  @override
  void didUpdateWidget(GhostPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final event = widget.reaction;
    if (event != null && event.key != _handledKey) {
      _handledKey = event.key;
      final reduced = MediaQuery.disableAnimationsOf(context);
      final deadFed =
          event.kind == GhostReactionKind.fed &&
          widget.state == GhostState.dead;
      if (!reduced && !deadFed) {
        _active = event;
        _shownKey = event.key;
      }
    }
    if (widget.state == GhostState.dead &&
        _active?.kind == GhostReactionKind.fed) {
      _active = null;
    }
  }

  void _end(int key) {
    if (!mounted || _active?.key != key) return;
    setState(() => _active = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = widget.health.clamp(0, 100);
    final active = _active;
    final mood = active == null
        ? moodFor(state)
        : switch (active.kind) {
            GhostReactionKind.fed => GhostMood.fed,
            GhostReactionKind.rising => GhostMood.rising,
          };
    final barColor = switch (state) {
      GhostState.dead || GhostState.fading => scheme.error,
      GhostState.hungry => scheme.secondary,
      GhostState.content || GhostState.thriving => scheme.tertiary,
    };

    return Semantics(
      container: true,
      label: GhostPanel.semanticLabel(widget.ghostName, value, state),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GhostLoader(
              size: 96,
              caption: widget.ghostName,
              mood: mood,
              reactionKey: _shownKey,
              onReactionEnd: active == null ? null : () => _end(active.key),
            ),
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
                Icon(GhostPanel.iconFor(state), color: barColor),
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
              GhostPanel.streakLine(widget.streak),
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
