/// A calendar day (year, month, day) with no time of day and no time zone.
///
/// Day counting uses integer civil-calendar arithmetic only. It never uses
/// `Duration` or 24-hour steps, so daylight saving cannot move a day.
final class LocalDay implements Comparable<LocalDay> {
  const LocalDay._(this.year, this.month, this.day);

  /// Creates a day from its parts.
  ///
  /// Throws [ArgumentError] when the date does not exist or [year] is not in
  /// 1..9999.
  factory LocalDay(int year, int month, int day) {
    if (!_isReal(year, month, day)) {
      throw ArgumentError('Not a real date: $year-$month-$day');
    }
    return LocalDay._(year, month, day);
  }

  /// Creates a day from the year, month and day of [local]. Time of day and
  /// zone are ignored.
  factory LocalDay.fromDateTime(DateTime local) =>
      LocalDay(local.year, local.month, local.day);

  /// Creates the day that is [epochDay] days after 1970-01-01 (negative values
  /// are before it). Throws [ArgumentError] when the year leaves 1..9999.
  factory LocalDay.fromEpochDay(int epochDay) {
    final z = epochDay + 719468;
    final era = _floorDiv(z, 146097);
    final doe = z - era * 146097;
    final yoe = (doe - doe ~/ 1460 + doe ~/ 36524 - doe ~/ 146096) ~/ 365;
    final doy = doe - (365 * yoe + yoe ~/ 4 - yoe ~/ 100);
    final mp = (5 * doy + 2) ~/ 153;
    final d = doy - (153 * mp + 2) ~/ 5 + 1;
    final m = mp < 10 ? mp + 3 : mp - 9;
    final y = yoe + era * 400 + (m <= 2 ? 1 : 0);
    return LocalDay(y, m, d);
  }

  /// Parses strict `YYYY-MM-DD` text. Returns null when the text has another
  /// shape or names a date that does not exist.
  static LocalDay? tryParse(String iso) {
    if (!_isoShape.hasMatch(iso)) {
      return null;
    }
    final year = int.parse(iso.substring(0, 4));
    final month = int.parse(iso.substring(5, 7));
    final day = int.parse(iso.substring(8, 10));
    if (!_isReal(year, month, day)) {
      return null;
    }
    return LocalDay._(year, month, day);
  }

  static final RegExp _isoShape = RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$');

  /// The year, 1..9999.
  final int year;

  /// The month, 1..12.
  final int month;

  /// The day of the month, starting at 1.
  final int day;

  /// Days since 1970-01-01 in the proleptic Gregorian calendar.
  int get epochDay {
    final y = month <= 2 ? year - 1 : year;
    final era = _floorDiv(y, 400);
    final yoe = y - era * 400;
    final mp = month > 2 ? month - 3 : month + 9;
    final doy = (153 * mp + 2) ~/ 5 + day - 1;
    final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;
    return era * 146097 + doe - 719468;
  }

  /// The following day.
  LocalDay get next => addDays(1);

  /// The preceding day.
  LocalDay get previous => addDays(-1);

  /// The day [n] days after this one. [n] may be negative.
  LocalDay addDays(int n) => LocalDay.fromEpochDay(epochDay + n);

  /// The number of days from this day to [other]. Negative when [other] is
  /// earlier.
  int daysUntil(LocalDay other) => other.epochDay - epochDay;

  /// The day as `YYYY-MM-DD`.
  String toIso() => '${_pad(year, 4)}-${_pad(month, 2)}-${_pad(day, 2)}';

  @override
  int compareTo(LocalDay other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) =>
      other is LocalDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();

  static String _pad(int v, int width) => v.toString().padLeft(width, '0');

  static int _floorDiv(int a, int b) => a >= 0 ? a ~/ b : -((-a + b - 1) ~/ b);

  static bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  static bool _isReal(int year, int month, int day) {
    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
      return false;
    }
    const lengths = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    final length = month == 2 && _isLeap(year) ? 29 : lengths[month - 1];
    return day <= length;
  }
}
