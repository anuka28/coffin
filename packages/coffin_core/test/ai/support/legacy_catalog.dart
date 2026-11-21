import 'package:coffin_core/src/ai/offline_engine.dart';
import 'package:coffin_core/src/ai/template_catalog.dart';
import 'package:coffin_core/src/ai/template_set.dart';

// Pure support code: no dart:io, no hive_ce, no Flutter. It runs in Chrome.

/// A frozen copy of the template catalog as it was before ghost-voice.
///
/// The single copy, shared by `legacy_equality_test.dart` and
/// `legacy_equality_property_test.dart`. Never edit these lists: they are the reference for
/// "legacy requests give the same text as before".
final TemplateCatalog frozenLegacyCatalog = TemplateCatalog(
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

/// An engine built from [frozenLegacyCatalog].
final OfflineEngine frozenLegacyEngine = OfflineEngine(frozenLegacyCatalog);
