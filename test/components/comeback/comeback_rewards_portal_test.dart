import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/components/comeback/comeback.dart';
import 'package:gkk_flutter/models/comeback_summary_model.dart';
import 'package:gkk_flutter/providers/comeback_summary_provider.dart';

void main() {
  group('ComebackModels Unit Tests', () {
    test('ComebackBuffInfo defaultBuff produces active 7-day buff with correct boosts', () {
      final DateTime now = DateTime(2026, 10, 28, 12);
      final ComebackBuffInfo buff = ComebackBuffInfo.defaultBuff(now: now, durationDays: 7);

      expect(buff.isActive, isTrue);
      expect(buff.expBoostPercent, equals(20));
      expect(buff.goldBoostPercent, equals(15));
      expect(buff.dropRateBoostPercent, equals(10));
      expect(buff.expiresAt.difference(buff.activatedAt).inDays, equals(7));
      expect(buff.isExpired, isFalse);
    });

    test('ComebackMilestoneTier generates default 7-day track with valid progression states', () {
      final List<ComebackMilestoneTier> track =
          ComebackMilestoneTier.generateDefaultTrack(currentProgressDay: 3);

      expect(track.length, equals(7));
      // Days 1 & 2 should be claimed
      expect(track[0].isClaimed, isTrue);
      expect(track[1].isClaimed, isTrue);
      // Day 3 should be ready
      expect(track[2].isReady, isTrue);
      expect(track[2].isClaimed, isFalse);
      expect(track[2].isLocked, isFalse);
      // Days 4..7 should be locked
      expect(track[3].isLocked, isTrue);
      expect(track[6].isLocked, isTrue);
      expect(track[6].rarity, equals(ComebackRarity.legendary));
    });

    test('ComebackGiftCardData handles default rewards and claim state copyWith', () {
      final ComebackGiftCardData card =
          ComebackGiftCardData.defaultForOffline(offlineHours: 72);

      expect(card.rewards.length, equals(4));
      expect(card.offlineHours, equals(72));
      expect(card.isClaimed, isFalse);

      final ComebackGiftCardData claimed = card.copyWith(isClaimed: true);
      expect(claimed.isClaimed, isTrue);
    });
  });

  group('Comeback Widget Tests (Mobile 390x844 Safe Area)', () {
    testWidgets('ComebackBuffBadge renders in expanded mode with stat chips', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ComebackBuffInfo buff = ComebackBuffInfo.defaultBuff();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: ComebackBuffBadge(buffInfo: buff),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Geri Dönen Savaşçı Kutsaması'), findsOneWidget);
      expect(find.text('AKTİF BUFF'), findsOneWidget);
      expect(find.text('+20% EXP'), findsOneWidget);
      expect(find.text('+15% Altın'), findsOneWidget);
      expect(find.text('+10% Drop'), findsOneWidget);
    });

    testWidgets('ComebackGiftCard displays rewards and fires onClaim callback with particle burst', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool claimed = false;
      final ComebackGiftCardData card =
          ComebackGiftCardData.defaultForOffline(offlineHours: 48);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: ComebackGiftCard(
                  data: card,
                  onClaim: () => claimed = true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Efsanevi Geri Dönüş Paketi'), findsOneWidget);
      expect(find.text('Paketi Al'), findsOneWidget);
      expect(find.text('Elmas Kesesi'), findsOneWidget);
      expect(find.text('5.000'), findsOneWidget);

      await tester.tap(find.text('Paketi Al'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(claimed, isTrue);
      expect(find.text('Alındı ✓'), findsOneWidget);
    });

    testWidgets('ComebackMilestoneTrack renders 7 days and allows claiming ready tier', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ComebackMilestoneTier? claimedTier;
      final List<ComebackMilestoneTier> track =
          ComebackMilestoneTier.generateDefaultTrack(currentProgressDay: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: ComebackMilestoneTrack(
                  tiers: track,
                  currentDay: 1,
                  onClaimTier: (ComebackMilestoneTier t) => claimedTier = t,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('7 Günlük Geri Dönüş Yolu'), findsOneWidget);
      expect(find.text('1. Gün'), findsOneWidget);
      expect(find.text('Al'), findsOneWidget);

      await tester.tap(find.text('Al'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(claimedTier, isNotNull);
      expect(claimedTier!.day, equals(1));
    });

    testWidgets('ComebackRewardsPortal renders responsive 390x844 layout without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const ComebackSummary dummySummary = ComebackSummary(
        showSummary: true,
        offlineHours: 74,
        pendingCount: 2,
        items: <ComebackSummaryItem>[
          ComebackSummaryItem(
            id: 'item_1',
            kind: ComebackItemKind.boxReady,
            title: 'Kutu Açılmaya Hazır',
            subtitle: 'Bronz sandık kilit açma tamamlandı',
            route: '/inventory',
            priority: 1,
            ctaLabel: 'Sandığa Git',
          ),
          ComebackSummaryItem(
            id: 'item_2',
            kind: ComebackItemKind.facilityReady,
            title: 'Tesis Üretimi Tamam',
            subtitle: 'Simya laboratuvarı iksirleri hazır',
            route: '/facility',
            priority: 2,
            ctaLabel: 'Topla',
          ),
        ],
      );

      bool closed = false;
      ComebackSummaryItem? tappedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComebackRewardsPortal(
              summary: dummySummary,
              onClose: () => closed = true,
              onActionItemTap: (ComebackSummaryItem i) => tappedItem = i,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Geri Dönen Savaşçı'), findsOneWidget);
      expect(find.text('Aion 2 Özel Karşılama Portalı'), findsOneWidget);
      expect(find.text('YOKLUĞUNDA GERÇEKLEŞENLER'), findsOneWidget);
      expect(find.text('Kutu Açılmaya Hazır'), findsOneWidget);
      expect(find.text('Tesis Üretimi Tamam'), findsOneWidget);
      expect(find.text('Atreia\'ya Dönüş Yap'), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);

      // Tap action item
      await tester.tap(find.text('Sandığa Git'));
      await tester.pump();
      expect(tappedItem?.id, equals('item_1'));

      // Tap close button
      await tester.tap(find.text('Atreia\'ya Dönüş Yap'));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('ComebackParticleBurst triggers particles without runtime errors', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ComebackParticleBurstController ctrl =
          ComebackParticleBurstController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: ComebackParticleBurst(
                  controller: ctrl,
                  particleCount: 30,
                  child: const Text('Target Child'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Target Child'), findsOneWidget);

      ctrl.burst(count: 30);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 1500));

      expect(tester.takeException(), isNull);
    });
  });
}
