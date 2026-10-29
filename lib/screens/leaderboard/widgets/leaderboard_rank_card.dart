import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/services/app_haptics.dart';
import '../../../models/leaderboard_model.dart';
import '../../../shaders/social/theme/social_theme_tokens.dart';
import '../../../theme/app_colors.dart';
import 'leaderboard_design.dart';

/// 2027 Aion 2 V3 AAA Cyber-Fantasy Iridescent Glassmorphic Rank Card.
///
/// Features authentic celestial aether frosted glass, metallic tier badges (#1-#100+),
/// Daeva avatar frames, class crests, Combat Power (CP) score badges,
/// guild affiliation crest heraldry, local player ("SEN") signature glow,
/// and interactive Daeva profile inspection with tactile [AppHaptics].
class LeaderboardRankRow extends StatelessWidget {
  const LeaderboardRankRow({
    super.key,
    required this.entry,
    required this.categoryKey,
    this.highlight = false,
    this.characterClass,
    this.customValueLabel,
    this.margin,
    this.showClassCrest = true,
    this.showGuildCrest = true,
    this.showPowerScore = true,
    this.onTap,
    this.onInspectProfile,
  });

  final LeaderboardEntry entry;
  final String categoryKey;
  final bool highlight;
  final String? characterClass;
  final String? customValueLabel;
  final EdgeInsetsGeometry? margin;
  final bool showClassCrest;
  final bool showGuildCrest;
  final bool showPowerScore;
  final VoidCallback? onTap;
  final ValueChanged<LeaderboardEntry>? onInspectProfile;

  @override
  Widget build(BuildContext context) {
    final Color categoryAccent = LeaderboardDesign.accentForCategory(categoryKey);
    final String resolvedClass = (characterClass != null && characterClass!.isNotEmpty)
        ? characterClass!
        : LeaderboardClassCrest.resolveClass(entry.username, entry.level, categoryKey);

    final LeaderboardCardTierStyle tierStyle = LeaderboardCardTierStyle.resolve(
      rank: entry.rank,
      isHighlight: highlight,
      categoryAccent: categoryAccent,
    );

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Iridescent chromatic and metallic tier border reflection
        gradient: tierStyle.borderGradient,
        boxShadow: tierStyle.boxShadow,
      ),
      child: Container(
        margin: const EdgeInsets.all(1.2), // Micro border reveal
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.8),
          gradient: tierStyle.backgroundGradient,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleTap(context, resolvedClass),
                borderRadius: BorderRadius.circular(14.8),
                splashColor: (highlight ? SocialThemeTokens.aetherCyan : categoryAccent).withValues(alpha: 0.18),
                highlightColor: (highlight ? SocialThemeTokens.aetherCyan : categoryAccent).withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: <Widget>[
                      // 1. Metallic Rank Badge (Tiered #1 through #100+)
                      _buildRankBadge(tierStyle),
                      const SizedBox(width: 10),
                      // 2. Avatar Frame with Daeva Ring & Level Pill
                      _buildAvatarFrame(categoryAccent, tierStyle),
                      const SizedBox(width: 12),
                      // 3. Player Info Column (Name, "SEN" tag, Guild Crest, Class Crest, CP)
                      Expanded(
                        child: _buildPlayerInfo(categoryAccent, resolvedClass),
                      ),
                      const SizedBox(width: 10),
                      // 4. Value / Stat Chip with Jewel Style
                      _buildValueChip(categoryAccent),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, String resolvedClass) {
    if (highlight || entry.rank <= 10) {
      unawaited(AppHaptics.medium());
    } else {
      unawaited(AppHaptics.selection());
    }

    if (onTap != null) {
      onTap!();
    } else if (onInspectProfile != null) {
      onInspectProfile!(entry);
    } else {
      LeaderboardProfileInspectionSheet.show(
        context,
        entry: entry,
        categoryKey: categoryKey,
        characterClass: resolvedClass,
        isLocalPlayer: highlight,
      );
    }
  }

  Widget _buildRankBadge(LeaderboardCardTierStyle tierStyle) {
    if (entry.rank == 1) {
      return _buildGoldRankBadge();
    }
    if (entry.rank == 2) {
      return _buildSilverRankBadge();
    }
    if (entry.rank == 3) {
      return _buildBronzeRankBadge();
    }
    if (entry.rank <= 10) {
      return _buildTopTenRankBadge();
    }
    if (entry.rank <= 25) {
      return _buildHighTemplarRankBadge();
    }
    if (entry.rank <= 50) {
      return _buildCenturionRankBadge();
    }
    if (entry.rank <= 100) {
      return _buildVeteranRankBadge();
    }
    return _buildChallengerRankBadge();
  }

  Widget _buildGoldRankBadge() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFF9C4),
            SocialThemeTokens.celestialGold,
            SocialThemeTokens.celestialGoldDark,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: SocialThemeTokens.celestialGold.withValues(alpha: 0.45),
            blurRadius: 10,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SocialThemeTokens.abyssVoid,
          border: Border.all(
            color: SocialThemeTokens.celestialGoldLight.withValues(alpha: 0.9),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          '#1',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: SocialThemeTokens.celestialGoldLight,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSilverRankBadge() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFECEFF1),
            Color(0xFF78909C),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x59B0BEC5),
            blurRadius: 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SocialThemeTokens.abyssVoid,
          border: Border.all(
            color: Color(0xFFECEFF1),
            width: 1.1,
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          '#2',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFFECEFF1),
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildBronzeRankBadge() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFCCBC),
            Color(0xFFFF8A65),
            Color(0xFF8D6E63),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x59FF7043),
            blurRadius: 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SocialThemeTokens.abyssVoid,
          border: Border.all(
            color: Color(0xFFFFCCBC),
            width: 1.1,
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          '#3',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFCCBC),
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildTopTenRankBadge() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SocialThemeTokens.aetherCyanLight,
            SocialThemeTokens.daevaPrismViolet,
            SocialThemeTokens.aetherCyanDark,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x6600E5FF),
            blurRadius: 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SocialThemeTokens.abyssVoid,
          border: Border.all(
            color: SocialThemeTokens.aetherCyanLight,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '#${entry.rank}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: SocialThemeTokens.aetherCyanLight,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildHighTemplarRankBadge() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFCE93D8),
            SocialThemeTokens.daevaPrismViolet,
            Color(0xFF4A148C),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x4D7C4DFF),
            blurRadius: 6,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.5),
          color: SocialThemeTokens.abyssVoid,
          border: Border.all(
            color: const Color(0xFFCE93D8).withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '#${entry.rank}',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFFE1BEE7),
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildCenturionRankBadge() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF90CAF9),
            Color(0xFF1E88E5),
            Color(0xFF0D47A1),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x331E88E5),
            blurRadius: 6,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.5),
          color: SocialThemeTokens.abyssVoid,
          border: Border.all(
            color: const Color(0xFF90CAF9).withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '#${entry.rank}',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFFBBDEFB),
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildVeteranRankBadge() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFB0BEC5),
            Color(0xFF78909C),
            Color(0xFF37474F),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.5),
          color: SocialThemeTokens.abyssCardSurface.withValues(alpha: 0.85),
          border: Border.all(
            color: const Color(0xFFCFD8DC).withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '#${entry.rank}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFFECEFF1),
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildChallengerRankBadge() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: SocialThemeTokens.abyssCardSurface.withValues(alpha: 0.7),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.9,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '#${entry.rank}',
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: AppColors.mutedTitanium,
        ),
      ),
    );
  }

  Widget _buildAvatarFrame(Color accent, LeaderboardCardTierStyle tierStyle) {
    final bool isRank1 = entry.rank == 1;
    final bool isRank2 = entry.rank == 2;
    final bool isRank3 = entry.rank == 3;
    final bool isTopTen = entry.rank <= 10;

    final Color ringColor = highlight
        ? SocialThemeTokens.aetherCyan
        : isRank1
            ? SocialThemeTokens.celestialGold
            : isRank2
                ? const Color(0xFFECEFF1)
                : isRank3
                    ? const Color(0xFFFF8A65)
                    : isTopTen
                        ? SocialThemeTokens.aetherCyan.withValues(alpha: 0.85)
                        : accent.withValues(alpha: 0.65);

    final double ringWidth = highlight
        ? 2.0
        : (isRank1 || isRank2 || isRank3 || isTopTen)
            ? 1.5
            : 1.2;

    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          // Circular Avatar with Glowing Edge & Subtle Radial Shading
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  ringColor.withValues(alpha: 0.35),
                  SocialThemeTokens.abyssVoid,
                ],
              ),
              border: Border.all(
                color: ringColor,
                width: ringWidth,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: ringColor.withValues(alpha: highlight ? 0.45 : 0.28),
                  blurRadius: highlight ? 10 : 8,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(entry.username),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: highlight
                    ? SocialThemeTokens.aetherCyanLight
                    : isRank1
                        ? SocialThemeTokens.celestialGoldLight
                        : isRank2
                            ? const Color(0xFFECEFF1)
                            : isRank3
                                ? const Color(0xFFFFCCBC)
                                : AppColors.textPrimary,
              ),
            ),
          ),
          // Level Pill Overlay
          Positioned(
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: SocialThemeTokens.abyssVoid,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (isRank1 ? SocialThemeTokens.celestialGold : ringColor)
                      .withValues(alpha: 0.7),
                  width: 0.8,
                ),
              ),
              child: Text(
                'Lv.${entry.level}',
                style: const TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  color: SocialThemeTokens.celestialGoldLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(Color accent, String resolvedClass) {
    final Color classColor = LeaderboardClassCrest.getColor(resolvedClass);
    final IconData classIcon = LeaderboardClassCrest.getIcon(resolvedClass);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        // Row 1: Username + "SEN" pill if local player + Class Crest
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                entry.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: highlight
                      ? SocialThemeTokens.aetherCyanLight
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (highlight) ...<Widget>[
              const SizedBox(width: 6),
              _buildLocalPlayerBadge(),
            ],
            if (showClassCrest) ...<Widget>[
              const SizedBox(width: 6),
              _buildClassCrestBadge(resolvedClass, classColor, classIcon),
            ],
          ],
        ),
        const SizedBox(height: 3.5),
        // Row 2: Guild Affiliation Crest + Power Score (CP)
        Row(
          children: <Widget>[
            if (showGuildCrest)
              Flexible(
                child: GuildAffiliationCrest(
                  guildName: entry.guild,
                  rank: entry.rank,
                ),
              ),
            if (showPowerScore) ...<Widget>[
              const SizedBox(width: 6),
              CombatPowerBadge(
                value: entry.value,
                rank: entry.rank,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLocalPlayerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            SocialThemeTokens.aetherCyan,
            SocialThemeTokens.aetherBlue,
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: SocialThemeTokens.aetherCyan.withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(
            Icons.person_rounded,
            size: 8.5,
            color: SocialThemeTokens.abyssVoid,
          ),
          SizedBox(width: 2),
          Text(
            'SEN',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: SocialThemeTokens.abyssVoid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCrestBadge(String resolvedClass, Color classColor, IconData classIcon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
      decoration: BoxDecoration(
        color: classColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: classColor.withValues(alpha: 0.5),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            classIcon,
            size: 9,
            color: classColor,
          ),
          const SizedBox(width: 2.5),
          Text(
            resolvedClass,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: classColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueChip(Color accent) {
    final String formattedValue = customValueLabel ??
        LeaderboardValueFormatter.format(entry.value, categoryKey);

    return Container(
      constraints: const BoxConstraints(minWidth: 70, maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: SocialThemeTokens.abyssVoid.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accent.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            formattedValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          Text(
            'Seviye ${entry.level}',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String username) {
    final String trimmed = username.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }
}

/// Alias for LeaderboardRankRow providing design token and card semantic parity.
typedef LeaderboardRankCard = LeaderboardRankRow;

/// Daeva class crest resolver and visual styling metadata.
abstract final class LeaderboardClassCrest {
  static const List<String> defaultClasses = <String>[
    'Gladiator',
    'Templar',
    'Sorcerer',
    'Spiritmaster',
    'Assassin',
    'Ranger',
    'Cleric',
    'Chanter',
  ];

  static String resolveClass(String username, int level, String categoryKey) {
    if (username.trim().isEmpty) return 'Gladiator';
    final int hash = username.codeUnits.fold(0, (int prev, int elem) => prev + elem) + level;
    return defaultClasses[hash.abs() % defaultClasses.length];
  }

  static IconData getIcon(String className) {
    final String cls = className.toLowerCase();
    if (cls.contains('gladiator') || cls.contains('savaş') || cls.contains('warrior')) {
      return Icons.shield_rounded;
    }
    if (cls.contains('templar') || cls.contains('muhafız')) {
      return Icons.security_rounded;
    }
    if (cls.contains('sorcerer') || cls.contains('büyü') || cls.contains('mage')) {
      return Icons.auto_awesome_rounded;
    }
    if (cls.contains('spiritmaster') || cls.contains('ruh')) {
      return Icons.all_inclusive_rounded;
    }
    if (cls.contains('assassin') || cls.contains('suikast') || cls.contains('gölge')) {
      return Icons.flash_on_rounded;
    }
    if (cls.contains('ranger') || cls.contains('okçu')) {
      return Icons.track_changes_rounded;
    }
    if (cls.contains('cleric') || cls.contains('şifa') || cls.contains('ruhban')) {
      return Icons.health_and_safety_rounded;
    }
    if (cls.contains('chanter') || cls.contains('ozan')) {
      return Icons.flare_rounded;
    }
    return Icons.military_tech_rounded;
  }

  static Color getColor(String className) {
    final String cls = className.toLowerCase();
    if (cls.contains('gladiator') || cls.contains('savaş') || cls.contains('warrior')) {
      return const Color(0xFFFF3D00); // Balaur Flame / Crimson
    }
    if (cls.contains('templar') || cls.contains('muhafız')) {
      return SocialThemeTokens.celestialGold;
    }
    if (cls.contains('sorcerer') || cls.contains('büyü') || cls.contains('mage')) {
      return SocialThemeTokens.daevaPrismViolet;
    }
    if (cls.contains('spiritmaster') || cls.contains('ruh')) {
      return const Color(0xFF1DE9B6); // Ethereal Teal
    }
    if (cls.contains('assassin') || cls.contains('suikast') || cls.contains('gölge')) {
      return const Color(0xFFAB47BC); // Asmodian Violet
    }
    if (cls.contains('ranger') || cls.contains('okçu')) {
      return SocialThemeTokens.aetherCyan;
    }
    if (cls.contains('cleric') || cls.contains('şifa') || cls.contains('ruhban')) {
      return const Color(0xFFFFB300); // Solar Amber
    }
    if (cls.contains('chanter') || cls.contains('ozan')) {
      return SocialThemeTokens.aetherBlue;
    }
    return SocialThemeTokens.aetherCyanLight;
  }

  static String getTitle(String className, int level) {
    if (level >= 85) return 'Efsanevi $className';
    if (level >= 75) return 'Kıdemli Daeva • $className';
    if (level >= 60) return 'Seçkin Daeva • $className';
    return 'Yükselen $className';
  }

  static String getPowerTier(int value) {
    if (value >= 10000) return 'SSS-Tier Daeva';
    if (value >= 5000) return 'SS-Tier Daeva';
    if (value >= 3000) return 'S-Tier Daeva';
    if (value >= 1500) return 'A-Tier Daeva';
    return 'B-Tier Daeva';
  }

  static String getClassSpecialty(String className) {
    final String cls = className.toLowerCase();
    if (cls.contains('gladiator') || cls.contains('savaş') || cls.contains('warrior')) {
      return 'Ağır Zırhlı Çift El Hücum ve Alan Hasarı';
    }
    if (cls.contains('templar') || cls.contains('muhafız')) {
      return 'Kalkan Savunması ve Kutsal Koruma Duvarı';
    }
    if (cls.contains('sorcerer') || cls.contains('büyü') || cls.contains('mage')) {
      return 'Kadim Aether ve Yıkıcı Element Büyüleri';
    }
    if (cls.contains('spiritmaster') || cls.contains('ruh')) {
      return 'Element Ruhları Çağırma ve Zayıflatma Lanetleri';
    }
    if (cls.contains('assassin') || cls.contains('suikast') || cls.contains('gölge')) {
      return 'Görünmezlik, Kritik Zehir ve Hızlı İnfaz';
    }
    if (cls.contains('ranger') || cls.contains('okçu')) {
      return 'Uzun Menzilli Keskin Nişancılık ve Aether Tuzakları';
    }
    if (cls.contains('cleric') || cls.contains('şifa') || cls.contains('ruhban')) {
      return 'Grup Şifası, Diriltme ve Kutsal Işık Koruması';
    }
    if (cls.contains('chanter') || cls.contains('ozan')) {
      return 'Savaş Mantraları, Hız Auraları ve Asa Dövüşü';
    }
    return 'Dengeli Daeva Muharip Disiplini';
  }
}

/// Tier-aware visual theme metadata resolver for rank row cards.
class LeaderboardCardTierStyle {
  const LeaderboardCardTierStyle({
    required this.borderGradient,
    required this.backgroundGradient,
    required this.boxShadow,
    required this.badgeBorderColor,
    required this.badgeTextColor,
  });

  final Gradient borderGradient;
  final Gradient backgroundGradient;
  final List<BoxShadow> boxShadow;
  final Color badgeBorderColor;
  final Color badgeTextColor;

  static LeaderboardCardTierStyle resolve({
    required int rank,
    required bool isHighlight,
    required Color categoryAccent,
  }) {
    if (isHighlight) {
      return LeaderboardCardTierStyle(
        borderGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SocialThemeTokens.aetherCyanLight,
            SocialThemeTokens.aetherCyan,
            SocialThemeTokens.daevaPrismViolet,
            SocialThemeTokens.celestialGold,
            SocialThemeTokens.aetherCyanLight,
          ],
        ),
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SocialThemeTokens.abyssCardHighlight.withValues(alpha: 0.98),
            SocialThemeTokens.abyssCard.withValues(alpha: 0.94),
            SocialThemeTokens.abyssVoid.withValues(alpha: 0.92),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: SocialThemeTokens.aetherCyan.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1.5,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: SocialThemeTokens.daevaPrismViolet.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        badgeBorderColor: SocialThemeTokens.aetherCyanLight,
        badgeTextColor: SocialThemeTokens.aetherCyanLight,
      );
    }

    if (rank == 1) {
      return LeaderboardCardTierStyle(
        borderGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFF9C4),
            SocialThemeTokens.celestialGold,
            SocialThemeTokens.celestialGoldDark,
            SocialThemeTokens.celestialGold,
          ],
        ),
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SocialThemeTokens.celestialGold.withValues(alpha: 0.16),
            SocialThemeTokens.abyssCard.withValues(alpha: 0.94),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: SocialThemeTokens.celestialGold.withValues(alpha: 0.38),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        badgeBorderColor: SocialThemeTokens.celestialGoldLight,
        badgeTextColor: SocialThemeTokens.celestialGoldLight,
      );
    }

    if (rank == 2) {
      return const LeaderboardCardTierStyle(
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFECEFF1),
            Color(0xFFCFD8DC),
            Color(0xFF78909C),
          ],
        ),
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0x1FCFD8DC),
            SocialThemeTokens.abyssCard,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x59B0BEC5),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
        badgeBorderColor: Color(0xFFECEFF1),
        badgeTextColor: Color(0xFFECEFF1),
      );
    }

    if (rank == 3) {
      return const LeaderboardCardTierStyle(
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFE0B2),
            Color(0xFFFFAB91),
            Color(0xFFFF8A65),
            Color(0xFF8D6E63),
          ],
        ),
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0x40FF7043),
            SocialThemeTokens.abyssCard,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x40FF7043),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
        badgeBorderColor: Color(0xFFFFCCBC),
        badgeTextColor: Color(0xFFFFCCBC),
      );
    }

    // Ranks 4 to 10: Ascendant Vanguard
    if (rank <= 10) {
      return LeaderboardCardTierStyle(
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SocialThemeTokens.aetherCyan.withValues(alpha: 0.8),
            SocialThemeTokens.daevaPrismViolet.withValues(alpha: 0.6),
            SocialThemeTokens.celestialGold.withValues(alpha: 0.5),
            SocialThemeTokens.aetherCyan.withValues(alpha: 0.4),
          ],
        ),
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SocialThemeTokens.aetherCyan.withValues(alpha: 0.08),
            SocialThemeTokens.abyssCard.withValues(alpha: 0.92),
            SocialThemeTokens.abyssVoid.withValues(alpha: 0.94),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: SocialThemeTokens.aetherCyan.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        badgeBorderColor: SocialThemeTokens.aetherCyanLight,
        badgeTextColor: SocialThemeTokens.aetherCyanLight,
      );
    }

    // Ranks 11 to 25: High Templar
    if (rank <= 25) {
      return LeaderboardCardTierStyle(
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SocialThemeTokens.daevaPrismViolet.withValues(alpha: 0.7),
            const Color(0xFFBA68C8).withValues(alpha: 0.5),
            SocialThemeTokens.aetherCyan.withValues(alpha: 0.35),
            SocialThemeTokens.daevaPrismViolet.withValues(alpha: 0.2),
          ],
        ),
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SocialThemeTokens.daevaPrismViolet.withValues(alpha: 0.06),
            SocialThemeTokens.abyssCard.withValues(alpha: 0.90),
            SocialThemeTokens.abyssVoid.withValues(alpha: 0.94),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: SocialThemeTokens.daevaPrismViolet.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        badgeBorderColor: const Color(0xFFCE93D8),
        badgeTextColor: const Color(0xFFE1BEE7),
      );
    }

    // Ranks 26 to 50: Elite Centurion
    if (rank <= 50) {
      return LeaderboardCardTierStyle(
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF42A5F5).withValues(alpha: 0.6),
            const Color(0xFF26C6DA).withValues(alpha: 0.4),
            const Color(0xFF78909C).withValues(alpha: 0.3),
            const Color(0xFF1E88E5).withValues(alpha: 0.2),
          ],
        ),
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF1E88E5).withValues(alpha: 0.05),
            SocialThemeTokens.abyssCard.withValues(alpha: 0.88),
            SocialThemeTokens.abyssVoid.withValues(alpha: 0.94),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        badgeBorderColor: const Color(0xFF90CAF9),
        badgeTextColor: const Color(0xFFBBDEFB),
      );
    }

    // Ranks 51 to 100: Veteran Daeva
    if (rank <= 100) {
      return LeaderboardCardTierStyle(
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.22),
            categoryAccent.withValues(alpha: 0.30),
            const Color(0xFF78909C).withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SocialThemeTokens.abyssCard.withValues(alpha: 0.86),
            SocialThemeTokens.abyssVoid.withValues(alpha: 0.94),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        badgeBorderColor: const Color(0xFFB0BEC5),
        badgeTextColor: AppColors.mutedTitanium,
      );
    }

    // Ranks 101+: Challenger
    return LeaderboardCardTierStyle(
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.04),
          categoryAccent.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.06),
        ],
      ),
      backgroundGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          SocialThemeTokens.abyssCard.withValues(alpha: 0.82),
          SocialThemeTokens.abyssVoid.withValues(alpha: 0.95),
        ],
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
      badgeBorderColor: Colors.white.withValues(alpha: 0.14),
      badgeTextColor: AppColors.textTertiary,
    );
  }
}

/// 2027 Aion 2 Cyber-Fantasy Guild Affiliation Crest widget with heraldic shield & faction marker.
class GuildAffiliationCrest extends StatelessWidget {
  const GuildAffiliationCrest({
    super.key,
    required this.guildName,
    this.rank,
    this.fontSize = 10.0,
  });

  final String? guildName;
  final int? rank;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final bool hasGuild = guildName != null && guildName!.trim().isNotEmpty;
    final String resolvedGuild = hasGuild ? guildName!.trim() : 'Bağımsız Daeva';
    final Color crestColor = hasGuild ? SocialThemeTokens.celestialGold : AppColors.textTertiary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          hasGuild ? Icons.shield_rounded : Icons.explore_outlined,
          size: 11,
          color: crestColor,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            hasGuild ? '🏰 $resolvedGuild' : 'Bağımsız Daeva',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: hasGuild ? AppColors.textSecondary : AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

/// V3 AAA Cyber-Fantasy Combat Power (CP) Score Badge with Stigma Crystal Shard styling.
class CombatPowerBadge extends StatelessWidget {
  const CombatPowerBadge({
    super.key,
    required this.value,
    this.rank,
    this.fontSize = 8.5,
  });

  final int value;
  final int? rank;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final String compactCp = LeaderboardValueFormatter.compact(value);
    final bool isElite = rank != null && rank! <= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: SocialThemeTokens.abyssVoid,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isElite
              ? SocialThemeTokens.celestialGold.withValues(alpha: 0.6)
              : SocialThemeTokens.celestialAmber.withValues(alpha: 0.45),
          width: 0.8,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (isElite ? SocialThemeTokens.celestialGold : SocialThemeTokens.celestialAmber)
                .withValues(alpha: 0.15),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.bolt_rounded,
            size: 10,
            color: isElite ? SocialThemeTokens.celestialGold : SocialThemeTokens.celestialAmber,
          ),
          const SizedBox(width: 2),
          Text(
            'CP $compactCp',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: isElite ? SocialThemeTokens.celestialGoldLight : SocialThemeTokens.celestialAmber,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet for Cyber-Fantasy Daeva Profile Inspection with [AppHaptics] integration.
class LeaderboardProfileInspectionSheet extends StatelessWidget {
  const LeaderboardProfileInspectionSheet({
    super.key,
    required this.entry,
    required this.categoryKey,
    required this.characterClass,
    this.isLocalPlayer = false,
  });

  final LeaderboardEntry entry;
  final String categoryKey;
  final String characterClass;
  final bool isLocalPlayer;

  static Future<void> show(
    BuildContext context, {
    required LeaderboardEntry entry,
    required String categoryKey,
    required String characterClass,
    bool isLocalPlayer = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (BuildContext sheetContext) {
        return LeaderboardProfileInspectionSheet(
          entry: entry,
          categoryKey: categoryKey,
          characterClass: characterClass,
          isLocalPlayer: isLocalPlayer,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color categoryAccent = LeaderboardDesign.accentForCategory(categoryKey);
    final Color classColor = LeaderboardClassCrest.getColor(characterClass);
    final IconData classIcon = LeaderboardClassCrest.getIcon(characterClass);
    final String classTitle = LeaderboardClassCrest.getTitle(characterClass, entry.level);
    final String specialty = LeaderboardClassCrest.getClassSpecialty(characterClass);
    final String powerTier = LeaderboardClassCrest.getPowerTier(entry.value);
    final String compactCp = LeaderboardValueFormatter.compact(entry.value);
    final String formattedCategoryScore = LeaderboardValueFormatter.format(entry.value, categoryKey);
    final bool hasGuild = entry.guild != null && entry.guild!.trim().isNotEmpty;
    final String guildName = hasGuild ? entry.guild!.trim() : 'Bağımsız Daeva';

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLocalPlayer
                ? <Color>[
                    SocialThemeTokens.aetherCyanLight,
                    SocialThemeTokens.daevaPrismViolet,
                    SocialThemeTokens.celestialGold,
                    SocialThemeTokens.aetherCyan,
                  ]
                : <Color>[
                    SocialThemeTokens.celestialGold.withValues(alpha: 0.6),
                    categoryAccent.withValues(alpha: 0.4),
                    SocialThemeTokens.daevaPrismViolet.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 0.12),
                  ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (isLocalPlayer ? SocialThemeTokens.aetherCyan : categoryAccent).withValues(alpha: 0.3),
              blurRadius: 28,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.5),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                SocialThemeTokens.abyssCardHighlight,
                SocialThemeTokens.abyssCard,
                SocialThemeTokens.abyssVoid,
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22.5),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Drag Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sheet Title & Close Button
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: SocialThemeTokens.aetherCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: SocialThemeTokens.aetherCyan.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const <Widget>[
                              Icon(
                                Icons.verified_user_rounded,
                                size: 12,
                                color: SocialThemeTokens.aetherCyanLight,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'DAEVA KİMLİK DENETİMİ',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: SocialThemeTokens.aetherCyanLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                          onPressed: () {
                            unawaited(AppHaptics.light());
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Hero Profile Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SocialThemeTokens.abyssVoid.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (isLocalPlayer ? SocialThemeTokens.aetherCyan : categoryAccent).withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          // Big Hero Avatar Frame
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: <Color>[
                                        (isLocalPlayer ? SocialThemeTokens.aetherCyan : categoryAccent)
                                            .withValues(alpha: 0.4),
                                        SocialThemeTokens.abyssVoid,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: isLocalPlayer
                                          ? SocialThemeTokens.aetherCyan
                                          : categoryAccent,
                                      width: 2,
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: (isLocalPlayer ? SocialThemeTokens.aetherCyan : categoryAccent)
                                            .withValues(alpha: 0.35),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    entry.username.isNotEmpty ? entry.username[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: SocialThemeTokens.celestialGoldLight,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: SocialThemeTokens.abyssVoid,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: SocialThemeTokens.celestialGold,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      'Lv.${entry.level}',
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: SocialThemeTokens.celestialGoldLight,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Profile Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        entry.username,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (isLocalPlayer) ...<Widget>[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: <Color>[
                                              SocialThemeTokens.aetherCyan,
                                              SocialThemeTokens.aetherBlue,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'SEN',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                            color: SocialThemeTokens.abyssVoid,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  classTitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: classColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: <Widget>[
                                    // Rank Tag
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: SocialThemeTokens.celestialGold.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: SocialThemeTokens.celestialGold.withValues(alpha: 0.5),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        '#${entry.rank} Sırada',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: SocialThemeTokens.celestialGoldLight,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Class Tag
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: classColor.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: classColor.withValues(alpha: 0.5),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Icon(classIcon, size: 9, color: classColor),
                                          const SizedBox(width: 3),
                                          Text(
                                            characterClass,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: classColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Guild & Heraldry Dossier Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: SocialThemeTokens.abyssCardSurface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: hasGuild
                              ? SocialThemeTokens.celestialGold.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: hasGuild
                                    ? <Color>[
                                        SocialThemeTokens.celestialGold.withValues(alpha: 0.3),
                                        SocialThemeTokens.celestialAmber.withValues(alpha: 0.15),
                                      ]
                                    : <Color>[
                                        Colors.white.withValues(alpha: 0.1),
                                        Colors.white.withValues(alpha: 0.03),
                                      ],
                              ),
                              border: Border.all(
                                color: hasGuild
                                    ? SocialThemeTokens.celestialGold.withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              hasGuild ? Icons.shield_rounded : Icons.explore_outlined,
                              size: 16,
                              color: hasGuild ? SocialThemeTokens.celestialGold : AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  hasGuild ? '🏰 $guildName' : 'Bağımsız Daeva',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasGuild
                                      ? 'Lejyon Bağı • Elyos & Asmodian İttifakı'
                                      : 'Herhangi bir lejyona bağlı olmayan bağımsız savaşçı',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Combat Power & Stats Grid (2 Tiles)
                    Row(
                      children: <Widget>[
                        // Tile 1: Combat Power (CP)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: SocialThemeTokens.abyssVoid.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: SocialThemeTokens.celestialAmber.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x1AFF9100),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: const <Widget>[
                                    Icon(Icons.bolt_rounded, size: 14, color: SocialThemeTokens.celestialAmber),
                                    SizedBox(width: 4),
                                    Text(
                                      'SAVAŞ GÜCÜ',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: SocialThemeTokens.celestialAmber,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'CP $compactCp',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: SocialThemeTokens.celestialGoldLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  powerTier,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: SocialThemeTokens.celestialAmber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Tile 2: Category Rank Value
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: SocialThemeTokens.abyssVoid.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: categoryAccent.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: categoryAccent.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Icon(Icons.insights_rounded, size: 14, color: categoryAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      'KATEGORİ SKORU',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: categoryAccent,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  formattedCategoryScore,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: categoryAccent,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '#${entry.rank} Derece',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Class Combat Specialty Note
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: SocialThemeTokens.abyssCardSurface.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: classColor.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.auto_awesome_rounded, size: 13, color: classColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              specialty,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action CTAs (Fısılda, Arkadaş Ekle, Partiye Davet Et)
                    Row(
                      children: <Widget>[
                        // 1. Whisper Button
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SocialThemeTokens.aetherCyanLight,
                              side: BorderSide(
                                color: SocialThemeTokens.aetherCyan.withValues(alpha: 0.5),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                            label: const Text(
                              'Fısılda',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                            onPressed: () {
                              unawaited(AppHaptics.selection());
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${entry.username} ile fısıldaşma başlatıldı.'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 2. Add Friend Button
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SocialThemeTokens.celestialGoldLight,
                              side: BorderSide(
                                color: SocialThemeTokens.celestialGold.withValues(alpha: 0.5),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                            label: const Text(
                              'Arkadaş',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                            onPressed: () {
                              unawaited(AppHaptics.success());
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${entry.username} kullanıcısına arkadaşlık isteği gönderildi.'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 3. Party Invite Button
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: SocialThemeTokens.aetherCyanDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.group_add_rounded, size: 14),
                            label: const Text(
                              'Parti',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                            onPressed: () {
                              unawaited(AppHaptics.medium());
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${entry.username} partiye davet edildi.'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

