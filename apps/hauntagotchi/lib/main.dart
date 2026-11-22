import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'src/data/haunt_storage.dart';
import 'src/data/system_clock.dart';
import 'src/ui/app_routes.dart';
import 'src/ui/home_controller.dart';
import 'src/ui/voice_ai.dart';
import 'src/ui/voice_controller.dart';

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
  ///
  /// [ai] gives the ghost its voice. When null, the offline default is used.
  const HauntagotchiApp({super.key, required this.controller, this.ai});

  /// The controller that owns the game state and storage.
  final HomeController controller;

  /// The AI that writes the ghost's lines, or null for the offline default.
  final CoffinAI? ai;

  @override
  State<HauntagotchiApp> createState() => _HauntagotchiAppState();
}

class _HauntagotchiAppState extends State<HauntagotchiApp> {
  late final VoiceController _voice;

  // Built once so rebuilds and hot reloads do not reset navigation.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _voice = VoiceController(
      home: widget.controller,
      ai: widget.ai ?? defaultVoiceAi(),
    );
    _router = FogRouter.create(
      routes: buildAppRoutes(widget.controller, voice: _voice),
    );
    widget.controller.load();
  }

  @override
  void dispose() {
    _router.dispose();
    _voice.dispose();
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
