import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/arch_epitaph.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const width = 270.0;
  const scaler = TextScaler.linear(1);

  test('omitting text matches passing GraveyardCopy.epitaph', () {
    final omitted = ArchEpitaph.rectFor(width: width, textScaler: scaler);
    final explicit = ArchEpitaph.rectFor(
      width: width,
      textScaler: scaler,
      text: GraveyardCopy.epitaph,
    );
    expect(GraveyardCopy.epitaph, 'R.I.P.');
    expect(explicit.left, omitted.left);
    expect(explicit.top, omitted.top);
    expect(explicit.right, omitted.right);
    expect(explicit.bottom, omitted.bottom);
  });

  test('custom text yields a finite, non-empty rect inside the stone', () {
    final rect = ArchEpitaph.rectFor(
      width: width,
      textScaler: scaler,
      text: 'RISEN',
    );
    for (final v in [rect.left, rect.top, rect.right, rect.bottom]) {
      expect(v.isFinite, isTrue);
    }
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(width));
    expect(rect.right, greaterThan(rect.left));
    expect(rect.bottom, greaterThan(rect.top));
  });
}
