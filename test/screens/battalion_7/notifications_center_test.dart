import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/notification_item.dart';
import 'package:gkk_flutter/screens/notifications/notification_card.dart';
import 'package:gkk_flutter/screens/notifications/notification_category.dart';
import 'package:gkk_flutter/screens/notifications/notification_center_view.dart';
import 'package:gkk_flutter/screens/notifications/notification_runic_empty_state.dart';

void main() {
  group('NotificationCategory Tests', () {
    test('NotificationCategory correctly maps all kinds', () {
      // System
      expect(NotificationCategory.system.matches(NotificationKind.facilityReady), isTrue);
      expect(NotificationCategory.system.matches(NotificationKind.hospital), isTrue);
      expect(NotificationCategory.system.matches(NotificationKind.hospitalDischarge), isTrue);
      expect(NotificationCategory.system.matches(NotificationKind.prison), isTrue);
      expect(NotificationCategory.system.matches(NotificationKind.nightMarketOpen), isTrue);
      expect(NotificationCategory.system.matches(NotificationKind.nightMarketEnding), isTrue);
      expect(NotificationCategory.system.matches(NotificationKind.bugReportUpdate), isTrue);
      expect(NotificationCategory.system.matches(NotificationKind.marketSale), isTrue);
      expect(NotificationCategory.system.matches(NotificationKind.craftReady), isTrue);
      expect(NotificationCategory.system.matches(NotificationKind.pvpInvite), isFalse);

      // Combat
      expect(NotificationCategory.combat.matches(NotificationKind.pvpInvite), isTrue);
      expect(NotificationCategory.combat.matches(NotificationKind.pvpResult), isTrue);
      expect(NotificationCategory.combat.matches(NotificationKind.nemesisRevenge), isTrue);
      expect(NotificationCategory.combat.matches(NotificationKind.nemesisOnline), isTrue);
      expect(NotificationCategory.combat.matches(NotificationKind.lowHealth), isTrue);
      expect(NotificationCategory.combat.matches(NotificationKind.healthFull), isTrue);
      expect(NotificationCategory.combat.matches(NotificationKind.classBuff), isTrue);
      expect(NotificationCategory.combat.matches(NotificationKind.friendRequest), isFalse);

      // Social
      expect(NotificationCategory.social.matches(NotificationKind.friendRequest), isTrue);
      expect(NotificationCategory.social.matches(NotificationKind.friendRequestAccepted), isTrue);
      expect(NotificationCategory.social.matches(NotificationKind.friendRequestRejected), isTrue);
      expect(NotificationCategory.social.matches(NotificationKind.tradeInvite), isTrue);
      expect(NotificationCategory.social.matches(NotificationKind.chatMessage), isTrue);
      expect(NotificationCategory.social.matches(NotificationKind.dailyReward), isFalse);

      // Rewards
      expect(NotificationCategory.rewards.matches(NotificationKind.dailyReward), isTrue);
      expect(NotificationCategory.rewards.matches(NotificationKind.questReward), isTrue);
      expect(NotificationCategory.rewards.matches(NotificationKind.referralReward), isTrue);
      expect(NotificationCategory.rewards.matches(NotificationKind.boxReady), isTrue);
      expect(NotificationCategory.rewards.matches(NotificationKind.codexNewEntry), isTrue);
      expect(NotificationCategory.rewards.matches(NotificationKind.codexMilestone), isTrue);
      expect(NotificationCategory.rewards.matches(NotificationKind.facilityReady), isFalse);

      // All
      for (final NotificationKind kind in NotificationKind.values) {
        expect(NotificationCategory.all.matches(kind), isTrue);
      }
    });

    test('NotificationCategory filters items and counts unread accurately', () {
      final List<GameNotificationItem> items = <GameNotificationItem>[
        GameNotificationItem(
          id: 'combat_1',
          kind: NotificationKind.pvpInvite,
          title: 'PvP Düello',
          body: 'Meydan okuma var',
          createdAt: DateTime.now(),
        ),
        GameNotificationItem(
          id: 'reward_1',
          kind: NotificationKind.dailyReward,
          title: 'Günlük Ödül',
          body: 'Ödülünü al',
          createdAt: DateTime.now(),
        ),
        GameNotificationItem(
          id: 'social_1',
          kind: NotificationKind.friendRequest,
          title: 'Arkadaşlık',
          body: 'Yeni istek',
          createdAt: DateTime.now(),
        ),
        GameNotificationItem(
          id: 'system_1',
          kind: NotificationKind.facilityReady,
          title: 'Tesis',
          body: 'Kaynaklar hazır',
          createdAt: DateTime.now(),
        ),
      ];

      expect(NotificationCategory.all.filter(items).length, 4);
      expect(NotificationCategory.combat.filter(items).length, 1);
      expect(NotificationCategory.rewards.filter(items).length, 1);
      expect(NotificationCategory.social.filter(items).length, 1);
      expect(NotificationCategory.system.filter(items).length, 1);

      expect(NotificationCategory.all.countUnread(items), 4);
      expect(NotificationCategory.combat.countUnread(items), 1);
      expect(NotificationCategory.rewards.countUnread(items), 1);
      expect(NotificationCategory.social.countUnread(items), 1);
      expect(NotificationCategory.system.countUnread(items), 1);
    });
  });

  group('NotificationRunicEmptyState Tests', () {
    testWidgets('renders runic empty state with title, subtitle and triggers buttons',
        (WidgetTester tester) async {
      bool refreshed = false;
      bool resetCategory = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationRunicEmptyState(
              category: NotificationCategory.combat,
              onRefresh: () => refreshed = true,
              onResetCategory: () => resetCategory = true,
            ),
          ),
        ),
      );

      expect(find.text('SAVAŞ ALANI DURGUN'), findsOneWidget);
      expect(find.text('SAVAŞ'), findsOneWidget);
      expect(find.text('YENİLE'), findsOneWidget);
      expect(find.text('TÜMÜNE DÖN'), findsOneWidget);

      await tester.tap(find.text('YENİLE'));
      expect(refreshed, isTrue);

      await tester.tap(find.text('TÜMÜNE DÖN'));
      expect(resetCategory, isTrue);
    });
  });

  group('NotificationCard Tests', () {
    testWidgets('renders card content, badges, and executes onTap/onDismiss',
        (WidgetTester tester) async {
      bool tapped = false;
      bool dismissed = false;

      final GameNotificationItem item = GameNotificationItem(
        id: 'test_card_1',
        kind: NotificationKind.questReward,
        title: 'GÖREV TAMAMLANDI',
        body: 'Ejderha ini temizlendi — ödülü al.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        routePath: '/quests',
        priority: 80,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              item: item,
              onTap: () => tapped = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('GÖREV TAMAMLANDI'), findsOneWidget);
      expect(find.text('Ejderha ini temizlendi — ödülü al.'), findsOneWidget);
      expect(find.text('GÖREVLER'), findsOneWidget);
      expect(find.text('ÖNEMLİ'), findsOneWidget);
      expect(find.text('Ödülü Topla'), findsOneWidget);
      expect(find.text('5 dk'), findsOneWidget);

      // Tap action button
      await tester.tap(find.text('Ödülü Topla'));
      expect(tapped, isTrue);

      // Tap dismiss 'X'
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(dismissed, isTrue);
    });

    testWidgets('swipe-to-dismiss gesture triggers onDismiss',
        (WidgetTester tester) async {
      bool dismissed = false;

      final GameNotificationItem item = GameNotificationItem(
        id: 'swipe_card_1',
        kind: NotificationKind.pvpInvite,
        title: 'PVP MEYDAN OKUMA',
        body: 'Aion savaşçısı seni bekliyor',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              item: item,
              onTap: () {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.drag(find.byType(NotificationCard), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });
  });

  group('NotificationCenterView Integration Tests', () {
    testWidgets('renders tabs with unread badges, filters by category, and shows empty state',
        (WidgetTester tester) async {
      final List<GameNotificationItem> testItems = <GameNotificationItem>[
        GameNotificationItem(
          id: 'n_combat',
          kind: NotificationKind.pvpInvite,
          title: 'Arena Meydan Okuma',
          body: 'Gladyatör seni çağırdı',
          createdAt: DateTime.now(),
          routePath: '/pvp',
        ),
        GameNotificationItem(
          id: 'n_reward',
          kind: NotificationKind.dailyReward,
          title: 'Günlük Ödül Hazır',
          body: 'Giriş hediyesi seni bekliyor',
          createdAt: DateTime.now(),
          routePath: '/rewards',
        ),
      ];

      GameNotificationItem? tappedItem;
      GameNotificationItem? dismissedItem;
      bool markAllCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCenterView(
              items: testItems,
              onItemTap: (item) => tappedItem = item,
              onItemDismiss: (item) => dismissedItem = item,
              onMarkAllAsRead: () => markAllCalled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Check tab names
      expect(find.text(NotificationCategory.all.label.toUpperCase()), findsOneWidget);
      expect(find.text(NotificationCategory.system.label.toUpperCase()), findsOneWidget);
      expect(find.text(NotificationCategory.combat.label.toUpperCase()), findsOneWidget);
      expect(find.text(NotificationCategory.social.label.toUpperCase()), findsOneWidget);
      expect(find.text(NotificationCategory.rewards.label.toUpperCase()), findsOneWidget);

      // On 'Tümü' tab, both items appear
      expect(find.text('Arena Meydan Okuma'), findsOneWidget);
      expect(find.text('Günlük Ödül Hazır'), findsOneWidget);
      expect(find.text('2 BİLDİRİM'), findsOneWidget);

      // Switch to 'Savaş' tab
      await tester.tap(find.text(NotificationCategory.combat.label.toUpperCase()));
      await tester.pumpAndSettle();

      expect(find.text('Arena Meydan Okuma'), findsOneWidget);
      expect(find.text('Günlük Ödül Hazır'), findsNothing);
      expect(find.text('1 BİLDİRİM'), findsOneWidget);

      // Switch to 'Sistem' tab which has no items -> triggers Runic Empty State
      await tester.tap(find.text(NotificationCategory.system.label.toUpperCase()));
      await tester.pumpAndSettle();

      expect(find.text('SİSTEM DENGEDE'), findsOneWidget);
      expect(find.text('Arena Meydan Okuma'), findsNothing);
      expect(find.text('Günlük Ödül Hazır'), findsNothing);

      // Test "Tümünü Oku" button
      await tester.tap(find.text(NotificationCategory.all.label.toUpperCase()));
      await tester.pumpAndSettle();

      expect(find.text('TÜMÜNÜ OKU'), findsOneWidget);
      await tester.tap(find.text('TÜMÜNÜ OKU'));
      expect(markAllCalled, isTrue);

      // Test item tap
      await tester.tap(find.text('Arena Meydan Okuma'));
      expect(tappedItem?.id, 'n_combat');

      // Test item dismiss button
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      expect(dismissedItem?.id, 'n_combat');
    });
  });
}
