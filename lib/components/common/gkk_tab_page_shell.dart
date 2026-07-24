import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../layout/game_chrome.dart';
import '../layout/game_screen_background.dart';

/// Section header — gold accent bar (monumentSectionTitle pattern).
class GkkTabSectionTitle extends StatelessWidget {
  const GkkTabSectionTitle(
    this.title, {
    super.key,
    this.accent = AppColors.liquidGold,
    this.trailing,
  });

  final String title;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
              boxShadow: <BoxShadow>[
                BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h3.copyWith(fontSize: 15),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Fade + slide list item on tab/content load.
class GkkTabStaggerItem extends StatelessWidget {
  const GkkTabStaggerItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDelayMs = 40,
  });

  final int index;
  final Widget child;
  final int baseDelayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('gkk_stagger_${index}_${child.hashCode}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index % 10) * baseDelayMs),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Premium tab body shell — dot mesh, optional section title, entrance motion.
class GkkTabPageShell extends StatelessWidget {
  const GkkTabPageShell({
    super.key,
    required this.tabIndex,
    required this.child,
    this.sectionTitle,
    this.sectionAccent = AppColors.liquidGold,
    this.padding,
  });

  final int tabIndex;
  final Widget child;
  final String? sectionTitle;
  final Color sectionAccent;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(tabIndex),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: animatedChild,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (sectionTitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: GkkTabSectionTitle(sectionTitle!, accent: sectionAccent),
            ),
          Expanded(
            child: CustomPaint(
              foregroundPainter: const DotGridPainter(spacing: 16, dotOpacity: 0.045),
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrap [TabBarView] page — handles scroll + section header outside list.
class GkkTabScrollShell extends StatelessWidget {
  const GkkTabScrollShell({
    super.key,
    required this.tabIndex,
    required this.sectionTitle,
    required this.child,
    this.sectionAccent = AppColors.liquidGold,
    this.onRefresh,
  });

  final int tabIndex;
  final String sectionTitle;
  final Widget child;
  final Color sectionAccent;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget content = CustomPaint(
      foregroundPainter: const DotGridPainter(spacing: 16, dotOpacity: 0.045),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: GameScrollLayout.withClearance(
          context,
          const EdgeInsets.fromLTRB(14, 10, 14, 24),
        ),
        children: <Widget>[
          GkkTabSectionTitle(sectionTitle, accent: sectionAccent),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );

    if (onRefresh != null) {
      content = RefreshIndicator(
        color: sectionAccent,
        onRefresh: onRefresh!,
        child: content,
      );
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(tabIndex),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: content,
          ),
        );
      },
    );
  }
}

/// DottedPanel list row — replaces flat ListTile shells in tab bodies.
class GkkTabListCard extends StatelessWidget {
  const GkkTabListCard({
    super.key,
    required this.child,
    this.borderColor,
    this.padding,
  });

  final Widget child;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      borderColor: borderColor ?? AppColors.liquidGold.withValues(alpha: 0.16),
      child: child,
    );
  }
}
