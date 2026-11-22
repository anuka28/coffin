/// A line the screen reader should announce once.
///
/// Each announcement has a [key] that is higher than the key of the one
/// before, so a listener can tell a new announcement from one it handled.
final class VoiceAnnouncement {
  /// Creates an announcement.
  const VoiceAnnouncement({required this.key, required this.text});

  /// Rises by one for each announcement of a controller, starting at 1.
  final int key;

  /// The line to announce.
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceAnnouncement && other.key == key && other.text == text;

  @override
  int get hashCode => Object.hash(key, text);

  @override
  String toString() => 'VoiceAnnouncement($key, $text)';
}
