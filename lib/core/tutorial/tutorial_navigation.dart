import 'package:flutter/foundation.dart';

/// Injected by [TutorialHost] so controller can route between tutorial steps.
typedef TutorialNavigateCallback = Future<void> Function(String route);

/// Route labels for pause banner copy.
abstract final class TutorialRouteLabels {
  static String labelFor(String route) {
    if (route == '/home') return 'Ana Sayfa';
    if (route == '/dungeon' || route.startsWith('/dungeon/')) return 'Zindan';
    if (route == '/inventory') return 'Envanter';
    if (route == '/character') return 'Karakter';
    if (route == '/enhancement') return 'Güçlendirme';
    if (route == '/bank') return 'Banka';
    if (route == '/market') return 'Pazar';
    if (route == '/shop') return 'Mağaza';
    if (route == '/season') return 'Sezon';
    if (route == '/quests') return 'Görevler';
    if (route == '/crafting') return 'Craft';
    if (route.startsWith('/guild')) return 'Lonca';
    if (route == '/pvp') return 'PvP';
    if (route.startsWith('/guild-war')) return 'Lonca Savaşı';
    if (route == '/horse-race') return 'At Yarışı';
    if (route.startsWith('/mekans') || route == '/my-mekan') return 'Mekanlar';
    return 'hedef ekran';
  }
}

/// Holds optional navigation callback registered at runtime.
class TutorialNavigationBridge {
  TutorialNavigationBridge._();

  static TutorialNavigateCallback? _navigate;

  static void register(TutorialNavigateCallback? callback) {
    _navigate = callback;
  }

  @visibleForTesting
  static TutorialNavigateCallback? get callback => _navigate;

  static Future<void> go(String route) async {
    final TutorialNavigateCallback? fn = _navigate;
    if (fn == null) return;
    await fn(route);
  }
}
