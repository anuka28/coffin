import '../domain/ghost_state.dart';
import 'mood_map.dart';

/// Returns the Mood_Fact for a ghost in [state].
///
/// It is the `name` of the steady mood shown for [state], one of `thriving`,
/// `content`, `hungry`, `fading` or `dead`. It is never `fed` or `rising`.
String moodFactFor(GhostState state) => moodFor(state).name;
