import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../models/leaderboard_model.dart';
import '../../../shaders/social/theme/social_theme_tokens.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

export 'leaderboard_header_banner.dart';
export 'leaderboard_podium.dart';
export 'leaderboard_rank_card.dart';
export 'leaderboard_sticky_footer.dart';

abstract final class LeaderboardDesign {
  static const Color gold = AppColors.liquidGold;
  static const Color silver = AppColors.mutedTitanium;
  static const Color bronze = AppColors.coralFlare;

  static Color accentForCategory(String key) {
    switch (key) {
      case 'gold':
        return AppColors.liquidGold;
      case 'pvp_rating':
        return AppColors.mysticRuby;
      case 'level':
        return AppColors.accentPurple;
      case 'guild_power':
        return AppColors.accentCyan;
      case 'dungeon':
      case 'dungeon_siege':
        return SocialThemeTokens.balaurFlame;
      default:
        return AppColors.toxicNeon;
    }
  }

  static String initials(String username) {
    final String trimmed = username.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }
}

class LeaderboardGlassPanel extends StatelessWidget {
  const LeaderboardGlassPanel({
    super.key,
    required this.child,
    this.accent = AppColors.liquidGold,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.glow = false,
  });

  final Widget child;
  final Color accent;
  final EdgeInsets padding;
  final double radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.bgCard.withValues(alpha: 0.82),
                AppColors.bgSurface.withValues(alpha: 0.72),
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: glow ? 0.55 : 0.28),
              width: glow ? 1.4 : 1,
            ),
            boxShadow: glow
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : <BoxShadow>[
                    BoxShadow(
                      color: AppColors.carbonVoid.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class LeaderboardHeaderStrip extends StatelessWidget {
  const LeaderboardHeaderStrip({
    super.key,
    required this.category,
    required this.weekly,
    required this.totalEntries,
    required this.onRefresh,
    this.isLoading = false,
  });

  final LeaderboardCategory category;
  final bool weekly;
  final int totalEntries;
  final VoidCallback? onRefresh;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final Color accent = LeaderboardDesign.accentForCategory(category.key);

    return LeaderboardGlassPanel(
      accent: accent,
      glow: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent.withValues(alpha: 0.35),
                  accent.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            alignment: Alignment.center,
            child: Text(category.icon, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${category.label} Sıralaması',
                  style: AppTextStyles.h3.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  weekly ? 'Haftalık • $totalEntries oyuncu' : 'Tüm zamanlar • $totalEntries oyuncu',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isLoading ? null : onRefresh,
            tooltip: 'Yenile',
            icon: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent.withValues(alpha: 0.8),
                    ),
                  )
                : Icon(Icons.refresh_rounded, color: accent.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class LeaderboardCategoryStrip extends StatelessWidget {
  const LeaderboardCategoryStrip({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.enabled = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: leaderboardCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final LeaderboardCategory category = leaderboardCategories[index];
          final bool selected = selectedIndex == index;
          final Color accent = LeaderboardDesign.accentForCategory(category.key);

          return GestureDetector(
            onTap: enabled ? () => onSelected(index) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 68,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          accent.withValues(alpha: 0.28),
                          accent.withValues(alpha: 0.10),
                        ],
                      )
                    : null,
                color: selected ? null : AppColors.bgCard.withValues(alpha: 0.45),
                border: Border.all(
                  color: selected ? accent.withValues(alpha: 0.65) : AppColors.borderFaint,
                ),
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.16),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(category.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class LeaderboardTimeSegment extends StatelessWidget {
  const LeaderboardTimeSegment({
    super.key,
    required this.allTimeLabel,
    required this.weeklyLabel,
    required this.weekly,
    required this.onAllTime,
    required this.onWeekly,
    this.enabled = true,
  });

  final String allTimeLabel;
  final String weeklyLabel;
  final bool weekly;
  final VoidCallback? onAllTime;
  final VoidCallback? onWeekly;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LeaderboardGlassPanel(
      padding: const EdgeInsets.all(4),
      radius: 16,
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SegmentChip(
              label: allTimeLabel,
              selected: !weekly,
              onTap: enabled ? onAllTime : null,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentChip(
              label: weeklyLabel,
              selected: weekly,
              onTap: enabled ? onWeekly : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected
              ? const LinearGradient(
                  colors: <Color>[AppColors.toxicNeon, Color(0xFF0A8A42)],
                )
              : null,
          color: selected ? null : Colors.transparent,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.carbonVoid : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class LeaderboardSearchField extends StatelessWidget {
  const LeaderboardSearchField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return LeaderboardGlassPanel(
      padding: EdgeInsets.zero,
      radius: 16,
      child: TextField(
        controller: controller,
        style: AppTextStyles.body.copyWith(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, TextEditingValue value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textSecondary,
                onPressed: () => controller.clear(),
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        ),
      ),
    );
  }
}

// Note: LeaderboardHeroPodium, MetallicTierEmblem, and CelestialAuraPainter
// are exported from 'leaderboard_podium.dart'.
// LeaderboardRankRow is exported from 'leaderboard_rank_card.dart'.



class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.initials,
    required this.accent,
    required this.size,
    this.ring = false,
  });

  final String initials;
  final Color accent;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.35),
            accent.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: ring ? 0.75 : 0.4),
          width: ring ? 2 : 1,
        ),
        boxShadow: ring
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Text(
        initials,
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
    );
  }
}

class LeaderboardPlayerCard extends StatelessWidget {
  const LeaderboardPlayerCard({
    super.key,
    required this.username,
    required this.subtitle,
    required this.valueLabel,
    required this.rankLabel,
    required this.categoryKey,
  });

  final String username;
  final String subtitle;
  final String valueLabel;
  final String rankLabel;
  final String categoryKey;

  @override
  Widget build(BuildContext context) {
    final Color accent = LeaderboardDesign.accentForCategory(categoryKey);

    return LeaderboardGlassPanel(
      accent: AppColors.accentBlue,
      glow: true,
      child: Row(
        children: <Widget>[
          _AvatarBadge(
            initials: LeaderboardDesign.initials(username),
            accent: AppColors.accentBlue,
            size: 42,
            ring: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'SEN',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentBlue,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _ValueChip(label: valueLabel, accent: accent),
              const SizedBox(height: 4),
              Text(
                rankLabel,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LeaderboardSectionLabel extends StatelessWidget {
  const LeaderboardSectionLabel({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.title.copyWith(fontSize: 14)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LeaderboardErrorPanel extends StatelessWidget {
  const LeaderboardErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LeaderboardGlassPanel(
          accent: AppColors.mysticRuby,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.leaderboard_rounded, color: AppColors.textSecondary, size: 48),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.liquidGold,
                  foregroundColor: AppColors.carbonVoid,
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Yeniden Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LeaderboardEmptySearch extends StatelessWidget {
  const LeaderboardEmptySearch({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          '"$query" için sonuç bulunamadı',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
