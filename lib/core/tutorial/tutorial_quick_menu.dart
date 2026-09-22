import '../../routing/app_router.dart';
import 'tutorial_track.dart';

/// Quick-menu tile anchors for menu-nav tutorial steps.
abstract final class TutorialQuickMenuAnchors {
  static String? anchorForRoute(String? route) {
    if (route == null) return null;
    return switch (route) {
      AppRoutes.enhancement => TutorialAnchorId.navMenuEnhancement,
      AppRoutes.season => TutorialAnchorId.navMenuSeason,
      AppRoutes.quests => TutorialAnchorId.navMenuQuests,
      AppRoutes.shop => TutorialAnchorId.navMenuShop,
      AppRoutes.crafting => TutorialAnchorId.navMenuCraft,
      AppRoutes.bank => TutorialAnchorId.navMenuBank,
      AppRoutes.market => TutorialAnchorId.navMenuMarket,
      AppRoutes.guild => TutorialAnchorId.navMenuGuild,
      AppRoutes.pvp => TutorialAnchorId.navMenuPvp,
      AppRoutes.facilities => TutorialAnchorId.navMenuFacilities,
      AppRoutes.trade => TutorialAnchorId.navMenuTrade,
      AppRoutes.hospital => TutorialAnchorId.navMenuHospital,
      AppRoutes.prison => TutorialAnchorId.navMenuPrison,
      _ => null,
    };
  }

  static bool isMenuItemAnchor(String? anchorId) =>
      anchorId != null && anchorId.startsWith('nav.menu_');
}
