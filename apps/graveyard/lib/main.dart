import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'src/data/grave_storage.dart';
import 'src/data/http_github_client.dart';
import 'src/data/system_clock.dart';
import 'src/ui/app_routes.dart';
import 'src/ui/grave_list_controller.dart';
import 'src/ui/seance_ai.dart';

void main() {
  const SystemClock clock = SystemClock();
  final GraveListController controller = GraveListController(
    clock: clock,
    github: HttpGitHubClient(clock: clock),
    openStorage: () => GraveStorage.open(
      StorageOpener(
        initializer: () => hiveFlutterInitializer(GraveStorage.subDirectory),
      ),
    ),
  );
  runApp(GraveyardApp(controller: controller, seanceAi: buildSeanceAi()));
}

/// Root widget of the Graveyard app.
class GraveyardApp extends StatefulWidget {
  /// Creates the app root around [controller].
  const GraveyardApp({
    super.key,
    required this.controller,
    required this.seanceAi,
  });

  /// The controller that owns the graves and their storage.
  final GraveListController controller;

  /// The AI that words the verdict line of each séance, built once.
  final CoffinAI seanceAi;

  @override
  State<GraveyardApp> createState() => _GraveyardAppState();
}

class _GraveyardAppState extends State<GraveyardApp> {
  // Built once so rebuilds and hot reloads do not reset navigation.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = FogRouter.create(
      routes: buildAppRoutes(widget.controller, widget.seanceAi),
    );
    widget.controller.load();
  }

  @override
  void dispose() {
    _router.dispose();
    widget.controller.disposeStorage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Graveyard',
      theme: CoffinTheme.dark(),
      routerConfig: _router,
    );
  }
}
