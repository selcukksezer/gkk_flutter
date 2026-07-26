import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Dot mesh background per tasarım skill.
class TutorialDotPattern extends StatelessWidget {
  const TutorialDotPattern({super.key, this.opacity = 0.08});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TutorialDotPainter(
        color: AppColors.mutedTitanium.withValues(alpha: opacity),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TutorialDotPainter extends CustomPainter {
  _TutorialDotPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 12;
    final Paint paint = Paint()..color = color;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TutorialDotPainter oldDelegate) =>
      oldDelegate.color != color;
}

class TutorialTooltipCard extends StatelessWidget {
  const TutorialTooltipCard({
    super.key,
    required this.title,
    required this.body,
    required this.stepIndex,
    required this.stepTotal,
    required this.onSkipAll,
    this.skipAllLabel = 'Tümünü Atla',
    this.onDismiss,
    this.primaryLabel,
    this.onPrimary,
    this.showLater = true,
    this.accent = AppColors.liquidGold,
  });

  final String title;
  final String body;
  final int stepIndex;
  final int stepTotal;
  final VoidCallback onSkipAll;
  final String skipAllLabel;
  final VoidCallback? onDismiss;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool showLater;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final double progress =
        stepTotal <= 0 ? 0 : (stepIndex / stepTotal).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.spaceNavy.withValues(alpha: 0.96),
                AppColors.carbonVoid.withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              const TutorialDotPattern(opacity: 0.07),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: accent.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            'REHBER',
                            style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$stepIndex / $stepTotal',
                          style: TextStyle(
                            color: AppColors.mutedTitanium.withValues(alpha: 0.95),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: AppColors.darkObsidian,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: TextStyle(
                        color: AppColors.mutedTitanium.withValues(alpha: 0.95),
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        TextButton(
                          onPressed: onSkipAll,
                          child: Text(
                            skipAllLabel,
                            style: TextStyle(
                              color: AppColors.mutedTitanium.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (showLater && onDismiss != null)
                          TextButton(
                            onPressed: onDismiss,
                            child: Text(
                              primaryLabel == null ? 'Tamam' : 'Sonra',
                              style: const TextStyle(
                                color: AppColors.mutedTitanium,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (primaryLabel != null && onPrimary != null) ...<Widget>[
                          const SizedBox(width: 6),
                          FilledButton(
                            onPressed: onPrimary,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: AppColors.carbonVoid,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              primaryLabel!,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TutorialTooltipPositioned extends StatelessWidget {
  const TutorialTooltipPositioned({
    super.key,
    required this.anchorRect,
    required this.child,
  });

  final Rect anchorRect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    const double margin = 12;
    double top = anchorRect.bottom + margin;
    if (top + 220 > screen.height) {
      top = anchorRect.top - margin - 220;
    }
    if (top < margin) top = margin;

    double left = anchorRect.center.dx - 170;
    left = left.clamp(margin, screen.width - 360 - margin);

    return Positioned(left: left, top: top, child: child);
  }
}

class TutorialPausedBanner extends StatelessWidget {
  const TutorialPausedBanner({
    super.key,
    required this.routeLabel,
    required this.onNavigate,
    this.onSkipAll,
    this.skipAllLabel = 'Atla',
  });

  final String routeLabel;
  final VoidCallback onNavigate;
  final VoidCallback? onSkipAll;
  final String skipAllLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: <Color>[
                    AppColors.cyberFuchsia.withValues(alpha: 0.22),
                    AppColors.spaceNavy.withValues(alpha: 0.92),
                  ],
                ),
                border: Border.all(
                  color: AppColors.cyberFuchsia.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Text('📍', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rehber devam ediyor — $routeLabel ekranına git',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onNavigate,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.liquidGold,
                      foregroundColor: AppColors.carbonVoid,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Git', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  if (onSkipAll != null) ...<Widget>[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: skipAllLabel,
                      onPressed: onSkipAll,
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.mutedTitanium.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
