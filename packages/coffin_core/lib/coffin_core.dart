/// Public API surface for the Coffin skeleton.
///
/// Apps import `package:coffin_core/coffin_core.dart` and must never
/// import files under `src/`.
library;

export 'package:go_router/go_router.dart'
    show GoRouter, GoRouterHelper, GoRouterState;

export 'src/router/app_route.dart' show AppRoute;
export 'src/router/fog_frame.dart' show FogFrame;
export 'src/router/fog_math.dart' show FogMath;
export 'src/router/fog_router.dart' show FogRouter;
export 'src/router/fog_transition.dart' show FogTransition;
export 'src/router/fog_transition_page.dart' show FogTransitionPage;
export 'src/router/not_found_page.dart' show NotFoundPage;
export 'src/theme/coffin_color_tokens.dart' show CoffinColorTokens;
export 'src/theme/coffin_glow.dart' show CoffinGlow;
export 'src/theme/coffin_metrics.dart' show CoffinMetrics;
export 'src/theme/coffin_theme.dart' show CoffinTheme;
export 'src/theme/coffin_typography.dart' show CoffinTypography;
export 'src/theme/contrast_pair.dart' show ContrastPair;
export 'src/theme/wcag_contrast.dart' show WcagContrast;
export 'src/widgets/coffin_mark.dart' show CoffinMark;
