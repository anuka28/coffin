import '../domain/import_failure.dart';
import '../domain/repo_parse_problem.dart';
import '../domain/repo_ref.dart';

part 'import_duplicate_found.dart';
part 'import_fetch_failed.dart';
part 'import_idle.dart';
part 'import_input_rejected.dart';
part 'import_running.dart';
part 'import_succeeded.dart';

/// The state of the import flow, owned by the grave list controller.
sealed class ImportState {
  /// Creates an import state.
  const ImportState();
}
