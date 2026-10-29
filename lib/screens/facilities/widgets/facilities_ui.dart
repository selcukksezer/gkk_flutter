import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';

/// Aion-2 2027 Mobile Spacing & Frosted Glass Design Foundations.
abstract final class FacilitiesUi {
  static const double gap = GameScrollLayout.sectionGap;
  static const double gapSm = GameScrollLayout.itemGap;
  static const double gapXs = 4.0;
  static const double gapLg = 20.0;
  static const double gapXl = 24.0;

  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusPill = 999.0;

  static EdgeInsets scrollPadding(BuildContext context) =>
      GameScrollLayout.pagePadding(context);

  static const EdgeInsets panelPadding = EdgeInsets.all(10);
  static const EdgeInsets cardPadding = EdgeInsets.all(12);
  static const EdgeInsets dialogPadding = EdgeInsets.fromLTRB(16, 16, 16, 14);
  static const EdgeInsets dialogInsetPadding =
      EdgeInsets.symmetric(horizontal: 22, vertical: 28);

  /// Luminous BoxShadow presets for fantasy frosted glass.
  static List<BoxShadow> glowShadow(
    Color color, {
    double blur = 14.0,
    double spread = -2.0,
    Offset offset = const Offset(0, 4),
  }) =>
      <BoxShadow>[
        BoxShadow(
          color: color,
          blurRadius: blur,
          spreadRadius: spread,
          offset: offset,
        ),
      ];

  /// Border decoration with luminous fantasy glow.
  static Border luminousBorder(Color color, {double width = 1.0}) =>
      Border.all(color: color, width: width);
}

/// Aion-2 Frosted Glass Panel with subtle blur and luminous borders.
class FacGlassPanel extends StatelessWidget {
  const FacGlassPanel({
    super.key,
    required this.child,
    this.borderColor,
    this.glowColor,
    this.backgroundColor,
    this.gradient,
    this.borderRadius = FacilitiesUi.radiusMd,
    this.padding = FacilitiesUi.panelPadding,
    this.margin,
    this.borderWidth = 1.0,
    this.blurSigma = 10.0,
    this.width,
    this.height,
    this.alignment,
    this.clipBehavior = Clip.antiAlias,
    this.hasInnerHighlight = true,
  });

  final Widget child;
  final Color? borderColor;
  final Color? glowColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderWidth;
  final double blurSigma;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final Clip clipBehavior;
  final bool hasInnerHighlight;

  @override
  Widget build(BuildContext context) {
    final Color border =
        borderColor ?? AppColors.liquidGold.withValues(alpha: 0.28);
    final Color glow = glowColor ?? border.withValues(alpha: 0.12);
    final Color bg =
        backgroundColor ?? AppColors.bgDeep.withValues(alpha: 0.78);

    Widget content = Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: border,
          width: borderWidth,
        ),
        boxShadow: FacilitiesUi.glowShadow(glow),
      ),
      child: child,
    );

    if (hasInnerHighlight) {
      content = Stack(
        children: <Widget>[
          content,
          Positioned(
            top: 0,
            left: borderRadius * 0.5,
            right: borderRadius * 0.5,
            height: 1.0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.transparent,
                      border.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final Widget glass = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: glass);
    }
    return glass;
  }
}

/// Screen shell wrapper ensuring seamless dark fantasy gradient background.
Widget facilitiesScreenShell({required Widget child}) {
  return GameScreenBackground(child: child);
}

/// Frosted glass panel convenience helper.
Widget facilitiesPanel({
  required Widget child,
  Color? borderColor,
  Color? glowColor,
  Color? backgroundColor,
  Gradient? gradient,
  double borderRadius = FacilitiesUi.radiusMd,
  EdgeInsetsGeometry? padding,
  EdgeInsetsGeometry? margin,
  double borderWidth = 1.0,
  double blurSigma = 10.0,
  bool hasInnerHighlight = true,
}) {
  return FacGlassPanel(
    padding: padding ?? FacilitiesUi.panelPadding,
    margin: margin,
    borderRadius: borderRadius,
    borderColor: borderColor ?? AppColors.liquidGold.withValues(alpha: 0.25),
    glowColor: glowColor,
    backgroundColor: backgroundColor,
    gradient: gradient,
    borderWidth: borderWidth,
    blurSigma: blurSigma,
    hasInnerHighlight: hasInnerHighlight,
    child: child,
  );
}

/// Visual stat chip for facility metrics, income rates, and counts.
Widget facilitiesStatChip(
  String label,
  String value, {
  Color? valueColor,
  IconData? icon,
  String? iconText,
  Widget? trailing,
  VoidCallback? onTap,
  double? minWidth,
  EdgeInsetsGeometry? padding,
}) {
  final Color tint = valueColor ?? AppColors.mutedTitanium;
  final Widget content = Container(
    constraints: minWidth != null ? BoxConstraints(minWidth: minWidth) : null,
    padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(FacilitiesUi.radiusSm),
      color: AppColors.bgCard.withValues(alpha: 0.65),
      border: Border.all(
        color: tint.withValues(alpha: 0.28),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: tint.withValues(alpha: 0.08),
          blurRadius: 8,
          spreadRadius: -2,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
        ] else if (iconText != null && iconText.isNotEmpty) ...<Widget>[
          Text(iconText, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.mutedTitanium,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? AppColors.textPrimary,
                  height: 1.15,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 6),
          trailing,
        ],
      ],
    ),
  );

  if (onTap != null) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(FacilitiesUi.radiusSm),
        child: content,
      ),
    );
  }

  return content;
}

/// Visual variants for facility badges.
enum FacBadgeVariant {
  gold,
  cyan,
  ruby,
  emerald,
  amber,
  purple,
  neutral;

  Color get color => switch (this) {
        FacBadgeVariant.gold => AppColors.liquidGold,
        FacBadgeVariant.cyan => AppColors.accentCyan,
        FacBadgeVariant.ruby => AppColors.mysticRuby,
        FacBadgeVariant.emerald => AppColors.toxicNeon,
        FacBadgeVariant.amber => AppColors.warningSolar,
        FacBadgeVariant.purple => AppColors.accentPurple,
        FacBadgeVariant.neutral => AppColors.mutedTitanium,
      };
}

/// Aion-2 Luminous Badge for status, tier, rarity, and facility indicators.
class FacBadge extends StatelessWidget {
  const FacBadge({
    super.key,
    required this.label,
    this.variant = FacBadgeVariant.gold,
    this.customColor,
    this.backgroundColor,
    this.icon,
    this.iconText,
    this.fontSize = 9.5,
    this.isOutlined = false,
    this.isPill = true,
    this.hasGlow = false,
    this.padding,
    this.onTap,
  });

  const FacBadge.gold(
    String label, {
    Key? key,
    IconData? icon,
    String? iconText,
    bool hasGlow = false,
    bool isOutlined = false,
    VoidCallback? onTap,
  }) : this(
          key: key,
          label: label,
          variant: FacBadgeVariant.gold,
          icon: icon,
          iconText: iconText,
          hasGlow: hasGlow,
          isOutlined: isOutlined,
          onTap: onTap,
        );

  const FacBadge.cyan(
    String label, {
    Key? key,
    IconData? icon,
    String? iconText,
    bool hasGlow = false,
    bool isOutlined = false,
    VoidCallback? onTap,
  }) : this(
          key: key,
          label: label,
          variant: FacBadgeVariant.cyan,
          icon: icon,
          iconText: iconText,
          hasGlow: hasGlow,
          isOutlined: isOutlined,
          onTap: onTap,
        );

  const FacBadge.ruby(
    String label, {
    Key? key,
    IconData? icon,
    String? iconText,
    bool hasGlow = false,
    bool isOutlined = false,
    VoidCallback? onTap,
  }) : this(
          key: key,
          label: label,
          variant: FacBadgeVariant.ruby,
          icon: icon,
          iconText: iconText,
          hasGlow: hasGlow,
          isOutlined: isOutlined,
          onTap: onTap,
        );

  const FacBadge.emerald(
    String label, {
    Key? key,
    IconData? icon,
    String? iconText,
    bool hasGlow = false,
    bool isOutlined = false,
    VoidCallback? onTap,
  }) : this(
          key: key,
          label: label,
          variant: FacBadgeVariant.emerald,
          icon: icon,
          iconText: iconText,
          hasGlow: hasGlow,
          isOutlined: isOutlined,
          onTap: onTap,
        );

  const FacBadge.neutral(
    String label, {
    Key? key,
    IconData? icon,
    String? iconText,
    VoidCallback? onTap,
  }) : this(
          key: key,
          label: label,
          variant: FacBadgeVariant.neutral,
          icon: icon,
          iconText: iconText,
          onTap: onTap,
        );

  factory FacBadge.level(
    int level, {
    Key? key,
    Color? accentColor,
    bool compact = false,
  }) {
    final int safeLevel = level < 1 ? 1 : level;
    return FacBadge(
      key: key,
      label: 'LV. $safeLevel',
      customColor: accentColor ?? AppColors.liquidGold,
      fontSize: compact ? 9.0 : 10.5,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      hasGlow: true,
    );
  }

  factory FacBadge.tier(
    int tier, {
    Key? key,
    Color? accentColor,
  }) {
    final int safeTier = tier < 1 ? 1 : tier;
    return FacBadge(
      key: key,
      label: 'TIER $safeTier',
      customColor: accentColor ?? AppColors.accentCyan,
      fontSize: 10.0,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      hasGlow: true,
    );
  }

  factory FacBadge.status({
    Key? key,
    required bool isActive,
    String? activeLabel,
    String? inactiveLabel,
    bool compact = false,
  }) {
    return FacBadge(
      key: key,
      label: isActive
          ? (activeLabel ?? 'AKTİF')
          : (inactiveLabel ?? 'PASİF'),
      variant: isActive ? FacBadgeVariant.emerald : FacBadgeVariant.neutral,
      fontSize: compact ? 9.0 : 10.0,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      hasGlow: isActive,
    );
  }

  final String label;
  final FacBadgeVariant variant;
  final Color? customColor;
  final Color? backgroundColor;
  final IconData? icon;
  final String? iconText;
  final double fontSize;
  final bool isOutlined;
  final bool isPill;
  final bool hasGlow;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = customColor ?? variant.color;
    final double radius =
        isPill ? FacilitiesUi.radiusPill : FacilitiesUi.radiusSm;
    final Color bg = backgroundColor ??
        (isOutlined
            ? Colors.transparent
            : color.withValues(alpha: 0.14));

    Widget badge = Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: bg,
        border: Border.all(
          color: color.withValues(alpha: isOutlined ? 0.65 : 0.45),
          width: 0.9,
        ),
        boxShadow: hasGlow
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: -1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ] else if (iconText != null && iconText!.isNotEmpty) ...<Widget>[
            Text(iconText!, style: TextStyle(fontSize: fontSize + 1)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.35,
              height: 1.15,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      badge = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap!();
          },
          borderRadius: BorderRadius.circular(radius),
          child: badge,
        ),
      );
    }

    return badge;
  }
}

/// Convenience function for rendering a facility badge.
Widget facilitiesBadge(
  String label, {
  FacBadgeVariant variant = FacBadgeVariant.gold,
  Color? color,
  IconData? icon,
  String? iconText,
  bool isPill = true,
  bool hasGlow = false,
  bool isOutlined = false,
  VoidCallback? onTap,
}) {
  return FacBadge(
    label: label,
    variant: variant,
    customColor: color,
    icon: icon,
    iconText: iconText,
    isPill: isPill,
    hasGlow: hasGlow,
    isOutlined: isOutlined,
    onTap: onTap,
  );
}

/// Aion-2 Luminous Progress Bar with animated fill, glowing gradient, and dark track.
class FacProgressBar extends StatelessWidget {
  const FacProgressBar({
    super.key,
    required this.progress,
    this.height = 6.0,
    this.fillColor,
    this.fillGradient,
    this.trackColor,
    this.borderColor,
    this.showGlow = true,
    this.borderRadius,
    this.animationDuration = const Duration(milliseconds: 350),
  });

  /// Normalized progress between 0.0 and 1.0 (clamped & null-safe).
  final double progress;
  final double height;
  final Color? fillColor;
  final Gradient? fillGradient;
  final Color? trackColor;
  final Color? borderColor;
  final bool showGlow;
  final BorderRadiusGeometry? borderRadius;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final double safeProgress =
        progress.isNaN || progress.isInfinite ? 0.0 : progress.clamp(0.0, 1.0);
    final Color barColor = fillColor ?? AppColors.liquidGold;
    final BorderRadius rad = (borderRadius as BorderRadius?) ??
        BorderRadius.circular(FacilitiesUi.radiusPill);
    final Color track =
        trackColor ?? AppColors.carbonVoid.withValues(alpha: 0.72);
    final Color border =
        borderColor ?? AppColors.mutedTitanium.withValues(alpha: 0.2);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: track,
        borderRadius: rad,
        border: Border.all(color: border, width: 0.7),
        boxShadow: showGlow
            ? <BoxShadow>[
                BoxShadow(
                  color: barColor.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: rad,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: safeProgress),
          duration: animationDuration,
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double animatedValue, Widget? _) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: animatedValue,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: rad,
                  gradient: fillGradient ??
                      LinearGradient(
                        colors: <Color>[
                          barColor.withValues(alpha: 0.85),
                          barColor,
                        ],
                      ),
                  boxShadow: showGlow
                      ? <BoxShadow>[
                          BoxShadow(
                            color: barColor.withValues(alpha: 0.45),
                            blurRadius: 8,
                            spreadRadius: -1,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Aion-2 Facility Metric Meter with label, value indicator, and progress bar.
class FacMeterWithHeader extends StatelessWidget {
  const FacMeterWithHeader({
    super.key,
    required this.label,
    required this.progress,
    this.valueText,
    this.height = 6.0,
    this.color,
    this.warningThreshold,
    this.dangerThreshold,
    this.showGlow = true,
  });

  final String label;
  final double progress;
  final String? valueText;
  final double height;
  final Color? color;
  final double? warningThreshold;
  final double? dangerThreshold;
  final bool showGlow;

  Color _resolveColor() {
    if (color != null) return color!;
    final double safe =
        progress.isNaN || progress.isInfinite ? 0.0 : progress.clamp(0.0, 1.0);
    if (dangerThreshold != null && safe >= dangerThreshold!) {
      return AppColors.mysticRuby;
    }
    if (warningThreshold != null && safe >= warningThreshold!) {
      return AppColors.warningSolar;
    }
    return AppColors.liquidGold;
  }

  @override
  Widget build(BuildContext context) {
    final Color barColor = _resolveColor();
    final double safe =
        progress.isNaN || progress.isInfinite ? 0.0 : progress.clamp(0.0, 1.0);
    final String displayValue =
        valueText ?? '${(safe * 100).toStringAsFixed(0)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.mutedTitanium,
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        FacProgressBar(
          progress: progress,
          height: height,
          fillColor: barColor,
          showGlow: showGlow,
        ),
      ],
    );
  }
}

/// Convenience function for rendering a standalone progress bar.
Widget facilitiesProgressBar({
  required double progress,
  double height = 6.0,
  Color? fillColor,
  Gradient? fillGradient,
  bool showGlow = true,
}) {
  return FacProgressBar(
    progress: progress,
    height: height,
    fillColor: fillColor,
    fillGradient: fillGradient,
    showGlow: showGlow,
  );
}

/// Convenience function for rendering a labeled progress meter.
Widget facilitiesMeter({
  required String label,
  required double progress,
  String? valueText,
  double height = 6.0,
  Color? color,
  bool showGlow = true,
}) {
  return FacMeterWithHeader(
    label: label,
    progress: progress,
    valueText: valueText,
    height: height,
    color: color,
    showGlow: showGlow,
  );
}

typedef FacilitiesTabOption = ({String id, String label});

/// Segmented tab row with gold glowing highlights and haptic feedback.
Widget facilitiesSegmentTabs({
  required String activeId,
  required List<FacilitiesTabOption> tabs,
  required ValueChanged<String> onChanged,
  Color? accentColor,
  double height = 36.0,
}) {
  final Color accent = accentColor ?? AppColors.liquidGold;

  return Row(
    children: tabs.map((FacilitiesTabOption tab) {
      final bool active = tab.id == activeId;
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(
            right: tab.id == tabs.last.id ? 0 : FacilitiesUi.gapSm,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(tab.id);
              },
              borderRadius: BorderRadius.circular(FacilitiesUi.radiusSm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: height,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FacilitiesUi.radiusSm),
                  border: Border.all(
                    color: active
                        ? accent
                        : AppColors.mutedTitanium.withValues(alpha: 0.28),
                    width: active ? 1.4 : 1.0,
                  ),
                  gradient: active
                      ? LinearGradient(
                          colors: <Color>[
                            accent.withValues(alpha: 0.24),
                            accent.withValues(alpha: 0.08),
                          ],
                        )
                      : null,
                  color: active
                      ? null
                      : AppColors.bgDeep.withValues(alpha: 0.45),
                  boxShadow: active
                      ? <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18),
                            blurRadius: 10,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: 0.3,
                    color: active ? accent : AppColors.mutedTitanium,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

/// Section header with vertical glowing accent pill and optional trailing badge.
Widget facilitiesSectionTitle(
  String title, {
  String? trailing,
  Widget? trailingWidget,
  Color? accentColor,
  IconData? icon,
  VoidCallback? onTrailingTap,
}) {
  final Color accent = accentColor ?? AppColors.liquidGold;

  return Row(
    children: <Widget>[
      Container(
        width: 3.5,
        height: 15,
        margin: const EdgeInsets.only(right: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              accent,
              accent.withValues(alpha: 0.4),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.4),
              blurRadius: 6,
              spreadRadius: -1,
            ),
          ],
        ),
      ),
      if (icon != null) ...<Widget>[
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 6),
      ],
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      if (trailingWidget != null)
        trailingWidget
      else if (trailing != null && trailing.isNotEmpty)
        FacBadge(
          label: trailing,
          customColor: accent,
          fontSize: 9.5,
          onTap: onTrailingTap,
        ),
    ],
  );
}

/// Standardized fantasy frosted glass decoration for facility dialogs.
BoxDecoration facDialogDecoration({
  Color? accentColor,
  double borderRadius = FacilitiesUi.radiusLg,
  bool showGlow = true,
}) {
  final Color accent = accentColor ?? AppColors.liquidGold;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: accent.withValues(alpha: 0.45),
      width: 1.3,
    ),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        AppColors.bgCardElevated.withValues(alpha: 0.94),
        AppColors.bgDeep.withValues(alpha: 0.96),
        AppColors.carbonVoid,
      ],
    ),
    boxShadow: showGlow
        ? <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 22,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ]
        : null,
  );
}

/// Aion-2 Dialog Shell with frosted glass, luminous accent borders, and spring responsiveness.
class FacDialogShell extends StatelessWidget {
  const FacDialogShell({
    super.key,
    required this.child,
    this.accentColor = AppColors.liquidGold,
    this.maxWidth = 340.0,
    this.padding = FacilitiesUi.dialogPadding,
    this.borderRadius = FacilitiesUi.radiusLg,
    this.blurSigma = 14.0,
  });

  final Widget child;
  final Color accentColor;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: facDialogDecoration(
              accentColor: accentColor,
              borderRadius: borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Header for facility dialogs featuring glowing icon medallion and title typography.
class FacDialogHeader extends StatelessWidget {
  const FacDialogHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconData,
    this.accentColor = AppColors.liquidGold,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final String? icon;
  final IconData? iconData;
  final Color accentColor;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null || iconData != null) ...<Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.14),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: iconData != null
                ? Icon(iconData, color: accentColor, size: 22)
                : Text(icon ?? '', style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: accentColor,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedTitanium,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onClose != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.mutedTitanium,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () {
              HapticFeedback.lightImpact();
              onClose!();
            },
          ),
      ],
    );
  }
}

/// Aion-2 Dialog Action Button supporting primary gradient fill and secondary outline states.
class FacDialogActionButton extends StatelessWidget {
  const FacDialogActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.accentColor = AppColors.liquidGold,
    this.height = 38.0,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final Color accentColor;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onPressed?.call();
                },
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: <Color>[
                  accentColor,
                  accentColor.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.carbonVoid,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.carbonVoid,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed?.call();
              },
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppColors.bgDeep.withValues(alpha: 0.75),
            border: Border.all(
              color: AppColors.mutedTitanium.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.mutedTitanium,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Error state panel with glowing ruby warning icon and retry action.
Widget facilitiesErrorPanel({
  required String message,
  required VoidCallback onRetry,
  String title = 'Tesisler Yüklenemedi',
  String retryLabel = 'Tekrar Dene',
  IconData icon = Icons.warning_amber_rounded,
  Color accentColor = AppColors.mysticRuby,
  bool isBusy = false,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: FacGlassPanel(
        borderColor: accentColor.withValues(alpha: 0.45),
        glowColor: accentColor.withValues(alpha: 0.2),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.15),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.4),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.mutedTitanium,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: FilledButton(
                onPressed: isBusy
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        onRetry();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.liquidGold,
                  foregroundColor: AppColors.carbonVoid,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.liquidGold.withValues(alpha: 0.35),
                ),
                child: isBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.carbonVoid,
                        ),
                      )
                    : Text(
                        retryLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
