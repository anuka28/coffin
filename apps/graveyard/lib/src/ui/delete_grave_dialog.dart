import 'package:flutter/material.dart';

import 'graveyard_copy.dart';

/// Asks the user to confirm deleting the grave called [name].
///
/// Returns true only when the user presses "Delete". "Keep it" has focus when
/// the dialog opens, Escape and a tap outside close it, and all of those
/// return false. Focus returns to the control that opened the dialog.
Future<bool> showDeleteGraveDialog(BuildContext context, String name) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => DeleteGraveDialog(name: name),
  );
  return confirmed ?? false;
}

/// The delete confirmation dialog. It names the grave and pops true to
/// confirm or false to keep it.
class DeleteGraveDialog extends StatelessWidget {
  /// Creates the dialog for the grave called [name].
  const DeleteGraveDialog({super.key, required this.name});

  /// The name of the grave to delete.
  final String name;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: GraveyardCopy.deleteTitle(name),
      child: AlertDialog(
        title: Text(GraveyardCopy.deleteTitle(name)),
        content: const Text(GraveyardCopy.deleteBody),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('delete-keep'),
            autofocus: true,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(GraveyardCopy.keepIt),
          ),
          TextButton(
            key: const ValueKey<String>('delete-confirm'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(GraveyardCopy.delete),
          ),
        ],
      ),
    );
  }
}
