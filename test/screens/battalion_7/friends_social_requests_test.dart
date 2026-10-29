import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/friends/blacklist_management_view.dart';
import 'package:gkk_flutter/screens/friends/friend_requests_view.dart';
import 'package:gkk_flutter/screens/friends/friend_search_bar.dart';
import 'package:gkk_flutter/screens/friends/friends_models.dart';

void main() {
  group('Social Models Tests', () {
    test('PlayerSearchResult parses from JSON and copyWith works correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 'usr_999',
        'username': 'shadow_hunter',
        'display_name': 'ShadowHunterX',
        'avatar_url': 'https://example.com/a.png',
        'level': 42,
        'power': 18000,
        'is_online': true,
        'character_class': 'Gölge',
        'is_friend': false,
        'has_pending_outgoing': false,
        'has_pending_incoming': false,
        'is_blocked': false,
      };

      final PlayerSearchResult player = PlayerSearchResult.fromJson(json);
      expect(player.id, 'usr_999');
      expect(player.username, 'shadow_hunter');
      expect(player.name, 'ShadowHunterX');
      expect(player.level, 42);
      expect(player.power, 18000);
      expect(player.isOnline, isTrue);
      expect(player.characterClass, 'Gölge');
      expect(player.isFriend, isFalse);

      final PlayerSearchResult updated = player.copyWith(
        isFriend: true,
        hasPendingOutgoing: true,
      );
      expect(updated.isFriend, isTrue);
      expect(updated.hasPendingOutgoing, isTrue);
      expect(updated.username, 'shadow_hunter');
    });

    test('BlockedPlayerEntry parses from JSON correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'blocked_user_id': 'blk_123',
        'username': 'toxic_troll',
        'display_name': 'TrollKing',
        'created_at': '2026-10-28T12:00:00Z',
        'reason': 'Spam',
      };

      final BlockedPlayerEntry entry = BlockedPlayerEntry.fromJson(json);
      expect(entry.id, 'blk_123');
      expect(entry.username, 'toxic_troll');
      expect(entry.name, 'TrollKing');
      expect(entry.reason, 'Spam');
      expect(entry.blockedAt, isNotNull);

      final Map<String, dynamic> map = entry.toJson();
      expect(map['id'], 'blk_123');
      expect(map['username'], 'toxic_troll');
    });
  });

  group('FriendSearchBar Widget Tests', () {
    testWidgets('renders input, hint, and handles direct send',
        (WidgetTester tester) async {
      String? requestedUser;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: FriendSearchBar(
                onSendRequest: (String user) async {
                  requestedUser = user;
                  return true;
                },
                hintText: 'Oyuncu ara...',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Oyuncu ara...'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Kaelen');
      await tester.pump();

      // Clear button appears when text is entered
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tapping clear button clears text
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(find.text('Kaelen'), findsNothing);
    });

    testWidgets('shows direct send CTA when no server results found',
        (WidgetTester tester) async {
      String? sentUser;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FriendSearchBar(
                onSendRequest: (String user) async {
                  sentUser = user;
                  return true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'MysticMage');
      // Wait for debounce timer
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // CTA button should be visible to send directly
      final Finder sendBtn = find.text('MysticMage Kullanıcısına Gönder');
      expect(sendBtn, findsOneWidget);

      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(sentUser, 'MysticMage');
    });
  });

  group('FriendRequestsView Widget Tests', () {
    final List<FriendEntry> mockIncoming = <FriendEntry>[
      const FriendEntry(
        friendshipId: 'req_1',
        username: 'elyos_guard',
        displayName: 'Ares',
        level: 40,
        power: 16500,
      ),
      const FriendEntry(
        friendshipId: 'req_2',
        username: 'asmo_ranger',
        displayName: 'Sylvanas',
        level: 48,
        power: 21000,
      ),
    ];

    final List<FriendEntry> mockOutgoing = <FriendEntry>[
      const FriendEntry(
        friendshipId: 'req_out_1',
        username: 'sorceress_elena',
        displayName: 'Elena',
        level: 35,
      ),
    ];

    testWidgets('renders tabs with counters and displays incoming requests',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendRequestsView(
              incomingRequests: mockIncoming,
              outgoingRequests: mockOutgoing,
              onAcceptRequest: (_) async {},
              onDeclineRequest: (_) async {},
            ),
          ),
        ),
      );

      // Verify sub-tabs with badge counts
      expect(find.text('Gelen İstekler'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // incoming count badge
      expect(find.text('Gönderilen'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // outgoing count badge

      // Check incoming items are rendered
      expect(find.text('Ares'), findsOneWidget);
      expect(find.text('@elyos_guard'), findsOneWidget);
      expect(find.text('Lv.40'), findsOneWidget);
      expect(find.text('⚡16500'), findsOneWidget);

      expect(find.text('Sylvanas'), findsOneWidget);
      expect(find.text('@asmo_ranger'), findsOneWidget);

      // Check action buttons exist
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
    });

    testWidgets('switching to outgoing tab renders outgoing requests and cancel button',
        (WidgetTester tester) async {
      FriendEntry? cancelledEntry;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendRequestsView(
              incomingRequests: mockIncoming,
              outgoingRequests: mockOutgoing,
              onAcceptRequest: (_) async {},
              onDeclineRequest: (_) async {},
              onCancelOutgoing: (FriendEntry entry) async {
                cancelledEntry = entry;
              },
            ),
          ),
        ),
      );

      // Tap on Gönderilen tab
      await tester.tap(find.text('Gönderilen'));
      await tester.pumpAndSettle();

      expect(find.text('Elena'), findsOneWidget);
      expect(find.text('@sorceress_elena'), findsOneWidget);
      expect(find.text('Bekliyor'), findsOneWidget);

      final Finder cancelBtn = find.byIcon(Icons.cancel_outlined);
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(cancelledEntry?.friendshipId, 'req_out_1');
    });

    testWidgets('accepting incoming request triggers animation and callback',
        (WidgetTester tester) async {
      FriendEntry? acceptedEntry;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendRequestsView(
              incomingRequests: mockIncoming,
              outgoingRequests: mockOutgoing,
              onAcceptRequest: (FriendEntry entry) async {
                acceptedEntry = entry;
              },
              onDeclineRequest: (_) async {},
            ),
          ),
        ),
      );

      // Tap accept on first item
      final Finder firstAccept = find.byIcon(Icons.check_rounded).first;
      await tester.tap(firstAccept);
      await tester.pump();

      // Check feedback text appears during accept animation
      expect(find.text('Arkadaşlık Kabul Edildi!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      expect(acceptedEntry?.friendshipId, 'req_1');
    });

    testWidgets('declining incoming request triggers animation and callback',
        (WidgetTester tester) async {
      FriendEntry? declinedEntry;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendRequestsView(
              incomingRequests: mockIncoming,
              outgoingRequests: mockOutgoing,
              onAcceptRequest: (_) async {},
              onDeclineRequest: (FriendEntry entry) async {
                declinedEntry = entry;
              },
            ),
          ),
        ),
      );

      // Tap decline on first item
      final Finder firstDecline = find.byIcon(Icons.close_rounded).first;
      await tester.tap(firstDecline);
      await tester.pump();

      // Check feedback text appears during decline animation
      expect(find.text('İstek Reddedildi'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      expect(declinedEntry?.friendshipId, 'req_1');
    });

    testWidgets('renders empty state when request lists are empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendRequestsView(
              incomingRequests: const <FriendEntry>[],
              outgoingRequests: const <FriendEntry>[],
              onAcceptRequest: (_) async {},
              onDeclineRequest: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Bekleyen Gelen İstek Yok'), findsOneWidget);
    });
  });

  group('BlacklistManagementView Widget Tests', () {
    final List<BlockedPlayerEntry> mockBlocked = <BlockedPlayerEntry>[
      const BlockedPlayerEntry(
        id: 'blk_1',
        username: 'spammer_99',
        displayName: 'SpamBot',
        reason: 'İstenmeyen mesaj',
      ),
    ];

    testWidgets('renders title, shield banner, and blocked list',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlacklistManagementView(
              initialBlockedUsers: mockBlocked,
            ),
          ),
        ),
      );

      expect(find.text('Engellenen Oyuncular'), findsOneWidget);
      expect(
        find.text(
          'Engellediğin oyuncular sana özel mesaj gönderemez ve arkadaşlık isteği iletemez.',
        ),
        findsOneWidget,
      );
      expect(find.text('SpamBot'), findsOneWidget);
      expect(find.text('@spammer_99'), findsOneWidget);
      expect(find.text('Engeli Kaldır'), findsOneWidget);
    });

    testWidgets('tapping unblock shows confirmation dialog and cancels on Vazgeç',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlacklistManagementView(
              initialBlockedUsers: mockBlocked,
            ),
          ),
        ),
      );

      // Tap Unblock button
      await tester.tap(find.text('Engeli Kaldır'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining('adlı oyuncunun engelini kaldırmak istediğinden emin misin?'),
        findsOneWidget,
      );

      // Tap Vazgeç
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      // Dialog closes, item still in list
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('SpamBot'), findsOneWidget);
    });

    testWidgets('confirming unblock triggers callback and removes item',
        (WidgetTester tester) async {
      String? unblockedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlacklistManagementView(
              initialBlockedUsers: mockBlocked,
              onUnblocked: (String id) {
                unblockedId = id;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Engeli Kaldır'));
      await tester.pumpAndSettle();

      // Tap confirmation in dialog
      final Finder confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Engeli Kaldır'),
      );
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(unblockedId, 'blk_1');
    });

    testWidgets('renders empty state when blacklist is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BlacklistManagementView(
              initialBlockedUsers: <BlockedPlayerEntry>[],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Engellenen Kimse Yok'), findsOneWidget);
    });
  });
}
