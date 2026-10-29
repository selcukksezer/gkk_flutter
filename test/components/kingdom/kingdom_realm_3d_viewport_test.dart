import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/kingdom/kingdom.dart';
import 'package:gkk_flutter/models/guild_war_model.dart';
import 'package:gkk_flutter/models/kingdom_market_blessing_model.dart';
import 'package:gkk_flutter/providers/kingdom_market_blessing_provider.dart';

void main() {
  group('KingdomTerritoryRealmController Tests', () {
    test('initializes with default Citadel mode and camera settings', () {
      final controller = KingdomTerritoryRealmController();
      expect(controller.mode, equals(KingdomRealmMode.citadel));
      expect(controller.yaw, equals(0.0));
      expect(controller.pitch, equals(0.12));
      expect(controller.zoom, equals(1.0));
      expect(controller.runicGlowActive, isTrue);
      expect(controller.selectedNodeIndex, isNull);
      expect(controller.nodes.length, equals(6));
    });

    test('switches modes and reframes camera angles', () {
      final controller = KingdomTerritoryRealmController();

      controller.setMode(KingdomRealmMode.territory);
      expect(controller.mode, equals(KingdomRealmMode.territory));
      expect(controller.pitch, equals(0.28));
      expect(controller.zoom, equals(0.88));

      controller.setMode(KingdomRealmMode.treasury);
      expect(controller.mode, equals(KingdomRealmMode.treasury));
      expect(controller.pitch, equals(0.08));
      expect(controller.zoom, equals(1.15));

      controller.setMode(KingdomRealmMode.citadel);
      expect(controller.mode, equals(KingdomRealmMode.citadel));
      expect(controller.pitch, equals(0.12));
      expect(controller.zoom, equals(1.0));
    });

    test('selects territory bastion and orients camera toward it', () {
      final controller = KingdomTerritoryRealmController();
      controller.selectNode(0);
      expect(controller.selectedNodeIndex, equals(0));

      controller.selectNode(null);
      expect(controller.selectedNodeIndex, isNull);
    });

    test('toggles runic glow and resets camera', () {
      final controller = KingdomTerritoryRealmController();
      expect(controller.runicGlowActive, isTrue);

      controller.toggleRunicGlow();
      expect(controller.runicGlowActive, isFalse);

      controller.toggleRunicGlow();
      expect(controller.runicGlowActive, isTrue);

      // Mutate camera state then reset
      controller.setMode(KingdomRealmMode.territory);
      controller.selectNode(2);
      controller.resetCamera();

      expect(controller.yaw, equals(0.0));
      expect(controller.pitch, equals(0.12));
      expect(controller.zoom, equals(1.0));
      expect(controller.selectedNodeIndex, isNull);
    });

    test('updates nodes from TerritoryData list', () {
      final controller = KingdomTerritoryRealmController();
      final territories = <TerritoryData>[
        const TerritoryData(
          id: 't1',
          name: 'Kuzey Kalesi',
          ownerGuildId: 'g1',
          ownerGuildName: 'Güneş Muhafızları',
          defenseLineLevel: 5,
          defensePower: 20000,
          hasActiveSiegeSession: false,
        ),
      ];

      controller.updateNodesFromTerritoryData(territories);
      expect(controller.nodes.first.name, equals('Kuzey Kalesi'));
      expect(controller.nodes.first.garrisonCount, equals(20000));
      expect(controller.nodes.first.defenseLevel, equals(5));
    });
  });

  group('KingdomRealm3DViewport Widget Tests', () {
    testWidgets('renders 3D realm viewport in Citadel mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KingdomRealm3DViewport(
              height: 320,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(KingdomRealm3DViewport), findsOneWidget);
      expect(find.text('Şato'), findsOneWidget);
      expect(find.text('Eyaletler'), findsOneWidget);
      expect(find.text('Kasa'), findsOneWidget);
      expect(find.text('3D Çevir & Yakınlaştır'), findsOneWidget);
      expect(find.text('Rün'), findsOneWidget);
      expect(find.text('Sıfırla'), findsOneWidget);
    });

    testWidgets('switches mode via top control chips', (tester) async {
      final controller = KingdomTerritoryRealmController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KingdomRealm3DViewport(
              controller: controller,
              height: 320,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Eyaletler'));
      await tester.pump();
      expect(controller.mode, equals(KingdomRealmMode.territory));

      await tester.tap(find.text('Kasa'));
      await tester.pump();
      expect(controller.mode, equals(KingdomRealmMode.treasury));
    });

    testWidgets('handles camera reset and runic toggle buttons', (tester) async {
      final controller = KingdomTerritoryRealmController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KingdomRealm3DViewport(
              controller: controller,
              height: 320,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Rün'));
      await tester.pump();
      expect(controller.runicGlowActive, isFalse);

      await tester.tap(find.text('Sıfırla'));
      await tester.pump();
      expect(controller.yaw, equals(0.0));
      expect(controller.pitch, equals(0.12));
    });

    testWidgets('displays selected bastion banner when node is chosen', (tester) async {
      final controller = KingdomTerritoryRealmController();
      RealmTerritoryNode? inspectedNode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KingdomRealm3DViewport(
              controller: controller,
              height: 340,
              onInspectTerritory: (node) => inspectedNode = node,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      controller.selectNode(0);
      await tester.pump();

      expect(find.text('Şafak Hisarı'), findsWidgets);
      expect(find.text('ELYOS'), findsOneWidget);
      expect(find.text('Teftiş Et'), findsOneWidget);

      await tester.tap(find.text('Teftiş Et'));
      expect(inspectedNode, isNotNull);
      expect(inspectedNode!.id, equals('node_dawn'));
    });
  });

  group('KingdomRealmView Master Dashboard Tests', () {
    testWidgets('renders all kingdom dashboard metrics, cards, and tax controls on 390x844 mobile viewport', (tester) async {
      tester.view.physicalSize = const Size(390 * 3.0, 844 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool taxCollected = false;
      bool mapOpened = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            kingdomMarketBlessingProvider.overrideWith(
              () => _FakeBlessingNotifier(
                KingdomMarketBlessingStatus(
                  active: true,
                  goldDiscountPct: 15,
                  gemDiscountPct: 10,
                  startedAt: DateTime.now(),
                  expiresAt: DateTime.now().add(const Duration(minutes: 30)),
                  activatedByUsername: 'KralArthur',
                  activatedByGuildName: 'Valhalla',
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: KingdomRealmView(
                  reignKingName: 'Lord Valerius',
                  reignGuildName: 'Güneş Şövalyeleri',
                  goldBalance: 3200000,
                  gemsBalance: 2400,
                  dailyTaxRevenue: 500000,
                  controlledTerritories: 5,
                  totalTerritories: 6,
                  isKing: true,
                  onTaxCollect: () => taxCollected = true,
                  onViewTerritoryMap: () => mapOpened = true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Header checks
      expect(find.text('AETHELGARD KRALLIK REJİMİ'), findsOneWidget);
      expect(find.text('Hükümdar: Lord Valerius [Güneş Şövalyeleri]'), findsOneWidget);

      // 3D Viewport checks
      expect(find.byType(KingdomRealm3DViewport), findsOneWidget);

      // Market blessing banner checks
      expect(find.text('KRAL İNDİRİMİ'), findsOneWidget);
      expect(find.text('Altın -%15'), findsOneWidget);
      expect(find.text('Elmas -%10'), findsOneWidget);

      // Treasury & Territory cards checks
      expect(find.text('KRALİYET HAZİNESİ'), findsOneWidget);
      expect(find.text('3.200.000 🪙'), findsOneWidget);
      expect(find.text('2.400 💎'), findsOneWidget);
      expect(find.text('Aethelgard Hükümranlığı'), findsOneWidget);

      // Tax action trigger check
      await tester.tap(find.text('Vergiyi Kasaya Aktar'));
      await tester.pump();
      expect(taxCollected, isTrue);

      // Territory map action trigger check
      await tester.tap(find.text('Haritayı Aç'));
      expect(mapOpened, isTrue);
    });

    testWidgets('opens King Gift dialog and submits gift', (tester) async {
      String? sentRecipient;
      int? sentAmount;
      String? sentNote;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: KingdomRealmView(
                  isKing: true,
                  onSendGift: (r, a, n) {
                    sentRecipient = r;
                    sentAmount = a;
                    sentNote = n;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Tap Hediye Gönder button
      await tester.tap(find.text('Hediye Gönder'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Kral Hediyesi Gönder'), findsOneWidget);

      // Enter recipient name
      await tester.enterText(find.byType(TextField).at(0), 'Galahad');
      // Enter amount
      await tester.enterText(find.byType(TextField).at(1), '50000');
      // Enter note
      await tester.enterText(find.byType(TextField).at(2), 'Kahramanlık Ödülü');

      await tester.tap(find.text('Gönder'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(sentRecipient, equals('Galahad'));
      expect(sentAmount, equals(50000));
      expect(sentNote, equals('Kahramanlık Ödülü'));
    });
  });
}

class _FakeBlessingNotifier extends KingdomMarketBlessingNotifier {
  _FakeBlessingNotifier(this._initialState);

  final KingdomMarketBlessingStatus _initialState;

  @override
  KingdomMarketBlessingStatus build() => _initialState;

  @override
  Future<void> load() async {}
}
