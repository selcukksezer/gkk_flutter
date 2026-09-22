import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_anchor.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_anchor_registry.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track.dart';

void main() {
  group('Tutorial onboarding anchors', () {
    testWidgets('home promo anchor registers measurable rect', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TutorialAnchorScope(
                id: TutorialAnchorId.homePromo,
                child: Container(
                  key: const Key('promo_box'),
                  width: 320,
                  height: 120,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      TutorialAnchorRegistry.instance.scheduleRefresh();
      await tester.pump();

      final Rect? hole = TutorialAnchorRegistry.instance.rectFor(
        TutorialAnchorId.homePromo,
      );
      expect(hole, isNotNull);
      expect(hole!.width, greaterThan(0));
      expect(hole.height, greaterThan(0));
    });
  });
}
