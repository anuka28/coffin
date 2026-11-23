import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'add_mode.dart';
import 'bury_by_hand_form.dart';
import 'grave_list_controller.dart';
import 'graveyard_copy.dart';
import 'import_form.dart';

/// Opens the add sheet and waits until it closes.
///
/// When the sheet closes for any reason, [GraveListController.cancelImport]
/// runs, so a result still on its way is dropped.
Future<void> showAddGraveSheet(
  BuildContext context,
  GraveListController controller, {
  AddMode initial = AddMode.buryByHand,
}) async {
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) =>
          AddGraveSheet(controller: controller, initial: initial),
    );
  } finally {
    controller.cancelImport();
  }
}

/// The content of the add sheet: a title, a close button, a two-option
/// selector and the form of the chosen option.
///
/// Escape closes the sheet. Enter inside a form submits that form.
class AddGraveSheet extends StatefulWidget {
  /// Creates the sheet content, starting on the [initial] option.
  const AddGraveSheet({
    super.key,
    required this.controller,
    this.initial = AddMode.buryByHand,
  });

  /// The controller the forms talk to.
  final GraveListController controller;

  /// The option shown first.
  final AddMode initial;

  @override
  State<AddGraveSheet> createState() => _AddGraveSheetState();
}

class _AddGraveSheetState extends State<AddGraveSheet> {
  late AddMode _mode = widget.initial;

  void _close() => Navigator.of(context).pop();

  void _select(AddMode mode) {
    if (mode == _mode) return;
    // Leaving the import option drops a request still on its way.
    if (_mode == AddMode.importFromGitHub) widget.controller.cancelImport();
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          GraveyardCopy.sheetTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>('sheet-close'),
                      tooltip: GraveyardCopy.closeSheet,
                      onPressed: _close,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<AddMode>(
                  key: const ValueKey<String>('sheet-mode'),
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll<Size>(Size(48, 48)),
                  ),
                  segments: const <ButtonSegment<AddMode>>[
                    ButtonSegment<AddMode>(
                      value: AddMode.buryByHand,
                      label: Text(
                        GraveyardCopy.buryByHand,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ButtonSegment<AddMode>(
                      value: AddMode.importFromGitHub,
                      label: Text(
                        GraveyardCopy.importFromGitHub,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  selected: <AddMode>{_mode},
                  onSelectionChanged: (Set<AddMode> s) => _select(s.first),
                ),
                const SizedBox(height: 16),
                switch (_mode) {
                  AddMode.buryByHand => BuryByHandForm(
                    controller: widget.controller,
                    onBuried: _close,
                  ),
                  AddMode.importFromGitHub => ImportForm(
                    controller: widget.controller,
                    onImported: _close,
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
