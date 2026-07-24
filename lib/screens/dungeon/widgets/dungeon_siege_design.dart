import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../guild_war/widgets/guild_war_design.dart';

/// Kuşatma UI — tasarim skill paleti + lonca savaşı bileşenleri.
abstract final class SiegePalette {
  static const Color void_ = AppColors.carbonVoid;
  static const Color navy = AppColors.spaceNavy;
  static const Color obsidian = AppColors.darkObsidian;
  static const Color titanium = AppColors.mutedTitanium;

  static const Color gold = AppColors.liquidGold;
  static const Color fuchsia = AppColors.cyberFuchsia;
  static const Color ruby = AppColors.mysticRuby;
  static const Color neon = AppColors.toxicNeon;
  static const Color coral = AppColors.coralFlare;
  static const Color solar = AppColors.warningSolar;

  static const LinearGradient siegeHeroGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0x33E01E5A),
      AppColors.spaceNavy,
      AppColors.carbonVoid,
    ],
  );

  static const LinearGradient siegeAttackGrad = LinearGradient(
    colors: <Color>[AppColors.mysticRuby, AppColors.coralFlare],
  );
}

typedef SiegeBackdrop = WarBackdrop;
typedef SiegePressable = WarPressable;
typedef SiegeFadeSlide = WarFadeSlide;
typedef SiegeDottedPanel = WarDottedPanel;
typedef SiegeNeonCard = WarNeonCard;
typedef SiegeSectionHeader = WarSectionHeader;
typedef SiegeStatusPill = WarStatusPill;
typedef SiegeStatChip = WarStatChip;
typedef SiegeGoldButton = WarGoldButton;
typedef SiegeOutlineButton = WarOutlineButton;
typedef SiegeAttackButton = WarAttackButton;
typedef SiegeEmptyTab = WarEmptyTab;

class SiegeHeroBanner extends StatelessWidget {
  const SiegeHeroBanner({
    super.key,
    required this.child,
    this.accent = SiegePalette.fuchsia,
  });

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return WarHeroBanner(accent: accent, child: child);
  }
}

class SiegeDialog {
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Vazgeç',
  }) {
    return WarDialog.confirm(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      accent: SiegePalette.ruby,
    );
  }
}

/// Bottom sheet chrome — blur + fuchsia/gold üst kenar.
class SiegeSheetShell extends StatelessWidget {
  const SiegeSheetShell({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.84,
  });

  final Widget child;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            SiegePalette.navy.withValues(alpha: 0.98),
            SiegePalette.void_.withValues(alpha: 0.99),
          ],
        ),
        border: Border.all(color: SiegePalette.fuchsia.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: SiegePalette.fuchsia.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      SiegePalette.fuchsia.withValues(alpha: 0.85),
                      SiegePalette.gold.withValues(alpha: 0.55),
                      SiegePalette.fuchsia.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: CustomPaint(painter: WarDotPainter(spacing: 13, opacity: 0.07)),
            ),
            Positioned(
              top: -40,
              right: -20,
              child: IgnorePointer(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        SiegePalette.fuchsia.withValues(alpha: 0.22),
                        SiegePalette.fuchsia.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class SiegeHandle extends StatelessWidget {
  const SiegeHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: LinearGradient(
            colors: <Color>[
              SiegePalette.titanium.withValues(alpha: 0.35),
              SiegePalette.gold.withValues(alpha: 0.45),
            ],
          ),
        ),
      ),
    );
  }
}

class SiegeTag extends StatelessWidget {
  const SiegeTag({
    super.key,
    required this.label,
    this.accent = SiegePalette.fuchsia,
    this.compact = false,
  });

  final String label;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.22),
            SiegePalette.navy.withValues(alpha: 0.85),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 10),
        ],
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w900,
          color: accent,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Lonca savaşı / menüden kuşatma merkezine giriş kartı.
class SiegeHubEntryCard extends StatelessWidget {
  const SiegeHubEntryCard({
    super.key,
    required this.onTap,
    this.siegeActive = false,
    this.inPrimeWindow = false,
    this.sessionCount = 0,
    this.unreadNotifications = 0,
  });

  final VoidCallback onTap;
  final bool siegeActive;
  final bool inPrimeWindow;
  final int sessionCount;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    final Color accent = inPrimeWindow
        ? SiegePalette.fuchsia
        : siegeActive
            ? SiegePalette.neon
            : SiegePalette.gold;
    final String subtitle = inPrimeWindow
        ? 'Prime time · $sessionCount oturum · hold & slot savaşı'
        : siegeActive
            ? 'Aktif kuşatmalar · sıralama & son düellolar'
            : 'Hold, bölge rezervi, haftalık sıralama';

    return SiegePressable(
      onTap: onTap,
      child: SiegeNeonCard(
        accent: accent,
        glow: inPrimeWindow,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    SiegePalette.fuchsia.withValues(alpha: 0.32),
                    SiegePalette.gold.withValues(alpha: 0.16),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SiegePalette.fuchsia.withValues(alpha: 0.45)),
              ),
              child: const Text('🏰', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Kuşatma Merkezi',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: SiegePalette.titanium,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (unreadNotifications > 0) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: SiegePalette.solar.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: SiegePalette.solar.withValues(alpha: 0.55)),
                ),
                child: Text(
                  '$unreadNotifications',
                  style: const TextStyle(
                    color: SiegePalette.solar,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (inPrimeWindow)
              const SiegeStatusPill(label: 'CANLI', color: SiegePalette.fuchsia)
            else if (siegeActive)
              const SiegeStatusPill(label: 'AKTİF', color: SiegePalette.neon),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.75), size: 20),
          ],
        ),
      ),
    );
  }
}

class SiegeChallengeButton extends StatelessWidget {
  const SiegeChallengeButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SiegePressable(
      enabled: onPressed != null,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null ? SiegePalette.siegeAttackGrad : null,
          color: onPressed == null ? SiegePalette.obsidian : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed != null
              ? <BoxShadow>[BoxShadow(color: SiegePalette.ruby.withValues(alpha: 0.28), blurRadius: 12)]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: onPressed != null ? AppColors.textPrimary : SiegePalette.titanium,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
