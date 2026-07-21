import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_anchor_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    // Registry is a singleton — clear keys between tests via unregister.
  });

  testWidgets('rectFor applies padding symmetrically', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: key,
              width: 40,
              height: 20,
            ),
          ),
        ),
      ),
    );

    TutorialAnchorRegistry.instance.register('pad_test', key);
    await tester.pump();

    final Rect? raw = TutorialAnchorRegistry.instance.rectFor('pad_test');
    final Rect? padded = TutorialAnchorRegistry.instance.rectFor(
      'pad_test',
      padding: const EdgeInsets.all(4),
    );

    expect(raw, isNotNull);
    expect(padded, isNotNull);
    expect(padded!.left, raw!.left - 4);
    expect(padded.top, raw.top - 4);
    expect(padded.right, raw.right + 4);
    expect(padded.bottom, raw.bottom + 4);

    TutorialAnchorRegistry.instance.unregister('pad_test', key);
  });
}
