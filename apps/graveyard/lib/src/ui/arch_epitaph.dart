import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';

import '../domain/scene/arch_fit.dart';
import '../domain/scene/keep_out_rect.dart';
import 'graveyard_copy.dart';

/// The engraved text ("R.I.P." by default) in the arch of a tombstone.
///
/// The text is placed by `ArchFit` so it stays inside the half-ellipse arch of
/// the stone. It is measured with a `TextPainter` at the scaled font size,
/// shrinks down to 12 px when it is too wide, and then truncates on one line
/// with an ellipsis. It never wraps. It is decoration, so it is excluded from
/// semantics. Place it as a child of the stone's `Stack`; it fills the stone
/// width and rotates with the stone.
class ArchEpitaph extends StatelessWidget {
  /// Creates the epitaph for a stone as wide as its parent.
  ///
  /// [text] is the engraved text. It defaults to `GraveyardCopy.epitaph`
  /// ("R.I.P.").
  const ArchEpitaph({super.key, this.text});

  /// The engraved text, or null for `GraveyardCopy.epitaph`.
  final String? text;

  /// Height of the arch curve, equal to the arch of `TombstoneCard`.
  static const double archRise = 140;

  /// Base font size at text scale 1.
  static const double baseFontSize = 20;

  /// Letter spacing of the engraved text.
  static const double letterSpacing = 2;

  static TextStyle _style(double fontSize) => TextStyle(
    fontFamily: CoffinTypography.displayFamily,
    package: CoffinTypography.package,
    fontSize: fontSize,
    letterSpacing: letterSpacing,
  );

  /// The rectangle the epitaph occupies, in stone coordinates (origin at the
  /// stone's top-left corner), for a stone of [width] at [textScaler].
  ///
  /// The rectangle lies inside [width] and is used as a crack keep-out area.
  ///
  /// [text] is the engraved text to measure. It defaults to
  /// `GraveyardCopy.epitaph` ("R.I.P.").
  static KeepOutRect rectFor({
    required double width,
    required TextScaler textScaler,
    String? text,
  }) => _layout(width, textScaler, text).rect;

  static _EpitaphLayout _layout(
    double width,
    TextScaler textScaler, [
    String? text,
  ]) {
    final engraved = text ?? GraveyardCopy.epitaph;
    final scaledBase = textScaler.scale(baseFontSize);
    final base = _measure(engraved, scaledBase, null);
    final fit = ArchFit.positionFor(
      archWidth: width,
      archRise: archRise,
      lineHeight: base.height,
      textWidth: base.width,
      fontSize: scaledBase,
    );
    final maxWidth = fit.truncated
        ? (width / 2 - ArchFit.margin) * 2
        : double.infinity;
    final size = _measure(
      engraved,
      fit.fontSize,
      maxWidth.isFinite ? maxWidth : null,
    );
    final w = size.width.clamp(0.0, width);
    final left = (width - w) / 2;
    final top = fit.top;
    return _EpitaphLayout(
      rect: KeepOutRect(
        left: left,
        top: top,
        right: left + w,
        bottom: top + size.height,
      ),
      fontSize: fit.fontSize,
    );
  }

  static Size _measure(String text, double fontSize, double? maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _style(fontSize)),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
      ellipsis: '\u2026',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? CoffinColorTokens.night
        : CoffinColorTokens.daylight;
    final scaler = MediaQuery.textScalerOf(context);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final layout = _layout(width, scaler, text);
          final rect = layout.rect;
          return Stack(
            children: [
              Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.right - rect.left,
                child: Text(
                  text ?? GraveyardCopy.epitaph,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: _style(layout.fontSize).copyWith(color: palette.muted),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EpitaphLayout {
  const _EpitaphLayout({required this.rect, required this.fontSize});

  final KeepOutRect rect;
  final double fontSize;
}
