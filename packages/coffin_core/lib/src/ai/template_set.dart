import 'template.dart';

/// The templates for one purpose, plus the short line used when nothing
/// else fits.
final class TemplateSet {
  /// Parses every entry of [patterns] in order. Throws [StateError] when a
  /// pattern is bad. [safeLine] is the last resort line of this set.
  TemplateSet(List<String> patterns, {required this.safeLine})
    : templates = List<Template>.unmodifiable(patterns.map(Template.new));

  /// The parsed templates, in catalog order.
  final List<Template> templates;

  /// The last resort line. It has no slots and is at most 16 units long.
  final String safeLine;
}
