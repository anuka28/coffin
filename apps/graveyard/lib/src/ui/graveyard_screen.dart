import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/grave.dart';
import 'add_grave_sheet.dart';
import 'add_mode.dart';
import 'delete_grave_dialog.dart';
import 'empty_graveyard_panel.dart';
import 'grave_list_controller.dart';
import 'grave_list_status.dart';
import 'grave_tile.dart';
import 'graveyard_copy.dart';
import 'load_error_view.dart';
import 'memory_notice.dart';
import 'save_error_banner.dart';
import 'save_status.dart';

/// The one screen of Graveyard: the tombstones, or the state that stands in
/// for them while loading, after a load error, or when nothing is buried.
class GraveyardScreen extends StatefulWidget {
  /// Creates the screen for [controller].
  const GraveyardScreen({super.key, required this.controller});

  /// The controller that owns the graves.
  final GraveListController controller;

  @override
  State<GraveyardScreen> createState() => _GraveyardScreenState();
}

class _GraveyardScreenState extends State<GraveyardScreen>
    with WidgetsBindingObserver {
  static const double _maxWidth = 560;
  static const double _sidePadding = 16;
  static const double _bottomPadding = 96;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshToday();
    }
  }

  void _openSheet([AddMode mode = AddMode.buryByHand]) {
    showAddGraveSheet(context, widget.controller, initial: mode);
  }

  Future<void> _delete(Grave grave) async {
    final bool confirmed = await showDeleteGraveDialog(context, grave.name);
    if (confirmed) await widget.controller.deleteGrave(grave.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? _) {
        final GraveListController c = widget.controller;
        final bool ready = c.status == GraveListStatus.ready;
        return Scaffold(
          floatingActionButton: ready
              ? FloatingActionButton.extended(
                  key: const ValueKey<String>('screen-add'),
                  tooltip: GraveyardCopy.addButton,
                  onPressed: _openSheet,
                  icon: const Icon(Icons.add),
                  label: const Text(GraveyardCopy.addButton),
                )
              : null,
          body: FogBackground(child: SafeArea(child: _body(context, c))),
        );
      },
    );
  }

  Widget _body(BuildContext context, GraveListController c) {
    if (c.status == GraveListStatus.loading) {
      return Center(
        child: Semantics(
          label: GraveyardCopy.loadingLabel,
          child: const GhostLoader(caption: GraveyardCopy.loadingCaption),
        ),
      );
    }
    final double width = MediaQuery.sizeOf(context).width;
    final double side = _sidePadding + math.max(0, (width - _maxWidth) / 2);
    final TextTheme text = Theme.of(context).textTheme;
    final List<Grave> graves = c.graves;
    final List<Widget> children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 16),
        child: Semantics(
          header: true,
          child: Text(
            GraveyardCopy.screenTitle,
            textAlign: TextAlign.center,
            style: text.displaySmall,
          ),
        ),
      ),
    ];
    if (c.status == GraveListStatus.loadError) {
      children.add(LoadErrorView(onRetry: c.load));
    } else {
      if (!c.isPersistent) {
        children.add(
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: MemoryNotice(),
          ),
        );
      }
      if (c.saveStatus == SaveStatus.saveError) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SaveErrorBanner(onRetry: c.retrySave),
          ),
        );
      }
      if (graves.isEmpty) {
        children.add(
          EmptyGraveyardPanel(
            onBuryByHand: () => _openSheet(AddMode.buryByHand),
            onImport: () => _openSheet(AddMode.importFromGitHub),
          ),
        );
      } else {
        final today = c.today;
        for (final Grave grave in graves) {
          children.add(
            Padding(
              key: ValueKey<String>('grave-${grave.id}'),
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: GraveTile(
                  grave: grave,
                  today: today,
                  onDelete: () => _delete(grave),
                ),
              ),
            ),
          );
        }
      }
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(side, 0, side, _bottomPadding),
      children: children,
    );
  }
}
