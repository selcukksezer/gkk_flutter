import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_anchor.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_anchor_registry.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_input_gate.dart';

void main() {
  tearDown(() {
    TutorialAnchorRegistry.instance.debugClearTapActions();
  });

  testWidgets('registered hole action fires without pass-through', (
    WidgetTester tester,
  ) async {
    const Size screen = Size(390, 844);
    await tester.binding.setSurfaceSize(screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const Rect hole = Rect.fromLTWH(140, 480, 72, 72);
    var actionCount = 0;
    var wrongTapped = false;
    var underTapped = false;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: screen),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fromRect(
                  rect: hole,
                  child: GestureDetector(
                    onTap: () => underTapped = true,
                    child: const ColoredBox(color: Colors.red),
                  ),
                ),
                TutorialInputGate(
                  hole: hole.inflate(8),
                  onWrongTap: () => wrongTapped = true,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      const IgnorePointer(
                        child: ColoredBox(color: Color(0x88000000)),
                      ),
                      Positioned.fromRect(
                        rect: hole.inflate(8),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => actionCount++,
                          child: const ColoredBox(color: Colors.transparent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(hole.center);
    await tester.pump();

    expect(actionCount, 1);
    expect(underTapped, isFalse);
    expect(wrongTapped, isFalse);
  });

  testWidgets('TutorialAnchorScope registers and invokes tap action', (
    WidgetTester tester,
  ) async {
    var called = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorialAnchorScope(
            id: 'inv.weapon',
            onTutorialTap: () => called = true,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(TutorialAnchorRegistry.instance.hasTapAction('inv.weapon'), isTrue);
    final bool ran =
        await TutorialAnchorRegistry.instance.invokeTapAction('inv.weapon');
    expect(ran, isTrue);
    expect(called, isTrue);
  });
}
