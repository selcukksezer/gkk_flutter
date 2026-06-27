import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'game_chrome.dart';

/// Scroll list layout — moderate gaps between sections; bottom bar clearance at end.
abstract final class GameScrollLayout {
  /// Major blocks (hero, panel groups, section titles + content).
  static const double sectionGap = AppSpacing.md;

  /// Stacked cards or rows inside one block.
  static const double itemGap = AppSpacing.sm;

  /// Section title → first child below it.
  static const double titleGap = AppSpacing.sm;

  static Widget get sectionSpacer => const SizedBox(height: sectionGap);
  static Widget get itemSpacer => const SizedBox(height: itemGap);
  static Widget get titleSpacer => const SizedBox(height: titleGap);

  static EdgeInsets pagePadding(BuildContext context) => padding(context);

  /// Bottom inset so last scroll item clears [GameBottomBar] (extendBody safe).
  static double bottomInset(BuildContext context) => gameBottomBarClearance(context);

  /// Standard scroll padding — bottom always clears overlay nav.
  static EdgeInsets padding(
    BuildContext context, {
    double horizontal = AppSpacing.base,
    double top = AppSpacing.base,
    double bottomExtra = 0,
  }) =>
      EdgeInsets.fromLTRB(
        horizontal,
        top,
        horizontal,
        bottomInset(context) + bottomExtra,
      );

  /// Like [padding] with explicit edges; bottom = bar clearance (+ optional extra).
  static EdgeInsets fromLTRB(
    BuildContext context, {
    required double left,
    required double top,
    required double right,
    double bottomExtra = 0,
  }) =>
      EdgeInsets.fromLTRB(
        left,
        top,
        right,
        bottomInset(context) + bottomExtra,
      );

  /// Keeps L/T/R from [base]; bottom = bar clearance + [base.bottom].
  static EdgeInsets withClearance(BuildContext context, EdgeInsets base) =>
      EdgeInsets.fromLTRB(
        base.left,
        base.top,
        base.right,
        bottomInset(context) + base.bottom,
      );

  static Widget bottomSpacer(BuildContext context) =>
      SizedBox(height: bottomInset(context));
}

/// Wraps a scroll block with consistent top spacing (skip [leadingGap] on first item).
class GameScrollSection extends StatelessWidget {
  const GameScrollSection({
    super.key,
    required this.child,
    this.leadingGap = true,
  });

  final Widget child;
  final bool leadingGap;

  @override
  Widget build(BuildContext context) {
    if (!leadingGap) return child;
    return Padding(
      padding: const EdgeInsets.only(top: GameScrollLayout.sectionGap),
      child: child,
    );
  }
}

/// Fixed-column grid for [ListView] children — avoids [GridView] shrinkWrap phantom space.
class GameFixedGrid extends StatelessWidget {
  const GameFixedGrid({
    super.key,
    required this.crossAxisCount,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = AppSpacing.sm,
  });

  final int crossAxisCount;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();

    final List<Widget> items = List<Widget>.generate(
      itemCount,
      (int index) => itemBuilder(context, index),
    );

    return GameGridColumns(
      crossAxisCount: crossAxisCount,
      spacing: spacing,
      children: items,
    );
  }
}

/// Fixed-height grid rows for [ListView] children — avoids [GridView] shrinkWrap phantom space.
class GameGridColumns extends StatelessWidget {
  const GameGridColumns({
    super.key,
    required this.crossAxisCount,
    required this.children,
    this.spacing = AppSpacing.sm,
  });

  final int crossAxisCount;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i += crossAxisCount) {
      if (i > 0) rows.add(SizedBox(height: spacing));
      final List<Widget> rowChildren = <Widget>[];
      for (int col = 0; col < crossAxisCount; col++) {
        if (col > 0) rowChildren.add(SizedBox(width: spacing));
        final int index = i + col;
        rowChildren.add(
          Expanded(
            child: index < children.length ? children[index] : const SizedBox.shrink(),
          ),
        );
      }
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowChildren,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Dotted grid overlay — Carbon Void / Space Navy aesthetic.
class DotGridPainter extends CustomPainter {
  const DotGridPainter({
    this.spacing = 16,
    this.dotRadius = 1.1,
    this.dotOpacity = 0.07,
  });

  final double spacing;
  final double dotRadius;
  final double dotOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: dotOpacity)
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) =>
      spacing != oldDelegate.spacing ||
      dotRadius != oldDelegate.dotRadius ||
      dotOpacity != oldDelegate.dotOpacity;
}

/// Full-screen background — home-style gradient + dot grid + subtle ambient glow.
class GameScreenBackground extends StatelessWidget {
  const GameScreenBackground({
    super.key,
    required this.child,
    this.showAmbientGlow = true,
  });

  final Widget child;
  final bool showAmbientGlow;

  static const Color carbonVoid = Color(0xFF080B12);
  static const Color spaceNavy = Color(0xFF121826);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF070B14),
                  carbonVoid,
                  Color(0xFF030509),
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: CustomPaint(painter: DotGridPainter()),
        ),
        if (showAmbientGlow) ...<Widget>[
          Positioned(
            top: -160,
            left: -120,
            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      spaceNavy.withValues(alpha: 0.45),
                      spaceNavy.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            right: -140,
            child: IgnorePointer(
              child: Container(
                width: 460,
                height: 460,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.gold.withValues(alpha: 0.06),
                      AppColors.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        child,
      ],
    );
  }
}

/// Card/panel shell with dotted dark surface (#121826 → #080B12).
class DottedPanel extends StatelessWidget {
  const DottedPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 14,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.06),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            GameScreenBackground.spaceNavy.withValues(alpha: 0.92),
            GameScreenBackground.carbonVoid.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(
                painter: DotGridPainter(spacing: 14, dotOpacity: 0.055),
              ),
            ),
            Padding(
              padding: padding ?? const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
