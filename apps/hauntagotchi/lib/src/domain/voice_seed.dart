import 'ghost_state.dart';
import 'voice_trigger.dart';

/// Builds the deterministic seed of a ghost voice line.
///
/// The same five inputs always give the same seed, so the same situation gives
/// the same line after a restart. The math uses only addition, multiplication
/// and remainder, so it gives identical results on the VM and on the web, where
/// integers are doubles and bit-level operators truncate to 32 bits.
abstract final class VoiceSeed {
  /// The largest prime below 2^32. Every seed is smaller than this value.
  static const int _modulus = 4294967291;

  /// Multiplier of the polynomial hash. Below 2^20, so `h * _base` stays below
  /// 2^52 and the sum stays below 2^53.
  static const int _base = 1000003;

  /// Computes the seed for one voice line.
  ///
  /// The inputs are folded in this order: [epochDay], the index of [state], the
  /// index of [trigger], [streak], [completedToday]. Negative values are
  /// folded into `0..4294967290` first. Changing the order of the
  /// [GhostState] or [VoiceTrigger] values changes the seeds.
  ///
  /// The result is in `0..4294967290`, which fits the AI request seed range.
  static int compute({
    required int epochDay,
    required GhostState state,
    required VoiceTrigger trigger,
    required int streak,
    required int completedToday,
  }) {
    var h = 17;
    for (final v in <int>[
      epochDay,
      state.index,
      trigger.index,
      streak,
      completedToday,
    ]) {
      h = (h * _base + _fold(v)) % _modulus;
    }
    return h;
  }

  static int _fold(int v) => ((v % _modulus) + _modulus) % _modulus;
}
