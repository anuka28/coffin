import 'package:flutter/material.dart';

/// Asks the user to confirm archiving a habit.
///
/// The dialog closes with `true` on confirm and `false` on cancel. The caller
/// archives the habit only when the result is true.
class ArchiveDialog extends StatelessWidget {
  /// Creates the dialog for the habit called [habitName].
  const ArchiveDialog({required this.habitName, super.key});

  /// The name of the habit to archive.
  final String habitName;

  /// Opens the dialog and returns true only when the user confirms.
  ///
  /// Returns false when the user cancels or dismisses the dialog.
  static Future<bool> show(
    BuildContext context, {
    required String habitName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ArchiveDialog(habitName: habitName),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lay this habit to rest?'),
      content: Text(
        '"$habitName" will move to the archive. Your ghost will stop '
        'counting it.',
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Keep habit',
          excludeSemantics: true,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
        ),
        Semantics(
          button: true,
          label: 'Archive $habitName',
          excludeSemantics: true,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ),
      ],
    );
  }
}
