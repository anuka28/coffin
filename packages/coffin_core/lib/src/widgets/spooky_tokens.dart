import 'package:flutter/material.dart';

import '../theme/coffin_color_tokens.dart';

/// Resolves the [CoffinColorTokens] that spooky widgets paint with.
abstract final class SpookyTokens {
  /// The Coffin token set that matches the brightness of the ambient Theme:
  /// [CoffinColorTokens.night] for dark, [CoffinColorTokens.daylight] for
  /// light.
  static CoffinColorTokens of(BuildContext context) {
    return switch (Theme.of(context).brightness) {
      Brightness.dark => CoffinColorTokens.night,
      Brightness.light => CoffinColorTokens.daylight,
    };
  }

  /// The ghost body color for [tokens]: `text` for a dark set, `primary`
  /// for a light set.
  static Color ghostBody(CoffinColorTokens tokens) {
    return tokens.brightness == Brightness.dark ? tokens.text : tokens.primary;
  }
}
