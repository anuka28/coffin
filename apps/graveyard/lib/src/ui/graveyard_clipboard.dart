import 'package:flutter/services.dart';

/// Copies text to the clipboard so the app can hand out a repository link
/// without a package that opens addresses.
abstract interface class GraveyardClipboard {
  /// Copies [text] to the clipboard. May throw when the platform refuses.
  Future<void> copy(String text);
}

/// The [GraveyardClipboard] backed by the platform clipboard.
class SystemGraveyardClipboard implements GraveyardClipboard {
  /// Creates the system clipboard.
  const SystemGraveyardClipboard();

  @override
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}
