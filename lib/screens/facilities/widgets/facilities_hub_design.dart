import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';
import 'facilities_ui.dart';

/// Tesis hub — /tasarim: dot doku, Carbon Void / Space Navy, Liquid Gold vurgu.
abstract final class FacHubDesign {
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFD64A), AppColors.liquidGold, Color(0xFFE08A00)],
  );
}

/// Şüphe + rüşvet paneli — altın gradient kenarlık.
class FacSuspicionPanel extends StatelessWidget {
  const FacSuspicionPanel({
    super.key,
    required this.activeCount,
    required this.globalSuspicion,
    required this.suspicionCap,
    required this.bribeGemCost,
    required this.bribeDisabled,
    required this.onBribe,
  });

  final int activeCount;
  final int globalSuspicion;
  final int suspicionCap;
  final int bribeGemCost;
  final bool bribeDisabled;
  final VoidCallback onBribe;

  @override
  Widget build(BuildContext context) {
    final Color suspicionColor = _suspicionColor(globalSuspicion);
    final double progress = suspicionCap > 0
        ? (globalSuspicion / suspicionCap).clamp(0.0, 1.0)
        : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: FacilitiesUi.gap),
      child: DottedPanel(
        borderColor: suspicionColor.withValues(alpha: 0.35),
        borderRadius: 14,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('🕵️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Genel Şüphe',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '%$globalSuspicion',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: suspicionColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: AppColors.darkObsidian,
                valueColor: AlwaysStoppedAnimation<Color>(suspicionColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    globalSuspicion <= 0 ? 'Şüphe yok — güvenli bölge' : 'Baskın riski artıyor',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedTitanium,
                    ),
                  ),
                ),
                SizedBox(
                  height: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: bribeDisabled ? null : FacHubDesign.goldGradient,
                      color: bribeDisabled
                          ? AppColors.mutedTitanium.withValues(alpha: 0.25)
                          : null,
                      boxShadow: bribeDisabled
                          ? null
                          : <BoxShadow>[
                              BoxShadow(
                                color: AppColors.liquidGold.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: bribeDisabled ? null : onBribe,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (bribeDisabled) ...<Widget>[
                                const Icon(
                                  Icons.lock_rounded,
                                  size: 13,
                                  color: AppColors.mutedTitanium,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                '💎 Rüşvet ($bribeGemCost)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: bribeDisabled
                                      ? AppColors.mutedTitanium
                                      : AppColors.carbonVoid,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$activeCount/15 tesis açık',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedTitanium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FacPrisonBanner extends StatelessWidget {
  const FacPrisonBanner({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FacilitiesUi.gap),
      child: DottedPanel(
        borderColor: AppColors.mysticRuby.withValues(alpha: 0.45),
        borderRadius: 12,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('👮', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Cezaevi — operasyonlar kilitli',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedTitanium,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _suspicionColor(int value) {
  if (value >= 80) return AppColors.coralFlare;
  if (value >= 50) return AppColors.warningSolar;
  return AppColors.toxicNeon;
}
