/// Small seeded pseudo-random generator with the same sequence on every
/// platform.
///
/// A Lehmer (MINSTD) generator: `state = state * 48271 % 2147483647`. The
/// product stays below 2^47, so it is exact in JavaScript numbers.
final class StableRandom {
  /// Creates a generator from [seed]. Any integer is a valid seed.
  StableRandom(int seed) : _state = (seed % 2147483646) + 1;

  int _state;

  /// Returns the next integer in `[0, max)`, or 0 when [max] is below 1.
  int nextInt(int max) {
    if (max < 1) return 0;
    _state = _state * 48271 % 2147483647;
    return _state % max;
  }
}
