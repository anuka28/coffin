import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'src/data/haunt_storage.dart';
import 'src/data/system_clock.dart';
import 'src/ui/app_routes.dart';
import 'src/ui/home_controller.dart';

void main() {
  final HomeController controller = HomeController(
    clock: const SystemClock(),
    openStorage: () => HauntStorage.open(
      StorageOpener(initializer: () => hiveFlutterInitializer('hauntagotchi')),
    ),
  );
  runApp(HauntagotchiApp(controller: controller));
}

/// Root widget of the Hauntagotchi app.
class HauntagotchiApp extends StatefulWidget {
  /// Creates the app root around [controller].
  const HauntagotchiApp({super.key, required this.controller});

  /// The controller that owns the game state and storage.
  final HomeController controller;

  @override
  State<HauntagotchiApp> createState() => _HauntagotchiAppState();
}

class _HauntagotchiAppState extends State<HauntagotchiApp> {
  // Built once so rebuilds and hot reloads do not reset navigation.
  late final GoRouter _router = FogRouter.create(
    routes: buildAppRoutes(widget.controller),
  );

  @override
  void initState() {
    super.initState();
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
      title: 'Hauntagotchi',
      theme: CoffinTheme.dark(),
      routerConfig: _router,
    );
  }
}
