/// Why a grave was refused.
enum GraveRejection {
  /// The name is empty after normalisation.
  nameEmpty,

  /// The name is over 80 code points after normalisation.
  nameTooLong,

  /// No date was given.
  dateMissing,

  /// The date is not a real calendar date.
  dateNotReal,

  /// The date is after Today.
  dateInFuture,

  /// The date is before 1970-01-01.
  dateTooEarly,

  /// The grave already exists.
  duplicate,
}
