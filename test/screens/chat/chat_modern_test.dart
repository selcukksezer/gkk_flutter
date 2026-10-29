import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/chat/chat_design_system.dart';
import 'package:gkk_flutter/screens/chat/chat_models.dart';
import 'package:gkk_flutter/screens/chat/widgets/chat_channel_bar.dart';
import 'package:gkk_flutter/screens/chat/widgets/chat_composer.dart';
import 'package:gkk_flutter/screens/chat/widgets/chat_macro_wheel.dart';

void main() {
  group('ChatChannel & Models - 2027 Aion 2 Mobile', () {
    test('All 6 channels exist with proper keys, labels and tags', () {
      expect(ChatChannel.values.length, 6);
      expect(ChatChannel.global.key, 'global');
      expect(ChatChannel.guild.key, 'guild');
      expect(ChatChannel.party.key, 'party');
      expect(ChatChannel.dm.key, 'dm');
      expect(ChatChannel.system.key, 'system');
      expect(ChatChannel.trade.key, 'trade');

      expect(ChatChannel.global.label, 'Dünya');
      expect(ChatChannel.guild.label, 'Lonca');
      expect(ChatChannel.party.label, 'Grup');
      expect(ChatChannel.dm.label, 'Fısıltı');
      expect(ChatChannel.system.label, 'Sistem');
      expect(ChatChannel.trade.label, 'Pazar');

      expect(ChatChannel.global.tag, '[DÜNYA]');
      expect(ChatChannel.party.tag, '[GRUP]');
      expect(ChatChannel.system.tag, '[SİSTEM]');
    });

    test('ChatChannel fromKey handles variants and fallbacks', () {
      expect(ChatChannelX.fromKey('party'), ChatChannel.party);
      expect(ChatChannelX.fromKey('grup'), ChatChannel.party);
      expect(ChatChannelX.fromKey('system'), ChatChannel.system);
      expect(ChatChannelX.fromKey('sistem'), ChatChannel.system);
      expect(ChatChannelX.fromKey('whisper'), ChatChannel.dm);
      expect(ChatChannelX.fromKey('pm'), ChatChannel.dm);
      expect(ChatChannelX.fromKey('world'), ChatChannel.global);
      expect(ChatChannelX.fromKey('unknown_key'), ChatChannel.global);
    });

    test('ChatDesignSystem includes party, system and glassmorphism tokens', () {
      expect(ChatDesignSystem.colorPartyAccent, isNotNull);
      expect(ChatDesignSystem.colorSystemAccent, isNotNull);
      expect(ChatDesignSystem.gradientParty, isNotNull);
      expect(ChatDesignSystem.gradientSystem, isNotNull);
      expect(ChatDesignSystem.blurGlassSigma, 16.0);
    });
  });

  group('ChatChannelBar Widget Tests', () {
    testWidgets('Renders all channel tabs and unread badges', (WidgetTester tester) async {
      ChatChannel selectedChannel = ChatChannel.global;
      bool modeToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatChannelBar(
              activeChannel: selectedChannel,
              guildUnreadCount: 5,
              dmUnreadCount: 2,
              partyUnreadCount: 3,
              systemUnreadCount: 1,
              onToggleMode: () => modeToggled = true,
              onChannelSelected: (ChatChannel c) => selectedChannel = c,
            ),
          ),
        ),
      );

      // Verify channel labels are present
      expect(find.text('Dünya'), findsOneWidget);
      expect(find.text('Lonca'), findsOneWidget);
      expect(find.text('Grup'), findsOneWidget);
      expect(find.text('Fısıltı'), findsOneWidget);
      expect(find.text('Sistem'), findsOneWidget);
      expect(find.text('Pazar'), findsOneWidget);

      // Verify unread badge numbers
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Tap on 'Grup' channel
      await tester.tap(find.text('Grup'));
      await tester.pump();
      expect(selectedChannel, ChatChannel.party);

      // Tap on view mode button
      await tester.tap(find.byIcon(Icons.aspect_ratio_rounded));
      await tester.pump();
      expect(modeToggled, isTrue);
    });
  });

  group('ChatMacroWheel Widget Tests', () {
    testWidgets('Renders tactical macros and allows selecting macro', (WidgetTester tester) async {
      String? selectedMacroText;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMacroWheel(
              activeChannel: ChatChannel.party,
              onSelectMacro: (String text) => selectedMacroText = text,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      expect(find.text('Taktik Makrolar & İfadeler'), findsOneWidget);
      expect(find.text('⚔️ Savaş'), findsOneWidget);
      expect(find.text('💬 Sosyal'), findsOneWidget);
      expect(find.text('✨ İfadeler'), findsOneWidget);

      // Find and tap a tactical combat macro
      expect(find.text('Saldırın'), findsOneWidget);
      await tester.tap(find.text('Saldırın'));
      await tester.pump();

      expect(selectedMacroText, contains('⚔️ Saldırın'));

      // Switch to Radial Wheel mode
      expect(find.text('Çark Modu'), findsOneWidget);
      await tester.tap(find.text('Çark Modu'));
      await tester.pump();

      expect(find.text('SEÇİN'), findsOneWidget);
      expect(find.text('Tepsi Modu'), findsOneWidget);

      // Close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, isTrue);
    });
  });

  group('ChatComposer Widget Tests', () {
    testWidgets('Standard channel input and macro toggle', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      bool sendTriggered = false;
      bool macroToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatComposer(
              asPanel: false,
              activeChannel: ChatChannel.party,
              activeBan: null,
              messageController: controller,
              isSending: false,
              maxMessageLength: 200,
              blockedUserCount: 0,
              onSend: () => sendTriggered = true,
              onOpenBlockedUsers: () {},
              onToggleMacroWheel: () => macroToggled = true,
              isMacroWheelOpen: false,
            ),
          ),
        ),
      );

      expect(find.text('Grup mesajı yaz...'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      // Tap macro wheel button
      await tester.tap(find.byIcon(Icons.bolt_rounded));
      await tester.pump();
      expect(macroToggled, isTrue);

      // Enter text and verify send
      controller.text = 'Hazırım, zindana girelim!';
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(sendTriggered, isTrue);
    });

    testWidgets('System channel is read-only and locks input', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(text: 'Dene');
      bool sendTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatComposer(
              asPanel: false,
              activeChannel: ChatChannel.system,
              activeBan: null,
              messageController: controller,
              isSending: false,
              maxMessageLength: 200,
              blockedUserCount: 0,
              onSend: () => sendTriggered = true,
              onOpenBlockedUsers: () {},
            ),
          ),
        ),
      );

      expect(find.text('Sistem kanalı salt okunurdur'), findsOneWidget);

      // Macro button is not shown for System channel
      expect(find.byIcon(Icons.bolt_rounded), findsNothing);

      // Attempt to send in System channel - must not trigger send callback
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(sendTriggered, isFalse);
    });
  });

  group('Mobile 390x844 SafeArea & Layout Integration', () {
    testWidgets('ChatChannelBar & Composer adapt gracefully in 390x844 viewport', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final TextEditingController controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  ChatChannelBar(
                    activeChannel: ChatChannel.global,
                    guildUnreadCount: 0,
                    dmUnreadCount: 0,
                    partyUnreadCount: 0,
                    systemUnreadCount: 0,
                    onChannelSelected: (_) {},
                  ),
                  const Spacer(),
                  ChatComposer(
                    asPanel: false,
                    activeChannel: ChatChannel.global,
                    activeBan: null,
                    messageController: controller,
                    isSending: false,
                    maxMessageLength: 200,
                    blockedUserCount: 0,
                    onSend: () {},
                    onOpenBlockedUsers: () {},
                    onToggleMacroWheel: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Dünya kanalında yaz...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
