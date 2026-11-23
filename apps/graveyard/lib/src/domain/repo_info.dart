/// Facts about an imported GitHub repository, kept on its grave.
final class RepoInfo {
  /// Creates repository facts.
  const RepoInfo({
    required this.fullName,
    this.htmlUrl,
    this.description,
    this.archived = false,
    this.stars = 0,
  });

  /// The `owner/repo` name as GitHub reports it.
  final String fullName;

  /// The web address of the repository, when known.
  final String? htmlUrl;

  /// The repository description, when there is one.
  final String? description;

  /// Whether the repository is archived.
  final bool archived;

  /// The star count, 0 or more.
  final int stars;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepoInfo &&
          other.fullName == fullName &&
          other.htmlUrl == htmlUrl &&
          other.description == description &&
          other.archived == archived &&
          other.stars == stars;

  @override
  int get hashCode =>
      Object.hash(fullName, htmlUrl, description, archived, stars);

  @override
  String toString() => 'RepoInfo($fullName)';
}
