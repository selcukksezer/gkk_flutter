import '../../l10n/app_localizations.dart';

abstract final class AuthValidators {
  static final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,16}$');
  static final RegExp passwordLetter = RegExp(r'[A-Za-z]');
  static final RegExp passwordDigit = RegExp(r'[0-9]');

  static const int minPasswordLength = 8;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 16;

  static String? validateEmail(String? value, AppLocalizations l10n) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) {
      return l10n.auth_email_required;
    }
    if (!emailPattern.hasMatch(email)) {
      return l10n.auth_email_invalid;
    }
    return null;
  }

  /// Login: non-empty only (existing short passwords must still work).
  static String? validateLoginIdentifier(
    String? value,
    AppLocalizations l10n, {
    required Map<String, String> knownUsernameEmails,
  }) {
    final String raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return l10n.auth_email_required;
    }
    if (emailPattern.hasMatch(raw)) {
      return null;
    }
    final String normalized = raw.startsWith('@')
        ? raw.substring(1).toLowerCase()
        : raw.toLowerCase();
    if (knownUsernameEmails.containsKey(normalized)) {
      return null;
    }
    return l10n.auth_email_invalid;
  }
  static String? validatePasswordLogin(String? value, AppLocalizations l10n) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return l10n.auth_password_required;
    }
    return null;
  }

  /// Register / reset: min 8 + letter + digit.
  static String? validatePassword(String? value, AppLocalizations l10n) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return l10n.auth_password_required;
    }
    if (password.length < minPasswordLength) {
      return l10n.auth_password_min_length;
    }
    if (!passwordLetter.hasMatch(password) || !passwordDigit.hasMatch(password)) {
      return l10n.auth_password_strength;
    }
    return null;
  }

  static String? validatePasswordConfirm(
    String? value,
    String password,
    AppLocalizations l10n,
  ) {
    final String confirm = value ?? '';
    if (confirm.isEmpty) {
      return l10n.auth_password_confirm_required;
    }
    if (confirm != password) {
      return l10n.auth_password_mismatch;
    }
    return null;
  }

  static String? validateUsername(String? value, AppLocalizations l10n) {
    final String username = value?.trim() ?? '';
    if (username.isEmpty) {
      return l10n.auth_username_required;
    }
    if (username.length < minUsernameLength ||
        username.length > maxUsernameLength ||
        !usernamePattern.hasMatch(username)) {
      return l10n.auth_username_invalid;
    }
    return null;
  }
}
