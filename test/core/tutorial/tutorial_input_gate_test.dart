import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_input_gate.dart';

void main() {
  testWidgets('coach Devam above hole remains tappable over dim blockers', (
    WidgetTester tester,
  ) async {
    const Size screen = Size(390, 844);
    await tester.binding.setSurfaceSize(screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // HUD hole at top — Devam card sits below it (same layout as gold/gems).
    const Rect hole = Rect.fromLTWH(280, 50, 90, 32);
    var devamTapped = false;
    var wrongTapped = false;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: screen),
        child: MaterialApp(
          home: Scaffold(
            body: TutorialInputGate(
              hole: hole,
              onWrongTap: () => wrongTapped = true,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  const IgnorePointer(child: ColoredBox(color: Colors.black26)),
                  Positioned(
                    left: 20,
                    top: hole.bottom + 24,
                    width: 350,
                    child: ElevatedButton(
                      onPressed: () => devamTapped = true,
                      child: const Text('Devam'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Devam'));
    await tester.pump();

    expect(devamTapped, isTrue);
    expect(wrongTapped, isFalse);
  });

  testWidgets('tap outside hole and card still registers wrong tap', (
    WidgetTester tester,
  ) async {
    const Size screen = Size(390, 844);
    await tester.binding.setSurfaceSize(screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const Rect hole = Rect.fromLTWH(280, 50, 90, 32);
    var wrongTapped = false;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: screen),
        child: MaterialApp(
          home: Scaffold(
            body: TutorialInputGate(
              hole: hole,
              onWrongTap: () => wrongTapped = true,
              child: const Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  IgnorePointer(child: ColoredBox(color: Colors.black26)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(40, 400));
    await tester.pump();

    expect(wrongTapped, isTrue);
  });
}
