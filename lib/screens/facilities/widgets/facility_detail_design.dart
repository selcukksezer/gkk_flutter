import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import 'facilities_ui.dart';

/// Aion-2 Frosted Glass Banner — Multi-layered dark glass with luminous borders.
class FacGridBanner extends StatelessWidget {
  const FacGridBanner({
    super.key,
    required this.child,
    this.height,
    this.gradientColors,
    this.borderColor,
    this.glowColor,
    this.padding,
    this.borderRadius = FacilitiesUi.radiusMd,
  });

  final Widget child;
  final double? height;
  final List<Color>? gradientColors;
  final Color? borderColor;
  final Color? glowColor;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final Color border = borderColor ?? AppColors.liquidGold.withValues(alpha: 0.35);
    final Color glow = glowColor ?? border.withValues(alpha: 0.12);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: height,
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: border,
              width: 1.1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors ??
                  <Color>[
                    AppColors.bgCardElevated.withValues(alpha: 0.82),
                    AppColors.bgDeep.withValues(alpha: 0.88),
                    AppColors.carbonVoid.withValues(alpha: 0.95),
                  ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glow,
                blurRadius: 14,
                spreadRadius: -2,
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

/// Aion-2 Tesis Hero Kartı — Medallion aura, ornate Lv badge, luminous status.
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
      borderColor: accent.withValues(alpha: 0.45),
      glowColor: accent.withValues(alpha: 0.18),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Ornate Facility Medallion
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.28),
                  AppColors.darkObsidian.withValues(alpha: 0.55),
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 28)),
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
                        name,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          height: 1.15,
                          letterSpacing: 0.2,
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
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.mutedTitanium,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _FacBadge(
                  label: isProducing ? '● Üretim Aktif' : '○ Boşta — Bekliyor',
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
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(
          color: color.withValues(alpha: 0.45),
          width: 0.9,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 9.5 : 10.5,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Aion-2 Üretim Banner — Sleek timer gauge, tabular countdown & neon energy triggers.
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
        borderColor: AppColors.toxicNeon.withValues(alpha: 0.5),
        glowColor: AppColors.toxicNeon.withValues(alpha: 0.16),
        gradientColors: <Color>[
          const Color(0xCC052014),
          AppColors.bgDeep.withValues(alpha: 0.88),
          AppColors.carbonVoid,
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.toxicNeon.withValues(alpha: 0.16),
                    border: Border.all(
                      color: AppColors.toxicNeon.withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: AppColors.toxicNeon,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ÜRETİM DEVAM EDİYOR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: AppColors.toxicNeon.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.toxicNeon.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    remainingLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.toxicNeon,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            if (previewItems.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: previewItems
                    .map(
                      (String label) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: AppColors.toxicNeon.withValues(alpha: 0.09),
                          border: Border.all(
                            color: AppColors.toxicNeon.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
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
      borderColor: AppColors.cyberFuchsia.withValues(alpha: 0.45),
      glowColor: AppColors.cyberFuchsia.withValues(alpha: 0.16),
      gradientColors: <Color>[
        const Color(0xCC1E0818),
        AppColors.bgDeep.withValues(alpha: 0.9),
        AppColors.carbonVoid,
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyberFuchsia.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.cyberFuchsia.withValues(alpha: 0.45),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.precision_manufacturing_rounded,
                  size: 14,
                  color: AppColors.cyberFuchsia,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ÜRETİM HATTI HAZIR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.cyberFuchsia.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.cyberFuchsia.withValues(alpha: 0.35),
                  ),
                ),
                child: const Text(
                  'Maliyet: 50⚡ Enerji',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cyberFuchsia,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FacGoldButton(
            label: startLabel,
            onPressed: startEnabled ? onStart : null,
          ),
        ],
      ),
    );
  }
}

/// Aion-2 Tactile Gold Button — Gradient + Luminous Border + Haptic Feedback.
class FacGoldButton extends StatefulWidget {
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
  State<FacGoldButton> createState() => _FacGoldButtonState();
}

class _FacGoldButtonState extends State<FacGoldButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accentColor ?? AppColors.liquidGold;
    final bool enabled = widget.onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Ink(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: enabled
                  ? LinearGradient(
                      colors: <Color>[
                        accent,
                        AppColors.warningSolar.withValues(alpha: 0.92),
                      ],
                    )
                  : null,
              color: enabled ? null : AppColors.darkObsidian.withValues(alpha: 0.5),
              border: Border.all(
                color: enabled
                    ? accent.withValues(alpha: 0.6)
                    : AppColors.mutedTitanium.withValues(alpha: 0.22),
                width: 1.1,
              ),
              boxShadow: enabled
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: enabled ? AppColors.carbonVoid : AppColors.mutedTitanium,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kaynak Hücresi — Aion-2 Rarity Glow & Radial Sheen.
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
        color: AppColors.bgDeep.withValues(alpha: 0.85),
        border: Border.all(
          color: accentColor.withValues(alpha: locked ? 0.18 : 0.45),
          width: locked ? 0.9 : 1.2,
        ),
        boxShadow: locked
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                    radius: 1.15,
                    colors: <Color>[
                      accentColor.withValues(alpha: locked ? 0.05 : 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(emoji, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: locked ? AppColors.mutedTitanium : AppColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    percentLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: locked ? AppColors.mutedTitanium : accentColor,
                      letterSpacing: 0.2,
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
      return AppColors.accentCyan;
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

/// Yükseltme Şeridi — Coral Flare / Gold Vurgu.
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
      borderColor: AppColors.coralFlare.withValues(alpha: 0.45),
      glowColor: AppColors.coralFlare.withValues(alpha: 0.18),
      gradientColors: <Color>[
        const Color(0xCC200F0A),
        AppColors.bgDeep.withValues(alpha: 0.9),
        AppColors.carbonVoid,
      ],
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.coralFlare.withValues(alpha: 0.16),
              border: Border.all(
                color: AppColors.coralFlare.withValues(alpha: 0.45),
              ),
            ),
            alignment: Alignment.center,
            child: const Text('⬆️', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 94,
            child: FacGoldButton(
              label: buttonLabel,
              height: 35,
              accentColor: AppColors.coralFlare,
              onPressed: enabled ? onUpgrade : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Boş / Kilitli Tesis Durumu — Frosted Glass Hero.
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
    return FacGlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: FacilitiesUi.radiusLg,
      borderColor: AppColors.mutedTitanium.withValues(alpha: 0.3),
      child: Row(
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.darkObsidian.withValues(alpha: 0.6),
              border: Border.all(
                color: AppColors.mutedTitanium.withValues(alpha: 0.3),
              ),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.mutedTitanium,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '← Geri tuşuyla tesis listesine dönebilirsiniz',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.liquidGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Depo Satırı — Frosted Glass Card with Rarity Indicator.
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.bgDeep.withValues(alpha: 0.8),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 0.9,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: accentColor,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: accentColor.withValues(alpha: 0.12),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Text(
              '×$quantity',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
