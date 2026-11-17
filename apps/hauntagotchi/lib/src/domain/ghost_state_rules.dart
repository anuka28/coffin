import 'ghost_state.dart';
import 'recent_history.dart';

/// Turns Health and recent history into a [GhostState].
abstract final class GhostStateRules {
  /// Derives the state for [health] (clamped to 0..100) and [history].
  ///
  /// Bands: 0 dead, 1-24 fading, 25-49 hungry, 50-79 content, 80-100
  /// thriving. One idle day caps the state at content and three idle days cap
  /// it at hungry. A cap never lowers the state below hungry.
  static GhostState derive(int health, RecentHistory history) {
    final h = health < 0 ? 0 : (health > 100 ? 100 : health);
    if (h == 0) {
      return GhostState.dead;
    }
    if (h < 25) {
      return GhostState.fading;
    }
    var state = h < 50
        ? GhostState.hungry
        : (h < 80 ? GhostState.content : GhostState.thriving);
    final GhostState? cap = history.idleDays >= 3
        ? GhostState.hungry
        : (history.idleDays >= 1 ? GhostState.content : null);
    if (cap != null && state.index > cap.index) {
      state = cap;
    }
    return state;
  }
}
