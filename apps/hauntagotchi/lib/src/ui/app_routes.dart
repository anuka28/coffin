import 'package:coffin_core/coffin_core.dart';

import 'placeholder_screen.dart';

/// The routes of Hauntagotchi. The home route shows the placeholder screen.
final List<AppRoute> appRoutes = <AppRoute>[
  AppRoute(
    path: '/',
    name: 'home',
    builder: (context, state) => const PlaceholderScreen(),
  ),
];
