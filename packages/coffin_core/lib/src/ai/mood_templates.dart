import 'clean_facts.dart';
import 'template_set.dart';

/// The copy for ghost mood lines: one base set per mood, plus an optional
/// set for each mood and event pair.
///
/// Set keys are `mood` (the base set) and `mood/event`, for example
/// `hungry` and `hungry/checkedOff`. Like the other catalog sets, the order of
/// each list is part of the determinism contract.
final class MoodTemplates {
  /// Builds the copy from [sets].
  ///
  /// Throws [StateError] unless every mood of [CleanFacts.moods] has a base
  /// set, so a valid mood always gives a set.
  MoodTemplates(Map<String, TemplateSet> sets)
    : sets = Map<String, TemplateSet>.unmodifiable(sets) {
    for (final mood in CleanFacts.moods) {
      if (!sets.containsKey(mood)) {
        throw StateError('Missing base template set for mood "$mood".');
      }
    }
  }

  /// The shipped copy: five moods, four events each.
  static final MoodTemplates standard = MoodTemplates(_shipped());

  /// Every set, by key (`mood` or `mood/event`).
  final Map<String, TemplateSet> sets;

  /// The set for [mood] and [event]: the `mood/event` set when it exists,
  /// otherwise the base set of [mood].
  ///
  /// Throws [StateError] when [mood] has no base set.
  TemplateSet setFor(String mood, String? event) {
    final set = sets['$mood/$event'] ?? sets[mood];
    if (set == null) {
      throw StateError('No template set for mood "$mood".');
    }
    return set;
  }

  static Map<String, TemplateSet> _shipped() {
    const n = '{ghostName|Your ghost}';
    const s = '{streakCount:day/days}';
    return <String, TemplateSet>{
      // ---- thriving ----
      'thriving': TemplateSet(const <String>[
        '$n is glowing and happy to see you.',
        'Moonlight, good company and a bright ghost.',
        'The mist is wholly on your side.',
        'Everything shimmers. Lovely to have you here.',
        'Streak: $s. The mist is cheering.',
      ], safeLine: 'Glowing happily.'),
      'thriving/appOpened': TemplateSet(const <String>[
        '$n is glowing. $s in a row.',
        '$n is glowing and so happy you\'re here.',
        'The mist is bright. $n says hi.',
        'Moonlight, good company and a happy ghost.',
        '$n floats over to welcome you.',
        'Streak: $s. The moon approves.',
      ], safeLine: 'Glowing happily.'),
      'thriving/checkedOff': TemplateSet(const <String>[
        'Yum. $n hums in the moonlight.',
        'That was delicious. $n glows brighter.',
        '$n does a happy little spin.',
        'Thank you. That glow is lovely.',
        'Another tick, another glow. Nicely done.',
        '$s in a row. $n is humming.',
      ], safeLine: 'Yum. Glowing.'),
      'thriving/moodChanged': TemplateSet(const <String>[
        '$n is glowing again, bright as the moon.',
        'The mist brightens. $n feels wonderful.',
        'Everything is shimmering.',
        'A warm glow fills the room.',
        'Bright, floaty and happy. Lovely.',
        '$n is shining. $s strong.',
      ], safeLine: 'Bright, floaty.'),
      'thriving/resurrected': TemplateSet(const <String>[
        '$n is back and shining!',
        'Welcome back! The moon is cheering.',
        'It worked! The mist is cheering.',
        'Hooray! $n floats free and happy.',
        'A fresh glow begins now.',
        '$n is back. Streak: $s.',
      ], safeLine: 'Back and bright!'),
      // ---- content ----
      'content': TemplateSet(const <String>[
        '$n is settled in and content.',
        'All is calm in the mist.',
        'A quiet, cozy hush. Nice to see you.',
        'Soft light, soft mist, soft ghost.',
        'The mist is calm. $s so far.',
      ], safeLine: 'All calm. Hello.'),
      'content/appOpened': TemplateSet(const <String>[
        'The mist is calm. $s so far.',
        '$n is settled in and content.',
        'A quiet, cozy hush. $n says hello.',
        'All is calm in the mist.',
        'Hello, friend. $n is happy you came.',
        '$n is calm. $s so far.',
      ], safeLine: 'All calm. Hello.'),
      'content/checkedOff': TemplateSet(const <String>[
        'A little glow for $n. Thank you.',
        'Nice and steady. That\'s the way.',
        '$n nods, content. Lovely work.',
        'Cozy. That went down well.',
        'One more tick. The mist approves.',
        '$s and steady. $n approves.',
      ], safeLine: 'Cozy. Thank you.'),
      'content/moodChanged': TemplateSet(const <String>[
        '$n settles in, content.',
        'A calm hush falls over the mist.',
        'Steady and cozy. Nicely done.',
        '$n glows softly. All is well.',
        'Peaceful and calm. Thank you for caring.',
        '$n is content. $s so far.',
      ], safeLine: 'Calm and cozy.'),
      'content/resurrected': TemplateSet(const <String>[
        '$n is back. Welcome home.',
        'It worked! Calm settles in.',
        'Welcome back! The mist is cozy.',
        'Hooray! $n floats home, content.',
        'A peaceful return. Lovely.',
        '$n is home. Streak: $s.',
      ], safeLine: 'Welcome home.'),
      // ---- hungry ----
      'hungry': TemplateSet(const <String>[
        '$n is peckish. One tick will do.',
        'A snack of progress would be lovely.',
        'No rush. A tiny tick is all it takes.',
        'The mist is quiet and the tummy rumbles.',
      ], safeLine: 'A snack, please.'),
      'hungry/appOpened': TemplateSet(const <String>[
        '$n is peckish. One tick will do.',
        'A small rumble in the mist. A tick helps.',
        'A snack of progress would be lovely.',
        '$n peeks out, hoping for a little glow.',
        'No rush. A tiny tick is all it takes.',
      ], safeLine: 'A snack, please.'),
      'hungry/checkedOff': TemplateSet(const <String>[
        'Crumbs of light. $n perks up.',
        'Nom. That helps a lot.',
        '$n smiles and nibbles the glow.',
        'Tasty. A little more and we\'re glowing.',
        'Thank you. The rumble is fading.',
      ], safeLine: 'Nom. Thank you.'),
      'hungry/moodChanged': TemplateSet(const <String>[
        '$n could use a snack, no rush.',
        'The mist whispers: a tick would be nice.',
        'A little hungry, still hopeful.',
        '$n peeks over, waiting kindly.',
        'Whenever you are ready, a snack awaits.',
      ], safeLine: 'A snack, please.'),
      'hungry/resurrected': TemplateSet(const <String>[
        '$n is back. Soft landing.',
        'Welcome back! Let\'s start with a snack.',
        'It worked! The mist is delighted.',
        'A fresh start, and a rumbling tummy.',
        '$n floats in, happy to be here.',
      ], safeLine: 'Back for snacks!'),
      // ---- fading ----
      'fading': TemplateSet(const <String>[
        '$n waits by the window. No rush.',
        'A pale glow, still here, still hopeful.',
        'One small tick brings the color back.',
        'Whenever you are ready, we are here.',
      ], safeLine: 'Hopeful glow.'),
      'fading/appOpened': TemplateSet(const <String>[
        '$n waits by the window. No rush.',
        'A pale glow, still here, still hopeful.',
        'One small tick brings the color back.',
        'The mist is quiet. $n would love company.',
        'Whenever you are ready, we are here.',
      ], safeLine: 'Hopeful glow.'),
      'fading/checkedOff': TemplateSet(const <String>[
        'A spark! $n drifts nearer.',
        'The glow is coming back, bit by bit.',
        'Thank you. That helped a lot.',
        '$n brightens a little. Lovely.',
        'Color returns to the mist.',
      ], safeLine: 'A spark. Thanks.'),
      'fading/moodChanged': TemplateSet(const <String>[
        '$n is a little pale. A tick helps.',
        'The glow is soft. Take your time.',
        'A quiet moment. One tick would warm it.',
        '$n is dim but hopeful.',
        'The mist waits patiently and kindly.',
      ], safeLine: 'Soft glow.'),
      'fading/resurrected': TemplateSet(const <String>[
        '$n is back. The mist cheers.',
        'It worked! Soft light fills the room.',
        'A glow returns. Welcome back.',
        '$n floats in, bright and hopeful.',
        'Hooray! A brand new glow begins.',
      ], safeLine: 'Back. Glow on.'),
      // ---- dead ----
      'dead': TemplateSet(const <String>[
        'The ritual waits. $n believes in you.',
        'A quiet crypt and a hopeful candle.',
        'One small step starts the ritual.',
        'The candles are lit. Ready when you are.',
      ], safeLine: 'Ritual awaits.'),
      'dead/appOpened': TemplateSet(const <String>[
        'The ritual waits. $n believes in you.',
        'A quiet crypt and a hopeful candle.',
        'One small step starts the ritual.',
        'The candles are lit. Ready when you are.',
        '$n is resting and rooting for you.',
      ], safeLine: 'Ritual awaits.'),
      'dead/checkedOff': TemplateSet(const <String>[
        'One step nearer. The candles flicker.',
        'The ritual hums. Keep going, gently.',
        '$n stirs. That helped.',
        'A little light returns to the crypt.',
        'Nicely done. The ritual is working.',
      ], safeLine: 'One step nearer.'),
      'dead/moodChanged': TemplateSet(const <String>[
        'The crypt is quiet. The ritual awaits.',
        'Candles glow. A small step will help.',
        '$n is resting. The ritual is near.',
        'A hush falls. Hope remains.',
        'The ritual is ready whenever you are.',
      ], safeLine: 'Hope remains.'),
      'dead/resurrected': TemplateSet(const <String>[
        'It worked! $n floats free!',
        'Hooray! The candles cheered it on.',
        'Welcome back! The mist is dancing.',
        '$n is back, glowing and giddy.',
        'The ritual worked. What a glow!',
      ], safeLine: 'It worked!'),
    };
  }
}
