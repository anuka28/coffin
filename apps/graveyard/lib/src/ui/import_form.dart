import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'grave_list_controller.dart';
import 'graveyard_copy.dart';
import 'import_state.dart';

/// The "Import from GitHub" option of the add sheet.
///
/// One field for `owner/repo` or a github.com address. While a request runs
/// the form shows a ghost loader and the submit button is disabled. A failure
/// shows its message in a live region with a "Try again" button. The typed
/// text always stays, and the field is never disabled.
class ImportForm extends StatefulWidget {
  /// Creates the form. [onImported] runs after a grave was added.
  const ImportForm({
    super.key,
    required this.controller,
    required this.onImported,
  });

  /// The controller that runs the import.
  final GraveListController controller;

  /// Called once, after an import added a grave.
  final VoidCallback onImported;

  @override
  State<ImportForm> createState() => _ImportFormState();
}

class _ImportFormState extends State<ImportForm> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.controller.importState is ImportRunning) return;
    final ImportState result = await widget.controller.startImport(_text.text);
    if (!mounted) return;
    if (result is ImportSucceeded) widget.onImported();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? _) {
        final ImportState state = widget.controller.importState;
        final bool running = state is ImportRunning;
        final String? fieldError = switch (state) {
          ImportInputRejected(:final problem) => GraveyardCopy.parseProblem(
            problem,
          ),
          ImportDuplicateFound() => GraveyardCopy.duplicate,
          _ => null,
        };
        final String? failure = state is ImportFetchFailed
            ? GraveyardCopy.importFailure(
                state.failure,
                now: widget.controller.clock.now(),
              )
            : null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('import-field'),
              controller: _text,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: GraveyardCopy.repoLabel,
                hintText: GraveyardCopy.repoHint,
                errorText: fieldError,
                errorMaxLines: 3,
              ),
            ),
            if (running)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(
                  child: GhostLoader(caption: GraveyardCopy.importingCaption),
                ),
              ),
            if (failure != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  container: true,
                  child: Text(
                    failure,
                    key: const ValueKey<String>('import-failure'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  key: const ValueKey<String>('import-retry'),
                  onPressed: _submit,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text(GraveyardCopy.tryAgain),
                ),
              ),
            FilledButton(
              key: const ValueKey<String>('import-submit'),
              onPressed: running ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text(GraveyardCopy.digUpButton),
            ),
          ],
        );
      },
    );
  }
}
