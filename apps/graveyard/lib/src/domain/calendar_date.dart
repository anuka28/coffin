/// A calendar day (year, month, day) with no time of day and no zone.
///
/// All arithmetic is integer calendar arithmetic. No `Duration` is used, so
/// daylight saving can never move a day. A `DateTime` is touched only in
/// [CalendarDate.fromDateTime], and only for its year, month and day.
final class CalendarDate implements Comparable<CalendarDate> {
  const CalendarDate._(this.year, this.month, this.day);

  /// Creates a date. Throws [ArgumentError] unless the date is real and the
  /// year is within 1 to 9999.
  factory CalendarDate(int year, int month, int day) {
    final date = tryCreate(year, month, day);
    if (date == null) {
      throw ArgumentError('Not a real calendar date: $year-$month-$day');
    }
    return date;
  }

  /// Creates a date, or returns null unless the date is real and the year is
  /// within 1 to 9999.
  static CalendarDate? tryCreate(int year, int month, int day) {
    if (year < 1 || year > 9999) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > _daysIn(year, month)) return null;
    return CalendarDate._(year, month, day);
  }

  /// Reads only the year, month and day of [dateTime], as they are in that
  /// value's own zone.
  factory CalendarDate.fromDateTime(DateTime dateTime) =>
      CalendarDate(dateTime.year, dateTime.month, dateTime.day);

  /// The date that is [epochDay] days after 1970-01-01 (negative values go
  /// back before it).
  factory CalendarDate.fromEpochDay(int epochDay) {
    final z = epochDay + 719468;
    final era = _floorDiv(z, 146097);
    final doe = z - era * 146097;
    final yoe = (doe - doe ~/ 1460 + doe ~/ 36524 - doe ~/ 146096) ~/ 365;
    final doy = doe - (365 * yoe + yoe ~/ 4 - yoe ~/ 100);
    final mp = (5 * doy + 2) ~/ 153;
    final d = doy - (153 * mp + 2) ~/ 5 + 1;
    final m = mp < 10 ? mp + 3 : mp - 9;
    final y = yoe + era * 400 + (m <= 2 ? 1 : 0);
    return CalendarDate(y, m, d);
  }

  /// Parses a strict `YYYY-MM-DD` string. Returns null for any other text and
  /// for dates that are not real.
  static CalendarDate? tryParse(String iso) {
    if (!_isoPattern.hasMatch(iso)) return null;
    return tryCreate(
      int.parse(iso.substring(0, 4)),
      int.parse(iso.substring(5, 7)),
      int.parse(iso.substring(8, 10)),
    );
  }

  static final RegExp _isoPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// The earliest date the app accepts: 1970-01-01.
  static final CalendarDate earliest = CalendarDate(1970, 1, 1);

  /// The year, 1 to 9999.
  final int year;

  /// The month, 1 to 12.
  final int month;

  /// The day of the month, 1 or more.
  final int day;

  /// Days since 1970-01-01 (negative before it).
  int get epochDay {
    final y = month <= 2 ? year - 1 : year;
    final era = _floorDiv(y, 400);
    final yoe = y - era * 400;
    final mp = month > 2 ? month - 3 : month + 9;
    final doy = (153 * mp + 2) ~/ 5 + day - 1;
    final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;
    return era * 146097 + doe - 719468;
  }

  /// The number of days in this date's month.
  int get daysInMonth => _daysIn(year, month);

  /// Whether this date is the last day of its month.
  bool get isLastDayOfMonth => day == daysInMonth;

  /// This date moved by [n] days. [n] may be negative.
  CalendarDate addDays(int n) => CalendarDate.fromEpochDay(epochDay + n);

  /// This date moved by [n] months, with the day clamped to the length of the
  /// target month. [n] may be negative.
  CalendarDate addMonthsClamped(int n) {
    final total = year * 12 + (month - 1) + n;
    final y = _floorDiv(total, 12);
    final m = total - y * 12 + 1;
    final maxDay = _daysIn(y, m);
    return CalendarDate(y, m, day > maxDay ? maxDay : day);
  }

  /// The number of days from this date to [other]. Negative when [other] is
  /// earlier.
  int daysUntil(CalendarDate other) => other.epochDay - epochDay;

  /// The number of whole months from this date to [later], or 0 when [later]
  /// is not after this date.
  ///
  /// A month is whole when [later] reaches this date's day of the month. When
  /// this date's day does not exist in [later]'s month, the last day of that
  /// month completes the month.
  int wholeMonthsUntil(CalendarDate later) {
    final m = (later.year - year) * 12 + (later.month - month);
    final complete =
        later.day >= day || (later.isLastDayOfMonth && day > later.daysInMonth);
    final result = complete ? m : m - 1;
    return result < 0 ? 0 : result;
  }

  /// This date as `YYYY-MM-DD`.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();

  static bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  static int _daysIn(int y, int m) {
    const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return m == 2 && _isLeap(y) ? 29 : lengths[m - 1];
  }

  /// Division rounded toward negative infinity.
  static int _floorDiv(int a, int b) {
    final q = a ~/ b;
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
  }
}
