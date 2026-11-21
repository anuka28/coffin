import '../common/seeded_random.dart';
import 'ai_request.dart';
import 'clean_facts.dart';
import 'compose_path.dart';
import 'composed_text.dart';
import 'template.dart';
import 'template_catalog.dart';
import 'template_set.dart';
import 'text_rules.dart';

/// Writes a line from a [TemplateCatalog], with no outside input.
///
/// The purpose identifier only chooses the template set. It never reaches
/// the seed or the text. The same request always gives the same result.
final class OfflineEngine {
  /// Creates an engine over [catalog].
  const OfflineEngine(this.catalog);

  /// The engine behind the public offline generator. Built on first use.
  static final OfflineEngine standard = OfflineEngine(TemplateCatalog.standard);

  /// The templates this engine draws from.
  final TemplateCatalog catalog;

  /// Writes the text for [request]. Never throws for a constructed request.
  ComposedText compose(AiRequest request) {
    final CleanFacts facts = CleanFacts.from(request.facts);
    final TemplateSet set = catalog.setFor(request.purpose, facts);
    final List<Template> pool = set.templates;
    final int max = request.maxLength;

    // Step 1: templates whose count slots all have a fact.
    final List<Template> eligible = <Template>[
      for (final Template t in pool)
        if (t.isEligible(facts)) t,
    ];

    // Step 2: nothing to draw from.
    if (eligible.isEmpty) {
      return ComposedText(set.safeLine, ComposePath.safeLine);
    }

    // Step 3: templates whose filled text fits.
    final List<Template> fitting = <Template>[
      for (final Template t in eligible)
        if (t.render(facts).length <= max) t,
    ];

    final Template picked;
    final String text;
    final ComposePath path;
    if (fitting.isNotEmpty) {
      // Step 4: most used facts win, then one draw from the seed.
      int best = 0;
      for (final Template t in fitting) {
        final int used = t.usedFacts(facts);
        if (used > best) best = used;
      }
      final List<Template> candidates = <Template>[
        for (final Template t in fitting)
          if (t.usedFacts(facts) == best) t,
      ];
      picked =
          candidates[SeededRandom(request.seed).nextInt(candidates.length)];
      text = picked.render(facts);
      path = ComposePath.picked;
    } else {
      // Step 5: cut the shortest eligible template.
      int shortestLength = eligible.first.render(facts).length;
      for (final Template t in eligible) {
        final int length = t.render(facts).length;
        if (length < shortestLength) shortestLength = length;
      }
      final List<Template> shortest = <Template>[
        for (final Template t in eligible)
          if (t.render(facts).length == shortestLength) t,
      ];
      picked = shortest[SeededRandom(request.seed).nextInt(shortest.length)];
      text = TextRules.truncate(picked.render(facts), max);
      path = ComposePath.truncated;
    }

    // Step 6: the banned check on the final text.
    if (!TextRules.containsBanned(text)) return ComposedText(text, path);

    // Step 7: Recovery (a), the picked template without real names.
    if (picked.usesRealName(facts)) {
      final String t = picked.render(facts, useNames: false);
      if (_acceptable(t, max)) {
        return ComposedText(t, ComposePath.noNameVariant);
      }
    }

    // Step 8: Recovery (b), the pool in seed-rotated catalog order.
    final int start = request.seed % pool.length;
    for (int i = 0; i < pool.length; i++) {
      final Template c = pool[(start + i) % pool.length];
      if (!c.isEligible(facts)) continue;
      final String t = c.render(facts);
      if (_acceptable(t, max)) return ComposedText(t, ComposePath.nextTemplate);
      if (c.usesRealName(facts)) {
        final String bare = c.render(facts, useNames: false);
        if (_acceptable(bare, max)) {
          return ComposedText(bare, ComposePath.nextTemplate);
        }
      }
    }

    // Step 9: Recovery (c), the Safe_Line.
    return ComposedText(set.safeLine, ComposePath.safeLine);
  }

  static bool _acceptable(String text, int max) =>
      text.length <= max && !TextRules.containsBanned(text);
}
