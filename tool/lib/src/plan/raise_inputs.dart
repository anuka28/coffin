import '../template/template_file.dart';

/// The facts the planner needs. The caller gathers them from disk.
final class RaiseInputs {
  /// Creates inputs for planning the raise of [appName].
  const RaiseInputs({
    required this.appName,
    required this.rootPubspec,
    required this.template,
    this.takenNames = const {},
    this.folderExists = false,
  });

  /// The name the developer asked for.
  final String appName;

  /// The root `pubspec.yaml` text, as read.
  final String rootPubspec;

  /// Package names that may not be used.
  final Set<String> takenNames;

  /// Whether `apps/<appName>` already exists.
  final bool folderExists;

  /// Every file read from the template folder.
  final List<TemplateFile> template;
}
