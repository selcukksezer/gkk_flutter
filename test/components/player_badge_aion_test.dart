import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/components/character/badge_showcase_panel.dart';
import 'package:gkk_flutter/components/player/player_action_sheet.dart';
import 'package:gkk_flutter/components/player/player_name_label.dart';
import 'package:gkk_flutter/components/player/staff_badge.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/player_badge_model.dart';
import 'package:gkk_flutter/providers/player_badges_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StaffBadge Component Tests', () {
    testWidgets('renders all staff and military prestige ranks',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                StaffBadge(badge: 'admin'),
                StaffBadge(badge: 'gm'),
                StaffBadge(badge: 'king'),
                StaffBadge(badge: 'vip'),
                StaffBadge(badge: 'abyss_general'),
                StaffBadge(badge: 'commander'),
                StaffBadge(badge: 'centurion'),
                StaffBadge(badge: 'legatus'),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('GM'), findsOneWidget);
      expect(find.text('KING'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('GENERAL'), findsOneWidget);
      expect(find.text('KOMUTAN'), findsOneWidget);
      expect(find.text('CENTURION'), findsOneWidget);
      expect(find.text('LEGATUS'), findsOneWidget);
    });

    testWidgets('compact mode renders with compact size',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaffBadge(badge: 'king', compact: true),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('KING'), findsOneWidget);
    });

    testWidgets('invokes onTap callback when tapped',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffBadge(
              badge: 'admin',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(StaffBadge));
      expect(tapped, isTrue);
    });
  });

  group('PlayerNameLabel Component Tests', () {
    testWidgets('renders displayName, username, and title prefix',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerNameLabel(
              username: 'valkyrie',
              displayName: 'Archon Valkyrie',
              staffBadge: 'abyss_general',
              titlePrefix: 'Abyss Baş Generali',
              isOnline: true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Archon Valkyrie'), findsOneWidget);
      expect(find.text(' @valkyrie'), findsOneWidget);
      expect(find.text('Abyss Baş Generali'), findsOneWidget);
      expect(find.text('GENERAL'), findsOneWidget);
    });

    testWidgets('triggers onTap and onLongPress gestures',
        (WidgetTester tester) async {
      bool tapped = false;
      bool longPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerNameLabel(
              username: 'gladiator_x',
              onTap: () => tapped = true,
              onLongPress: () => longPressed = true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(PlayerNameLabel));
      expect(tapped, isTrue);

      await tester.longPress(find.byType(PlayerNameLabel));
      expect(longPressed, isTrue);
    });
  });

  group('AionBadgeCanvasPainter Direct Painting Tests', () {
    test('paints all AionBadgeType variants without throwing', () {
      for (final AionBadgeType type in AionBadgeType.values) {
        final AionBadgeCanvasPainter painter = AionBadgeCanvasPainter(
          badgeType: type,
          rarity: Rarity.mythic,
          primaryColor: const Color(0xFFFF1744),
        );

        final PictureRecorder recorder = PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        const Size size = Size(100, 100);

        expect(() => painter.paint(canvas, size), returnsNormally);
        recorder.endRecording();
      }
    });
  });

  group('BadgeShowcasePanel Component Tests', () {
    final List<PlayerBadge> sampleBadges = <PlayerBadge>[
      PlayerBadge(
        itemId: 'abyss_general_insignia',
        name: 'Abyss Baş Generali',
        rarity: Rarity.mythic,
        icon: 'crest_general',
        source: 'abyss_siege',
        earnedAt: DateTime(2026, 10, 15),
      ),
      PlayerBadge(
        itemId: 'commander_crest',
        name: 'Bölük Komutanı',
        rarity: Rarity.legendary,
        icon: 'crest_commander',
        source: 'legion_war',
        earnedAt: DateTime(2026, 10, 16),
      ),
      PlayerBadge(
        itemId: 'badge_season_3',
        name: 'Sezon 3 Şampiyonu',
        rarity: Rarity.epic,
        icon: 'season_3',
        source: 'season_pvp',
        earnedAt: DateTime(2026, 10, 17),
      ),
      PlayerBadge(
        itemId: 'centurion_targe',
        name: 'Abyss Yüzbaşısı',
        rarity: Rarity.rare,
        icon: 'targe_centurion',
        source: 'pvp_kill',
        earnedAt: DateTime(2026, 10, 18),
      ),
    ];

    testWidgets('renders badge tiles with canvas heraldry and count',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerBadgesProvider.overrideWith(
              () => _FakePlayerBadgesNotifier(sampleBadges),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BadgeShowcasePanel(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Abyss & Lejyon Rozet Vitrini'), findsOneWidget);
      expect(find.text('4 Rozet'), findsOneWidget);
      expect(find.text('Abyss Baş Generali'), findsOneWidget);
      expect(find.text('Bölük Komutanı'), findsOneWidget);
      expect(find.text('Sezon 3 Şampiyonu'), findsOneWidget);
      expect(find.text('Abyss Yüzbaşısı'), findsOneWidget);
      expect(find.text('S3'), findsOneWidget);
    });

    testWidgets('filter pills switch categories correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerBadgesProvider.overrideWith(
              () => _FakePlayerBadgesNotifier(sampleBadges),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BadgeShowcasePanel(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "⚔️ Askeri" filter
      await tester.tap(find.text('⚔️ Askeri'));
      await tester.pumpAndSettle();

      expect(find.text('Abyss Baş Generali'), findsOneWidget);
      expect(find.text('Bölük Komutanı'), findsOneWidget);
      expect(find.text('Abyss Yüzbaşısı'), findsOneWidget);
    });

    testWidgets('tapping a badge opens high-fantasy inspection modal with lore',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerBadgesProvider.overrideWith(
              () => _FakePlayerBadgesNotifier(sampleBadges),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BadgeShowcasePanel(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Abyss Baş Generali badge card
      await tester.tap(find.text('Abyss Baş Generali'));
      await tester.pumpAndSettle();

      expect(find.text('RÜTBE HİKAYESİ'), findsOneWidget);
      expect(find.text('MYTHIC'), findsOneWidget);
      expect(find.text('Aktif Başlık Olarak Kuşan'), findsOneWidget);
    });
  });

  group('PlayerActionSheet MMORPG Deck Tests', () {
    testWidgets('renders 6 interaction buttons and triggers callbacks',
        (WidgetTester tester) async {
      bool whisperCalled = false;
      bool partyCalled = false;
      bool tradeCalled = false;
      bool inspectCalled = false;
      bool duelCalled = false;
      bool friendCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  return Consumer(
                    builder: (BuildContext ctx, WidgetRef ref, _) {
                      return ElevatedButton(
                        onPressed: () => showPlayerActionSheet(
                          context,
                          ref,
                          authId: 'test_user_id_001',
                          username: 'ares_warrior',
                          displayName: 'Lord Ares',
                          staffBadge: 'abyss_general',
                          kingBadge: 'king',
                          onWhisper: () => whisperCalled = true,
                          onInviteParty: () => partyCalled = true,
                          onTrade: () => tradeCalled = true,
                          onInspect: () => inspectCalled = true,
                          onDuel: () => duelCalled = true,
                          onAddFriend: () => friendCalled = true,
                        ),
                        child: const Text('Open Sheet'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('OYUNCU ETKİLEŞİMİ'), findsOneWidget);
      expect(find.text('Fısılda'), findsOneWidget);
      expect(find.text('Grup Daveti'), findsOneWidget);
      expect(find.text('Takas'), findsOneWidget);
      expect(find.text('İncele'), findsOneWidget);
      expect(find.text('Düello'), findsOneWidget);
      expect(find.text('Arkadaş'), findsOneWidget);

      // Tap Fısılda
      await tester.tap(find.text('Fısılda'));
      expect(whisperCalled, isTrue);

      // Tap Grup Daveti
      await tester.tap(find.text('Grup Daveti'));
      expect(partyCalled, isTrue);

      // Tap Takas
      await tester.tap(find.text('Takas'));
      expect(tradeCalled, isTrue);

      // Tap İncele
      await tester.tap(find.text('İncele'));
      expect(inspectCalled, isTrue);

      // Tap Düello
      await tester.tap(find.text('Düello'));
      expect(duelCalled, isTrue);

      // Tap Arkadaş
      await tester.tap(find.text('Arkadaş'));
      expect(friendCalled, isTrue);
    });
  });
}

class _FakePlayerBadgesNotifier extends PlayerBadgesNotifier {
  _FakePlayerBadgesNotifier(this._initialBadges);

  final List<PlayerBadge> _initialBadges;

  @override
  PlayerBadgesState build() {
    return PlayerBadgesState(badges: _initialBadges, isLoading: false);
  }

  @override
  Future<void> load() async {}
}
