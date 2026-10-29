import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../providers/mekan_provider.dart';
import 'mekan_design.dart';
import 'mekan_theme.dart';

/// Luxury V3 leaderboard rank row with tier-based metallic accents,
/// frosted glassmorphic card styling, player avatar rings, and win rate badge pill.
class MekanArenaRankRow extends StatelessWidget {
  const MekanArenaRankRow({
    super.key,
    required this.row,
    required this.isMe,
  });

  final ArenaRankRow row;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final _RankTier tier = _resolveTier(row.rank);
    final _TierStyle style = _TierStyle.from(tier: tier, isMe: isMe);

    final int totalMatches = row.wins + row.losses;
    final double winRate = totalMatches > 0 ? (row.wins / totalMatches) * 100 : 0.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: style.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: style.backgroundGradient,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: style.borderColor,
                width: isMe ? 1.5 : (row.rank <= 3 ? 1.3 : 1.0),
              ),
            ),
            child: Row(
              children: <Widget>[
                // 1. Tier-based Rank Badge / Medallion
                _RankBadge(rank: row.rank, tier: tier, style: style),
                const SizedBox(width: 10),

                // 2. Player Avatar with Concentric Tier Ring & Level Tag
                _PlayerAvatarRing(
                  username: row.username,
                  level: row.level,
                  tier: tier,
                  isMe: isMe,
                  style: style,
                ),
                const SizedBox(width: 10),

                // 3. Player Name & Stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              row.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isMe ? MekanPalette.cyan : MekanPalette.textHi,
                                letterSpacing: 0.2,
                                shadows: isMe
                                    ? <Shadow>[
                                        Shadow(
                                          color: MekanPalette.aqua.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                          if (isMe) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: <Color>[MekanPalette.aqua, Color(0xFF007ACC)],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: MekanPalette.aqua.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'SEN',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          _WinRatePill(winRate: winRate),
                          const SizedBox(width: 6),
                          Text(
                            '${row.wins}G / ${row.losses}M',
                            style: const TextStyle(
                              fontSize: 11,
                              color: MekanPalette.textLow,
                              fontWeight: FontWeight.w600,
                              fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 4. Rating & Weekly Rewards
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: MekanPalette.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: MekanPalette.gold.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.emoji_events_rounded,
                            size: 13,
                            color: MekanPalette.gold,
                          ),
                          const SizedBox(width: 3.5),
                          Text(
                            '${row.pvpRating}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: MekanPalette.gold,
                              fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (row.weeklyReward > 0) ...<Widget>[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.monetization_on_rounded,
                            size: 10.5,
                            color: MekanPalette.neon,
                          ),
                          const SizedBox(width: 2.5),
                          Text(
                            '+${formatMekanGold(row.weeklyReward)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: MekanPalette.neon,
                              fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static _RankTier _resolveTier(int rank) {
    if (rank == 1) return _RankTier.gold;
    if (rank == 2) return _RankTier.silver;
    if (rank == 3) return _RankTier.bronze;
    if (rank <= 10) return _RankTier.obsidian;
    return _RankTier.standard;
  }
}

enum _RankTier { gold, silver, bronze, obsidian, standard }

class _TierStyle {
  const _TierStyle({
    required this.accentColor,
    required this.borderColor,
    required this.backgroundGradient,
    required this.cardShadow,
  });

  final Color accentColor;
  final Color borderColor;
  final Gradient backgroundGradient;
  final List<BoxShadow> cardShadow;

  factory _TierStyle.from({required _RankTier tier, required bool isMe}) {
    if (isMe) {
      return _TierStyle(
        accentColor: MekanPalette.aqua,
        borderColor: MekanPalette.aqua.withValues(alpha: 0.80),
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            MekanPalette.aqua.withValues(alpha: 0.20),
            MekanPalette.surfaceHi.withValues(alpha: 0.85),
            MekanPalette.void_.withValues(alpha: 0.95),
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ),
        cardShadow: <BoxShadow>[
          BoxShadow(
            color: MekanPalette.aqua.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: MekanPalette.void_.withValues(alpha: 0.70),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );
    }

    switch (tier) {
      case _RankTier.gold:
        return _TierStyle(
          accentColor: MekanPalette.gold,
          borderColor: MekanPalette.gold.withValues(alpha: 0.60),
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              MekanPalette.gold.withValues(alpha: 0.16),
              MekanPalette.surfaceHi.withValues(alpha: 0.80),
              MekanPalette.void_.withValues(alpha: 0.95),
            ],
            stops: const <double>[0.0, 0.40, 1.0],
          ),
          cardShadow: <BoxShadow>[
            BoxShadow(
              color: MekanPalette.gold.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 3),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: MekanPalette.void_.withValues(alpha: 0.60),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        );
      case _RankTier.silver:
        return _TierStyle(
          accentColor: const Color(0xFFCFD9E8),
          borderColor: const Color(0xFFCFD9E8).withValues(alpha: 0.45),
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFFCFD9E8).withValues(alpha: 0.12),
              MekanPalette.surfaceHi.withValues(alpha: 0.75),
              MekanPalette.void_.withValues(alpha: 0.95),
            ],
            stops: const <double>[0.0, 0.35, 1.0],
          ),
          cardShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFCFD9E8).withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: MekanPalette.void_.withValues(alpha: 0.60),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );
      case _RankTier.bronze:
        return _TierStyle(
          accentColor: const Color(0xFFE27D48),
          borderColor: const Color(0xFFE27D48).withValues(alpha: 0.45),
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFFE27D48).withValues(alpha: 0.12),
              MekanPalette.surfaceHi.withValues(alpha: 0.75),
              MekanPalette.void_.withValues(alpha: 0.95),
            ],
            stops: const <double>[0.0, 0.35, 1.0],
          ),
          cardShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFE27D48).withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: MekanPalette.void_.withValues(alpha: 0.60),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );
      case _RankTier.obsidian:
        return _TierStyle(
          accentColor: MekanPalette.titanium,
          borderColor: const Color(0xFF38435C),
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFF1E2740).withValues(alpha: 0.65),
              MekanPalette.void_.withValues(alpha: 0.92),
            ],
          ),
          cardShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );
      case _RankTier.standard:
        return _TierStyle(
          accentColor: MekanPalette.textLow,
          borderColor: Colors.white.withValues(alpha: 0.07),
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              MekanPalette.surface.withValues(alpha: 0.55),
              MekanPalette.void_.withValues(alpha: 0.85),
            ],
          ),
          cardShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        );
    }
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.rank,
    required this.tier,
    required this.style,
  });

  final int rank;
  final _RankTier tier;
  final _TierStyle style;

  @override
  Widget build(BuildContext context) {
    if (rank <= 3) {
      final (Gradient gradient, Color textColor, IconData icon) = switch (tier) {
        _RankTier.gold => (
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFFFEA7A), Color(0xFFFFB800), Color(0xFFC77700)],
            ),
            const Color(0xFF381E00),
            Icons.workspace_premium_rounded,
          ),
        _RankTier.silver => (
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFFFFFFF), Color(0xFFCBD6E4), Color(0xFF7A8B9E)],
            ),
            const Color(0xFF16202C),
            Icons.military_tech_rounded,
          ),
        _RankTier.bronze => (
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFFFB590), Color(0xFFE27338), Color(0xFF8F3B14)],
            ),
            const Color(0xFF2E0F04),
            Icons.shield_rounded,
          ),
        _ => (
            const LinearGradient(colors: <Color>[Colors.grey, Colors.black]),
            Colors.white,
            Icons.star,
          ),
      };

      return Container(
        width: 34,
        height: 38,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: style.accentColor.withValues(alpha: 0.40),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 13, color: textColor),
            Text(
              '$rank',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: textColor,
                height: 1.1,
                fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    final bool isElite = rank <= 10;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isElite ? const Color(0xFF1E2740) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isElite
            ? Border.all(color: const Color(0xFF3B4868), width: 0.9)
            : null,
      ),
      child: Text(
        '#$rank',
        style: TextStyle(
          fontSize: isElite ? 12 : 11.5,
          fontWeight: isElite ? FontWeight.w800 : FontWeight.w700,
          color: isElite ? MekanPalette.titanium : MekanPalette.textLow,
          fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PlayerAvatarRing extends StatelessWidget {
  const _PlayerAvatarRing({
    required this.username,
    required this.level,
    required this.tier,
    required this.isMe,
    required this.style,
  });

  final String username;
  final int level;
  final _RankTier tier;
  final bool isMe;
  final _TierStyle style;

  @override
  Widget build(BuildContext context) {
    final String initial = username.isNotEmpty ? username.characters.first.toUpperCase() : '?';

    final Color ringColor = isMe
        ? MekanPalette.aqua
        : (tier == _RankTier.gold
            ? MekanPalette.gold
            : (tier == _RankTier.silver
                ? const Color(0xFFCFD9E8)
                : (tier == _RankTier.bronze ? const Color(0xFFE27D48) : const Color(0xFF42506E))));

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          // Outer Concentric Ring
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: 1.6),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: ringColor.withValues(alpha: 0.28),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      MekanPalette.surfaceHi,
                      MekanPalette.navy,
                      MekanPalette.void_,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isMe ? MekanPalette.cyan : MekanPalette.textHi,
                    shadows: <Shadow>[
                      Shadow(
                        color: ringColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Small Level Tag at Bottom-Right
          if (level > 0)
            Positioned(
              bottom: -2,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.5),
                decoration: BoxDecoration(
                  color: MekanPalette.void_,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: ringColor.withValues(alpha: 0.75),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$level',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: ringColor,
                    fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WinRatePill extends StatelessWidget {
  const _WinRatePill({required this.winRate});

  final double winRate;

  @override
  Widget build(BuildContext context) {
    final (Color color, Color bg) = switch (winRate) {
      >= 70.0 => (MekanPalette.neon, MekanPalette.neon.withValues(alpha: 0.14)),
      >= 50.0 => (MekanPalette.aqua, MekanPalette.aqua.withValues(alpha: 0.14)),
      _ => (MekanPalette.coral, MekanPalette.coral.withValues(alpha: 0.14)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            winRate >= 50.0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2.5),
          Text(
            '%${winRate.toStringAsFixed(0)} WR',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

