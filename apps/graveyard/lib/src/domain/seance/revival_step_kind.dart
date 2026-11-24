/// The kind of one revival step. Carries no user-facing text; the UI maps
/// each kind to its wording.
enum RevivalStepKind {
  /// Condition step: the repository is archived.
  forkRepository,

  /// Condition step: the grave was buried by hand.
  writeDownPurpose,

  /// Condition step: dead for more than 365 days.
  updateDependencies,

  /// General fill step: skim the README.
  skimReadme,

  /// General fill step: fix one small thing.
  fixOneThing,

  /// General fill step: ask a friend to help.
  askAFriend,

  /// General fill step: add one test.
  addOneTest,
}
