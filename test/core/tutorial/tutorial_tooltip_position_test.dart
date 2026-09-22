import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_tooltip.dart';

void main() {
  testWidgets('bottom-nav tooltip stays above hole and does not cover it', (
    WidgetTester tester,
  ) async {
    const Size screen = Size(390, 844);
    await tester.binding.setSurfaceSize(screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Simulated dungeon tab near bottom (typical safe-area + bar).
    const Rect hole = Rect.fromLTWH(140, 740, 70, 50);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: screen,
          padding: EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fromRect(
                  rect: hole,
                  child: const ColoredBox(
                    color: Colors.red,
                    child: SizedBox.expand(),
                  ),
                ),
                TutorialTooltipPositioned(
                  anchorRect: hole,
                  anchorId: TutorialAnchorId.navDungeonTab,
                  child: Container(
                    key: const Key('coach_card'),
                    width: 300,
                    height: 220,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder card = find.byKey(const Key('coach_card'));
    expect(card, findsOneWidget);
    final Rect cardRect = tester.getRect(card);
    expect(cardRect.bottom, lessThanOrEqualTo(hole.top - 8));
    expect(cardRect.intersect(hole).isEmpty, isTrue);
    // Coach must not extend into bottom-nav band (skip text over Karakter).
    expect(cardRect.bottom, lessThan(screen.height - 100));
  });

  testWidgets('character tab tooltip stays in upper band', (
    WidgetTester tester,
  ) async {
    const Size screen = Size(390, 844);
    await tester.binding.setSurfaceSize(screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const Rect hole = Rect.fromLTWH(250, 740, 70, 50);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: screen,
          padding: EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                TutorialTooltipPositioned(
                  anchorRect: hole,
                  anchorId: TutorialAnchorId.navCharacterTab,
                  child: Container(
                    key: const Key('coach_card'),
                    width: 300,
                    height: 220,
                    color: Colors.blue,
                    child: const Align(
                      alignment: Alignment.bottomLeft,
                      child: Text('Tümünü atla'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect cardRect = tester.getRect(find.byKey(const Key('coach_card')));
    expect(cardRect.intersect(hole).isEmpty, isTrue);
    expect(cardRect.bottom, lessThan(hole.top - 8));
    expect(find.text('Tümünü atla'), findsOneWidget);
    final Rect skipRect = tester.getRect(find.text('Tümünü atla'));
    expect(skipRect.intersect(hole).isEmpty, isTrue);
  });

  testWidgets('hud gold tooltip stays below hole and does not cover it', (
    WidgetTester tester,
  ) async {
    const Size screen = Size(390, 844);
    await tester.binding.setSurfaceSize(screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Simulated gold chip in top-left HUD.
    const Rect hole = Rect.fromLTWH(24, 58, 88, 28);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: screen,
          padding: EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fromRect(
                  rect: hole,
                  child: const ColoredBox(
                    color: Colors.red,
                    child: SizedBox.expand(),
                  ),
                ),
                TutorialTooltipPositioned(
                  anchorRect: hole,
                  anchorId: TutorialAnchorId.hudGold,
                  child: Container(
                    key: const Key('coach_card'),
                    width: 300,
                    height: 220,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder card = find.byKey(const Key('coach_card'));
    expect(card, findsOneWidget);
    final Rect cardRect = tester.getRect(card);
    expect(cardRect.top, greaterThanOrEqualTo(hole.bottom + 8));
    expect(cardRect.intersect(hole).isEmpty, isTrue);
  });

  testWidgets('tall hole pins coach to top so Devam stays visible', (
    WidgetTester tester,
  ) async {
    const Size screen = Size(390, 844);
    await tester.binding.setSurfaceSize(screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Class-abilities style panel: mid-screen, very tall.
    const Rect hole = Rect.fromLTWH(16, 220, 358, 480);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: screen,
          padding: EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fromRect(
                  rect: hole,
                  child: const ColoredBox(
                    color: Colors.red,
                    child: SizedBox.expand(),
                  ),
                ),
                TutorialTooltipPositioned(
                  anchorRect: hole,
                  anchorId: TutorialAnchorId.characterClassAbilities,
                  child: Container(
                    key: const Key('coach_card'),
                    width: 300,
                    height: 240,
                    color: Colors.blue,
                    alignment: Alignment.bottomCenter,
                    child: const Text('Devam'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(TutorialTooltipPositioned.isTallHole(hole, screen), isTrue);
    final Finder card = find.byKey(const Key('coach_card'));
    expect(card, findsOneWidget);
    final Rect cardRect = tester.getRect(card);
    // Pinned near top — full card (incl. Devam) above bottom nav band.
    expect(cardRect.top, lessThan(120));
    expect(cardRect.bottom, lessThan(screen.height - 80));
    expect(find.text('Devam'), findsOneWidget);
  });

  testWidgets('equip-btn mid-modal coach does not overflow tight band', (
    WidgetTester tester,
  ) async {
    const Size screen = Size(430, 932);
    await tester.binding.setSurfaceSize(screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // KUŞAN near upper-mid (item detail sheet) — tight room above hole.
    const Rect hole = Rect.fromLTWH(250, 280, 140, 44);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: screen,
          padding: EdgeInsets.only(top: 59, bottom: 34),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                TutorialTooltipPositioned(
                  anchorRect: hole,
                  anchorId: TutorialAnchorId.inventoryEquipBtn,
                  child: TutorialTooltipCard(
                    title: 'Kuşan',
                    body: 'Kuşan butonuna bas.',
                    stepIndex: 6,
                    stepTotal: 7,
                    onSkipAll: () {},
                    skipAllLabel: 'Tümünü atla',
                    accent: const Color(0xFFC9A227),
                    trackEmoji: '⚒',
                    trackLabel: 'GELİŞTİRME',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Kuşan'), findsOneWidget);
    final Rect cardRect = tester.getRect(find.byType(TutorialTooltipCard));
    expect(cardRect.bottom, lessThanOrEqualTo(hole.top - 8));
  });
}
