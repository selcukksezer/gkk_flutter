import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';
import 'facilities_ui.dart';

/// Kare grid — home kutu banner stili.
class FacSquareGridPainter extends CustomPainter {
  const FacSquareGridPainter({this.cell = 18, this.opacity = 0.06});

  final double cell;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant FacSquareGridPainter oldDelegate) =>
      cell != oldDelegate.cell || opacity != oldDelegate.opacity;
}

/// Gradient + kare grid kabuk — mekan/home banner hissi.
class FacGridBanner extends StatelessWidget {
  const FacGridBanner({
    super.key,
    required this.child,
    this.height,
    this.gradientColors,
    this.borderColor,
    this.padding,
  });

  final Widget child;
  final double? height;
  final List<Color>? gradientColors;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors ??
              <Color>[
                AppColors.spaceNavy.withValues(alpha: 0.95),
                AppColors.carbonVoid.withValues(alpha: 0.98),
              ],
        ),
        border: Border.all(
          color: borderColor ?? AppColors.liquidGold.withValues(alpha: 0.22),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (borderColor ?? AppColors.liquidGold).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          fit: height == null ? StackFit.passthrough : StackFit.expand,
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(painter: FacSquareGridPainter()),
            ),
            Padding(
              padding: padding ?? FacilitiesUi.panelPadding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tesis hero — enerji/altın yok; yalnızca tesis kimliği + durum.
class FacDetailHero extends StatelessWidget {
  const FacDetailHero({
    super.key,
    required this.icon,
    required this.name,
    required this.description,
    required this.level,
    required this.isProducing,
  });

  final String icon;
  final String name;
  final String description;
  final int level;
  final bool isProducing;

  @override
  Widget build(BuildContext context) {
    final Color accent = isProducing ? AppColors.toxicNeon : AppColors.liquidGold;

    return FacGridBanner(
      borderColor: accent.withValues(alpha: 0.35),
      gradientColors: <Color>[
        AppColors.carbonVoid,
        AppColors.spaceNavy.withValues(alpha: 0.92),
        AppColors.carbonVoid,
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.22),
                  AppColors.darkObsidian.withValues(alpha: 0.4),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          height: 1.1,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    _FacBadge(
                      label: 'Lv.$level',
                      color: AppColors.liquidGold,
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedTitanium,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                _FacBadge(
                  label: isProducing ? '● Üretimde' : '○ Boşta',
                  color: accent,
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FacBadge extends StatelessWidget {
  const _FacBadge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// Üretim aksiyon banner — fuchsia/neon veya gold gradient.
class FacProductionBanner extends StatelessWidget {
  const FacProductionBanner({
    super.key,
    required this.isRunning,
    required this.remainingLabel,
    required this.onStart,
    required this.startEnabled,
    required this.startLabel,
    this.previewItems = const <String>[],
  });

  final bool isRunning;
  final String remainingLabel;
  final VoidCallback? onStart;
  final bool startEnabled;
  final String startLabel;
  final List<String> previewItems;

  @override
  Widget build(BuildContext context) {
    if (isRunning) {
      return FacGridBanner(
        borderColor: AppColors.toxicNeon.withValues(alpha: 0.4),
        gradientColors: <Color>[
          const Color(0xFF041A0F),
          AppColors.spaceNavy,
          AppColors.carbonVoid,
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.bolt_rounded, size: 16, color: AppColors.toxicNeon),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Üretim aktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  remainingLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.toxicNeon,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (previewItems.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: previewItems
                    .map(
                      (String label) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: AppColors.toxicNeon.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppColors.toxicNeon.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 9, color: AppColors.textPrimary),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      );
    }

    return FacGridBanner(
      borderColor: AppColors.cyberFuchsia.withValues(alpha: 0.35),
      gradientColors: <Color>[
        const Color(0xFF1A0610),
        AppColors.carbonVoid,
        const Color(0xFF120818),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Üretim Hattı',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedTitanium,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          FacGoldButton(
            label: startLabel,
            onPressed: startEnabled ? onStart : null,
          ),
        ],
      ),
    );
  }
}

class FacGoldButton extends StatelessWidget {
  const FacGoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 38,
    this.accentColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final Color accent = accentColor ?? AppColors.liquidGold;
    final bool enabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: enabled
                ? LinearGradient(
                    colors: <Color>[
                      accent,
                      AppColors.warningSolar.withValues(alpha: 0.9),
                    ],
                  )
                : null,
            color: enabled ? null : AppColors.darkObsidian,
            border: Border.all(
              color: enabled ? accent.withValues(alpha: 0.5) : AppColors.mutedTitanium.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: enabled ? AppColors.carbonVoid : AppColors.mutedTitanium,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kaynak hücresi — envanter popup radial glow.
class FacResourceCell extends StatelessWidget {
  const FacResourceCell({
    super.key,
    required this.emoji,
    required this.name,
    required this.percentLabel,
    required this.accentColor,
    required this.locked,
  });

  final String emoji;
  final String name;
  final String percentLabel;
  final Color accentColor;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.carbonVoid.withValues(alpha: 0.85),
        border: Border.all(color: accentColor.withValues(alpha: locked ? 0.15 : 0.35)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.1,
                    colors: <Color>[
                      accentColor.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: locked ? AppColors.mutedTitanium : AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    percentLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: locked ? AppColors.mutedTitanium : accentColor,
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

Color facRarityAccent(String rarity) {
  switch (rarity) {
    case 'common':
      return AppColors.mutedTitanium;
    case 'uncommon':
      return AppColors.toxicNeon;
    case 'rare':
      return AppColors.liquidGold;
    case 'epic':
      return AppColors.cyberFuchsia;
    case 'legendary':
      return AppColors.warningSolar;
    case 'mythic':
      return AppColors.coralFlare;
    default:
      return AppColors.mutedTitanium;
  }
}

/// Yükseltme şeridi — coral flare vurgu.
class FacUpgradeStrip extends StatelessWidget {
  const FacUpgradeStrip({
    super.key,
    required this.summary,
    required this.buttonLabel,
    required this.onUpgrade,
    required this.enabled,
  });

  final String summary;
  final String buttonLabel;
  final VoidCallback? onUpgrade;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FacGridBanner(
      borderColor: AppColors.coralFlare.withValues(alpha: 0.38),
      gradientColors: <Color>[
        const Color(0xFF1A0E08),
        AppColors.carbonVoid,
      ],
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: FacGoldButton(
              label: buttonLabel,
              height: 34,
              accentColor: AppColors.coralFlare,
              onPressed: enabled ? onUpgrade : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Boş / kilitli tesis — dotted panel (karakter stili).
class FacEmptyState extends StatelessWidget {
  const FacEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      borderColor: AppColors.mutedTitanium.withValues(alpha: 0.25),
      child: Row(
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: AppColors.mutedTitanium, height: 1.3),
                ),
                const SizedBox(height: 4),
                const Text(
                  '← Geri ile tesis listesine dön',
                  style: TextStyle(fontSize: 9, color: AppColors.liquidGold, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Depo satırı — popup kart stili.
class FacDepotRow extends StatelessWidget {
  const FacDepotRow({
    super.key,
    required this.label,
    required this.quantity,
    required this.accentColor,
  });

  final String label;
  final int quantity;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.darkObsidian.withValues(alpha: 0.75),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: accentColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.textPrimary),
            ),
          ),
          Text(
            '×$quantity',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accentColor),
          ),
        ],
      ),
    );
  }
}
