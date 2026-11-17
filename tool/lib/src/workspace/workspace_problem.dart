/// Why [WorkspaceEditor.addApp] refused to edit a root `pubspec.yaml`.
enum WorkspaceProblem {
  /// The file has no `workspace:` key followed by at least one list item.
  noWorkspaceList,

  /// The workspace list already holds the requested `apps/<name>` entry.
  alreadyListed,
}
