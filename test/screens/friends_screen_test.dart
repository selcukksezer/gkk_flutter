import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/friends/friends_screen.dart';
import 'package:gkk_flutter/screens/friends/widgets/friend_card_view.dart';
import 'package:gkk_flutter/screens/friends/widgets/friend_class_crest.dart';
import 'package:gkk_flutter/screens/friends/widgets/friend_party_invite_cta.dart';
import 'package:gkk_flutter/screens/friends/widgets/friend_presence_orb.dart';
import 'package:gkk_flutter/screens/friends/widgets/friend_quick_whisper_dialog.dart';

void main() {
  group('FriendEntry Model Tests', () {
    test('parses standard JSON correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'friendship_id': 'f101',
        'username': 'elyos_warrior',
        'display_name': 'AionChampion',
        'avatar_url': 'https://example.com/avatar.png',
        'level': 45,
        'power': 18500,
        'is_online': true,
      };

      final FriendEntry entry = FriendEntry.fromJson(json);

      expect(entry.friendshipId, 'f101');
      expect(entry.username, 'elyos_warrior');
      expect(entry.name, 'AionChampion');
      expect(entry.level, 45);
      expect(entry.power, 18500);
      expect(entry.isOnline, isTrue);
      expect(entry.location, 'Sanctum Tapınağı');
    });

    test('parses extended fields when available', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'friendship_id': 'f102',
        'username': 'asmo_sorcerer',
        'level': 50,
        'power': 24000,
        'is_online': true,
        'character_class': 'Büyücü',
        'location': 'Abyss Derinlikleri',
        'guild_name': 'Legion of Storms',
        'activity_status': 'Zindanda',
      };

      final FriendEntry entry = FriendEntry.fromJson(json);

      expect(entry.name, 'asmo_sorcerer');
      expect(entry.characterClass, 'Büyücü');
      expect(entry.location, 'Abyss Derinlikleri');
      expect(entry.guildName, 'Legion of Storms');
      expect(entry.activityStatus, 'Zindanda');
    });

    test('offline fallback location', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'friendship_id': 'f103',
        'username': 'lonely_ranger',
        'is_online': false,
      };

      final FriendEntry entry = FriendEntry.fromJson(json);
      expect(entry.isOnline, isFalse);
      expect(entry.location, 'Çevrimdışı');
    });
  });

  group('FriendClassCrest & Badges Tests', () {
    test('returns correct class icons and colors', () {
      expect(FriendClassCrest.getIcon('Savaşçı'), Icons.shield_rounded);
      expect(FriendClassCrest.getIcon('Büyücü'), Icons.auto_awesome_rounded);
      expect(FriendClassCrest.getIcon('Simyacı'), Icons.science_rounded);
      expect(FriendClassCrest.getIcon('Gölge'), Icons.visibility_off_rounded);
      expect(FriendClassCrest.getIcon('Şifacı'), Icons.health_and_safety_rounded);
      expect(FriendClassCrest.getIcon('Okçu'), Icons.track_changes_rounded);

      expect(FriendClassCrest.getColor('Savaşçı'), const Color(0xFFEF4444));
      expect(FriendClassCrest.getColor('Büyücü'), const Color(0xFFA855F7));
    });

    test('formats combat power correctly', () {
      expect(FriendClassCrest.formatCp(950), '950');
      expect(FriendClassCrest.formatCp(5400), '5,400');
      expect(FriendClassCrest.formatCp(15200), '15.2k');
      expect(FriendClassCrest.formatCp(1200000), '1.2M');
    });

    testWidgets('ClassCrestBadge and CombatPowerBadge render correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                ClassCrestBadge(className: 'Büyücü'),
                CombatPowerBadge(power: 12500),
                LocationBadge(location: 'Sanctum Tapınağı', isOnline: true),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Büyücü'), findsOneWidget);
      expect(find.text('CP 12.5k'), findsOneWidget);
      expect(find.text('Sanctum Tapınağı'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    });
  });

  group('FriendPresenceOrb Tests', () {
    test('maps presence status properly', () {
      expect(
        FriendPresenceStatus.fromOnline(isOnline: false),
        FriendPresenceStatus.offline,
      );
      expect(
        FriendPresenceStatus.fromOnline(isOnline: true, activity: 'Zindanda'),
        FriendPresenceStatus.inDungeon,
      );
      expect(
        FriendPresenceStatus.fromOnline(isOnline: true, activity: 'Partide'),
        FriendPresenceStatus.inParty,
      );
      expect(
        FriendPresenceStatus.fromOnline(isOnline: true, activity: 'Boşta'),
        FriendPresenceStatus.away,
      );
      expect(
        FriendPresenceStatus.fromOnline(isOnline: true),
        FriendPresenceStatus.online,
      );
    });

    testWidgets('FriendPresenceOrb renders online orb and aura',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FriendPresenceOrb(
              status: FriendPresenceStatus.online,
              size: 16,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(FriendPresenceOrb), findsOneWidget);
    });

    testWidgets('FriendPresenceOrb renders offline orb without error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FriendPresenceOrb(
              status: FriendPresenceStatus.offline,
              size: 14,
            ),
          ),
        ),
      );

      expect(find.byType(FriendPresenceOrb), findsOneWidget);
    });
  });

  group('FriendCardView Widget Tests', () {
    testWidgets('renders all friend details, CP badge, class crest, location',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FriendCardView(
              friendshipId: 'fr_1',
              username: 'gladiator_99',
              displayName: 'Kaelen',
              level: 48,
              power: 19800,
              isOnline: true,
              characterClass: 'Savaşçı',
              location: 'Ateş Tapınağı',
              guildName: 'AionLegion',
            ),
          ),
        ),
      );

      expect(find.text('Kaelen'), findsOneWidget);
      expect(find.text('Lv.48'), findsOneWidget);
      expect(find.text('[AionLegion]'), findsOneWidget);
      expect(find.text('Savaşçı'), findsOneWidget);
      expect(find.text('CP 19.8k'), findsOneWidget);
      expect(find.text('Ateş Tapınağı'), findsOneWidget);
      expect(find.text('Partiye Çağır'), findsOneWidget);
      expect(find.text('Fısılda'), findsOneWidget);
    });

    testWidgets('online card displays Quick Party Invite and Whisper buttons',
        (WidgetTester tester) async {
      bool inviteTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendCardView(
              friendshipId: 'fr_2',
              username: 'cleric_healer',
              displayName: 'Lyra',
              level: 42,
              power: 16400,
              isOnline: true,
              characterClass: 'Şifacı',
              onPartyInvite: ({
                required String targetUser,
                required PartyRole role,
                required String activity,
              }) async {
                inviteTriggered = true;
                return true;
              },
              onDirectWhisper: (String msg) async {
                return true;
              },
            ),
          ),
        ),
      );

      // Verify buttons exist
      final Finder inviteBtn = find.text('Partiye Çağır');
      final Finder whisperBtn = find.text('Fısılda');
      expect(inviteBtn, findsOneWidget);
      expect(whisperBtn, findsOneWidget);

      // Tap Party Invite opens sheet
      await tester.tap(inviteBtn);
      await tester.pumpAndSettle();
      expect(find.byType(FriendPartyInviteCtaSheet), findsOneWidget);

      // Tap CTA inside sheet
      final Finder confirmInviteBtn = find.text('Lyra Kişisini Partiye Çağır');
      expect(confirmInviteBtn, findsOneWidget);
      await tester.tap(confirmInviteBtn);
      await tester.pumpAndSettle();

      expect(inviteTriggered, isTrue);
    });

    testWidgets('tapping whisper button opens FriendQuickWhisperDialog',
        (WidgetTester tester) async {
      bool whisperTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendCardView(
              friendshipId: 'fr_3',
              username: 'shadow_blade',
              displayName: 'Vesper',
              level: 50,
              power: 28000,
              isOnline: true,
              characterClass: 'Gölge',
              onDirectWhisper: (String msg) async {
                whisperTriggered = true;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Fısılda'));
      await tester.pumpAndSettle();

      expect(find.byType(FriendQuickWhisperDialog), findsOneWidget);

      // Tap quick macro
      final Finder macroChip = find.text('⚔️ Zindana hazır mısın?');
      expect(macroChip, findsOneWidget);
      await tester.tap(macroChip);
      await tester.pumpAndSettle();

      expect(whisperTriggered, isTrue);
    });
  });

  group('FriendQuickWhisperDialog Tests', () {
    testWidgets('allows custom input text and sending whisper',
        (WidgetTester tester) async {
      String? sentMessage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) => ElevatedButton(
                onPressed: () {
                  FriendQuickWhisperDialog.show(
                    context: ctx,
                    friendshipId: 'fr_4',
                    recipientName: 'Thorin',
                    level: 30,
                    characterClass: 'Savaşçı',
                    onSendWhisper: (String msg) async {
                      sentMessage = msg;
                      return true;
                    },
                  );
                },
                child: const Text('Open Whisper'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Whisper'));
      await tester.pumpAndSettle();

      expect(find.byType(FriendQuickWhisperDialog), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Hadi zindana girelim dostum!',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(sentMessage, 'Hadi zindana girelim dostum!');
      expect(find.byType(FriendQuickWhisperDialog), findsNothing);
    });
  });

  group('FriendPartyInviteCtaSheet Tests', () {
    testWidgets('allows role switching and activity selection',
        (WidgetTester tester) async {
      PartyRole? selectedRole;
      String? selectedActivity;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) => ElevatedButton(
                onPressed: () {
                  FriendPartyInviteCtaSheet.show(
                    context: ctx,
                    friendshipId: 'fr_5',
                    friendName: 'Valeria',
                    level: 45,
                    power: 21000,
                    characterClass: 'Simyacı',
                    onSendInvite: ({
                      required String targetUser,
                      required PartyRole role,
                      required String activity,
                    }) async {
                      selectedRole = role;
                      selectedActivity = activity;
                      return true;
                    },
                  );
                },
                child: const Text('Open Party Invite'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Party Invite'));
      await tester.pumpAndSettle();

      expect(find.byType(FriendPartyInviteCtaSheet), findsOneWidget);

      // Select Tank role
      await tester.tap(find.text('Tank'));
      await tester.pump();

      // Select PvP 3v3 Arena activity
      await tester.tap(find.text('PvP 3v3 Arena'));
      await tester.pump();

      // Submit
      await tester.tap(find.text('Valeria Kişisini Partiye Çağır'));
      await tester.pumpAndSettle();

      expect(selectedRole, PartyRole.tank);
      expect(selectedActivity, 'PvP 3v3 Arena');
      expect(find.byType(FriendPartyInviteCtaSheet), findsNothing);
    });
  });
}
