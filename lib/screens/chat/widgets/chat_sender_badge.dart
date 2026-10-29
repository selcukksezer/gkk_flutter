import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../chat_design_system.dart';
import '../chat_models.dart';

/// Micro-gradients, specular borders, and luxury lighting tokens for chat sender badges.
abstract final class _BadgeMetals {
  static const Color obsidianCore = Color(0xFF090D15);
  static const Color obsidianGlass = Color(0xEB0C111C);

  // Celestial Gold (VIP high-tier, Guild Master, Elyos solar light)
  static const LinearGradient goldSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF2A1F08), Color(0xFF140F04)],
  );
  static const LinearGradient goldBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFF2A8),
      Color(0xFFFFC72C),
      Color(0xFF8A5B08),
      Color(0xFFFFDF6D),
    ],
  );
  static const List<BoxShadow> goldGlow = <BoxShadow>[
    BoxShadow(color: Color(0x4DF5C842), blurRadius: 6, spreadRadius: 0.5),
  ];

  // Abyssal Violet (Asmodian shadow, Officers, Epic tier)
  static const LinearGradient violetSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF200F2E), Color(0xFF0F0717)],
  );
  static const LinearGradient violetBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFF0ABFC),
      Color(0xFFA855F7),
      Color(0xFF581C87),
      Color(0xFFD8B4FE),
    ],
  );
  static const List<BoxShadow> violetGlow = <BoxShadow>[
    BoxShadow(color: Color(0x4DA855F7), blurRadius: 6, spreadRadius: 0.5),
  ];

  // Mythic Prismatic Crimson (Level 65+, VIP Max, Divine rank)
  static const LinearGradient mythicSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF2E0D17), Color(0xFF15050A)],
  );
  static const LinearGradient mythicBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFCCD5),
      Color(0xFFF43F5E),
      Color(0xFF881337),
      Color(0xFFFF8A00),
    ],
  );
  static const List<BoxShadow> mythicGlow = <BoxShadow>[
    BoxShadow(color: Color(0x59F43F5E), blurRadius: 8, spreadRadius: 1),
  ];

  // Cyber Cobalt (Veterans, Rare tier, Mana blue)
  static const LinearGradient cobaltSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF081B2B), Color(0xFF040C14)],
  );
  static const LinearGradient cobaltBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFBAE6FD),
      Color(0xFF0284C7),
      Color(0xFF082F49),
      Color(0xFF38BDF8),
    ],
  );
  static const List<BoxShadow> cobaltGlow = <BoxShadow>[
    BoxShadow(color: Color(0x4D0284C7), blurRadius: 6, spreadRadius: 0.5),
  ];

  // Emerald Verdant (Recruits, Initiates, Nature)
  static const LinearGradient emeraldSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF0A2218), Color(0xFF04110C)],
  );
  static const LinearGradient emeraldBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFA7F3D0),
      Color(0xFF10B981),
      Color(0xFF064E3B),
      Color(0xFF34D399),
    ],
  );
  static const List<BoxShadow> emeraldGlow = <BoxShadow>[
    BoxShadow(color: Color(0x4D10B981), blurRadius: 5, spreadRadius: 0.5),
  ];

  // Polished Titanium / Slate (Standard tier)
  static const LinearGradient steelSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF1A2230), Color(0xFF0D121B)],
  );
  static const LinearGradient steelBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFFFFF),
      Color(0xFF94A3B8),
      Color(0xFF334155),
      Color(0xFFCBD5E1),
    ],
  );
  static const List<BoxShadow> steelGlow = <BoxShadow>[
    BoxShadow(color: Color(0x2694A3B8), blurRadius: 4),
  ];

  // Divine GM Obsidian (Game Masters & Admins)
  static const LinearGradient gmSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF111827), Color(0xFF05070C)],
  );
  static const LinearGradient gmBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF00E5FF),
      Color(0xFFFFC72C),
      Color(0xFF007799),
      Color(0xFFFFDF6D),
    ],
  );
  static const List<BoxShadow> gmGlow = <BoxShadow>[
    BoxShadow(color: Color(0x5900E5FF), blurRadius: 8, spreadRadius: 0.8),
    BoxShadow(color: Color(0x33FFC72C), blurRadius: 4),
  ];
}

/// Class insignia badge with specialized Aion-2 colors, icon, and role.
/// Upgraded to V3 AAA Cyber-Fantasy luxury standard with metallic faceted rim,
/// crystalline inner core, and optional prestige micro-gradients.
class SenderClassInsignia extends StatelessWidget {
  const SenderClassInsignia({
    super.key,
    required this.senderClass,
    this.size = 18,
    this.showLabel = false,
    this.isVip = false,
    this.showGlow = true,
    this.onTap,
  });

  final ChatCharacterClass senderClass;
  final double size;
  final bool showLabel;
  final bool isVip;
  final bool showGlow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = senderClass.accentColor;
    final Widget iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.42),
            _BadgeMetals.obsidianCore,
          ],
          stops: const <double>[0.15, 1.0],
        ),
        border: Border.all(
          color: isVip ? const Color(0xFFFFD54F) : color.withValues(alpha: 0.75),
          width: isVip ? 1.3 : 1.0,
        ),
        boxShadow: showGlow
            ? <BoxShadow>[
                BoxShadow(
                  color: isVip ? const Color(0x66FFC72C) : color.withValues(alpha: 0.38),
                  blurRadius: isVip ? 6 : 4.5,
                  spreadRadius: isVip ? 0.8 : 0.4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          senderClass.icon,
          size: size * 0.62,
          color: isVip ? const Color(0xFFFFF7C2) : color,
        ),
      ),
    );

    final Widget badgeContent;
    if (!showLabel) {
      badgeContent = iconWidget;
    } else {
      badgeContent = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: _BadgeMetals.obsidianGlass,
          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusSm),
          border: Border.all(
            color: isVip ? const Color(0x99FFC72C) : color.withValues(alpha: 0.45),
            width: 0.9,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.16),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            iconWidget,
            const SizedBox(width: 4.5),
            Text(
              senderClass.label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: isVip ? const Color(0xFFFFE082) : color,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              '•',
              style: TextStyle(
                fontSize: 8,
                color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              senderClass.role,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
                color: ChatDesignSystem.colorTextTertiary,
              ),
            ),
          ],
        ),
      );
    }

    final Widget interactiveBadge = onTap != null
        ? GestureDetector(onTap: onTap, child: badgeContent)
        : badgeContent;

    return Tooltip(
      message: '${senderClass.label} • ${senderClass.role}',
      child: interactiveBadge,
    );
  }
}

/// Faction crest badge: Elyos (Celestial Sun/Wings), Asmodian (Shadow Abyss Claw), or Neutral (Vanguard).
/// Upgraded to V3 AAA Cyber-Fantasy luxury standard with dual-rim metallic bevels,
/// obsidian glass backing, and luminous monospaced rune stone glyphs.
class SenderFactionInsignia extends StatelessWidget {
  const SenderFactionInsignia({
    super.key,
    required this.faction,
    this.size = 16,
    this.showRune = true,
    this.compact = false,
    this.showGlow = true,
    this.onTap,
  });

  final ChatFaction faction;
  final double size;
  final bool showRune;
  final bool compact;
  final bool showGlow;
  final VoidCallback? onTap;

  LinearGradient get _surfaceGradient {
    switch (faction) {
      case ChatFaction.elyos:
        return _BadgeMetals.goldSurface;
      case ChatFaction.asmodian:
        return _BadgeMetals.violetSurface;
      case ChatFaction.neutral:
        return _BadgeMetals.cobaltSurface;
    }
  }

  Color get _runeGlowColor {
    switch (faction) {
      case ChatFaction.elyos:
        return const Color(0xFFFFD54F);
      case ChatFaction.asmodian:
        return const Color(0xFFE879F9);
      case ChatFaction.neutral:
        return const Color(0xFF38BDF8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = faction.color;
    final Color runeColor = _runeGlowColor;

    final Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 3.5 : 5.0,
        vertical: compact ? 1.0 : 2.0,
      ),
      decoration: BoxDecoration(
        gradient: _surfaceGradient,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.65),
          width: 0.9,
        ),
        boxShadow: showGlow
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 4,
                  spreadRadius: 0.3,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            faction.icon,
            size: size * 0.75,
            color: color,
          ),
          if (showRune) ...<Widget>[
            const SizedBox(width: 3.0),
            Text(
              faction.rune,
              style: TextStyle(
                fontSize: compact ? 8.0 : 9.0,
                fontWeight: FontWeight.w800,
                color: runeColor,
                fontFamily: 'monospace',
                shadows: <Shadow>[
                  Shadow(
                    color: runeColor.withValues(alpha: 0.6),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    final Widget interactiveBadge = onTap != null
        ? GestureDetector(onTap: onTap, child: badge)
        : badge;

    return Tooltip(
      message: '${faction.title} • [${faction.factionName}]',
      child: interactiveBadge,
    );
  }
}

/// Rich Level badge with metallic faceted styling, prestige color mapping, and Aion-2 glow.
/// Upgraded to V3 AAA Cyber-Fantasy luxury standard with tiered micro-gradients,
/// obsidian glass core, and prestige crest star/crown adornments.
class SenderLevelBadge extends StatelessWidget {
  const SenderLevelBadge({
    super.key,
    required this.level,
    this.compact = false,
    this.showCrown = true,
    this.onTap,
  });

  final int level;
  final bool compact;
  final bool showCrown;
  final VoidCallback? onTap;

  bool get isMaxTier => level >= 65; // Mythic / Prismatic
  bool get isLegendaryTier => level >= 50 && level < 65; // Amber Gold
  bool get isEpicTier => level >= 35 && level < 50; // Royal Violet
  bool get isRareTier => level >= 20 && level < 35; // Crystal Cyan

  Color get _tierColor {
    if (isMaxTier) return const Color(0xFFF43F5E); // Mythic Crimson
    if (isLegendaryTier) return const Color(0xFFF59E0B); // Amber Gold
    if (isEpicTier) return const Color(0xFFA855F7); // Royal Violet
    if (isRareTier) return const Color(0xFF38BDF8); // Crystal Cyan
    return const Color(0xFF94A3B8); // Slate Steel
  }

  LinearGradient get _tierSurface {
    if (isMaxTier) return _BadgeMetals.mythicSurface;
    if (isLegendaryTier) return _BadgeMetals.goldSurface;
    if (isEpicTier) return _BadgeMetals.violetSurface;
    if (isRareTier) return _BadgeMetals.cobaltSurface;
    return _BadgeMetals.steelSurface;
  }

  @override
  Widget build(BuildContext context) {
    final Color tierColor = _tierColor;

    final Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4.5 : 6.0,
        vertical: compact ? 1.0 : 1.8,
      ),
      decoration: BoxDecoration(
        gradient: _tierSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: tierColor.withValues(alpha: isMaxTier ? 0.95 : (isLegendaryTier ? 0.85 : 0.65)),
          width: isMaxTier ? 1.2 : 0.9,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tierColor.withValues(alpha: isMaxTier ? 0.45 : (isLegendaryTier ? 0.30 : 0.18)),
            blurRadius: isMaxTier ? 7 : (isLegendaryTier ? 5 : 3.5),
            spreadRadius: isMaxTier ? 0.8 : 0.2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showCrown && isMaxTier)
            Padding(
              padding: const EdgeInsets.only(right: 2.5),
              child: Icon(
                Icons.workspace_premium_rounded,
                size: compact ? 9.5 : 11,
                color: const Color(0xFFFFD54F),
              ),
            )
          else if (showCrown && isLegendaryTier)
            Padding(
              padding: const EdgeInsets.only(right: 2.0),
              child: Icon(
                Icons.star_rounded,
                size: compact ? 9.0 : 10.5,
                color: const Color(0xFFFFD54F),
              ),
            ),
          Text(
            'Lv.$level',
            style: TextStyle(
              fontSize: compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w800,
              color: isMaxTier ? const Color(0xFFFFCCD5) : tierColor,
              letterSpacing: 0.35,
              shadows: isMaxTier || isLegendaryTier
                  ? <Shadow>[
                      Shadow(
                        color: tierColor.withValues(alpha: 0.7),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );

    final Widget interactiveBadge = onTap != null
        ? GestureDetector(onTap: onTap, child: badge)
        : badge;

    return Tooltip(
      message: 'Seviye $level ${isMaxTier ? "• [Mitik Max]" : (isLegendaryTier ? "• [Efsanevi]" : "")}',
      child: interactiveBadge,
    );
  }
}

/// Compact player avatar thumbnail with class ring border, VIP/GM aura, and online status.
/// Upgraded to V3 AAA Cyber-Fantasy luxury standard with dual-rim metallic bevels,
/// toxic-neon beacon pulse, and prestige overlay crests.
class ChatAvatarThumbnail extends StatelessWidget {
  const ChatAvatarThumbnail({
    super.key,
    this.avatarUrl,
    this.senderClass,
    this.isOnline,
    this.size = 32,
    this.onTap,
    this.vipTier,
    this.isGm = false,
    this.guildRole,
  });

  final String? avatarUrl;
  final ChatCharacterClass? senderClass;
  final bool? isOnline;
  final double size;
  final VoidCallback? onTap;
  final int? vipTier;
  final bool isGm;
  final ChatGuildRole? guildRole;

  @override
  Widget build(BuildContext context) {
    final Color classColor = senderClass?.accentColor ?? const Color(0xFF38BDF8);
    final bool isHighVip = vipTier != null && vipTier! >= 7;

    final Widget avatarContent = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Avatar Ring Core
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                isGm
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
                    : (isHighVip
                        ? const Color(0xFFFFC72C).withValues(alpha: 0.35)
                        : classColor.withValues(alpha: 0.30)),
                _BadgeMetals.obsidianCore,
              ],
              stops: const <double>[0.2, 1.0],
            ),
            border: Border.all(
              color: isGm
                  ? const Color(0xFF00E5FF)
                  : (isHighVip
                      ? const Color(0xFFFFD54F)
                      : classColor.withValues(alpha: 0.8)),
              width: (isGm || isHighVip) ? 1.4 : 1.1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: isGm
                    ? const Color(0x6600E5FF)
                    : (isHighVip
                        ? const Color(0x59FFC72C)
                        : classColor.withValues(alpha: 0.28)),
                blurRadius: (isGm || isHighVip) ? 7 : 5,
                spreadRadius: (isGm || isHighVip) ? 0.8 : 0.2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipOval(
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                        _buildFallback(classColor),
                  )
                : _buildFallback(classColor),
          ),
        ),

        // Online Status Beacon (Bottom-Right)
        if (isOnline != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline!
                    ? const Color(0xFF00FF66)
                    : const Color(0xFF64748B),
                border: Border.all(
                  color: _BadgeMetals.obsidianCore,
                  width: 1.5,
                ),
                boxShadow: isOnline!
                    ? <BoxShadow>[
                        const BoxShadow(
                          color: Color(0x9900FF66),
                          blurRadius: 5,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
            ),
          ),

        // Prestige Notch Overlay (Top-Right)
        if (isGm)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: _BadgeMetals.obsidianCore,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00E5FF), width: 1),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x6600E5FF), blurRadius: 4),
                ],
              ),
              child: const Icon(
                Icons.security_rounded,
                size: 8,
                color: Color(0xFFFFD54F),
              ),
            ),
          )
        else if (vipTier != null)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: _BadgeMetals.obsidianCore,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isHighVip ? const Color(0xFFFFC72C) : const Color(0xFF94A3B8),
                  width: 1,
                ),
                boxShadow: isHighVip
                    ? const <BoxShadow>[
                        BoxShadow(color: Color(0x66FFC72C), blurRadius: 4),
                      ]
                    : null,
              ),
              child: Icon(
                isHighVip ? Icons.workspace_premium_rounded : Icons.star_rounded,
                size: 8,
                color: isHighVip ? const Color(0xFFFFD54F) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarContent,
      );
    }
    return avatarContent;
  }

  Widget _buildFallback(Color classColor) {
    return Center(
      child: Icon(
        senderClass?.icon ?? Icons.person_rounded,
        size: size * 0.55,
        color: classColor.withValues(alpha: 0.95),
      ),
    );
  }
}

/// VIP prestige crest badge with micro-gradients, crisp typography, and tier color mapping.
/// Supports VIP 1 to VIP 10+ (Mythic Prismatic Crown).
class VipCrestBadge extends StatelessWidget {
  const VipCrestBadge({
    super.key,
    required this.vipTier,
    this.compact = false,
    this.showLabel = true,
    this.onTap,
  });

  final int vipTier;
  final bool compact;
  final bool showLabel;
  final VoidCallback? onTap;

  bool get isMaxTier => vipTier >= 10;
  bool get isGoldTier => vipTier >= 7 && vipTier < 10;
  bool get isSilverTier => vipTier >= 4 && vipTier < 7;
  bool get isBronzeTier => vipTier < 4;

  LinearGradient get _surfaceGradient {
    if (isMaxTier) return _BadgeMetals.mythicSurface;
    if (isGoldTier) return _BadgeMetals.goldSurface;
    if (isSilverTier) return _BadgeMetals.steelSurface;
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF2E1A0C), Color(0xFF160D05)],
    );
  }

  Color get _borderColor {
    if (isMaxTier) return const Color(0xFFF43F5E);
    if (isGoldTier) return const Color(0xFFFFC72C);
    if (isSilverTier) return const Color(0xFFCBD5E1);
    return const Color(0xFFD97706);
  }

  Color get _textColor {
    if (isMaxTier) return const Color(0xFFFFCCD5);
    if (isGoldTier) return const Color(0xFFFFE082);
    if (isSilverTier) return const Color(0xFFF1F5F9);
    return const Color(0xFFFDE68A);
  }

  List<BoxShadow> get _boxShadow {
    if (isMaxTier) return _BadgeMetals.mythicGlow;
    if (isGoldTier) return _BadgeMetals.goldGlow;
    if (isSilverTier) return _BadgeMetals.steelGlow;
    return const <BoxShadow>[
      BoxShadow(color: Color(0x33D97706), blurRadius: 4),
    ];
  }

  IconData get _crestIcon {
    if (isMaxTier) return Icons.workspace_premium_rounded;
    if (isGoldTier) return Icons.stars_rounded;
    if (isSilverTier) return Icons.star_rounded;
    return Icons.shield_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4.0 : 6.0,
        vertical: compact ? 1.0 : 1.8,
      ),
      decoration: BoxDecoration(
        gradient: _surfaceGradient,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _borderColor,
          width: isMaxTier ? 1.2 : 0.9,
        ),
        boxShadow: <BoxShadow>[
          ..._boxShadow,
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            _crestIcon,
            size: compact ? 9.5 : 11,
            color: _borderColor,
          ),
          if (showLabel) ...<Widget>[
            const SizedBox(width: 3),
            Text(
              isMaxTier ? 'VIP MAX' : 'VIP $vipTier',
              style: TextStyle(
                fontSize: compact ? 8.5 : 9.5,
                fontWeight: FontWeight.w900,
                color: _textColor,
                letterSpacing: 0.35,
                shadows: <Shadow>[
                  Shadow(
                    color: _borderColor.withValues(alpha: 0.6),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    final Widget interactiveBadge = onTap != null
        ? GestureDetector(onTap: onTap, child: badge)
        : badge;

    return Tooltip(
      message: 'VIP Seviye $vipTier ${isMaxTier ? "[Mitik Ayrıcalık]" : "[Ayrıcalıklı Üye]"}',
      child: interactiveBadge,
    );
  }
}

/// Official Game Master / Admin prestige authority badge.
/// Features divine obsidian black backing, solar gold & cyber cyan dual specular rim,
/// and radiant bloom lighting.
class GmBadge extends StatelessWidget {
  const GmBadge({
    super.key,
    this.roleTitle = 'GM',
    this.compact = false,
    this.onTap,
  });

  final String roleTitle;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5.0 : 7.0,
        vertical: compact ? 1.2 : 2.0,
      ),
      decoration: BoxDecoration(
        gradient: _BadgeMetals.gmSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF00E5FF),
          width: 1.1,
        ),
        boxShadow: <BoxShadow>[
          ..._BadgeMetals.gmGlow,
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.security_rounded,
            size: compact ? 9.5 : 11.5,
            color: const Color(0xFFFFD54F),
          ),
          const SizedBox(width: 3.5),
          Text(
            roleTitle.toUpperCase(),
            style: TextStyle(
              fontSize: compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFFFF2A8),
              letterSpacing: 0.6,
              shadows: const <Shadow>[
                Shadow(
                  color: Color(0x9900E5FF),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final Widget interactiveBadge = onTap != null
        ? GestureDetector(onTap: onTap, child: badge)
        : badge;

    return Tooltip(
      message: 'Yetkili Oyun Yöneticisi [$roleTitle]',
      child: interactiveBadge,
    );
  }
}

/// Guild hierarchy roles for cyber-fantasy social identity.
enum ChatGuildRole {
  guildMaster,
  officer,
  veteran,
  recruit,
}

/// Extension mapping metadata, colors, and Elder runes for guild roles.
extension ChatGuildRoleX on ChatGuildRole {
  String get label {
    switch (this) {
      case ChatGuildRole.guildMaster:
        return 'Lonca Lideri';
      case ChatGuildRole.officer:
        return 'Subay';
      case ChatGuildRole.veteran:
        return 'Kıdemli';
      case ChatGuildRole.recruit:
        return 'Çaylak';
    }
  }

  String get englishLabel {
    switch (this) {
      case ChatGuildRole.guildMaster:
        return 'Guild Master';
      case ChatGuildRole.officer:
        return 'Officer';
      case ChatGuildRole.veteran:
        return 'Veteran';
      case ChatGuildRole.recruit:
        return 'Recruit';
    }
  }

  String get tag {
    switch (this) {
      case ChatGuildRole.guildMaster:
        return '[LİDER]';
      case ChatGuildRole.officer:
        return '[SUBAY]';
      case ChatGuildRole.veteran:
        return '[KIDEMLİ]';
      case ChatGuildRole.recruit:
        return '[ÇAYLAK]';
    }
  }

  Color get primaryColor {
    switch (this) {
      case ChatGuildRole.guildMaster:
        return const Color(0xFFF59E0B);
      case ChatGuildRole.officer:
        return const Color(0xFFA855F7);
      case ChatGuildRole.veteran:
        return const Color(0xFF0284C7);
      case ChatGuildRole.recruit:
        return const Color(0xFF10B981);
    }
  }

  LinearGradient get surfaceGradient {
    switch (this) {
      case ChatGuildRole.guildMaster:
        return _BadgeMetals.goldSurface;
      case ChatGuildRole.officer:
        return _BadgeMetals.violetSurface;
      case ChatGuildRole.veteran:
        return _BadgeMetals.cobaltSurface;
      case ChatGuildRole.recruit:
        return _BadgeMetals.emeraldSurface;
    }
  }

  List<BoxShadow> get glowShadow {
    switch (this) {
      case ChatGuildRole.guildMaster:
        return _BadgeMetals.goldGlow;
      case ChatGuildRole.officer:
        return _BadgeMetals.violetGlow;
      case ChatGuildRole.veteran:
        return _BadgeMetals.cobaltGlow;
      case ChatGuildRole.recruit:
        return _BadgeMetals.emeraldGlow;
    }
  }

  IconData get icon {
    switch (this) {
      case ChatGuildRole.guildMaster:
        return Icons.military_tech_rounded;
      case ChatGuildRole.officer:
        return Icons.shield_rounded;
      case ChatGuildRole.veteran:
        return Icons.star_half_rounded;
      case ChatGuildRole.recruit:
        return Icons.nature_people_rounded;
    }
  }

  /// Elder Futhark rune representing the role's fantasy authority.
  String get rune {
    switch (this) {
      case ChatGuildRole.guildMaster:
        return 'ᚠ'; // Fehu (Wealth/Sovereignty)
      case ChatGuildRole.officer:
        return 'ᚦ'; // Thurisaz (Martial Force)
      case ChatGuildRole.veteran:
        return 'ᚱ'; // Raidho (Proven Journey)
      case ChatGuildRole.recruit:
        return 'ᛚ'; // Laguz (Budding Flow/Initiate)
    }
  }

  static ChatGuildRole? fromKey(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase().trim()) {
      case 'guildmaster':
      case 'guild_master':
      case 'master':
      case 'leader':
      case 'lider':
      case 'baskan':
      case 'kurucu':
        return ChatGuildRole.guildMaster;
      case 'officer':
      case 'subay':
      case 'yetkili':
      case 'commander':
        return ChatGuildRole.officer;
      case 'veteran':
      case 'kidemli':
      case 'kıdemli':
      case 'elite':
        return ChatGuildRole.veteran;
      case 'recruit':
      case 'caylak':
      case 'çaylak':
      case 'member':
      case 'uye':
      case 'üye':
        return ChatGuildRole.recruit;
      default:
        return null;
    }
  }
}

/// Cyber-Fantasy Guild Role Badge with metallic rune styling and hierarchy tags.
class GuildRoleBadge extends StatelessWidget {
  const GuildRoleBadge({
    super.key,
    required this.role,
    this.compact = false,
    this.showIcon = true,
    this.showRune = false,
    this.onTap,
  });

  final ChatGuildRole role;
  final bool compact;
  final bool showIcon;
  final bool showRune;
  final VoidCallback? onTap;

  /// Tolerant factory constructor parsing string role keys.
  factory GuildRoleBadge.fromKey(
    String? roleKey, {
    Key? key,
    bool compact = false,
    bool showIcon = true,
    bool showRune = false,
    VoidCallback? onTap,
  }) {
    final ChatGuildRole? parsed = ChatGuildRoleX.fromKey(roleKey);
    return GuildRoleBadge(
      key: key,
      role: parsed ?? ChatGuildRole.recruit,
      compact: compact,
      showIcon: showIcon,
      showRune: showRune,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color color = role.primaryColor;

    final Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4.5 : 6.0,
        vertical: compact ? 1.0 : 1.8,
      ),
      decoration: BoxDecoration(
        gradient: role.surfaceGradient,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.8),
          width: 0.9,
        ),
        boxShadow: <BoxShadow>[
          ...role.glowShadow,
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showIcon) ...<Widget>[
            Icon(
              role.icon,
              size: compact ? 9.5 : 11,
              color: color,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            role.label,
            style: TextStyle(
              fontSize: compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          if (showRune) ...<Widget>[
            const SizedBox(width: 3.5),
            Text(
              role.rune,
              style: TextStyle(
                fontSize: compact ? 8.5 : 9.5,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.85),
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );

    final Widget interactiveBadge = onTap != null
        ? GestureDetector(onTap: onTap, child: badge)
        : badge;

    return Tooltip(
      message: 'Lonca Rolü: ${role.label} [${role.englishLabel}]',
      child: interactiveBadge,
    );
  }
}

/// Generic Metallic Rune Border Badge with custom Elder rune glyph and bevel styling.
class MetallicRuneBadge extends StatelessWidget {
  const MetallicRuneBadge({
    super.key,
    required this.rune,
    required this.label,
    this.color = const Color(0xFFF59E0B),
    this.secondaryColor,
    this.icon,
    this.size = 18,
    this.compact = false,
    this.onTap,
    this.tooltip,
  });

  final String rune;
  final String label;
  final Color color;
  final Color? secondaryColor;
  final IconData? icon;
  final double size;
  final bool compact;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4.0 : 6.0,
        vertical: compact ? 1.0 : 2.0,
      ),
      decoration: BoxDecoration(
        color: _BadgeMetals.obsidianGlass,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.75),
          width: 0.9,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 4,
            spreadRadius: 0.3,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: compact ? 9.5 : 11,
              color: color,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            rune,
            style: TextStyle(
              fontSize: compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: 'monospace',
              shadows: <Shadow>[
                Shadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          if (label.isNotEmpty) ...<Widget>[
            const SizedBox(width: 3.5),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 8.5 : 9.5,
                fontWeight: FontWeight.w700,
                color: secondaryColor ?? ChatDesignSystem.colorTextSecondary,
                letterSpacing: 0.25,
              ),
            ),
          ],
        ],
      ),
    );

    final Widget interactiveBadge = onTap != null
        ? GestureDetector(onTap: onTap, child: badge)
        : badge;

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: interactiveBadge);
    }
    return interactiveBadge;
  }
}

/// Unified composite widget bringing together all active sender badges
/// with luxury layout, consistent spacing, and hierarchy.
class SenderBadgeCluster extends StatelessWidget {
  const SenderBadgeCluster({
    super.key,
    this.senderClass,
    this.faction,
    this.level,
    this.guildRole,
    this.vipTier,
    this.isGm = false,
    this.staffBadge,
    this.kingBadge,
    this.compact = true,
    this.spacing = 4.0,
  });

  final ChatCharacterClass? senderClass;
  final ChatFaction? faction;
  final int? level;
  final ChatGuildRole? guildRole;
  final int? vipTier;
  final bool isGm;
  final String? staffBadge;
  final String? kingBadge;
  final bool compact;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final bool effectiveGm = isGm ||
        staffBadge?.toLowerCase() == 'gm' ||
        staffBadge?.toLowerCase() == 'admin';

    final int? effectiveVip = vipTier ?? (kingBadge != null ? 10 : null);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing,
      runSpacing: 2.0,
      children: <Widget>[
        // 1. GM Authority Badge
        if (effectiveGm)
          GmBadge(
            roleTitle: staffBadge ?? 'GM',
            compact: compact,
          ),

        // 2. VIP Crest Badge
        if (effectiveVip != null)
          VipCrestBadge(
            vipTier: effectiveVip,
            compact: compact,
          ),

        // 3. Guild Role Badge
        if (guildRole != null)
          GuildRoleBadge(
            role: guildRole!,
            compact: compact,
          ),

        // 4. Faction Crest Insignia
        if (faction != null)
          SenderFactionInsignia(
            faction: faction!,
            size: compact ? 14 : 16,
            compact: compact,
          ),

        // 5. Class Insignia
        if (senderClass != null)
          SenderClassInsignia(
            senderClass: senderClass!,
            size: compact ? 15 : 18,
          ),

        // 6. Level Badge
        if (level != null)
          SenderLevelBadge(
            level: level!,
            compact: compact,
          ),
      ],
    );
  }
}
