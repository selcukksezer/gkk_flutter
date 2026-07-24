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
    this.compact = false,
  })  : _kind = _HomeStatBadgeKind.power,
        reputation = 0;

  const HomeStatBadge.reputation({
    super.key,
    required this.reputation,
    this.compact = false,
  })  : _kind = _HomeStatBadgeKind.reputation,
        value = null;

  final _HomeStatBadgeKind _kind;
  final String? value;
  final int reputation;
  final bool compact;

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
          compact: compact,
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
          compact: compact,
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
    this.compact = false,
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
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double outerRadius = compact ? 12 : 16;
    final double innerRadius = compact ? 10.6 : 14.6;
    final EdgeInsets contentPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    final double labelSize = compact ? 8.5 : 10;
    final double valueSize = compact ? 12.5 : 15;
    final double maxWidth = compact ? 92.0 : double.infinity;

    final Widget badge = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact ? 62 : 78,
        maxWidth: maxWidth,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerRadius),
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
              color: accent.withValues(alpha: compact ? 0.35 : 0.45),
              blurRadius: compact ? 8 : 14,
              spreadRadius: compact ? -3 : -2,
            ),
            if (!compact)
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 2,
              ),
          ],
        ),
        padding: EdgeInsets.all(compact ? 1.1 : 1.4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
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
                      opacity: compact ? 0.06 : 0.08,
                      spacing: compact ? 11 : 14,
                    ),
                  ),
                ),
                Padding(
                  padding: contentPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.micro.copyWith(
                          fontSize: labelSize,
                          color: AppColors.textPrimary.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w800,
                          letterSpacing: compact ? 1.1 : 1.4,
                          height: 1,
                          shadows: <Shadow>[
                            Shadow(color: accent.withValues(alpha: 0.85), blurRadius: 6),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 1 : 2),
                      Text(
                        value,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(
                          fontSize: valueSize,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          shadows: <Shadow>[
                            Shadow(color: accent.withValues(alpha: 0.7), blurRadius: 8),
                          ],
                        ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        SizedBox(height: compact ? 2 : 3),
                        if (compact && progressLabel != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.micro.copyWith(
                                    fontSize: 8.5,
                                    color: subtitleColor ?? accent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                    height: 1,
                                  ),
                                ),
                              ),
                              Text(
                                ' · ',
                                style: AppTextStyles.micro.copyWith(
                                  fontSize: 8.5,
                                  color: AppColors.mutedTitanium,
                                  height: 1,
                                ),
                              ),
                              Text(
                                progressLabel!,
                                style: AppTextStyles.micro.copyWith(
                                  fontSize: 8.5,
                                  color: AppColors.mutedTitanium,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.micro.copyWith(
                              color: subtitleColor ?? accent,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                      ],
                      if (!compact && progress != null && progressLabel != null) ...<Widget>[
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
                      if (compact && progress != null) ...<Widget>[
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: SizedBox(
                            height: 2,
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
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
