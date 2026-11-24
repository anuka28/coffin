import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_coffin_ai.dart';

void main() {
  final request = AiRequest(
    purpose: AiPurpose.seanceVerdict,
    maxLength: AiRequest.minimumMaxLength,
  );

  test('replies at once and records the request', () async {
    final ai = FakeCoffinAI.replying('boo');
    expect((await ai.ask(request)).text, 'boo');
    expect(ai.requests, <AiRequest>[request]);
  });

  test('held reply waits for release', () async {
    final ai = FakeCoffinAI.held('boo');
    var done = false;
    final future = ai.ask(request).then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    ai.release();
    await future;
    expect(done, isTrue);
  });

  test('failing, throwing, blank and over-length behave as named', () async {
    await expectLater(FakeCoffinAI.failing().ask(request), throwsA(anything));
    expect(() => FakeCoffinAI.throwing().ask(request), throwsA(anything));
    expect(
      (await FakeCoffinAI.blank().ask(request)).isUsableFor(request),
      isFalse,
    );
    expect(
      (await FakeCoffinAI.overLength().ask(request)).isUsableFor(request),
      isFalse,
    );
  });
}
