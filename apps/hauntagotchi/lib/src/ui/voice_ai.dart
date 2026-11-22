import 'package:coffin_core/coffin_core.dart';

/// The AI behind the ghost voice.
///
/// Both sides of the fallback are the offline generator, so it works without
/// a network or a key. The wrapper adds a 2 second timeout and shields the
/// caller from a throwing or slow primary.
CoffinAI defaultVoiceAi() => FallbackCoffinAI(
  primary: const OfflineCoffinAI(),
  secondary: const OfflineCoffinAI(),
  timeout: const Duration(seconds: 2),
);
