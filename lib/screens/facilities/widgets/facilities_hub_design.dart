import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import 'facilities_ui.dart';

/// Aion-2 Tesis Hub — Frosted Glass, Liquid Gold & Celestial Cyan Accents.
abstract final class FacHubDesign {
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFDF70),
      AppColors.liquidGold,
      Color(0xFFE08A00),
    ],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF80F7FF),
      Color(0xFF00E5FF),
      Color(0xFF0099B8),
    ],
  );

  static const LinearGradient rubyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFF6666),
      AppColors.mysticRuby,
      Color(0xFF8B0000),
    ],
  );
}

/// Şüphe + Rüşvet Paneli — Aion-2 Frosted Glass & Luminous Accent.
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
      child: FacGlassPanel(
        borderColor: suspicionColor.withValues(alpha: 0.38),
        glowColor: suspicionColor.withValues(alpha: 0.14),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: suspicionColor.withValues(alpha: 0.15),
                    border: Border.all(
                      color: suspicionColor.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🕵️', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'GENEL ŞÜPHE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: suspicionColor.withValues(alpha: 0.16),
                    border: Border.all(
                      color: suspicionColor.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '%$globalSuspicion',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: suspicionColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Luminous Suspicion Gauge
            Stack(
              children: <Widget>[
                Container(
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.darkObsidian.withValues(alpha: 0.7),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: <Color>[
                          suspicionColor.withValues(alpha: 0.6),
                          suspicionColor,
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: suspicionColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    globalSuspicion <= 0
                        ? 'Güvenli Bölge • Baskın Riski Yok'
                        : 'Baskın Riski Artıyor! Dikkatli Ol',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: globalSuspicion <= 0
                          ? AppColors.toxicNeon.withValues(alpha: 0.85)
                          : AppColors.warningSolar.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                SizedBox(
                  height: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: bribeDisabled ? null : FacHubDesign.goldGradient,
                      color: bribeDisabled
                          ? AppColors.mutedTitanium.withValues(alpha: 0.18)
                          : null,
                      boxShadow: bribeDisabled
                          ? null
                          : <BoxShadow>[
                              BoxShadow(
                                color: AppColors.liquidGold.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: bribeDisabled
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                onBribe();
                              },
                        borderRadius: BorderRadius.circular(9),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                              ] else ...<Widget>[
                                const Text('💎', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                'Rüşvet ($bribeGemCost Gem)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '$activeCount/15 Tesis Aktif Çalışıyor',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedTitanium,
                  ),
                ),
                Text(
                  'Maks Sınır: %$suspicionCap',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedTitanium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cezaevi Banner — Dark Ruby Frosted Glass.
class FacPrisonBanner extends StatelessWidget {
  const FacPrisonBanner({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FacilitiesUi.gap),
      child: FacGlassPanel(
        borderColor: AppColors.mysticRuby.withValues(alpha: 0.6),
        glowColor: AppColors.mysticRuby.withValues(alpha: 0.25),
        backgroundColor: const Color(0x99180709),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mysticRuby.withValues(alpha: 0.2),
                border: Border.all(
                  color: AppColors.mysticRuby.withValues(alpha: 0.6),
                  width: 1.4,
                ),
              ),
              alignment: Alignment.center,
              child: const Text('👮', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'CEZAEVİ — OPERASYONLAR KİLİTLİ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      color: AppColors.mysticRuby,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kefalet ödeyerek serbest kalabilir ve tesisleri yönetmeye devam edebilirsiniz.',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.mutedTitanium,
                      height: 1.25,
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
