import '../../l10n/app_localizations.dart';

abstract final class AuthValidators {
  static final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

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

  static String? validatePassword(String? value, AppLocalizations l10n) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return l10n.auth_password_required;
    }
    if (password.length < 6) {
      return l10n.auth_password_min_length;
    }
    return null;
  }

  static String? validateUsername(String? value, AppLocalizations l10n) {
    final String username = value?.trim() ?? '';
    if (username.isEmpty) {
      return l10n.auth_username_required;
    }
    return null;
  }
}
