import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import 'src/ui/app_routes.dart';

void main() {
  runApp(const HauntagotchiApp());
}

/// Root widget of the Hauntagotchi app.
class HauntagotchiApp extends StatefulWidget {
  /// Creates the app root.
  const HauntagotchiApp({super.key});

  @override
  State<HauntagotchiApp> createState() => _HauntagotchiAppState();
}

class _HauntagotchiAppState extends State<HauntagotchiApp> {
  // Built once so rebuilds and hot reloads do not reset navigation.
  late final GoRouter _router = FogRouter.create(routes: appRoutes);

  @override
  void dispose() {
    _router.dispose();
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
