/// The unit of a dead-for span.
///
/// Declaration order runs from the youngest span to the oldest, so
/// [DeadForUnit.index] can be used to compare ages.
enum DeadForUnit {
  /// The project died today (or the date of death is after today).
  today,

  /// A span of 1 to 6 days.
  days,

  /// A span of whole weeks, shorter than one whole month.
  weeks,

  /// A span of whole calendar months, shorter than 12.
  months,

  /// A span of 12 or more whole calendar months.
  years,
}
