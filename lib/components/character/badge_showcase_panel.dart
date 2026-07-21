import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/item_icon_view.dart';
import '../layout/game_screen_background.dart';

/// Rozet vitrini — envanterdeki cosmetic itemları (ör. Veteran Badge) gösterir.
/// Kozmetik yoksa hiç render edilmez.
class BadgeShowcasePanel extends ConsumerWidget {
  const BadgeShowcasePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<InventoryItem> badges = ref
        .watch(inventoryProvider)
        .items
        .where((InventoryItem item) =>
            item.itemType == ItemType.cosmetic ||
            item.itemId.startsWith('badge_'))
        .toList(growable: false);

    if (badges.isEmpty) return const SizedBox.shrink();

    return DottedPanel(
      borderColor: AppColors.accentPurple.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '🏅 Rozet Vitrini',
            style: AppTextStyles.titleBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges
                .map((InventoryItem badge) => _BadgeTile(badge: badge))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final InventoryItem badge;

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
                  itemType: badge.itemType,
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
