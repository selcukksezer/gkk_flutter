import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/item_model.dart';
import '../../models/player_badge_model.dart';
import '../../providers/player_badges_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/item_icon_view.dart';
import '../layout/game_screen_background.dart';

/// Rozet vitrini — kazanılan rozetler (player_badges), envanterden bağımsız.
/// Varsayılan: son 4. "Tümünü gör" → aşağı expand.
class BadgeShowcasePanel extends ConsumerStatefulWidget {
  const BadgeShowcasePanel({super.key});

  @override
  ConsumerState<BadgeShowcasePanel> createState() => _BadgeShowcasePanelState();
}

class _BadgeShowcasePanelState extends ConsumerState<BadgeShowcasePanel> {
  static const int _previewCount = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final PlayerBadgesState badgeState = ref.watch(playerBadgesProvider);
    final List<PlayerBadge> badges = badgeState.badges;

    if (badgeState.isLoading && badges.isEmpty) {
      return const SizedBox.shrink();
    }
    if (badges.isEmpty) return const SizedBox.shrink();

    final bool canExpand = badges.length > _previewCount;
    final List<PlayerBadge> visible = (!_expanded && canExpand)
        ? badges.take(_previewCount).toList(growable: false)
        : badges;

    return DottedPanel(
      borderColor: AppColors.accentPurple.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '🏅 Rozet Vitrini',
                  style: AppTextStyles.titleBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${badges.length}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visible
                  .map((PlayerBadge badge) => _BadgeTile(badge: badge))
                  .toList(growable: false),
            ),
          ),
          if (canExpand) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPurple,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _expanded ? 'Daralt' : 'Tümünü gör',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accentPurple,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.accentPurple,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final PlayerBadge badge;

  static String? _seasonLabel(String itemId) {
    final RegExp match = RegExp(r'^badge_season_(\d+)$');
    final RegExpMatch? found = match.firstMatch(itemId);
    if (found == null) return null;
    final int season = int.tryParse(found.group(1) ?? '') ?? 0;
    if (season <= 0) return null;
    return 'S$season';
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityC = getRarityColor(badge.rarity);
    final String? seasonLabel = _seasonLabel(badge.itemId);
    return Tooltip(
      message: badge.name,
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: rarityC.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rarityC.withValues(alpha: 0.45)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: rarityC.withValues(alpha: 0.15),
              blurRadius: 10,
              spreadRadius: -3,
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                ItemIconView(
                  iconValue: badge.icon,
                  itemId: badge.itemId,
                  itemType: ItemType.cosmetic,
                  size: 40,
                  fallback: '🏅',
                ),
                if (seasonLabel != null)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.spaceNavy,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: rarityC.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        seasonLabel,
                        style: AppTextStyles.micro.copyWith(
                          color: rarityC,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              badge.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.micro.copyWith(
                color: rarityC,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
