import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../models/leaderboard_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

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

class LeaderboardHeroPodium extends StatelessWidget {
  const LeaderboardHeroPodium({
    super.key,
    required this.entries,
    required this.categoryKey,
    this.dimmed = false,
  });

  final List<LeaderboardEntry> entries;
  final String categoryKey;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 3) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: dimmed ? 0.5 : 1,
      child: LeaderboardGlassPanel(
        accent: LeaderboardDesign.gold,
        glow: !dimmed,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          children: <Widget>[
            Text(
              'İlk 3',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 210,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(child: _PodiumSlot(entry: entries[1], medal: '🥈', accent: LeaderboardDesign.silver, flex: 4, categoryKey: categoryKey)),
                  const SizedBox(width: 8),
                  Expanded(child: _PodiumSlot(entry: entries[0], medal: '🥇', accent: LeaderboardDesign.gold, flex: 5, categoryKey: categoryKey, highlight: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _PodiumSlot(entry: entries[2], medal: '🥉', accent: LeaderboardDesign.bronze, flex: 3, categoryKey: categoryKey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.medal,
    required this.accent,
    required this.flex,
    required this.categoryKey,
    this.highlight = false,
  });

  final LeaderboardEntry entry;
  final String medal;
  final Color accent;
  final int flex;
  final String categoryKey;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (highlight)
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text('👑', style: TextStyle(fontSize: 16)),
          ),
        _AvatarBadge(
          initials: LeaderboardDesign.initials(entry.username),
          accent: accent,
          size: highlight ? 44 : 36,
          ring: highlight,
        ),
        const SizedBox(height: 6),
        Text(
          entry.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(medal, style: TextStyle(fontSize: highlight ? 24 : 20)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Text(
            LeaderboardValueFormatter.format(entry.value, categoryKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: flex,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  accent.withValues(alpha: highlight ? 0.45 : 0.28),
                  accent.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              boxShadow: highlight
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, -2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: AppTextStyles.h2.copyWith(
                fontSize: highlight ? 28 : 22,
                color: accent.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LeaderboardRankRow extends StatelessWidget {
  const LeaderboardRankRow({
    super.key,
    required this.entry,
    required this.categoryKey,
    this.highlight = false,
  });

  final LeaderboardEntry entry;
  final String categoryKey;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color accent = LeaderboardDesign.accentForCategory(categoryKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: <Color>[
            highlight
                ? AppColors.accentBlue.withValues(alpha: 0.16)
                : AppColors.bgCard.withValues(alpha: 0.55),
            AppColors.bgSurface.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(
          color: highlight
              ? AppColors.accentBlue.withValues(alpha: 0.45)
              : AppColors.borderFaint,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            _RankBadge(rank: entry.rank, accent: accent),
            const SizedBox(width: 10),
            _AvatarBadge(
              initials: LeaderboardDesign.initials(entry.username),
              accent: accent,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title.copyWith(fontSize: 14),
                  ),
                  if (entry.guild != null && entry.guild!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      '🏰 ${entry.guild}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ValueChip(
              label: LeaderboardValueFormatter.format(entry.value, categoryKey),
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.accent});

  final int rank;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        '#$rank',
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w900,
          color: accent,
          fontSize: 10,
        ),
      ),
    );
  }
}

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
                label: const Text('Tekrar Dene'),
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
          '"$query" için sonuç yok',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
