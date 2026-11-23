/// A zone with a constant UTC offset, usable as a `ZoneConverter`.
///
/// It never depends on the machine's time zone.
class FixedOffsetZone {
  /// Creates a zone that is [offset] ahead of UTC (negative when behind).
  const FixedOffsetZone(this.offset);

  /// The constant offset from UTC.
  final Duration offset;

  /// Returns [utc] shifted by [offset].
  DateTime call(DateTime utc) => utc.add(offset);
}
