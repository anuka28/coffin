/// The kind of one visible text fragment on a tombstone.
enum TombstoneFragmentKind {
  /// The "Dead for ..." text.
  deadFor,

  /// The date line.
  dateLine,

  /// The project name, shown as the title.
  title,

  /// The GitHub `full_name`, shown as a source line.
  fullName,
}
