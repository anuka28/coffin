import 'package:flutter/material.dart';

import '../theme/coffin_metrics.dart';
import '../theme/coffin_theme.dart';
import 'crypt_gallery_panel.dart';

/// A page that shows every spooky widget in the night and the daylight theme.
///
/// The two panels sit side by side at 900 logical pixels and above and are
/// stacked below that. The page needs no router: [onBack] is a plain callback.
class CryptGallery extends StatefulWidget {
  /// Creates the gallery page.
  ///
  /// When [onBack] is not null a "Back to the crypt" button calls it.
  const CryptGallery({super.key, this.onBack});

  /// Called when the "Back to the crypt" button is pressed. Null hides it.
  final VoidCallback? onBack;

  @override
  State<CryptGallery> createState() => _CryptGalleryState();
}

class _CryptGalleryState extends State<CryptGallery> {
  static const double _maxWidth = 1200;
  static const double _sideBySideWidth = 900;

  final ThemeData _night = CoffinTheme.dark();
  final ThemeData _daylight = CoffinTheme.light();

  void _showGraveSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The grave stirs, but nothing rises. Yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Widget night = CryptGalleryPanel(
      title: 'Night',
      theme: _night,
      onGraveTap: _showGraveSnack,
    );
    final Widget daylight = CryptGalleryPanel(
      title: 'Daylight',
      theme: _daylight,
      onGraveTap: _showGraveSnack,
    );
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      'Crypt gallery',
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Every haunt we own, by moonlight and by day.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (widget.onBack != null) ...<Widget>[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: CoffinMetrics.minTapTarget,
                          minHeight: CoffinMetrics.minTapTarget,
                        ),
                        child: FilledButton(
                          onPressed: widget.onBack,
                          child: const Text('Back to the crypt'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) {
                      // The page padding is 16 on each side, so 900 of
                      // window width leaves 868 for this builder.
                      final bool wide = box.maxWidth + 32 >= _sideBySideWidth;
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: night),
                            const SizedBox(width: 16),
                            Expanded(child: daylight),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          night,
                          const SizedBox(height: 16),
                          daylight,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
