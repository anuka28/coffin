/// The fact keys the offline generator reads. Other keys are ignored.
abstract final class AiFactKeys {
  /// Number of days in a row a habit was kept.
  static const String streakCount = 'streakCount';

  /// Number of days since the last commit of a project.
  static const String daysSinceLastCommit = 'daysSinceLastCommit';

  /// Name of a ghost.
  static const String ghostName = 'ghostName';

  /// Name of a project.
  static const String projectName = 'projectName';
}
