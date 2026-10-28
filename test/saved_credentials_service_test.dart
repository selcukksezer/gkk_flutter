import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/services/saved_credentials_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saves, encrypts, loads, and resolves saved login credentials', () async {
    final SavedLoginCredentials initial = await SavedCredentialsService.load();
    expect(initial.rememberMe, isTrue);
    expect(initial.hasSavedAccount, isFalse);

    await SavedCredentialsService.save(
      email: 'warrior@gkk.example',
      password: 'SecretPassword99',
      username: 'GolgeKrali',
      rememberMe: true,
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? rawVault = prefs.getString('gkk_auth_saved_vault_v1');
    expect(rawVault, isNotNull);
    expect(rawVault!.contains('SecretPassword99'), isFalse);

    final SavedLoginCredentials loaded = await SavedCredentialsService.load();
    expect(loaded.hasSavedAccount, isTrue);
    expect(loaded.email, 'warrior@gkk.example');
    expect(loaded.username, 'GolgeKrali');
    expect(loaded.password, 'SecretPassword99');
    expect(loaded.displayHandle, '@GolgeKrali');

    expect(
      SavedCredentialsService.resolveIdentifier(
        'golgekrali',
        loaded.knownUsernameEmails,
      ),
      'warrior@gkk.example',
    );
    expect(
      SavedCredentialsService.resolveIdentifier(
        '@GolgeKrali',
        loaded.knownUsernameEmails,
      ),
      'warrior@gkk.example',
    );

    await SavedCredentialsService.updatePasswordIfSaved('NewPass123');
    final SavedLoginCredentials afterUpdate =
        await SavedCredentialsService.load();
    expect(afterUpdate.password, 'NewPass123');

    await SavedCredentialsService.clearSavedAccount();
    final SavedLoginCredentials afterClear =
        await SavedCredentialsService.load();
    expect(afterClear.hasSavedAccount, isFalse);
    expect(afterClear.rememberMe, isTrue);
    // Known username -> email mapping stays intact for convenience
    expect(
      SavedCredentialsService.resolveIdentifier(
        'GolgeKrali',
        afterClear.knownUsernameEmails,
      ),
      'warrior@gkk.example',
    );
  });

  test('disabling rememberMe purges encrypted vault', () async {
    await SavedCredentialsService.save(
      email: 'test@gkk.example',
      password: 'Password123',
      username: 'TestHero',
      rememberMe: true,
    );
    await SavedCredentialsService.setRememberMe(false);

    final SavedLoginCredentials loaded = await SavedCredentialsService.load();
    expect(loaded.rememberMe, isFalse);
    expect(loaded.hasSavedAccount, isFalse);
    expect(loaded.password, isEmpty);
  });
}
