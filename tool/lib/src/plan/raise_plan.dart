import 'planned_file.dart';

/// Everything a raise will write. Immutable and free of disk access.
final class RaisePlan {
  /// Creates a plan for [appName].
  const RaisePlan({
    required this.appName,
    required this.files,
    required this.newRootPubspec,
  });

  /// The validated app name.
  final String appName;

  /// The files to create under `apps/<appName>/`, in template order.
  final List<PlannedFile> files;

  /// The full text of the root `pubspec.yaml` after the edit.
  final String newRootPubspec;
}
