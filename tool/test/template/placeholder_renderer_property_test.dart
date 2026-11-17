import 'package:coffin_raise/src/template/placeholder_renderer.dart';
import 'package:coffin_raise/src/template/placeholders.dart';
import 'package:coffin_raise/src/template/render_outcome.dart';
import 'package:coffin_raise/src/template/template_file.dart';
import 'package:glados/glados.dart';

/// Characters for literal text and values. No `{`, so no marker can form.
const List<String> _chars = [
  'a',
  'Z',
  '0',
  ' ',
  '\n',
  '}',
  '_',
  '-',
  '{', // filtered out of values and literals below via [_noBrace]
  'é',
  '👻',
];

String _noBrace(List<String> chars) => chars.join().replaceAll('{', '');

/// One piece of a template: a literal when [key] is null, else a placeholder.
final class _Segment {
  const _Segment(this.literal, this.key);
  final String literal;
  final String? key;
}

/// A template with its expected output.
final class _Case {
  const _Case(this.segments, this.values);
  final List<_Segment> segments;
  final Map<String, String> values;

  String get template =>
      segments.map((s) => s.key == null ? s.literal : '{{${s.key}}}').join();

  String get expected =>
      segments.map((s) => s.key == null ? s.literal : values[s.key]!).join();

  @override
  String toString() =>
      'segments: ${[for (final s in segments) s.key == null ? '"${s.literal}"' : '{{${s.key}}}']}, values: $values';
}

extension _AnyRender on Any {
  Generator<String> get _text =>
      listWithLengthInRange(0, 8, choose(_chars)).map(_noBrace);

  Generator<_Segment> get _segment => combine3(
    choose([true, false]),
    _text,
    choose(Placeholders.known),
    (bool isLiteral, String text, String key) =>
        isLiteral ? _Segment(text, null) : _Segment('', key),
  );

  Generator<Map<String, String>> get _values => combine4(
    _text,
    _text,
    _text,
    _text,
    (String a, String b, String c, String d) => {
      for (final (i, k) in Placeholders.known.indexed) k: [a, b, c, d][i],
    },
  );

  Generator<_Case> get renderCase => combine2(
    listWithLengthInRange(0, 10, _segment),
    _values,
    (List<_Segment> segments, Map<String, String> values) =>
        _Case(segments, values),
  );

  Generator<String> get plainText => _text;

  Generator<List<int>> get byteList =>
      listWithLengthInRange(0, 64, intInRange(0, 256));
}

void main() {
  group('PlaceholderRenderer properties', () {
    // Feature: raise-app, Property 5: Rendering replaces every known placeholder and preserves everything else
    // Validates: Requirements 3.2, 3.4, 3.6
    Glados(
      any.renderCase,
      ExploreConfig(numRuns: 200),
    ).test('replaces every known placeholder and keeps all other text', (c) {
      final RenderOutcome outcome = PlaceholderRenderer(c.values)
          .render(c.template);
      if (outcome is! Rendered) {
        throw TestFailure('expected Rendered for ${c.template}, got $outcome');
      }
      if (outcome.text != c.expected) {
        throw TestFailure('expected "${c.expected}" but got "${outcome.text}"');
      }
      if (outcome.text.contains('{{')) {
        throw TestFailure('result still contains "{{": "${outcome.text}"');
      }
    });

    // Feature: raise-app, Property 5: Rendering replaces every known placeholder and preserves everything else
    // Validates: Requirements 3.2, 3.4, 3.6
    Glados2(any.plainText, any.renderCase, ExploreConfig(numRuns: 200)).test(
      'returns text without "{{" unchanged',
      (text, c) {
        final RenderOutcome outcome = PlaceholderRenderer(c.values)
            .render(text);
        if (outcome is! Rendered || outcome.text != text) {
          throw TestFailure('"$text" changed: $outcome');
        }
      },
    );

    // Feature: raise-app, Property 5: Rendering replaces every known placeholder and preserves everything else
    // Validates: Requirements 3.2, 3.4, 3.6
    Glados(any.byteList, ExploreConfig(numRuns: 200)).test(
      'non-.tmpl files are binary and keep exactly their bytes',
      (bytes) {
        final file = TemplateFile('assets/file.bin', bytes);
        if (file.isText) {
          throw TestFailure('non-.tmpl file treated as text');
        }
        if (file.bytes.length != bytes.length) {
          throw TestFailure('length changed');
        }
        for (var i = 0; i < bytes.length; i++) {
          if (file.bytes[i] != bytes[i]) {
            throw TestFailure('byte $i changed');
          }
        }
      },
    );
  });
}
