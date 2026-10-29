import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/live_ticker_model.dart';
import '../../theme/app_colors.dart';

/// 2027 Aion 2 visual tokens for announcement strips, ribbon pills, and bento cards.
abstract final class TickerPalette {
  // Legacy / backward-compatible tokens
  static const Color void_ = AppColors.carbonVoid;
  static const Color navy = AppColors.spaceNavy;
  static const Color gold = AppColors.liquidGold;
  static const Color neon = AppColors.toxicNeon;
  static const Color fuchsia = AppColors.cyberFuchsia;
  static const Color ruby = AppColors.mysticRuby;
  static const Color textHi = Color(0xFFF2F6FF);
  static const Color textMid = Color(0xFFA9B7D0);

  // 2027 Aion 2 Obsidian-Glass & Celestial Palette
  static const Color obsidianVoid = Color(0xFF090D15);
  static const Color obsidianGlass = Color(0xCC090D15);
  static const Color obsidianSurface = Color(0xFF0E1422);

  // 2027 Aion 2 Cyan Ether Luminescence
  static const Color cyanEther = Color(0xFF00E5FF);
  static const Color cyanEtherGlow = Color(0x3300E5FF);
  static const Color cyanEtherLight = Color(0xFF80F3FF);

  // 2027 Aion 2 Celestial Gold Accents
  static const Color celestialGold = Color(0xFFFFD700);
  static const Color celestialGoldLight = Color(0xFFFFF4B8);
  static const Color celestialGoldGlow = Color(0x33FFD700);

  // Text & Border tokens
  static const Color etherBorder = Color(0x5200E5FF);
  static const Color textMuted = Color(0xFF6B7D99);
  static const Color textCelestial = Color(0xFFFFF7D6);

  // Obsidian frosted gradients
  static const LinearGradient obsidianGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xEB090D15),
      Color(0xD9101726),
      Color(0xF0090D15),
    ],
    stops: <double>[0.0, 0.52, 1.0],
  );

  static const LinearGradient cyanEtherBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0x8000E5FF),
      Color(0x2600E5FF),
      Color(0x80FFD700),
    ],
  );
}

/// Visual representation metadata for ticker item categories.
class LiveTickerVisual {
  const LiveTickerVisual({
    required this.icon,
    required this.accent,
    required this.label,
    this.badgeAccent = TickerPalette.celestialGold,
    this.secondaryAccent = TickerPalette.cyanEther,
    this.glowColor,
  });

  final String icon;
  final Color accent;
  final String label;
  final Color badgeAccent;
  final Color secondaryAccent;
  final Color? glowColor;

  Color get resolvedGlow => glowColor ?? accent.withValues(alpha: 0.28);

  static LiveTickerVisual forType(String type) {
    switch (type) {
      case 'dungeon_clear':
        return const LiveTickerVisual(
          icon: '⚔️',
          accent: TickerPalette.ruby,
          label: 'Boss',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.ruby,
        );
      case 'enhance_success':
        return const LiveTickerVisual(
          icon: '✨',
          accent: TickerPalette.celestialGold,
          label: 'Güçlendirme',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.cyanEther,
        );
      case 'loot_rare':
        return const LiveTickerVisual(
          icon: '🎁',
          accent: TickerPalette.fuchsia,
          label: 'Nadir loot',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.cyanEther,
        );
      case 'guild_war':
        return const LiveTickerVisual(
          icon: '🏰',
          accent: TickerPalette.neon,
          label: 'Lonca savaşı',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.cyanEther,
        );
      case 'siege_win':
        return const LiveTickerVisual(
          icon: '🛡️',
          accent: TickerPalette.neon,
          label: 'Kuşatma',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.cyanEther,
        );
      case 'siege_soon':
        return const LiveTickerVisual(
          icon: '🛡️',
          accent: TickerPalette.neon,
          label: 'Kuşatma yakında',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.cyanEther,
        );
      case 'siege_start':
        return const LiveTickerVisual(
          icon: '🔥',
          accent: TickerPalette.ruby,
          label: 'Kuşatma başladı',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.ruby,
        );
      case 'siege_live':
        return const LiveTickerVisual(
          icon: '🔥',
          accent: TickerPalette.ruby,
          label: 'Canlı kuşatma',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.ruby,
        );
      case 'night_market':
        return const LiveTickerVisual(
          icon: '🌙',
          accent: TickerPalette.fuchsia,
          label: 'Gece Pazarı',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.cyanEther,
        );
      case 'king_blessing':
        return const LiveTickerVisual(
          icon: '👑',
          accent: TickerPalette.celestialGold,
          label: 'Kral indirimi',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.celestialGoldLight,
        );
      case 'king_gift':
        return const LiveTickerVisual(
          icon: '🎁',
          accent: TickerPalette.celestialGold,
          label: 'Kral hediyesi',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.cyanEther,
        );
      case 'staff_broadcast':
        return const LiveTickerVisual(
          icon: '📣',
          accent: TickerPalette.cyanEther,
          label: 'Duyuru',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.cyanEther,
        );
      case 'player_ban':
        return const LiveTickerVisual(
          icon: '🚫',
          accent: TickerPalette.ruby,
          label: 'Ban',
          badgeAccent: TickerPalette.ruby,
          secondaryAccent: TickerPalette.ruby,
        );
      default:
        return const LiveTickerVisual(
          icon: '📣',
          accent: TickerPalette.celestialGold,
          label: 'Duyuru',
          badgeAccent: TickerPalette.celestialGold,
          secondaryAccent: TickerPalette.cyanEther,
        );
    }
  }
}

/// 2027 Aion 2 Obsidian Frosted Glass Ribbon Pill Container.
///
/// Features:
/// - Obsidian frosted glass base (Color(0xFF090D15) with BackdropFilter blur)
/// - Cyan ether border luminescence and celestial gold / category accent aura
/// - Clean alignment with SafeArea insets
/// - Haptic feedback on tap interactions
class TickerGlassShell extends StatelessWidget {
  const TickerGlassShell({
    super.key,
    required this.child,
    this.accent = TickerPalette.gold,
    this.luminescenceColor = TickerPalette.cyanEther,
    this.backgroundColor = TickerPalette.obsidianVoid,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.margin,
    this.radius = 999,
    this.blurSigma = 14.0,
    this.borderWidth = 1.0,
    this.applySafeArea = false,
    this.safeAreaMinimum = EdgeInsets.zero,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.safeAreaLeft = true,
    this.safeAreaRight = true,
    this.enableHaptics = true,
    this.onTap,
  });

  final Widget child;
  final Color accent;
  final Color luminescenceColor;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double blurSigma;
  final double borderWidth;
  final bool applySafeArea;
  final EdgeInsets safeAreaMinimum;
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final bool safeAreaLeft;
  final bool safeAreaRight;
  final bool enableHaptics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    final Widget ribbonContainer = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.82),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            backgroundColor.withValues(alpha: 0.90),
            const Color(0xFF101726).withValues(alpha: 0.76),
            backgroundColor.withValues(alpha: 0.92),
          ],
          stops: const <double>[0.0, 0.52, 1.0],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: luminescenceColor.withValues(alpha: 0.40),
          width: borderWidth,
        ),
        boxShadow: <BoxShadow>[
          // Cyan ether border luminescence aura
          BoxShadow(
            color: luminescenceColor.withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: -1,
          ),
          // Celestial / accent glow
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 16,
            spreadRadius: -2,
          ),
          // Abyssal obsidian depth drop shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    Widget shell = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: ribbonContainer,
      ),
    );

    if (onTap != null) {
      shell = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (enableHaptics) {
              HapticFeedback.lightImpact();
            }
            onTap?.call();
          },
          borderRadius: borderRadius,
          splashColor: luminescenceColor.withValues(alpha: 0.16),
          highlightColor: accent.withValues(alpha: 0.08),
          child: shell,
        ),
      );
    }

    if (margin != null) {
      shell = Padding(
        padding: margin!,
        child: shell,
      );
    }

    if (applySafeArea) {
      shell = SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        left: safeAreaLeft,
        right: safeAreaRight,
        minimum: safeAreaMinimum,
        child: shell,
      );
    }

    return shell;
  }
}

/// Standalone 2027 Aion 2 obsidian-glass ribbon pill notification bar.
class TickerRibbonPill extends StatelessWidget {
  const TickerRibbonPill({
    super.key,
    required this.message,
    this.badgeText,
    this.icon,
    this.accent = TickerPalette.celestialGold,
    this.luminescenceColor = TickerPalette.cyanEther,
    this.onTap,
    this.onDismiss,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.applySafeArea = true,
  });

  final String message;
  final String? badgeText;
  final Widget? icon;
  final Color accent;
  final Color luminescenceColor;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final EdgeInsetsGeometry margin;
  final bool applySafeArea;

  @override
  Widget build(BuildContext context) {
    return TickerGlassShell(
      accent: accent,
      luminescenceColor: luminescenceColor,
      margin: margin,
      applySafeArea: applySafeArea,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            icon!,
            const SizedBox(width: 8),
          ],
          if (badgeText != null && badgeText!.isNotEmpty) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accent.withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              child: Text(
                badgeText!.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TickerPalette.textHi,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (onDismiss != null) ...<Widget>[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onDismiss?.call();
              },
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: TickerPalette.textMid.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 2027 Aion 2 category filter chip with obsidian frosted background and cyan ether glow.
class TickerTypeChip extends StatelessWidget {
  const TickerTypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = TickerPalette.gold,
    this.luminescenceColor = TickerPalette.cyanEther,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Color luminescenceColor;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onTap();
      },
      selectedColor: accent.withValues(alpha: 0.22),
      checkmarkColor: accent,
      labelStyle: TextStyle(
        color: selected ? TickerPalette.textHi : TickerPalette.textMid,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
        letterSpacing: selected ? 0.3 : 0.1,
      ),
      side: BorderSide(
        color: selected
            ? accent.withValues(alpha: 0.75)
            : luminescenceColor.withValues(alpha: 0.24),
        width: selected ? 1.2 : 0.9,
      ),
      backgroundColor: TickerPalette.obsidianVoid.withValues(alpha: 0.70),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// 2027 Aion 2 Bento notification card with obsidian frosted glass and celestial badges.
class TickerBentoCard extends StatelessWidget {
  const TickerBentoCard({
    super.key,
    required this.text,
    required this.visual,
    this.createdAt,
    this.onTap,
    this.applySafeArea = false,
    this.margin,
  });

  final String text;
  final LiveTickerVisual visual;
  final DateTime? createdAt;
  final VoidCallback? onTap;
  final bool applySafeArea;
  final EdgeInsetsGeometry? margin;

  String _timeAgo(DateTime? at) {
    if (at == null) return '';
    final Duration d = DateTime.now().difference(at.toLocal());
    if (d.inMinutes < 1) return 'Az önce';
    if (d.inHours < 1) return '${d.inMinutes} dk';
    if (d.inDays < 1) return '${d.inHours} sa';
    if (d.inDays < 7) return '${d.inDays} g';
    return '${at.day}.${at.month}';
  }

  @override
  Widget build(BuildContext context) {
    return TickerGlassShell(
      accent: visual.accent,
      luminescenceColor: visual.secondaryAccent,
      radius: 16,
      padding: const EdgeInsets.all(14),
      margin: margin,
      applySafeArea: applySafeArea,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Icon container with frosted obsidian background & accent border
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TickerPalette.obsidianVoid.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: visual.accent.withValues(alpha: 0.45),
                width: 1.1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: visual.accent.withValues(alpha: 0.20),
                  blurRadius: 10,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Text(
              visual.icon,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    // Celestial gold/accent badge pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: visual.badgeAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: visual.badgeAccent.withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        visual.label.toUpperCase(),
                        style: TextStyle(
                          color: visual.badgeAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (createdAt != null)
                      Text(
                        _timeAgo(createdAt),
                        style: const TextStyle(
                          color: TickerPalette.textMid,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: TickerPalette.textHi,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.38,
                    letterSpacing: 0.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension LiveTickerItemVisual on LiveTickerItem {
  LiveTickerVisual get visual => LiveTickerVisual.forType(type);
}
