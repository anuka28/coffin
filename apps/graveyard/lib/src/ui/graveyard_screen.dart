import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/grave.dart';
import '../domain/living_split.dart';
import 'add_grave_sheet.dart';
import 'add_mode.dart';
import 'delete_grave_dialog.dart';
import 'empty_graveyard_panel.dart';
import 'grave_list_controller.dart';
import 'grave_list_status.dart';
import 'graveyard_clipboard.dart';
import 'graveyard_copy.dart';
import 'graveyard_scene.dart';
import 'load_error_view.dart';
import 'memory_notice.dart';
import 'rest_dialog.dart';
import 'risen_announcement.dart';
import 'save_error_banner.dart';
import 'save_status.dart';

/// The one screen of Graveyard: the tombstones, or the state that stands in
/// for them while loading, after a load error, or when nothing is buried.
class GraveyardScreen extends StatefulWidget {
  /// Creates the screen for [controller].
  const GraveyardScreen({
    super.key,
    required this.controller,
    required this.seanceAi,
    this.clipboard = const SystemGraveyardClipboard(),
  });

  /// The controller that owns the graves.
  final GraveListController controller;

  /// The AI that words the verdict line of each séance.
  final CoffinAI seanceAi;

  /// Where repository links of the Living_Row are copied to.
  final GraveyardClipboard clipboard;

  @override
  State<GraveyardScreen> createState() => _GraveyardScreenState();
}

class _GraveyardScreenState extends State<GraveyardScreen>
    with WidgetsBindingObserver {
  static const double _maxWidth = 560;
  static const double _sidePadding = 16;

  /// Ids of the graves whose Resurrection_Play runs now. Never saved.
  final Set<String> _playing = <String>{};

  /// Count of Raises so far, read by [RisenAnnouncement]. Never saved.
  int _announceKey = 0;
  String? _announceName;

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
    if (!confirmed) return;
    if (mounted) setState(() => _playing.remove(grave.id));
    await widget.controller.deleteGrave(grave.id);
  }

  /// Raises [grave]. The séance sheet has already closed itself.
  void _raise(Grave grave) {
    if (!widget.controller.raise(grave.id)) return;
    setState(() {
      _playing.add(grave.id);
      _announceKey++;
      _announceName = grave.name;
    });
  }

  void _onPlayEnd(String id) {
    if (!mounted || !_playing.contains(id)) return;
    setState(() => _playing.remove(id));
  }

  Future<void> _layToRest(Grave grave) async {
    final bool confirmed = await showRestDialog(context, grave.name);
    if (!mounted) return;
    if (confirmed) widget.controller.layToRest(grave.id);
    _returnFocusTo(grave.id);
  }

  /// Gives focus back to the Lay_To_Rest_Control of [id] while it is in the
  /// tree. After a confirmed Lay_To_Rest the control is gone and nothing moves.
  void _returnFocusTo(String id) {
    final Key key = ValueKey<String>('lay-to-rest-$id');
    FocusNode? found;
    void visit(Element element) {
      if (found != null) return;
      final Widget w = element.widget;
      if (w.key == key && w is TextButton) {
        found = w.focusNode;
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    final FocusNode? node = found;
    if (node != null && node.context != null && node.canRequestFocus) {
      node.requestFocus();
    }
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
          body: c.status == GraveListStatus.loading
              ? FogBackground(child: SafeArea(child: _body(context, c)))
              : _body(context, c),
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
    final split = LivingSplit.split(graves: graves, playing: _playing);
    final bool noRows = split.$1.isEmpty;
    final bool noLiving = split.$2.isEmpty;
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
      if (noRows && noLiving) {
        children.add(
          EmptyGraveyardPanel(
            onBuryByHand: () => _openSheet(AddMode.buryByHand),
            onImport: () => _openSheet(AddMode.importFromGitHub),
          ),
        );
      }
      children.add(
        RisenAnnouncement(announcement: _announceKey, name: _announceName),
      );
    }
    // One scene for every non-loading state, at one place in the tree, so a
    // grave added to an empty graveyard rises. The title, notices, banners
    // and panels scroll inside it, above the rows. Loading drops the scene,
    // so graves of the first or of a retried load never rise.
    //
    // The key tells the load error scene from the ready scene. A retried load
    // may go from error to ready within one frame, with no loading frame in
    // between, and its graves must still not rise.
    return GraveyardScene(
      key: ValueKey<bool>(c.status == GraveListStatus.loadError),
      graves: c.status == GraveListStatus.loadError ? const <Grave>[] : graves,
      today: c.today,
      onDelete: _delete,
      seanceAi: widget.seanceAi,
      playingIds: _playing,
      onPlayEnd: _onPlayEnd,
      onRaise: _raise,
      onLayToRest: _layToRest,
      clipboard: widget.clipboard,
      noRows: Padding(
        padding: EdgeInsets.fromLTRB(side, 12, side, 0),
        child: Text(
          GraveyardCopy.allRisen,
          textAlign: TextAlign.center,
          style: text.bodyLarge,
        ),
      ),
      header: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(side, 0, side, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
