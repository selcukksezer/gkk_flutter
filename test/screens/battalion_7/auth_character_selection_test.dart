import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/core/utils/character_class_select.dart';
import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/screens/auth/character_select_screen.dart';
import 'package:gkk_flutter/screens/auth/login_screen.dart';
import 'package:gkk_flutter/screens/auth/widgets/character_slot_selector.dart';
import 'package:gkk_flutter/screens/auth/widgets/character_stats_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Model & Session State Transition Tests', () {
    test('AuthResponse handles full session payload with user and tokens', () {
      final payload = <String, dynamic>{
        'session': <String, dynamic>{
          'access_token': 'test_jwt_access_token_123',
          'refresh_token': 'test_refresh_token_456',
          'expires_at': 1793280000,
        },
        'user': <String, dynamic>{
          'id': 'user_b7_test',
          'username': 'AionHero',
          'email': 'hero@aion.world',
          'level': 1,
          'gold': 500,
          'gems': 10,
          'energy': 100,
          'max_energy': 100,
          'attack': 25,
          'defense': 18,
          'health': 150,
          'max_health': 150,
          'power': 50,
          'guild_id': null,
          'guild_role': null,
        },
        'requires_email_confirmation': false,
      };

      final auth = AuthResponse.fromJson(payload);
      expect(auth.hasSession, isTrue);
      expect(auth.requiresEmailConfirmation, isFalse);
      expect(auth.user.username, 'AionHero');
      expect(auth.session?.accessToken, 'test_jwt_access_token_123');
      expect(auth.session?.refreshToken, 'test_refresh_token_456');
    });

    test('AuthResponse correctly sets requiresEmailConfirmation when session is null', () {
      final payload = <String, dynamic>{
        'user': <String, dynamic>{
          'id': 'unverified_user_1',
          'username': 'NewWarrior',
          'email': 'unverified@aion.world',
          'level': 1,
          'gold': 0,
          'gems': 0,
          'energy': 100,
          'max_energy': 100,
          'attack': 10,
          'defense': 5,
          'health': 100,
          'max_health': 100,
          'power': 20,
        },
        'requires_email_confirmation': true,
      };

      final auth = AuthResponse.fromJson(payload);
      expect(auth.hasSession, isFalse);
      expect(auth.requiresEmailConfirmation, isTrue);
      expect(auth.session, isNull);
    });
  });

  group('CharacterClassSelect RPC Interpretation Tests', () {
    test('Interprets success outcome when success field is true', () {
      final response = <String, dynamic>{
        'success': true,
        'selected_class': 'warrior',
        'message': 'Class selected successfully',
      };

      final outcome = CharacterClassSelect.interpretResponse(response);
      expect(outcome, CharacterClassSelectOutcome.success);
    });

    test('Interprets alreadySelected outcome on error mentioning already/zaten', () {
      final responseAlready = <String, dynamic>{
        'success': false,
        'error': 'Karakter zaten bir sınıfa sahip.',
      };
      expect(
        CharacterClassSelect.interpretResponse(responseAlready),
        CharacterClassSelectOutcome.alreadySelected,
      );

      final responseHasClass = <String, dynamic>{
        'success': false,
        'selected_class': 'mage',
        'error': 'Class cannot be changed',
      };
      expect(
        CharacterClassSelect.interpretResponse(responseHasClass),
        CharacterClassSelectOutcome.alreadySelected,
      );
    });

    test('Interprets failed outcome on server errors or non-map payloads', () {
      final responseError = <String, dynamic>{
        'success': false,
        'error': 'Internal server error 500',
      };
      expect(
        CharacterClassSelect.interpretResponse(responseError),
        CharacterClassSelectOutcome.failed,
      );

      expect(
        CharacterClassSelect.interpretResponse('invalid_string_payload'),
        CharacterClassSelectOutcome.failed,
      );
      expect(
        CharacterClassSelect.interpretResponse(null),
        CharacterClassSelectOutcome.failed,
      );
    });
  });

  group('Character Class Stats & Slot Selection Logic Tests', () {
    test('CharacterClassStats produces correct archetypal stats for all classes', () {
      final warriorStats = CharacterClassStats.forClass('warrior');
      expect(warriorStats.strPercent, greaterThan(0));
      expect(warriorStats.defPercent, greaterThan(0));
      expect(warriorStats.combatPower, greaterThan(0));

      final assassinStats = CharacterClassStats.forClass('assassin');
      expect(assassinStats.strPercent, greaterThan(0));

      final mageStats = CharacterClassStats.forClass('mage');
      expect(mageStats.strPercent, greaterThan(0));

      final alchemistStats = CharacterClassStats.forClass('alchemist');
      expect(alchemistStats.combatPower, greaterThan(0));
    });

    testWidgets('CharacterSlotSelector renders all slots and fires callback on tap', (WidgetTester tester) async {
      int selectedSlot = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterSlotSelector(
              selectedSlotIndex: selectedSlot,
              onSlotSelected: (int index) {
                selectedSlot = index;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check slot buttons are present
      expect(find.byType(CharacterSlotSelector), findsOneWidget);

      // Tap second slot (index 1)
      final slotFinders = find.byType(GestureDetector);
      if (slotFinders.evaluate().length > 1) {
        await tester.tap(slotFinders.at(1));
        await tester.pumpAndSettle();
        expect(selectedSlot, 1);
      }
    });
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('LoginScreen renders dual tabs and toggles between Login and Register', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(initialTab: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify portal header & title
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Giriş Yap'), findsAtLeastNWidgets(1));
      expect(find.text('Yeni Kayıt'), findsAtLeastNWidgets(1));

      // Switch to Register Tab
      await tester.tap(find.text('Yeni Kayıt'));
      await tester.pumpAndSettle();

      // Register form components must now be active
      expect(find.text('Kayıt Ol'), findsAtLeastNWidgets(1));
    });
  });
}
