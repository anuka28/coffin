import 'package:coffin_core/coffin_core.dart';

import '../domain/ghost_state.dart';
import '../domain/voice_seed.dart';
import '../domain/voice_trigger.dart';
import 'mood_fact.dart';

/// Builds the request for one ghost voice line.
///
/// The request carries the mood, the event (the [trigger] name), the [streak]
/// only when it is 1 or more, and the [ghostName]. No habit name can enter,
/// because the builder takes none. The seed comes from [VoiceSeed.compute].
AiRequest buildVoiceRequest({
  required VoiceTrigger trigger,
  required GhostState state,
  required int streak,
  required int completedToday,
  required String ghostName,
  required int epochDay,
}) => AiRequest(
  purpose: AiPurpose.ghostMoodLine,
  facts: <String, Object?>{
    AiFactKeys.ghostMood: moodFactFor(state),
    AiFactKeys.ghostEvent: trigger.name,
    if (streak >= 1) AiFactKeys.streakCount: streak,
    AiFactKeys.ghostName: ghostName,
  },
  maxLength: 80,
  seed: VoiceSeed.compute(
    epochDay: epochDay,
    state: state,
    trigger: trigger,
    streak: streak,
    completedToday: completedToday,
  ),
);
