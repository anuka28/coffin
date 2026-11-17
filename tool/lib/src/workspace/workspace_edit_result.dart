import 'workspace_problem.dart';

/// The result of trying to add an app to a root `pubspec.yaml`.
sealed class WorkspaceEditResult {
  const WorkspaceEditResult();
}

/// The edit succeeded; [pubspec] is the complete new file text.
final class Edited extends WorkspaceEditResult {
  /// Creates a successful result holding the new [pubspec] text.
  const Edited(this.pubspec);

  /// The full text of the edited `pubspec.yaml`.
  final String pubspec;
}

/// The edit was refused; the input text is left as it was.
final class NotEdited extends WorkspaceEditResult {
  /// Creates a refusal for [problem].
  const NotEdited(this.problem);

  /// The reason the file could not be edited.
  final WorkspaceProblem problem;
}
