import 'package:flutter/material.dart';

import 'tutorial_anchor.dart';
import 'tutorial_track.dart';

/// Thin measurable wrapper — does NOT change chip visual size/layout.
class TutorialHudAnchorChip extends StatelessWidget {
  const TutorialHudAnchorChip({
    super.key,
    required this.anchorId,
    required this.child,
  });

  final String anchorId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TutorialAnchorScope(
      id: anchorId,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: child,
      ),
    );
  }
}

/// Spotlight helpers — inflate hole in OVERLAY only, never the real HUD widgets.
abstract final class TutorialSpotlightGeometry {
  static EdgeInsets paddingFor(String? anchorId) {
    if (anchorId == TutorialAnchorId.navBottomBar) {
      return EdgeInsets.zero;
    }
    // Quick-menu tiles: icon (64) + label — pad top so gold frame not clipped
    // when dialog slide / scroll leaves a slightly stale rect for one frame.
    if (anchorId != null && anchorId.startsWith('nav.menu_')) {
      return const EdgeInsets.fromLTRB(6, 10, 6, 8);
    }
    // Bottom-nav tabs — fat-finger + active-pill overlap.
    if (anchorId != null &&
        (anchorId.endsWith('_tab') || anchorId == TutorialAnchorId.navMenuTab)) {
      return const EdgeInsets.symmetric(horizontal: 4, vertical: 6);
    }
    if (anchorId != null && anchorId.startsWith('hud.')) {
      return const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    }
    return const EdgeInsets.symmetric(horizontal: 2, vertical: 3);
  }

  static double borderRadiusFor(String? anchorId) {
    if (anchorId == TutorialAnchorId.navBottomBar) {
      return 24;
    }
    if (anchorId != null && anchorId.startsWith('nav.menu_')) {
      return 14;
    }
    if (anchorId != null && anchorId.startsWith('hud.')) {
      return 10;
    }
    return 12;
  }

  static Rect normalizeHole(Rect hole, String anchorId) {
    final Size? minSize = switch (anchorId) {
      final String id when id.startsWith('hud.') => const Size(96, 34),
      // Cover full menu tile (64px icon + gap + 1–2 line label).
      final String id when id.startsWith('nav.menu_') => const Size(76, 96),
      _ => null,
    };
    if (minSize == null) return hole;
    final double width =
        hole.width < minSize.width ? minSize.width : hole.width;
    final double height =
        hole.height < minSize.height ? minSize.height : hole.height;
    if (width == hole.width && height == hole.height) return hole;
    // Grow upward/outward from top-center so icon stays inside when height
    // was under-measured (label-only / mid-slide stale rect).
    if (anchorId.startsWith('nav.menu_') && height > hole.height) {
      final double growY = height - hole.height;
      final double growX = (width - hole.width) / 2;
      return Rect.fromLTRB(
        hole.left - growX,
        hole.top - growY,
        hole.right + growX,
        hole.bottom,
      );
    }
    return Rect.fromCenter(center: hole.center, width: width, height: height);
  }

  /// True for main shell bottom tabs (not quick-menu tiles / whole bar).
  static bool isShellNavTab(String? anchorId) {
    if (anchorId == null) return false;
    if (!anchorId.startsWith('nav.')) return false;
    if (anchorId.startsWith('nav.menu_')) return false;
    if (anchorId == TutorialAnchorId.navBottomBar) return false;
    return anchorId.endsWith('_tab') ||
        anchorId == TutorialAnchorId.navMenuTab;
  }

  /// When GlobalKey measure fails (overlay race / mid rebuild), estimate tab
  /// hole so Karakter/Zindan never stay under a full-screen lock + bottom skip.
  ///
  /// Mirrors [GameBottomBar] layout: SafeArea min pad 12/10, pill height 64.
  static Rect? fallbackNavTabHole({
    required String anchorId,
    required Size screen,
    required EdgeInsets safePadding,
  }) {
    final int? index = switch (anchorId) {
      TutorialAnchorId.navHomeTab => 0,
      TutorialAnchorId.navInventoryTab => 1,
      TutorialAnchorId.navDungeonTab => 2,
      TutorialAnchorId.navCharacterTab => 3,
      TutorialAnchorId.navMenuTab => 4,
      _ => null,
    };
    if (index == null) return null;

    const double hPad = 12;
    const double vBottomMin = 10;
    const double barHeight = 64;
    const int tabCount = 5;

    final double bottomInset =
        safePadding.bottom < vBottomMin ? vBottomMin : safePadding.bottom;
    final double barBottom = screen.height - bottomInset;
    final double barTop = barBottom - barHeight;
    final double usableWidth = (screen.width - hPad * 2).clamp(0.0, screen.width);
    final double tabW = usableWidth / tabCount;
    final double left = hPad + index * tabW;
    final EdgeInsets pad = paddingFor(anchorId);
    return Rect.fromLTRB(
      left - pad.left,
      barTop - pad.top,
      left + tabW + pad.right,
      barBottom + pad.bottom,
    );
  }

  /// HUD / home body fallbacks when GlobalKey measure fails after settings replay
  /// (top-bar dispose/register race → null hole → no spotlight).
  static Rect? fallbackHomeHole({
    required String anchorId,
    required Size screen,
    required EdgeInsets safePadding,
  }) {
    final double top = safePadding.top + 8;
    final double contentTop = safePadding.top + 110;
    final EdgeInsets pad = paddingFor(anchorId);
    final Rect? raw = switch (anchorId) {
      TutorialAnchorId.hudGold => Rect.fromLTWH(
          12,
          top + 8,
          screen.width * 0.30,
          30,
        ),
      TutorialAnchorId.hudGems => Rect.fromLTWH(
          screen.width * 0.68,
          top + 8,
          screen.width * 0.28,
          28,
        ),
      TutorialAnchorId.hudEnergy => Rect.fromLTWH(
          screen.width * 0.68,
          top + 40,
          screen.width * 0.28,
          28,
        ),
      TutorialAnchorId.homePromo => Rect.fromLTWH(
          16,
          contentTop,
          screen.width - 32,
          150,
        ),
      TutorialAnchorId.homeHero => Rect.fromLTWH(
          16,
          contentTop + 170,
          screen.width - 32,
          220,
        ),
      TutorialAnchorId.navBottomBar => Rect.fromLTWH(
          12,
          screen.height - safePadding.bottom - 74,
          screen.width - 24,
          64,
        ),
      _ => null,
    };
    if (raw == null) return null;
    return Rect.fromLTRB(
      raw.left - pad.left,
      raw.top - pad.top,
      raw.right + pad.right,
      raw.bottom + pad.bottom,
    );
  }

  /// Prefer measured hole; else nav/HUD/home fallback so replay never blanks.
  static Rect? resolveHole({
    required String? anchorId,
    required Rect? measuredLocal,
    required Size screen,
    required EdgeInsets safePadding,
  }) {
    if (measuredLocal != null) return measuredLocal;
    if (anchorId == null) return null;
    if (isShellNavTab(anchorId)) {
      return fallbackNavTabHole(
        anchorId: anchorId,
        screen: screen,
        safePadding: safePadding,
      );
    }
    return fallbackHomeHole(
      anchorId: anchorId,
      screen: screen,
      safePadding: safePadding,
    );
  }
}
