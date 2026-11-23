part of 'import_state.dart';

/// No import is under way and no message is shown.
final class ImportIdle extends ImportState {
  /// Creates the idle state.
  const ImportIdle();

  @override
  bool operator ==(Object other) => other is ImportIdle;

  @override
  int get hashCode => (ImportIdle).hashCode;
}
