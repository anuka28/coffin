const int _mask = 0xFFFFFFFF;

/// 32-bit multiply. Each partial product is below 2^48, exact as a double.
int _imul(int a, int b) =>
    ((a & 0xFFFF) * b + ((((a >>> 16) * b) & 0xFFFF) << 16)) & _mask;

/// Mulberry32. Same output on the Dart VM and on Flutter Web.
///
/// The seed is masked to 32 bits. The generator is deterministic: two
/// instances built from the same seed give the same sequence.
final class SeededRandom {
  /// Creates a generator. [seed] is in 0..4294967295 and is masked to 32 bits.
  SeededRandom(int seed) : _a = seed & _mask;

  int _a;

  /// Returns the next value, in 0..4294967295.
  int nextUint32() {
    _a = (_a + 0x6D2B79F5) & _mask;
    int t = _imul(_a ^ (_a >>> 15), _a | 1);
    t = ((t + _imul(t ^ (t >>> 7), t | 61)) & _mask) ^ t;
    return (t ^ (t >>> 14)) & _mask;
  }

  /// Returns `nextUint32() % n`, for `1 <= n <= 65536`.
  ///
  /// The remainder bias is below 2^-16 per value, which does not matter for
  /// choosing among a handful of templates.
  int nextInt(int n) {
    assert(n >= 1, 'n must be at least 1');
    return nextUint32() % n;
  }
}
