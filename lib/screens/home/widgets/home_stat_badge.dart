import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/reputation_tier.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../mekans/widgets/mekan_design.dart';

enum _HomeStatBadgeKind { power, reputation }

/// Premium neon stat badge for the home hero showcase (POWER / REP).
class HomeStatBadge extends StatelessWidget {
  const HomeStatBadge.power({
    super.key,
    required this.value,
  })  : _kind = _HomeStatBadgeKind.power,
        reputation = 0;

  const HomeStatBadge.reputation({
    super.key,
    required this.reputation,
  })  : _kind = _HomeStatBadgeKind.reputation,
        value = null;

  final _HomeStatBadgeKind _kind;
  final String? value;
  final int reputation;

  static String _compact(int v) {
    if (v >= 1000000000) {
      return '${(v / 1000000000).toStringAsFixed(1)}B';
    }
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    switch (_kind) {
      case _HomeStatBadgeKind.power:
        return _NeonStatBadgeShell(
          label: 'POWER',
          accent: AppColors.cyberFuchsia,
          accentSecondary: AppColors.mysticRuby,
          value: value ?? '0',
          onTap: null,
        );
      case _HomeStatBadgeKind.reputation:
        final int rep = reputation.clamp(0, 999999999);
        final ReputationTier tier = reputationTierFor(rep);
        final ReputationTierProgress progress = reputationTierProgressFor(rep);
        final int pct = (progress.progress * 100).round().clamp(0, 100);
        return _NeonStatBadgeShell(
          label: 'REP',
          accent: AppColors.accentPurple,
          accentSecondary: AppColors.accentPurpleDim,
          value: _compact(rep),
          subtitle: tier.title,
          subtitleColor: tier.color,
          progress: progress.progress,
          progressLabel: pct >= 100 ? 'MAX' : '$pct%',
          onTap: () => context.push(AppRoutes.reputation),
        );
    }
  }
}

class _NeonStatBadgeShell extends StatelessWidget {
  const _NeonStatBadgeShell({
    required this.label,
    required this.accent,
    required this.accentSecondary,
    required this.value,
    this.subtitle,
    this.subtitleColor,
    this.progress,
    this.progressLabel,
    this.onTap,
  });

  final String label;
  final Color accent;
  final Color accentSecondary;
  final String value;
  final String? subtitle;
  final Color? subtitleColor;
  final double? progress;
  final String? progressLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget badge = Container(
      constraints: const BoxConstraints(minWidth: 78),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.95),
            accentSecondary.withValues(alpha: 0.65),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.6),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                AppColors.spaceNavy.withValues(alpha: 0.96),
                AppColors.carbonVoid.withValues(alpha: 0.98),
              ],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotPatternPainter(
                    color: AppColors.mutedTitanium,
                    opacity: 0.08,
                    spacing: 14,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        shadows: <Shadow>[
                          Shadow(color: accent.withValues(alpha: 0.85), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        shadows: <Shadow>[
                          Shadow(color: accent.withValues(alpha: 0.7), blurRadius: 8),
                        ],
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: AppTextStyles.micro.copyWith(
                          color: subtitleColor ?? accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                    if (progress != null && progressLabel != null) ...<Widget>[
                      const SizedBox(height: 5),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: SizedBox(
                                height: 3,
                                child: LinearProgressIndicator(
                                  value: progress!.clamp(0.0, 1.0),
                                  backgroundColor:
                                      AppColors.darkObsidian.withValues(alpha: 0.85),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    accent.withValues(alpha: 0.95),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            progressLabel!,
                            style: AppTextStyles.micro.copyWith(
                              color: AppColors.mutedTitanium,
                              fontWeight: FontWeight.w700,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return badge;
    return PressableScale(onTap: onTap, child: badge);
  }
}

class _DotPatternPainter extends CustomPainter {
  const _DotPatternPainter({
    required this.color,
    required this.opacity,
    required this.spacing,
  });

  final Color color;
  final double opacity;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color.withValues(alpha: opacity);
    for (double y = spacing / 2; y < size.height; y += spacing) {
      final bool odd = ((y / spacing).floor()) % 2 == 1;
      for (double x = odd ? spacing : spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity ||
      oldDelegate.spacing != spacing;
}
