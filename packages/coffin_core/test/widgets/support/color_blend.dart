// Pure support code: no dart:io, no Flutter. It runs in Chrome.

/// Blends the opaque color [foreground] over the opaque color [background]
/// with [alpha] from 0 to 1.
///
/// Both colors are `0xAARRGGBB` ints. The result is opaque (`0xFF` alpha).
/// Each channel is `round(fg * alpha + bg * (1 - alpha))`, stored in 8 bits.
int blendOver(int foreground, int background, double alpha) {
  int channel(int shift) {
    final int fg = (foreground >> shift) & 0xFF;
    final int bg = (background >> shift) & 0xFF;
    return (fg * alpha + bg * (1 - alpha)).round().clamp(0, 255);
  }

  return 0xFF000000 | (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

/// Blends [fog] over [base] [layers] times in a row, each layer with [alpha].
///
/// The result of every layer is rounded to 8 bits before the next one is
/// blended. Zero or fewer layers return [base] as an opaque color.
int blendRepeated(int fog, int base, double alpha, int layers) {
  int result = 0xFF000000 | (base & 0xFFFFFF);
  for (int i = 0; i < layers; i++) {
    result = blendOver(fog, result, alpha);
  }
  return result;
}
