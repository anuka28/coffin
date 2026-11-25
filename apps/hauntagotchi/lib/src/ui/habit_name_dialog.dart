import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/habit_rejection.dart';
import 'haunt_copy.dart';

/// Asks for a habit name. Used to add and to rename a habit.
///
/// The dialog calls [onSubmit] with the typed text. When it returns a
/// [HabitRejection], the dialog stays open, keeps the typed text and shows
/// [HauntCopy.rejectionReason]. When it returns null, the dialog closes with
/// `true`. Cancel closes it with `false`.
class HabitNameDialog extends StatefulWidget {
  /// Creates the dialog.
  const HabitNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.onSubmit,
    this.initialName = '',
    super.key,
  });

  /// The dialog title, such as `Add a habit`.
  final String title;

  /// The label of the submit button.
  final String confirmLabel;

  /// The text the field starts with. Empty when adding.
  final String initialName;

  /// Applies the typed name and returns why it was refused, or null on
  /// success.
  final FutureOr<HabitRejection?> Function(String name) onSubmit;

  /// Opens the dialog and returns true once [onSubmit] accepted a name.
  ///
  /// Returns false when the user cancels or dismisses the dialog.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required FutureOr<HabitRejection?> Function(String name) onSubmit,
    String initialName = '',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => HabitNameDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialName: initialName,
        onSubmit: onSubmit,
      ),
    );
    return result ?? false;
  }

  @override
  State<HabitNameDialog> createState() => _HabitNameDialogState();
}

class _HabitNameDialogState extends State<HabitNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  HabitRejection? _rejection;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final rejection = await widget.onSubmit(_controller.text);
    if (!mounted) return;
    if (rejection == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _rejection = rejection;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rejection = _rejection;
    return AlertDialog(
      title: Text(widget.title),
      content: Semantics(
        label: 'Habit name',
        textField: true,
        child: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Habit name',
            errorText: rejection == null
                ? null
                : HauntCopy.rejectionReason(rejection),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Cancel',
          excludeSemantics: true,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ),
        Semantics(
          button: true,
          label: widget.confirmLabel,
          excludeSemantics: true,
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}
