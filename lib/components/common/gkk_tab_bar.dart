import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tutorial/tutorial_anchor.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../layout/game_screen_background.dart';

/// Tasarım-system defaults for [GkkTabBar] — 2027 Aion 2 Obsidian-Glass & Luminescence.
abstract final class GkkTabBarTheme {
  static const Duration animationDuration = Duration(milliseconds: 250);
  static const Curve animationCurve = Curves.easeOutCubic;
  static const double pressedScale = 0.96;

  static const double containerRadius = 14;
  static const double pillRadius = 999;
  static const double defaultBlurSigma = 16.0;

  // ──────────────────────────── 2027 Aion 2 Palette ────────────────────────────
  /// 2027 Aion 2 Celestial Gold (#E5C158).
  static const Color celestialGold = Color(0xFFE5C158);

  /// 2027 Aion 2 Ether Cyan (#00E5FF).
  static const Color etherCyan = Color(0xFF00E5FF);

  /// Ether cyan secondary aura glow (#38BDF8).
  static const Color etherCyanGlow = Color(0xFF38BDF8);

  /// Cosmic obsidian abyss void (#05070B).
  static const Color obsidianVoid = Color(0xFF05070B);

  /// Deep obsidian base (#090D15).
  static const Color obsidianBase = Color(0xFF090D15);

  /// Elevated obsidian surface (#0E131E).
  static const Color obsidianSurface = Color(0xFF0E131E);

  /// Translucent obsidian elevated dock (#121A2B).
  static const Color obsidianElevated = Color(0xFF121A2B);

  /// Backward compatibility alias.
  static const Color liquidGold = AppColors.liquidGold;

  /// 2027 Aion 2 Active Tab Pill Decoration:
  /// Luminous celestial gold gradient + ether cyan (#00E5FF) glow BoxShadow + celestial rim.
  static BoxDecoration selectedPillDecoration({
    Color primaryColor = celestialGold,
    Color secondaryColor = AppColors.liquidGold,
    Color glowColor = etherCyan,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(pillRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.35),
        width: 0.85,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFFFFF2B2), // Specular luminous highlight
          primaryColor,            // Celestial Gold #E5C158
          secondaryColor,          // Liquid Gold #FFB800
          const Color(0xFFB8860B), // Deep gold dusk rim
        ],
        stops: const <double>[0.0, 0.28, 0.70, 1.0],
      ),
      boxShadow: <BoxShadow>[
        // Ether cyan active tab pill glow BoxShadow (2027 Aion 2 specification)
        BoxShadow(
          color: glowColor.withValues(alpha: 0.55),
          blurRadius: 16,
          spreadRadius: 1.0,
          offset: const Offset(0, 1),
        ),
        // Celestial gold luminescence core glow
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.45),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
        // Soft elevation shadow
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.40),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// 2027 Aion 2 Subtle Translucent Inactive Tab State.
  static BoxDecoration unselectedPillDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(pillRadius),
      color: Colors.white.withValues(alpha: 0.035),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.06),
        width: 0.75,
      ),
    );
  }

  static TextStyle get selectedLabelStyle => AppTextStyles.captionBold.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.carbonVoid,
        letterSpacing: 0.25,
      );

  static TextStyle get unselectedLabelStyle => AppTextStyles.caption.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.mutedTitanium.withValues(alpha: 0.90),
        letterSpacing: 0.1,
      );

  static TabBarThemeData tabBarTheme({TabAlignment tabAlignment = TabAlignment.start}) {
    return TabBarThemeData(
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: celestialGold,
      unselectedLabelColor: AppColors.mutedTitanium,
      labelStyle: selectedLabelStyle,
      unselectedLabelStyle: unselectedLabelStyle,
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      tabAlignment: tabAlignment,
    );
  }
}

/// Press-scale wrapper — 0.96 on pointer down, 250ms easeOutCubic.
class GkkTabLabel extends StatefulWidget {
  const GkkTabLabel({super.key, required this.child});

  final Widget child;

  @override
  State<GkkTabLabel> createState() => _GkkTabLabelState();
}

class _GkkTabLabelState extends State<GkkTabLabel> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? GkkTabBarTheme.pressedScale : 1,
        duration: GkkTabBarTheme.animationDuration,
        curve: GkkTabBarTheme.animationCurve,
        child: widget.child,
      ),
    );
  }
}

/// 2027 Aion 2 Celestial Gold (#E5C158) Badge Indicator.
class GkkTabBadge extends StatelessWidget {
  const GkkTabBadge({
    super.key,
    this.count,
    this.label,
    this.color = GkkTabBarTheme.celestialGold,
    this.textColor = AppColors.carbonVoid,
    this.glowColor = GkkTabBarTheme.etherCyan,
  });

  final int? count;
  final String? label;
  final Color color;
  final Color textColor;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    final String text = label ?? (count != null ? (count! > 99 ? '99+' : count.toString()) : '');
    if (text.isEmpty && count == null) {
      return const SizedBox.shrink();
    }

    if (text.isEmpty) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.85),
              blurRadius: 6,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: glowColor.withValues(alpha: 0.50),
              blurRadius: 4,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 0.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.70),
            blurRadius: 7,
            spreadRadius: 0.5,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.35),
            blurRadius: 4,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: textColor,
            height: 1.05,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

/// Single pill segment — 2027 Aion 2 Celestial Gold selected with Ether Cyan glow BoxShadow,
/// subtle translucent inactive state, and HapticFeedback.
class _GkkTabPill extends StatelessWidget {
  const _GkkTabPill({
    required this.active,
    required this.onTap,
    required this.child,
    this.badgeCount,
    this.badgeLabel,
  });

  final bool active;
  final VoidCallback onTap;
  final Widget child;
  final int? badgeCount;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    Widget tabBody = child;
    if (badgeCount != null || badgeLabel != null) {
      tabBody = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: child,
            ),
          ),
          const SizedBox(width: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: GkkTabBadge(
              count: badgeCount,
              label: badgeLabel,
            ),
          ),
        ],
      );
    } else {
      tabBody = FittedBox(
        fit: BoxFit.scaleDown,
        child: child,
      );
    }

    final Widget pill = GkkTabLabel(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: GkkTabBarTheme.animationDuration,
          curve: GkkTabBarTheme.animationCurve,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: active
              ? GkkTabBarTheme.selectedPillDecoration()
              : GkkTabBarTheme.unselectedPillDecoration(),
          child: DefaultTextStyle(
            style: active
                ? GkkTabBarTheme.selectedLabelStyle
                : GkkTabBarTheme.unselectedLabelStyle,
            child: IconTheme(
              data: IconThemeData(
                size: 13,
                color: active ? AppColors.carbonVoid : AppColors.mutedTitanium,
              ),
              child: tabBody,
            ),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(child: pill),
        AnimatedContainer(
          duration: GkkTabBarTheme.animationDuration,
          curve: GkkTabBarTheme.animationCurve,
          margin: const EdgeInsets.only(top: 2),
          width: active ? 18 : 0,
          height: active ? 2.5 : 0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: <Color>[
                GkkTabBarTheme.etherCyan,
                GkkTabBarTheme.celestialGold,
              ],
            ),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: GkkTabBarTheme.etherCyan.withValues(alpha: 0.85),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                    BoxShadow(
                      color: GkkTabBarTheme.celestialGold.withValues(alpha: 0.60),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}


/// 2027 Aion 2 Obsidian Frosted Glass Floating Dock Shell.
///
/// Features:
/// - Real [BackdropFilter] Gaussian blur (default sigma: 16.0)
/// - Multi-tone translucent obsidian cosmic gradient
/// - Celestial gold & ether cyan luminescence edge highlights
/// - Ambient starlight micro-dot grid matrix
class GkkFloatingDock extends StatelessWidget {
  const GkkFloatingDock({
    super.key,
    required this.child,
    this.borderRadius = GkkTabBarTheme.containerRadius,
    this.borderColor,
    this.borderWidth = 1.0,
    this.enableGlassBlur = true,
    this.blurSigma = GkkTabBarTheme.defaultBlurSigma,
    this.padding = const EdgeInsets.fromLTRB(5, 5, 5, 4),
  });

  final Widget child;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final bool enableGlassBlur;
  final double blurSigma;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Radius radius = Radius.circular(borderRadius);
    final BorderRadius br = BorderRadius.all(radius);

    final Color effectiveBorderColor = borderColor ??
        GkkTabBarTheme.celestialGold.withValues(alpha: 0.22);

    Widget dockBody = Stack(
      children: <Widget>[
        // Layer 1: Ambient starlight micro-dot grid
        const Positioned.fill(
          child: CustomPaint(
            painter: DotGridPainter(
              spacing: 12,
              dotOpacity: 0.045,
              celestialMatrix: false,
            ),
          ),
        ),

        // Layer 2: Specular top edge glint (AAA Aion 2 luminous rim)
        Positioned(
          top: 0,
          left: borderRadius * 0.5,
          right: borderRadius * 0.5,
          child: Container(
            height: 1.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.0),
                  GkkTabBarTheme.etherCyan.withValues(alpha: 0.45),
                  GkkTabBarTheme.celestialGold.withValues(alpha: 0.65),
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
          ),
        ),

        // Layer 3: Padded dock content
        Padding(
          padding: padding,
          child: child,
        ),
      ],
    );

    if (enableGlassBlur && blurSigma > 0) {
      dockBody = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: dockBody,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
        boxShadow: <BoxShadow>[
          // Deep obsidian void ambient shadow
          BoxShadow(
            color: GkkTabBarTheme.obsidianVoid.withValues(alpha: 0.70),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
          // Ether cyan luminescence edge aura
          BoxShadow(
            color: GkkTabBarTheme.etherCyan.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
          // Celestial gold specular hint
          BoxShadow(
            color: GkkTabBarTheme.celestialGold.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xDD121A2B), // Translucent elevated obsidian surface
            GkkTabBarTheme.obsidianBase.withValues(alpha: 0.88),
            GkkTabBarTheme.obsidianVoid.withValues(alpha: 0.94),
          ],
          stops: const <double>[0.0, 0.50, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: br,
        child: dockBody,
      ),
    );
  }
}

/// 2027 Aion 2 Obsidian-Glass Floating Dock Tab Bar.
///
/// Features:
/// - Real [BackdropFilter] glass blur (sigmaX: 16, sigmaY: 16)
/// - Celestial Gold (#E5C158) badge indicators & highlights
/// - Ether Cyan (#00E5FF) active tab pill glow BoxShadow
/// - Distinct selected luminescence & subtle translucent inactive states
/// - HapticFeedback.selectionClick() on tab switching
/// - Optional [SafeArea] device inset padding
class GkkTabBar extends StatelessWidget {
  const GkkTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.isScrollable,
    this.tabAlignment = TabAlignment.start,
    this.height = 48,
    this.margin,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
    this.borderRadius = GkkTabBarTheme.containerRadius,
    this.tabAnchorIds,
    this.onTabTutorialTap,
    this.badgeCounts,
    this.badgeLabels,
    this.enableGlassBlur = true,
    this.blurSigma = GkkTabBarTheme.defaultBlurSigma,
    this.enableHaptics = true,
    this.useSafeArea = false,
    this.safeAreaBottom = true,
    this.safeAreaTop = false,
    this.safeAreaLeft = true,
    this.safeAreaRight = true,
  });

  final TabController controller;
  final List<Widget> tabs;
  final bool? isScrollable;
  final TabAlignment tabAlignment;
  final double height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final List<String?>? tabAnchorIds;
  final void Function(int index, String anchorId)? onTabTutorialTap;

  /// Optional per-tab badge counts.
  final List<int?>? badgeCounts;

  /// Optional per-tab badge string labels.
  final List<String?>? badgeLabels;

  /// Whether to render real BackdropFilter gaussian blur.
  final bool enableGlassBlur;

  /// Blur sigma (defaults to 16.0 per 2027 Aion 2 spec).
  final double blurSigma;

  /// Whether to trigger HapticFeedback.selectionClick() on tab changes.
  final bool enableHaptics;

  /// Whether to wrap dock in SafeArea.
  final bool useSafeArea;
  final bool safeAreaBottom;
  final bool safeAreaTop;
  final bool safeAreaLeft;
  final bool safeAreaRight;

  /// Text-only tabs with press-scale micro-interaction and optional badge support.
  static List<Widget> textTabs(
    List<String> labels, {
    List<int?>? badgeCounts,
    List<String?>? badgeLabels,
  }) {
    return List<Widget>.generate(labels.length, (int i) {
      final int? count = (badgeCounts != null && i < badgeCounts.length) ? badgeCounts[i] : null;
      final String? label = (badgeLabels != null && i < badgeLabels.length) ? badgeLabels[i] : null;
      final Widget textWidget = Text(
        labels[i],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      if (count != null || label != null) {
        return labeledTab(
          child: badge(
            child: textWidget,
            count: count,
            label: label,
          ),
        );
      }
      return labeledTab(child: textWidget);
    }, growable: false);
  }

  /// Wrap arbitrary tab child with [GkkTabLabel].
  static Widget labeledTab({required Widget child}) => child;

  /// Wraps [child] with a 2027 Aion 2 Celestial Gold (#E5C158) badge indicator.
  static Widget badge({
    required Widget child,
    int? count,
    String? label,
    bool show = true,
    Color color = GkkTabBarTheme.celestialGold,
    Color textColor = AppColors.carbonVoid,
    Color glowColor = GkkTabBarTheme.etherCyan,
  }) {
    if (!show || ((count == null || count <= 0) && (label == null || label.isEmpty))) {
      return child;
    }
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        child,
        Positioned(
          top: -4,
          right: -8,
          child: GkkTabBadge(
            count: count,
            label: label,
            color: color,
            textColor: textColor,
            glowColor: glowColor,
          ),
        ),
      ],
    );
  }

  bool get _scrollable => isScrollable ?? tabs.length >= 5;

  @override
  Widget build(BuildContext context) {
    Widget dock = Padding(
      padding: margin ?? padding,
      child: GkkFloatingDock(
        borderRadius: borderRadius,
        enableGlassBlur: enableGlassBlur,
        blurSigma: blurSigma,
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
        child: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? _) {
            final List<Widget> pills = List<Widget>.generate(tabs.length, (int index) {
              final String? tabAnchor = tabAnchorIds != null &&
                      index < tabAnchorIds!.length
                  ? tabAnchorIds![index]
                  : null;
              final int? badgeCount = (badgeCounts != null && index < badgeCounts!.length)
                  ? badgeCounts![index]
                  : null;
              final String? badgeLabel = (badgeLabels != null && index < badgeLabels!.length)
                  ? badgeLabels![index]
                  : null;

              Widget pill = _GkkTabPill(
                active: controller.index == index,
                badgeCount: badgeCount,
                badgeLabel: badgeLabel,
                onTap: () {
                  if (tabAnchor != null) {
                    onTabTutorialTap?.call(index, tabAnchor);
                  }
                  if (controller.index != index) {
                    if (enableHaptics) {
                      HapticFeedback.selectionClick();
                    }
                    controller.animateTo(index);
                  }
                },
                child: tabs[index],
              );
              if (tabAnchor != null) {
                pill = TutorialAnchorScope(id: tabAnchor, child: pill);
              }

              if (_scrollable) {
                return Padding(
                  padding: EdgeInsets.only(right: index < tabs.length - 1 ? 6 : 0),
                  child: pill,
                );
              }

              // Expanded must be direct Row child — not under Padding.
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: pill,
                    ),
                  ),
                ),
              );
            });

            final Widget row = Row(
              mainAxisAlignment:
                  _scrollable ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
              children: pills,
            );

            return SizedBox(
              height: height,
              child: _scrollable
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: row,
                    )
                  : row,
            );
          },
        ),
      ),
    );

    if (useSafeArea) {
      dock = SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        left: safeAreaLeft,
        right: safeAreaRight,
        child: dock,
      );
    }

    return dock;
  }
}

/// Index-driven tab row — 2027 Aion 2 Obsidian-Glass Floating Dock without [TabController].
class GkkSegmentedTabBar extends StatelessWidget {
  const GkkSegmentedTabBar({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
    this.isScrollable,
    this.height = 48,
    this.margin,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
    this.borderRadius = GkkTabBarTheme.containerRadius,
    this.badgeCounts,
    this.badgeLabels,
    this.enableGlassBlur = true,
    this.blurSigma = GkkTabBarTheme.defaultBlurSigma,
    this.enableHaptics = true,
    this.useSafeArea = false,
    this.safeAreaBottom = true,
    this.safeAreaTop = false,
    this.safeAreaLeft = true,
    this.safeAreaRight = true,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final bool? isScrollable;
  final double height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final List<int?>? badgeCounts;
  final List<String?>? badgeLabels;
  final bool enableGlassBlur;
  final double blurSigma;
  final bool enableHaptics;
  final bool useSafeArea;
  final bool safeAreaBottom;
  final bool safeAreaTop;
  final bool safeAreaLeft;
  final bool safeAreaRight;

  bool get _scrollable => isScrollable ?? labels.length >= 5;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pills = List<Widget>.generate(labels.length, (int index) {
      final int? badgeCount = (badgeCounts != null && index < badgeCounts!.length)
          ? badgeCounts![index]
          : null;
      final String? badgeLabel = (badgeLabels != null && index < badgeLabels!.length)
          ? badgeLabels![index]
          : null;

      final Widget pill = _GkkTabPill(
        active: index == activeIndex,
        badgeCount: badgeCount,
        badgeLabel: badgeLabel,
        onTap: () {
          if (index != activeIndex) {
            if (enableHaptics) {
              HapticFeedback.selectionClick();
            }
            onChanged(index);
          }
        },
        child: Text(
          labels[index],
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

      if (_scrollable) {
        return Padding(
          padding: EdgeInsets.only(right: index < labels.length - 1 ? 6 : 0),
          child: pill,
        );
      }

      // Expanded must be direct Row child — not under Padding.
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: pill,
            ),
          ),
        ),
      );
    });

    final Widget row = Row(
      mainAxisAlignment: _scrollable ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
      children: pills,
    );

    Widget dock = Padding(
      padding: margin ?? padding,
      child: GkkFloatingDock(
        borderRadius: borderRadius,
        enableGlassBlur: enableGlassBlur,
        blurSigma: blurSigma,
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
        child: SizedBox(
          height: height,
          child: _scrollable
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
              : row,
        ),
      ),
    );

    if (useSafeArea) {
      dock = SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        left: safeAreaLeft,
        right: safeAreaRight,
        child: dock,
      );
    }

    return dock;
  }
}

