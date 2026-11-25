import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/graveyard_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SystemGraveyardClipboard puts the text on the clipboard', () async {
    final List<MethodCall> calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    const GraveyardClipboard clipboard = SystemGraveyardClipboard();
    await clipboard.copy('https://github.com/a/b');

    expect(calls.single.method, 'Clipboard.setData');
    expect(
      (calls.single.arguments as Map<Object?, Object?>)['text'],
      'https://github.com/a/b',
    );
  });

  test('SystemGraveyardClipboard can be a const', () {
    expect(const SystemGraveyardClipboard(), isA<GraveyardClipboard>());
  });
}
