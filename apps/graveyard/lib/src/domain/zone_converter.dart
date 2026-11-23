/// Converts a UTC moment to the zone whose calendar the user lives by.
///
/// Only the year, month and day of the result are read.
typedef ZoneConverter = DateTime Function(DateTime utc);

/// The production [ZoneConverter]: the device's local time zone.
DateTime localZone(DateTime utc) => utc.toLocal();
