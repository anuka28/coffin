import 'package:coffin_core/coffin_core.dart';

import '../domain/ghost_state.dart';

/// Returns the steady [GhostMood] that shows a ghost in [state].
///
/// Each state maps to the mood with the same name. The reaction moods
/// (`fed` and `rising`) are never returned; they come from events.
GhostMood moodFor(GhostState state) => switch (state) {
  GhostState.dead => GhostMood.dead,
  GhostState.fading => GhostMood.fading,
  GhostState.hungry => GhostMood.hungry,
  GhostState.content => GhostMood.content,
  GhostState.thriving => GhostMood.thriving,
};
