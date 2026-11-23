/// A parsed GitHub repository reference: an owner and a repository name.
final class RepoRef {
  /// Creates a reference. Use [isValidOwner] and [isValidRepo] to check text.
  const RepoRef(this.owner, this.repo);

  /// The account name, in the letter case the user typed.
  final String owner;

  /// The repository name, in the letter case the user typed.
  final String repo;

  static final RegExp _ownerPattern = RegExp(r'^[A-Za-z0-9]+(-[A-Za-z0-9]+)*$');
  static final RegExp _repoPattern = RegExp(r'^[A-Za-z0-9._-]+$');

  /// Whether [owner] is a valid Owner_Name: 1 to 39 ASCII letters, digits and
  /// single hyphens, not starting or ending with a hyphen.
  static bool isValidOwner(String owner) =>
      owner.length <= 39 && _ownerPattern.hasMatch(owner);

  /// Whether [repo] is a valid Repo_Name: 1 to 100 ASCII letters, digits, `-`,
  /// `_` and `.`, not `.` or `..`, and not ending in `.git` in any letter case.
  static bool isValidRepo(String repo) =>
      repo.length <= 100 &&
      repo != '.' &&
      repo != '..' &&
      _repoPattern.hasMatch(repo) &&
      !repo.toLowerCase().endsWith('.git');

  @override
  bool operator ==(Object other) =>
      other is RepoRef && other.owner == owner && other.repo == repo;

  @override
  int get hashCode => Object.hash(owner, repo);

  @override
  String toString() => '$owner/$repo';
}
