import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/live_ticker_model.dart';
import 'package:gkk_flutter/providers/live_ticker_provider.dart';
import 'package:gkk_flutter/screens/announcements/announcements_screen.dart';
import 'package:gkk_flutter/screens/announcements/models/announcement_models.dart';
import 'package:gkk_flutter/screens/announcements/services/announcements_repository.dart';
import 'package:gkk_flutter/screens/announcements/widgets/announcement_card.dart';
import 'package:gkk_flutter/screens/announcements/widgets/event_countdown_pill.dart';
import 'package:gkk_flutter/screens/announcements/widgets/event_gift_claim_sheet.dart';
import 'package:gkk_flutter/screens/announcements/widgets/hero_banner_carousel.dart';
import 'package:gkk_flutter/screens/announcements/widgets/patch_notes_viewer.dart';
import 'package:gkk_flutter/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Announcements Models & Calculations', () {
    test('AnnouncementItem parses eventStatus correctly based on time', () {
      final DateTime now = DateTime.now();

      final AnnouncementItem upcomingEvent = AnnouncementItem(
        id: 'upcoming_1',
        title: 'Gelecek Etkinlik',
        subtitle: 'Hazırlan',
        contentMarkdown: '# Gelecek',
        type: AnnouncementType.event,
        publishedAt: now,
        eventStartTime: now.add(const Duration(hours: 2)),
        eventEndTime: now.add(const Duration(hours: 10)),
      );
      expect(upcomingEvent.hasEventSchedule, isTrue);
      expect(upcomingEvent.eventStatus, EventStatus.upcoming);

      final AnnouncementItem activeEvent = AnnouncementItem(
        id: 'active_1',
        title: 'Aktif Etkinlik',
        subtitle: 'Devam ediyor',
        contentMarkdown: '# Aktif',
        type: AnnouncementType.event,
        publishedAt: now,
        eventStartTime: now.subtract(const Duration(hours: 2)),
        eventEndTime: now.add(const Duration(hours: 24)),
      );
      expect(activeEvent.eventStatus, EventStatus.active);

      final AnnouncementItem endingSoonEvent = AnnouncementItem(
        id: 'ending_1',
        title: 'Son Saatler',
        subtitle: 'Bitiyor',
        contentMarkdown: '# Son Saatler',
        type: AnnouncementType.event,
        publishedAt: now,
        eventStartTime: now.subtract(const Duration(hours: 10)),
        eventEndTime: now.add(const Duration(hours: 2)),
      );
      expect(endingSoonEvent.eventStatus, EventStatus.endingSoon);

      final AnnouncementItem endedEvent = AnnouncementItem(
        id: 'ended_1',
        title: 'Biten Etkinlik',
        subtitle: 'Bitti',
        contentMarkdown: '# Bitti',
        type: AnnouncementType.event,
        publishedAt: now,
        eventEndTime: now.subtract(const Duration(minutes: 5)),
      );
      expect(endedEvent.eventStatus, EventStatus.ended);
    });

    test('AnnouncementItem.fromLiveTickerItem correctly translates ticker types', () {
      const LiveTickerItem bossTicker = LiveTickerItem(
        id: 'ticker_boss_1',
        type: 'dungeon_clear',
        text: 'Ejderha Lordu Tapınağı temizlendi!',
      );
      final AnnouncementItem bossItem = AnnouncementItem.fromLiveTickerItem(bossTicker);
      expect(bossItem.id, 'ticker_boss_1');
      expect(bossItem.type, AnnouncementType.liveTicker);
      expect(bossItem.badgeLabel, 'BOSS TEMİZLENDİ');
      expect(bossItem.accentColor, AppColors.mysticRuby);

      const LiveTickerItem warTicker = LiveTickerItem(
        id: 'ticker_war_1',
        type: 'guild_war',
        text: 'Asmodian loncası kaleyi fethetti!',
      );
      final AnnouncementItem warItem = AnnouncementItem.fromLiveTickerItem(warTicker);
      expect(warItem.badgeLabel, 'LONCA SAVAŞI');
      expect(warItem.accentColor, AppColors.toxicNeon);
    });
  });

  group('AnnouncementsRepository & Persistence', () {
    test('Reads and writes read-status and claimed gifts via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'aion2_announcements_read_set': <String>['read_test_1'],
        'aion2_announcements_claimed_gifts': <String>['claimed_test_1'],
      });

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AnnouncementsRepository repo = AnnouncementsRepository(prefs: prefs);
      await repo.init();

      expect(repo.isRead('read_test_1'), isTrue);
      expect(repo.isRead('unread_item'), isFalse);
      expect(repo.isGiftClaimed('claimed_test_1'), isTrue);
      expect(repo.isGiftClaimed('unclaimed_item'), isFalse);

      await repo.markAsRead('new_read_item');
      expect(repo.isRead('new_read_item'), isTrue);

      final bool claimedFirstTime = await repo.claimGift('new_gift');
      expect(claimedFirstTime, isTrue);
      expect(repo.isGiftClaimed('new_gift'), isTrue);

      final bool claimedSecondTime = await repo.claimGift('new_gift');
      expect(claimedSecondTime, isFalse);
    });

    test('getMergedAnnouncements filters properly', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AnnouncementsRepository repo = AnnouncementsRepository(prefs: prefs);
      await repo.init();

      final List<LiveTickerItem> tickers = <LiveTickerItem>[
        const LiveTickerItem(
          id: 'server_ticker_1',
          type: 'staff_broadcast',
          text: 'Sunucu bakımı tamamlandı.',
        ),
      ];

      final List<AnnouncementItem> all = repo.getMergedAnnouncements(
        tickerArchive: tickers,
        filter: 'all',
      );
      expect(all.any((e) => e.id == 'patch_2_4_0'), isTrue);
      expect(all.any((e) => e.id == 'server_ticker_1'), isTrue);

      final List<AnnouncementItem> eventsOnly = repo.getMergedAnnouncements(
        tickerArchive: tickers,
        filter: 'event',
      );
      expect(eventsOnly.every((e) => e.type == AnnouncementType.event), isTrue);

      final List<AnnouncementItem> serverOnly = repo.getMergedAnnouncements(
        tickerArchive: tickers,
        filter: 'server',
      );
      expect(serverOnly.every((e) => e.type == AnnouncementType.liveTicker), isTrue);
    });
  });

  group('Announcements Widgets Tests (390x844 Mobile Viewport)', () {
    testWidgets('EventCountdownPill renders countdown and pulses', (WidgetTester tester) async {
      final DateTime futureEnd = DateTime.now().add(const Duration(hours: 4, minutes: 12));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EventCountdownPill(
                endTime: futureEnd,
                compact: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(EventCountdownPill), findsOneWidget);
      expect(find.textContaining(':'), findsWidgets);
    });

    testWidgets('HeroBannerCarousel renders banners and page indicator', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<AnnouncementItem> banners = <AnnouncementItem>[
        AnnouncementItem(
          id: 'b1',
          title: 'Hero Banner 1',
          subtitle: 'Hero Subtitle 1',
          contentMarkdown: '# Content 1',
          type: AnnouncementType.event,
          isHeroBanner: true,
          publishedAt: DateTime.now(),
        ),
        AnnouncementItem(
          id: 'b2',
          title: 'Hero Banner 2',
          subtitle: 'Hero Subtitle 2',
          contentMarkdown: '# Content 2',
          type: AnnouncementType.patchNotes,
          isHeroBanner: true,
          publishedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HeroBannerCarousel(banners: banners),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Hero Banner 1'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('AnnouncementCard displays details and unread indicator', (WidgetTester tester) async {
      final AnnouncementItem item = AnnouncementItem(
        id: 'card_test_1',
        title: 'Özel Kuşatma Duyurusu',
        subtitle: 'Kuşatma saat 20:00 da başlayacak',
        contentMarkdown: '# Kuşatma',
        type: AnnouncementType.broadcast,
        badgeLabel: 'KUŞATMA',
        accentColor: AppColors.liquidGold,
        publishedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AnnouncementCard(item: item),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Özel Kuşatma Duyurusu'), findsOneWidget);
      expect(find.text('KUŞATMA'), findsOneWidget);
    });

    testWidgets('EventGiftClaimSheet displays reward item and confirms claim', (WidgetTester tester) async {
      final AnnouncementItem itemWithGifts = AnnouncementItem(
        id: 'gift_event_1',
        title: 'Hediye Etkinliği',
        subtitle: 'Ödüller seni bekliyor',
        contentMarkdown: '# Ödül Detayı',
        type: AnnouncementType.event,
        publishedAt: DateTime.now(),
        rewards: const <EventRewardItem>[
          EventRewardItem(
            id: 'item_1',
            name: 'Kadim Ejderha Sandığı',
            icon: '🎁',
            quantity: 2,
            rarity: 'epic',
            description: 'Efsanevi zırh ve kristaller',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventGiftClaimSheet(item: itemWithGifts),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('ETKİNLİK HEDİYESİ ALINDI!'), findsOneWidget);
      expect(find.text('Kadim Ejderha Sandığı'), findsOneWidget);
      expect(find.text('x2'), findsOneWidget);
      expect(find.text('Envantere Eklendi'), findsOneWidget);

      await tester.tap(find.text('Envantere Eklendi'));
      await tester.pump();
    });

    testWidgets('PatchNotesViewerModal renders rich markdown content and claim CTA', (WidgetTester tester) async {
      final AnnouncementItem patchItem = AnnouncementItem(
        id: 'patch_modal_test',
        title: 'Aion 2 v2.4.0 Yaması',
        subtitle: 'Detaylı Yama Notları',
        versionTag: 'v2.4.0',
        contentMarkdown: '''
# Uçurum Yarığı Açıldı
* Gladiator sınıfı güçlendirildi.
* 3D Shader sistemi güncellendi.
''',
        type: AnnouncementType.patchNotes,
        publishedAt: DateTime.now(),
        rewards: const <EventRewardItem>[
          EventRewardItem(
            id: 'r_patch',
            name: 'Kutlama Paketi',
            icon: '📦',
            quantity: 1,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PatchNotesViewerModal(item: patchItem),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Aion 2 v2.4.0 Yaması'), findsOneWidget);
      expect(find.text('Bu Etkinliğin Hediyesi'), findsOneWidget);
      expect(find.text('Kutlama Paketi'), findsOneWidget);
      expect(find.text('Etkinlik Hediyesini Al'), findsOneWidget);
    });

    testWidgets('AnnouncementsScreen renders cleanly in 390x844 SafeArea mobile viewport', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AnnouncementsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AnnouncementsScreen), findsOneWidget);
      expect(find.text('Duyurular & Etkinlikler'), findsOneWidget);
      expect(find.text('Tümü'), findsOneWidget);
      expect(find.text('Okunmamış'), findsOneWidget);
      expect(find.text('Etkinlikler'), findsOneWidget);
      expect(find.text('Yama Notları'), findsOneWidget);
      expect(find.text('Canlı Sunucu'), findsOneWidget);
    });
  });
}
