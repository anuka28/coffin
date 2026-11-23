/// Why the text typed for an import could not become a repository reference.
enum RepoParseProblem {
  /// The address is not a GitHub address.
  notGitHub,

  /// The text does not hold an owner and a repository.
  needOwnerRepo,

  /// The owner is not a valid GitHub account name.
  invalidOwner,

  /// The repository is not a valid GitHub repository name.
  invalidRepo,
}
