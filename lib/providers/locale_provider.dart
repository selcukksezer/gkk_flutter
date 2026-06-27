import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _localePrefKey = 'app_locale';

/// Supported app language codes.
const Set<String> kSupportedLocaleCodes = <String>{'tr', 'en'};

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    _restoreSavedLocale();
    return const Locale('tr');
  }

  Future<void> _restoreSavedLocale() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? code = prefs.getString(_localePrefKey);
    if (code == null || !kSupportedLocaleCodes.contains(code)) return;
    final Locale saved = Locale(code);
    if (saved != state) {
      state = saved;
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!kSupportedLocaleCodes.contains(locale.languageCode)) return;
    state = locale;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefKey, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
