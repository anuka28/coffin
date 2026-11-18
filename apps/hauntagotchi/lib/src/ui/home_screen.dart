import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/habit.dart';
import '../domain/haunting.dart';
import 'archive_dialog.dart';
import 'empty_habits_panel.dart';
import 'ghost_panel.dart';
import 'habit_name_dialog.dart';
import 'habit_tile.dart';
import 'haunt_copy.dart';
import 'home_controller.dart';
import 'home_status.dart';
import 'load_error_view.dart';
import 'memory_notice.dart';
import 'resurrection_panel.dart';
import 'save_error_banner.dart';
import 'save_status.dart';

/// The home screen: the ghost, today's habits and the controls around them.
///
/// The screen reads everything from [controller] and calls
/// [HomeController.refresh] when the app returns to the foreground. It does
/// not call [HomeController.load] on first build; whoever creates the
/// controller does that.
class HomeScreen extends StatefulWidget {
  /// Creates the home screen for [controller].
  const HomeScreen({super.key, required this.controller});

  /// The controller that owns the game state.
  final HomeController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const double _maxWidth = 560;

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
      widget.controller.refresh();
    }
  }

  HomeController get _controller => widget.controller;

  Future<void> _add() async {
    await HabitNameDialog.show(
      context,
      title: 'A new habit',
      confirmLabel: 'Add',
      onSubmit: _controller.addHabit,
    );
  }

  Future<void> _rename(Habit habit) async {
    await HabitNameDialog.show(
      context,
      title: 'Rename habit',
      confirmLabel: 'Rename',
      initialName: habit.name,
      onSubmit: (String name) => _controller.renameHabit(habit.id, name),
    );
  }

  Future<void> _archive(Habit habit) async {
    final bool confirmed = await ArchiveDialog.show(
      context,
      habitName: habit.name,
    );
    if (confirmed) {
      await _controller.archiveHabit(habit.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FogBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (BuildContext context, Widget? _) => switch (_controller
                .status) {
              HomeStatus.loading => const Center(
                child: GhostLoader(size: 96, caption: 'Waking the ghost…'),
              ),
              HomeStatus.loadError => LoadErrorView(onRetry: _controller.load),
              HomeStatus.ready => _buildReady(context, _controller.haunting!),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReady(BuildContext context, Haunting haunting) {
    final ThemeData theme = Theme.of(context);
    final List<Habit> active = haunting.book.active;
    final bool dead = haunting.ghost.isDead;
    final String? welcome = _controller.welcomeBack;
    final int missing = haunting.book.missingToSuggested;

    final List<Widget> children = <Widget>[
      if (!_controller.isPersistent) const MemoryNotice(),
      if (_controller.saveStatus == SaveStatus.saveError)
        SaveErrorBanner(onRetry: _controller.retrySave),
      if (welcome != null)
        _WelcomeBack(message: welcome, controller: _controller),
      GhostPanel(
        ghostName: haunting.ghost.name,
        health: haunting.liveHealth,
        state: haunting.state,
        streak: haunting.streak,
      ),
      if (dead)
        ResurrectionPanel(
          ghostName: haunting.ghost.name,
          ritual: haunting.ritual,
          resurrectionCount: haunting.ghost.resurrectionCount,
        ),
      if (active.isEmpty)
        EmptyHabitsPanel(onAdd: _add)
      else ...<Widget>[
        for (final Habit habit in active)
          HabitTile(
            key: ValueKey<String>('habit-${habit.id}'),
            name: habit.name,
            done: habit.isCompletedOn(haunting.today),
            onToggle: () => _controller.toggle(habit.id),
            onRename: () => _rename(habit),
            onArchive: () => _archive(habit),
          ),
        if (missing > 0)
          Text(
            HauntCopy.nudge(missing),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        _AddControl(canAdd: haunting.book.canAdd, onAdd: _add),
      ],
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 16),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The add-habit button, disabled with a readable reason at the limit.
class _AddControl extends StatelessWidget {
  const _AddControl({required this.canAdd, required this.onAdd});

  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          enabled: canAdd,
          label: canAdd
              ? HauntCopy.addHabit
              : '${HauntCopy.addHabit}. ${HauntCopy.addLimitReason}',
          excludeSemantics: true,
          child: FilledButton.icon(
            onPressed: canAdd ? onAdd : null,
            icon: const Icon(Icons.add),
            label: const Text(HauntCopy.addHabit),
          ),
        ),
        if (!canAdd) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            HauntCopy.addLimitReason,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// The dismissable message shown once after a resurrection.
class _WelcomeBack extends StatelessWidget {
  const _WelcomeBack({required this.message, required this.controller});

  final String message;
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(CoffinMetrics.cornerRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              liveRegion: true,
              container: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: HauntCopy.welcomeBackDismiss,
              excludeSemantics: true,
              child: TextButton(
                onPressed: controller.dismissWelcome,
                child: const Text(HauntCopy.welcomeBackDismiss),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
