import 'voice_snapshot.dart';
import 'voice_trigger.dart';

/// Decides whether a change of the home screen is a [VoiceTrigger].
///
/// The order of the checks is the priority: resurrected, checked off, mood
/// changed, app opened.
final class VoicePolicy {
  const VoicePolicy._();

  /// Returns the trigger for the step from [previous] to [next], or null when
  /// the voice should stay quiet.
  ///
  /// A null [previous], or one that was not ready, makes the first ready
  /// snapshot an `appOpened`. Equal snapshots never trigger.
  static VoiceTrigger? decide(VoiceSnapshot? previous, VoiceSnapshot next) {
    if (next.state == null) return null;
    if (previous == null || previous.state == null) {
      return VoiceTrigger.appOpened;
    }
    if (next.resurrections > previous.resurrections) {
      return VoiceTrigger.resurrected;
    }
    if (next.checkOffs > previous.checkOffs) return VoiceTrigger.checkedOff;
    if (next.state != previous.state) return VoiceTrigger.moodChanged;
    return null;
  }
}
