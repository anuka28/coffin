import 'package:coffin_core/coffin_core.dart';

import 'home_controller.dart';
import 'home_screen.dart';

/// Builds the routes of Hauntagotchi around [controller].
///
/// The home route shows the [HomeScreen]. The `/gallery` route shows the
/// crypt gallery of spooky widgets. Nothing links to it, so it is reached
/// only by its address.
List<AppRoute> buildAppRoutes(HomeController controller) => <AppRoute>[
  AppRoute(
    path: '/',
    name: 'home',
    builder: (context, state) => HomeScreen(controller: controller),
  ),
  AppRoute(
    path: '/gallery',
    name: 'gallery',
    builder: (context, state) => CryptGallery(onBack: () => context.go('/')),
  ),
];
