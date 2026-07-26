import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/kingdom_market_blessing_model.dart';
import '../../providers/kingdom_market_blessing_provider.dart';
import '../../theme/app_colors.dart';

class KingdomMarketBlessingBanner extends ConsumerWidget {
  const KingdomMarketBlessingBanner({
    super.key,
    this.locationLabel,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  final String? locationLabel;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final KingdomMarketBlessingStatus blessing = ref.watch(kingdomMarketBlessingProvider);
    if (!blessing.active) return const SizedBox.shrink();

    final String remaining = blessing.remainingLabel();

    return Padding(
      padding: margin,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.liquidGold.withValues(alpha: 0.22),
              AppColors.accentCyan.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('👑', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    blessing.bannerMessage(locationLabel: locationLabel),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (remaining.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      remaining,
                      style: TextStyle(
                        color: AppColors.liquidGold.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
