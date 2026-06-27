import 'package:flutter/material.dart';

import '../../../models/mekan_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

class MekanTypeVisual {
  const MekanTypeVisual({
    required this.icon,
    required this.accent,
    required this.label,
  });

  final IconData icon;
  final Color accent;
  final String label;

  static MekanTypeVisual forKey(String? key) {
    switch (key) {
      case 'bar':
        return const MekanTypeVisual(
          icon: Icons.local_bar_rounded,
          accent: AppColors.accentCyan,
          label: 'Bar',
        );
      case 'kahvehane':
        return const MekanTypeVisual(
          icon: Icons.coffee_rounded,
          accent: AppColors.warning,
          label: 'Kahvehane',
        );
      case 'dovus_kulubu':
        return const MekanTypeVisual(
          icon: Icons.sports_mma_rounded,
          accent: AppColors.danger,
          label: 'Dövüş Kulübü',
        );
      case 'luks_lounge':
        return const MekanTypeVisual(
          icon: Icons.diamond_rounded,
          accent: AppColors.liquidGold,
          label: 'Lüks Lounge',
        );
      case 'yeralti':
        return const MekanTypeVisual(
          icon: Icons.nightlight_round,
          accent: AppColors.textSecondary,
          label: 'Yeraltı',
        );
      default:
        return const MekanTypeVisual(
          icon: Icons.storefront_rounded,
          accent: AppColors.gold,
          label: 'Mekan',
        );
    }
  }
}

class MekanTypeInfo {
  const MekanTypeInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.cost,
    required this.reqLevel,
  });

  final String type;
  final String name;
  final String description;
  final int cost;
  final int reqLevel;

  MekanTypeVisual get visual => MekanTypeVisual.forKey(type);

  static const List<MekanTypeInfo> all = <MekanTypeInfo>[
    MekanTypeInfo(type: 'bar', name: 'Bar', description: 'İksir ticareti ve sosyal ortam', cost: 5000000, reqLevel: 15),
    MekanTypeInfo(type: 'kahvehane', name: 'Kahvehane', description: 'Buff iksirleri ve detox', cost: 8000000, reqLevel: 20),
    MekanTypeInfo(type: 'dovus_kulubu', name: 'Dövüş Kulübü', description: 'PvP arena ve şöhret', cost: 15000000, reqLevel: 30),
    MekanTypeInfo(type: 'luks_lounge', name: 'Lüks Lounge', description: 'VIP müşteri + PvP', cost: 50000000, reqLevel: 45),
    MekanTypeInfo(type: 'yeralti', name: 'Yeraltı', description: 'Kaçak ticaret, yüksek risk', cost: 200000000, reqLevel: 60),
  ];

  static MekanTypeInfo? byKey(String? key) {
    if (key == null) return null;
    for (final MekanTypeInfo info in all) {
      if (info.type == key) return info;
    }
    return null;
  }
}

String mekanTypeLabel(MekanType type) {
  switch (type) {
    case MekanType.bar:
      return 'Bar';
    case MekanType.kahvehane:
      return 'Kahvehane';
    case MekanType.dovusKulubu:
      return 'Dövüş Kulübü';
    case MekanType.luksLounge:
      return 'Lüks Lounge';
    case MekanType.yeralti:
      return 'Yeraltı';
  }
}

String mekanTypeLabelKey(String? key) => MekanTypeInfo.byKey(key)?.name ?? key ?? '';

bool mekanSupportsPvp(String? typeKey) =>
    typeKey == 'dovus_kulubu' || typeKey == 'luks_lounge' || typeKey == 'yeralti';

bool isMekanStockEligible({required bool isHanOnly, required String? itemType}) =>
    isHanOnly || (itemType ?? '').toLowerCase() == 'potion';

String formatMekanGold(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
  return '$value';
}

/// Mirror of the backend `mekan_price_band` (PLAN_07 sections 4.2 + 5.2).
/// Used for client-side hints; the RPC is authoritative.
class MekanPriceBand {
  const MekanPriceBand(this.min, this.max);
  final int min;
  final int max;
}

const Map<String, MekanPriceBand> _mekanPriceBands = <String, MekanPriceBand>{
  'potion_health_minor': MekanPriceBand(7500, 25000),
  'potion_health_major': MekanPriceBand(150000, 500000),
  'potion_health_supreme': MekanPriceBand(300000, 1000000),
  'potion_energy_minor': MekanPriceBand(7500, 50000),
  'potion_energy_major': MekanPriceBand(50000, 300000),
  'potion_energy_supreme': MekanPriceBand(150000, 1000000),
  'potion_attack_buff': MekanPriceBand(300000, 1000000),
  'potion_defense_buff': MekanPriceBand(300000, 1000000),
  'potion_luck_buff': MekanPriceBand(750000, 2500000),
  'potion_xp_buff': MekanPriceBand(300000, 1500000),
  'detox_minor': MekanPriceBand(75000, 250000),
  'detox_major': MekanPriceBand(300000, 1000000),
  'detox_supreme': MekanPriceBand(750000, 2500000),
  'han_item_vigor_minor': MekanPriceBand(80000, 200000),
  'han_item_vigor_major': MekanPriceBand(300000, 800000),
  'han_item_elixir_purge': MekanPriceBand(150000, 400000),
  'han_item_clarity': MekanPriceBand(700000, 2000000),
  'han_item_berserk': MekanPriceBand(1500000, 5000000),
  'han_item_shadow_brew': MekanPriceBand(1200000, 3500000),
  'han_item_restoration': MekanPriceBand(1200000, 3500000),
};

MekanPriceBand? mekanPriceBand(String itemId) => _mekanPriceBands[itemId];

bool mekanItemIsContraband(String itemId) =>
    itemId == 'han_item_berserk' || itemId == 'han_item_shadow_brew';

class MekanScreenBackground extends StatelessWidget {
  const MekanScreenBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.bgDeep, AppColors.bgBase, AppColors.bgDeep],
        ),
      ),
      child: child,
    );
  }
}

class MekanPanel extends StatelessWidget {
  const MekanPanel({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: AppColors.bgCard.withValues(alpha: 0.88),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: AppColors.borderDefault.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (accent != null)
            Container(height: 3, color: accent),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class MekanSectionHeader extends StatelessWidget {
  const MekanSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class MekanStatChip extends StatelessWidget {
  const MekanStatChip({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class MekanStatusBadge extends StatelessWidget {
  const MekanStatusBadge({super.key, required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final Color color = isOpen ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(isOpen ? Icons.circle : Icons.circle_outlined, size: 8, color: color),
          const SizedBox(width: 4),
          Text(
            isOpen ? 'Açık' : 'Kapalı',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class MekanTypeAvatar extends StatelessWidget {
  const MekanTypeAvatar({
    super.key,
    required this.typeKey,
    this.size = 44,
  });

  final String? typeKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final MekanTypeVisual visual = MekanTypeVisual.forKey(typeKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: visual.accent.withValues(alpha: 0.16),
        border: Border.all(color: visual.accent.withValues(alpha: 0.45)),
      ),
      child: Icon(visual.icon, color: visual.accent, size: size * 0.48),
    );
  }
}

class MekanEmptyState extends StatelessWidget {
  const MekanEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.base),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
