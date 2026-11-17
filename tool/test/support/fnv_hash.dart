/// Computes the 64-bit FNV-1a hash of [bytes].
///
/// Runs on the Dart VM, where `int` is 64 bits wide and multiplication wraps.
/// The result may be negative when read as a signed value; compare it only
/// against other results of this function.
int fnv1a64(List<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte & 0xff;
    hash *= 0x100000001b3;
  }
  return hash;
}
