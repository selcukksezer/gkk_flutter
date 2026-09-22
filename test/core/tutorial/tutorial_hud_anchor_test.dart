import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_anchor_registry.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_hud_anchor.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track.dart';

void main() {
  group('Tutorial HUD anchors', () {
    testWidgets('gold energy gems chips register measurable rects', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TutorialHudAnchorChip(
                    anchorId: TutorialAnchorId.hudGold,
                    child: const Text('13.3k'),
                  ),
                  TutorialHudAnchorChip(
                    anchorId: TutorialAnchorId.hudGems,
                    child: const Text('100'),
                  ),
                  TutorialHudAnchorChip(
                    anchorId: TutorialAnchorId.hudEnergy,
                    child: const Text('92'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      TutorialAnchorRegistry.instance.scheduleRefresh();
      await tester.pump();

      for (final String id in <String>[
        TutorialAnchorId.hudGold,
        TutorialAnchorId.hudGems,
        TutorialAnchorId.hudEnergy,
      ]) {
        final Rect? hole = TutorialAnchorRegistry.instance.rectFor(
          id,
          padding: TutorialSpotlightGeometry.paddingFor(id),
        );
        expect(hole, isNotNull, reason: id);
        expect(hole!.width, greaterThan(0));
        expect(hole.height, greaterThan(0));
      }
    });

    test('normalizeHole inflates tiny hud rects', () {
      const Rect tiny = Rect.fromLTWH(10, 20, 12, 10);
      final Rect normalized = TutorialSpotlightGeometry.normalizeHole(
        tiny,
        TutorialAnchorId.hudGold,
      );
      expect(normalized.width, greaterThanOrEqualTo(96));
      expect(normalized.height, greaterThanOrEqualTo(34));
      expect(normalized.center, tiny.center);
    });

    test('normalizeHole grows menu tiles upward', () {
      const Rect short = Rect.fromLTWH(40, 200, 80, 40);
      final Rect normalized = TutorialSpotlightGeometry.normalizeHole(
        short,
        TutorialAnchorId.navMenuEnhancement,
      );
      expect(normalized.width, greaterThanOrEqualTo(76));
      expect(normalized.height, greaterThanOrEqualTo(96));
      expect(normalized.bottom, short.bottom);
      expect(normalized.top, lessThan(short.top));
    });

    test('menu padding taller on top', () {
      final EdgeInsets pad = TutorialSpotlightGeometry.paddingFor(
        TutorialAnchorId.navMenuEnhancement,
      );
      expect(pad.top, greaterThanOrEqualTo(pad.bottom));
      expect(pad.top, greaterThanOrEqualTo(8));
    });

    test('fallbackNavTabHole places character in rightmost third of bar', () {
      const Size screen = Size(390, 844);
      const EdgeInsets safe = EdgeInsets.only(top: 47, bottom: 34);
      final Rect? hole = TutorialSpotlightGeometry.fallbackNavTabHole(
        anchorId: TutorialAnchorId.navCharacterTab,
        screen: screen,
        safePadding: safe,
      );
      expect(hole, isNotNull);
      expect(hole!.center.dx, greaterThan(screen.width * 0.55));
      expect(hole.bottom, greaterThan(screen.height - 120));
    });

    test('fallbackHomeHole covers hud gold and home promo', () {
      const Size screen = Size(390, 844);
      const EdgeInsets safe = EdgeInsets.only(top: 47, bottom: 34);
      final Rect? gold = TutorialSpotlightGeometry.fallbackHomeHole(
        anchorId: TutorialAnchorId.hudGold,
        screen: screen,
        safePadding: safe,
      );
      final Rect? promo = TutorialSpotlightGeometry.fallbackHomeHole(
        anchorId: TutorialAnchorId.homePromo,
        screen: screen,
        safePadding: safe,
      );
      expect(gold, isNotNull);
      expect(gold!.top, lessThan(120));
      expect(promo, isNotNull);
      expect(promo!.width, greaterThan(200));

      final Rect? resolved = TutorialSpotlightGeometry.resolveHole(
        anchorId: TutorialAnchorId.hudEnergy,
        measuredLocal: null,
        screen: screen,
        safePadding: safe,
      );
      expect(resolved, isNotNull);
    });
  });
}
