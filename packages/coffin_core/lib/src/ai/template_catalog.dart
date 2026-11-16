import 'ai_purpose.dart';
import 'template_set.dart';

/// The three template sets of the offline generator.
///
/// The order of each list is part of the determinism contract: changing the
/// order, or adding a line, changes the reply for existing seeds.
final class TemplateCatalog {
  /// Builds a catalog from three sets.
  TemplateCatalog({
    required this.ghostMoodLine,
    required this.seanceVerdict,
    required this.generic,
  });

  /// The shipped copy.
  static final TemplateCatalog standard = TemplateCatalog(
    ghostMoodLine: TemplateSet(const <String>[
      'Floating along.',
      'Your ghost is getting hungry…',
      'Mist, moonlight and good company.',
      '{ghostName|Your ghost} drifts by to say boo. 👻',
      'Streak: {streakCount:day/days}. The mist is on your side.',
      '{ghostName|Your ghost} has counted {streakCount:day/days} and is still floating.',
      '{streakCount:day/days} so far. {ghostName|Your ghost} is humming.',
      '{ghostName|Your ghost} waits by the window, glowing softly.',
    ], safeLine: 'Boo. Still here.'),
    seanceVerdict: TemplateSet(const <String>[
      'The spirits are still listening.',
      'Not gone, just napping.',
      'Not quite gone.',
      '{projectName|This project} has been dead for {daysSinceLastCommit:day/days}. Not forever, though.',
      'Last commit: {daysSinceLastCommit:day/days} ago. The ghost remembers.',
      '{projectName|This project} still glows faintly in the dark.',
      '{daysSinceLastCommit:day/days} of silence, and {projectName|this project} is still worth a séance.',
      'Every great haunting starts with one small commit.',
    ], safeLine: 'Rest, then rise.'),
    generic: TemplateSet(const <String>[
      'Boo. Hello from the mist.',
      'Something spooky this way comes.',
      'Quiet in here.',
      'The pumpkins say hi. 🎃',
      '{ghostName|A friendly ghost} says hello.',
      '{projectName|This one} is waiting in the moonlight.',
      '{streakCount:day/days} so far. The moon approves.',
      '{daysSinceLastCommit:day/days} on the clock. The fog is patient.',
    ], safeLine: 'Still here.'),
  );

  /// Lines for a ghost mood.
  final TemplateSet ghostMoodLine;

  /// Lines for a séance verdict.
  final TemplateSet seanceVerdict;

  /// Lines for any other purpose.
  final TemplateSet generic;

  /// The set for [purpose]: a known identifier gives its own set, anything
  /// else gives [generic].
  TemplateSet forPurpose(AiPurpose purpose) {
    switch (purpose.id) {
      case 'ghost_mood_line':
        return ghostMoodLine;
      case 'seance_verdict':
        return seanceVerdict;
      default:
        return generic;
    }
  }
}
