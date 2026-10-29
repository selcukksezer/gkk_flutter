import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/chat/chat_design_system.dart';
import 'package:gkk_flutter/screens/chat/chat_models.dart';
import 'package:gkk_flutter/screens/chat/widgets/chat_item_preview_modal.dart';
import 'package:gkk_flutter/screens/chat/widgets/chat_message_bubble.dart';
import 'package:gkk_flutter/screens/chat/widgets/chat_message_list.dart';
import 'package:gkk_flutter/screens/chat/widgets/chat_sender_badge.dart';
import 'package:gkk_flutter/screens/chat/widgets/chat_system_announcement.dart';

void main() {
  group('Chat Models & Parsing', () {
    test('ChatFaction parses keys and provides correct lore and runes', () {
      expect(ChatFactionX.fromKey('elyos'), ChatFaction.elyos);
      expect(ChatFactionX.fromKey('CELestial'), ChatFaction.elyos);
      expect(ChatFactionX.fromKey('asmodian'), ChatFaction.asmodian);
      expect(ChatFactionX.fromKey('dark'), ChatFaction.asmodian);
      expect(ChatFactionX.fromKey('neutral'), ChatFaction.neutral);
      expect(ChatFactionX.fromKey('unknown'), isNull);

      expect(ChatFaction.elyos.rune, 'ᛟ');
      expect(ChatFaction.asmodian.rune, 'ᛉ');
      expect(ChatFaction.neutral.rune, 'ᚱ');
      expect(ChatFaction.elyos.factionName, 'Elyos');
      expect(ChatFaction.asmodian.title, 'Gölgepençe Akıncısı');
    });

    test('ChatCharacterClass parses keys and roles', () {
      expect(ChatCharacterClassX.fromKey('gladiator'), ChatCharacterClass.gladiator);
      expect(ChatCharacterClassX.fromKey('warrior'), ChatCharacterClass.gladiator);
      expect(ChatCharacterClassX.fromKey('templar'), ChatCharacterClass.templar);
      expect(ChatCharacterClassX.fromKey('assassin'), ChatCharacterClass.assassin);
      expect(ChatCharacterClassX.fromKey('ranger'), ChatCharacterClass.ranger);
      expect(ChatCharacterClassX.fromKey('sorcerer'), ChatCharacterClass.sorcerer);
      expect(ChatCharacterClassX.fromKey('spiritmaster'), ChatCharacterClass.spiritmaster);
      expect(ChatCharacterClassX.fromKey('cleric'), ChatCharacterClass.cleric);
      expect(ChatCharacterClassX.fromKey('chanter'), ChatCharacterClass.chanter);
      expect(ChatCharacterClassX.fromKey('invalid'), isNull);

      expect(ChatCharacterClass.gladiator.label, 'Gladyatör');
      expect(ChatCharacterClass.sorcerer.role, 'Elementel Yıkım');
    });

    test('ChatItemLink parses tag and json correctly', () {
      const String rawTag = '[item:blade_99:Ejderha Katili:mythic:15:65:Kılıç]';
      final ChatItemLink? item = ChatItemLink.tryParseTag(rawTag);
      expect(item, isNotNull);
      expect(item!.id, 'blade_99');
      expect(item.name, 'Ejderha Katili');
      expect(item.rarity, ChatItemRarity.mythic);
      expect(item.enhancementLevel, 15);
      expect(item.requiredLevel, 65);
      expect(item.itemType, 'Kılıç');
      expect(item.displayName, '+15 Ejderha Katili');
      expect(item.tag, '[+15 Ejderha Katili]');

      final Map<String, dynamic> json = item.toJson();
      expect(json['id'], 'blade_99');
      expect(json['rarity'], 'mythic');
    });

    test('ChatMessage parses rich fields and inline item links from content', () {
      final Map<String, dynamic> raw = <String, dynamic>{
        'id': 'msg_101',
        'channel': 'global',
        'sender_id': 'user_42',
        'sender_name': 'Kromede',
        'content': 'Bakın ne düşürdüm: [item:spear_1:Kromede Mızrağı:legendary:10:50:Mızrak]!',
        'timestamp': '2026-10-28T21:00:00Z',
        'is_system': false,
        'sender_class': 'gladiator',
        'sender_faction': 'elyos',
        'sender_level': 55,
      };

      final ChatMessage msg = ChatMessage.fromJson(raw);
      expect(msg.id, 'msg_101');
      expect(msg.senderClass, ChatCharacterClass.gladiator);
      expect(msg.senderFaction, ChatFaction.elyos);
      expect(msg.senderLevel, 55);
      expect(msg.itemLinks, isNotNull);
      expect(msg.itemLinks!.length, 1);
      expect(msg.itemLinks!.first.name, 'Kromede Mızrağı');
      expect(msg.itemLinks!.first.rarity, ChatItemRarity.legendary);
    });
  });

  group('Sender Badges Widgets', () {
    testWidgets('SenderClassInsignia renders icon and label', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                SenderClassInsignia(senderClass: ChatCharacterClass.gladiator),
                SenderClassInsignia(senderClass: ChatCharacterClass.sorcerer, showLabel: true),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SenderClassInsignia), findsNWidgets(2));
      expect(find.text('Büyücü'), findsOneWidget);
    });

    testWidgets('SenderFactionInsignia renders rune and emblem', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                SenderFactionInsignia(faction: ChatFaction.elyos),
                SenderFactionInsignia(faction: ChatFaction.asmodian),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ᛟ'), findsOneWidget);
      expect(find.text('ᛉ'), findsOneWidget);
    });

    testWidgets('SenderLevelBadge renders level and max tier star', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                SenderLevelBadge(level: 25),
                SenderLevelBadge(level: 65),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Lv.25'), findsOneWidget);
      expect(find.text('Lv.65'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('ChatAvatarThumbnail renders fallback and online dot', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatAvatarThumbnail(
              senderClass: ChatCharacterClass.templar,
              isOnline: true,
            ),
          ),
        ),
      );

      expect(find.byType(ChatAvatarThumbnail), findsOneWidget);
      expect(find.byIcon(ChatCharacterClass.templar.icon), findsOneWidget);
    });
  });

  group('Item Preview Modal & Chip', () {
    testWidgets('ChatItemLinkChip renders and triggers preview on tap', (WidgetTester tester) async {
      const ChatItemLink testItem = ChatItemLink(
        id: 'sword_test',
        name: 'Aion Işık Kılıcı',
        rarity: ChatItemRarity.mythic,
        enhancementLevel: 12,
        requiredLevel: 65,
        attack: 850,
        defense: 120,
        magicPower: 450,
        criticalRate: 180,
        description: 'Eski Daeva savaşçılarının kutsal silahı.',
        sockets: <String>['Fiziksel Saldırı +5', 'Kritik +17'],
      );

      bool tapHandled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChatItemLinkChip(
                item: testItem,
                onTap: () => tapHandled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('+12 Aion Işık Kılıcı'), findsOneWidget);
      await tester.tap(find.byType(ChatItemLinkChip));
      await tester.pumpAndSettle();
      expect(tapHandled, isTrue);
    });

    testWidgets('ChatItemPreviewModal displays full item stats and sockets', (WidgetTester tester) async {
      const ChatItemLink testItem = ChatItemLink(
        id: 'sword_test',
        name: 'Aion Işık Kılıcı',
        rarity: ChatItemRarity.mythic,
        enhancementLevel: 12,
        requiredLevel: 65,
        itemType: 'Kılıç',
        attack: 850,
        defense: 120,
        magicPower: 450,
        criticalRate: 180,
        description: 'Eski Daeva savaşçılarının kutsal silahı.',
        sockets: <String>['Fiziksel Saldırı +5', 'Kritik +17'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatItemPreviewModal(
              item: testItem,
              senderName: 'Kromede',
            ),
          ),
        ),
      );

      expect(find.text('+12 Aion Işık Kılıcı'), findsOneWidget);
      expect(find.text(testItem.rarity.label.toUpperCase()), findsOneWidget);
      expect(find.text(testItem.itemType.toUpperCase()), findsOneWidget);
      expect(find.text('SEVİYE 65'), findsOneWidget);
      expect(find.text('TEMEL NİTELİKLER'), findsOneWidget);
      expect(find.text('+850'), findsOneWidget);
      expect(find.text('+120'), findsOneWidget);
      expect(find.text('MANA TAŞI YUVALARI'), findsOneWidget);
      expect(find.text('Fiziksel Saldırı +5'), findsOneWidget);
      expect(find.text('"Eski Daeva savaşçılarının kutsal silahı."'), findsOneWidget);
      expect(find.text('Kopyala'), findsOneWidget);
    });
  });

  group('System Announcement Banner', () {
    testWidgets('ChatSystemAnnouncementBanner renders Aion runic border and pulse', (WidgetTester tester) async {
      final ChatMessage sysMsg = ChatMessage(
        id: 'sys_1',
        channel: ChatChannel.global,
        senderId: '',
        senderName: 'Sistem',
        content: 'Dünya Bossu Rudra göklerden indi!',
        timestamp: DateTime(2026, 10, 28, 21, 30),
        isSystem: true,
        systemTone: 'danger',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatSystemAnnouncementBanner(message: sysMsg),
          ),
        ),
      );

      expect(find.text('AION DUYURUSU'), findsOneWidget);
      expect(find.text('Dünya Bossu Rudra göklerden indi!'), findsOneWidget);
      expect(find.text('ᛉ᚛'), findsOneWidget);
      expect(find.text('᚜ᛉ'), findsOneWidget);

      // Verify pulse animation frames
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ChatSystemAnnouncementBanner), findsOneWidget);
    });
  });

  group('ChatMessageBubble & ChatMessageList', () {
    testWidgets('ChatMessageBubble renders own and peer messages with badges', (WidgetTester tester) async {
      final ChatMessage ownMsg = ChatMessage(
        id: 'own_1',
        channel: ChatChannel.global,
        senderId: 'me',
        senderName: 'Sen',
        content: 'Selam lonca!',
        timestamp: DateTime(2026, 10, 28, 21, 32),
        isSystem: false,
        senderClass: ChatCharacterClass.gladiator,
        senderLevel: 65,
      );

      final ChatMessage peerMsg = ChatMessage(
        id: 'peer_1',
        channel: ChatChannel.global,
        senderId: 'peer_10',
        senderName: 'StormWalker',
        content: 'Harika kılıç!',
        timestamp: DateTime(2026, 10, 28, 21, 33),
        isSystem: false,
        senderClass: ChatCharacterClass.sorcerer,
        senderFaction: ChatFaction.elyos,
        senderLevel: 58,
        senderGuildName: 'EjderhaMuhafizlari',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                ChatMessageBubble(
                  message: ownMsg,
                  isOwn: true,
                  isOnline: true,
                  activeChannel: ChatChannel.global,
                ),
                ChatMessageBubble(
                  message: peerMsg,
                  isOwn: false,
                  isOnline: true,
                  activeChannel: ChatChannel.global,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Sen'), findsOneWidget);
      expect(find.text('Selam lonca!'), findsOneWidget);
      expect(find.text('[EjderhaMuhafizlari]'), findsOneWidget);
      expect(find.text('Harika kılıç!'), findsOneWidget);
      expect(find.text('Lv.58'), findsOneWidget);
      expect(find.text('Lv.65'), findsOneWidget);
    });

    testWidgets('ChatMessageList renders complete list with system banners and bubbles', (WidgetTester tester) async {
      final List<ChatMessage> list = <ChatMessage>[
        ChatMessage(
          id: 'sys_ann',
          channel: ChatChannel.global,
          senderId: '',
          senderName: 'Sistem',
          content: 'Sunucu bakımı tamamlandı.',
          timestamp: DateTime(2026, 10, 28, 20, 0),
          isSystem: true,
          systemTone: 'success',
        ),
        ChatMessage(
          id: 'peer_msg',
          channel: ChatChannel.global,
          senderId: 'peer_1',
          senderName: 'HeroDaeva',
          content: 'Zindana kimler geliyor?',
          timestamp: DateTime(2026, 10, 28, 20, 5),
          isSystem: false,
          senderClass: ChatCharacterClass.templar,
          senderFaction: ChatFaction.asmodian,
          senderLevel: 60,
        ),
      ];

      final ScrollController controller = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageList(
              isLoading: false,
              messages: list,
              activeChannel: ChatChannel.global,
              scrollController: controller,
              isOwnSender: (String id) => id == 'me',
              isUserOnline: (String id, {bool? fallback}) => true,
              onMuteSender: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.text('AION DUYURUSU'), findsOneWidget);
      expect(find.text('Sunucu bakımı tamamlandı.'), findsOneWidget);
      expect(find.text('Zindana kimler geliyor?'), findsOneWidget);
      expect(find.text('Lv.60'), findsOneWidget);
    });
  });
}
