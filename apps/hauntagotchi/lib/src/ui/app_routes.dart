import 'package:coffin_core/coffin_core.dart';

import 'placeholder_screen.dart';

/// The routes of Hauntagotchi. The home route shows the placeholder screen.
/// The `/gallery` route shows the crypt gallery of spooky widgets. Nothing
/// links to it, so it is reached only by its address.
final List<AppRoute> appRoutes = <AppRoute>[
  AppRoute(
    path: '/',
    name: 'home',
    builder: (context, state) => const PlaceholderScreen(),
  ),
  AppRoute(
    path: '/gallery',
    name: 'gallery',
    builder: (context, state) => CryptGallery(onBack: () => context.go('/')),
  ),
];
