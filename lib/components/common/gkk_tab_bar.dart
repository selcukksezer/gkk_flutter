import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../layout/game_screen_background.dart';

/// Tasarım-system defaults for [GkkTabBar] — exportable for ThemeData wiring.
abstract final class GkkTabBarTheme {
  static const Duration animationDuration = Duration(milliseconds: 250);
  static const Curve animationCurve = Curves.easeOutCubic;
  static const double pressedScale = 0.96;

  static const double containerRadius = 14;
  static const double pillRadius = 999;

  static BoxDecoration selectedPillDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(pillRadius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          AppColors.liquidGold,
          Color(0xFFE8A800),
          AppColors.goldDim,
        ],
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: AppColors.liquidGold.withValues(alpha: 0.38),
          blurRadius: 14,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: AppColors.cyberFuchsia.withValues(alpha: 0.12),
          blurRadius: 8,
          spreadRadius: -2,
        ),
      ],
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
        color: AppColors.mutedTitanium,
        letterSpacing: 0.1,
      );

  static TabBarThemeData tabBarTheme({TabAlignment tabAlignment = TabAlignment.start}) {
    return TabBarThemeData(
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: AppColors.liquidGold,
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

/// Single pill segment — Liquid Gold selected, transparent unselected + fuchsia dot.
class _GkkTabPill extends StatelessWidget {
  const _GkkTabPill({
    required this.active,
    required this.onTap,
    required this.child,
    this.expanded = false,
  });

  final bool active;
  final VoidCallback onTap;
  final Widget child;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final Widget pill = GkkTabLabel(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: GkkTabBarTheme.animationDuration,
          curve: GkkTabBarTheme.animationCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: active ? GkkTabBarTheme.selectedPillDecoration() : null,
          child: DefaultTextStyle(
            style: active
                ? GkkTabBarTheme.selectedLabelStyle
                : GkkTabBarTheme.unselectedLabelStyle,
            child: IconTheme(
              data: IconThemeData(
                size: 13,
                color: active ? AppColors.carbonVoid : AppColors.mutedTitanium,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );

    final Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        pill,
        AnimatedContainer(
          duration: GkkTabBarTheme.animationDuration,
          curve: GkkTabBarTheme.animationCurve,
          margin: const EdgeInsets.only(top: 3),
          width: active ? 16 : 0,
          height: active ? 2 : 0,
          decoration: BoxDecoration(
            color: AppColors.cyberFuchsia,
            borderRadius: BorderRadius.circular(1),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.cyberFuchsia.withValues(alpha: 0.65),
                      blurRadius: 5,
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );

    if (expanded) {
      return Expanded(child: column);
    }
    return column;
  }
}

/// Segmented pill rail inside [DottedPanel] — no Material TabBar indicator styling.
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
  });

  final TabController controller;
  final List<Widget> tabs;
  final bool? isScrollable;
  final TabAlignment tabAlignment;
  final double height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Text-only tabs with press-scale micro-interaction.
  static List<Widget> textTabs(List<String> labels) {
    return labels
        .map(
          (String label) => labeledTab(child: Text(label)),
        )
        .toList(growable: false);
  }

  /// Wrap arbitrary tab child with [GkkTabLabel].
  static Widget labeledTab({required Widget child}) => child;

  bool get _scrollable => isScrollable ?? tabs.length >= 5;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? padding,
      child: DottedPanel(
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
        borderRadius: borderRadius,
        borderColor: AppColors.liquidGold.withValues(alpha: 0.2),
        child: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? _) {
            final List<Widget> pills = List<Widget>.generate(tabs.length, (int index) {
              final Widget pill = _GkkTabPill(
                active: controller.index == index,
                expanded: !_scrollable,
                onTap: () {
                  if (controller.index != index) {
                    controller.animateTo(index);
                  }
                },
                child: tabs[index],
              );

              if (_scrollable) {
                return Padding(
                  padding: EdgeInsets.only(right: index < tabs.length - 1 ? 6 : 0),
                  child: pill,
                );
              }

              return Padding(
                padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
                child: pill,
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
  }
}

/// Index-driven tab row — same DottedPanel pill rail without [TabController].
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
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final bool? isScrollable;
  final double height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  bool get _scrollable => isScrollable ?? labels.length >= 5;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pills = List<Widget>.generate(labels.length, (int index) {
      final Widget pill = _GkkTabPill(
        active: index == activeIndex,
        expanded: !_scrollable,
        onTap: () => onChanged(index),
        child: Text(
          labels[index],
          textAlign: TextAlign.center,
        ),
      );

      if (_scrollable) {
        return Padding(
          padding: EdgeInsets.only(right: index < labels.length - 1 ? 6 : 0),
          child: pill,
        );
      }

      return Padding(
        padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
        child: pill,
      );
    });

    final Widget row = Row(
      mainAxisAlignment: _scrollable ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
      children: pills,
    );

    return Padding(
      padding: margin ?? padding,
      child: DottedPanel(
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
        borderRadius: borderRadius,
        borderColor: AppColors.liquidGold.withValues(alpha: 0.2),
        child: SizedBox(
          height: height,
          child: _scrollable
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
              : row,
        ),
      ),
    );
  }
}
