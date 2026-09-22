import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'tutorial_track.dart';

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

/// Premium rehber kartı — track madalyonu, adım noktaları, parıltılı CTA.
class TutorialTooltipCard extends StatelessWidget {
  const TutorialTooltipCard({
    super.key,
    required this.title,
    required this.body,
    required this.stepIndex,
    required this.stepTotal,
    this.onSkipAll,
    this.skipAllLabel = 'Tümünü Atla',
    this.onDismiss,
    this.primaryLabel,
    this.onPrimary,
    this.showLater = true,
    this.accent = AppColors.liquidGold,
    this.trackEmoji = '✨',
    this.trackLabel = 'REHBER',
  });

  final String title;
  final String body;
  final int stepIndex;
  final int stepTotal;
  final VoidCallback? onSkipAll;
  final String skipAllLabel;
  final VoidCallback? onDismiss;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool showLater;
  final Color accent;
  final String trackEmoji;
  final String trackLabel;

  @override
  Widget build(BuildContext context) {
    // No BackdropFilter — Impeller+SimMetal SaveLayer crashes simulator GPU host.
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.spaceNavy.withValues(alpha: 0.98),
            AppColors.carbonVoid,
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 16,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: TutorialDotPattern(opacity: 0.06)),
            // Üst accent ışık şeridi
            Positioned(
              top: 0,
              left: 24,
              right: 24,
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      accent.withValues(alpha: 0),
                      accent,
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      // Track madalyonu
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              accent.withValues(alpha: 0.3),
                              accent.withValues(alpha: 0.05),
                            ],
                          ),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.6),
                            width: 1.4,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            trackEmoji,
                            style: const TextStyle(fontSize: 19),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              trackLabel.toUpperCase(),
                              style: TextStyle(
                                color: accent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _StepDots(
                              index: stepIndex,
                              total: stepTotal,
                              accent: accent,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '$stepIndex/$stepTotal',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: <Color>[
                          accent,
                          accent.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: TextStyle(
                      color: AppColors.mutedTitanium.withValues(alpha: 0.96),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      if (onSkipAll != null)
                        TextButton(
                          onPressed: onSkipAll,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(
                            skipAllLabel,
                            style: TextStyle(
                              color: AppColors.mutedTitanium
                                  .withValues(alpha: 0.7),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (showLater && onDismiss != null)
                        TextButton(
                          onPressed: onDismiss,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
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
                        _GlowButton(
                          label: primaryLabel!,
                          accent: accent,
                          onPressed: onPrimary!,
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
    );
  }
}

/// Adım ilerleme noktaları — tamamlanan dolu, aktif parlak, kalan sönük.
class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.index,
    required this.total,
    required this.accent,
  });

  final int index;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Çok adımlı tracklerde nokta sayısını sınırla; ilerleme çubuğuna düş.
    if (total > 8) {
      final double progress =
          total <= 0 ? 0 : (index / total).clamp(0.0, 1.0);
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 120,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= total; i++) ...<Widget>[
          if (i > 1) const SizedBox(width: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i < index
                  ? accent.withValues(alpha: 0.55)
                  : i == index
                      ? accent
                      : Colors.white.withValues(alpha: 0.12),
              boxShadow: i == index
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.55),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _GlowButton extends StatelessWidget {
  const _GlowButton({
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              accent,
              Color.lerp(accent, Colors.black, 0.25)!,
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.carbonVoid,
            fontWeight: FontWeight.w900,
            fontSize: 13,
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
    this.anchorId,
  });

  final Rect anchorRect;
  final Widget child;
  final String? anchorId;

  /// Tall spotlight (skills panels, etc.) — pin coach to top so Devam stays on-screen.
  static bool isTallHole(Rect hole, Size screen) =>
      hole.height > screen.height * 0.28;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    const double margin = 12;
    const double cardMaxWidth = 360;
    const double clearance = 24;

    double left = anchorRect.center.dx - cardMaxWidth / 2;
    left = left.clamp(margin, screen.width - cardMaxWidth - margin);

    // Huge highlight (class abilities / long cards): never park coach under hole —
    // Devam would sit below the fold / under bottom nav.
    if (isTallHole(anchorRect, screen)) {
      final double top = safe.top + 12;
      final double maxHeight =
          (screen.height - safe.bottom - 96 - top).clamp(220.0, 360.0);
      return Positioned(
        left: left,
        top: top,
        width: cardMaxWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Align(
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      );
    }

    final bool topHeavy = (anchorId != null && anchorId!.startsWith('hud.')) ||
        anchorRect.top < screen.height * 0.22;

    final bool bottomHeavy = !topHeavy &&
        ((anchorId != null &&
                (anchorId!.startsWith('nav.') ||
                    anchorId == TutorialAnchorId.dungeonEnterBtn ||
                    anchorId == TutorialAnchorId.dungeonConfirmOk ||
                    anchorId == TutorialAnchorId.dungeonAttackBtn ||
                    anchorId == TutorialAnchorId.enhanceForgeBtn ||
                    anchorId == TutorialAnchorId.inventoryEquipBtn)) ||
            anchorRect.bottom > screen.height * 0.70);

    // Top HUD (gold/gems/energy): pin coach BELOW hole — never cover chips.
    // Also never sit in the top status band (replay stale holes).
    if (topHeavy) {
      final double minTop = safe.top + 96;
      final double preferred = anchorRect.bottom + clearance;
      final double top = preferred < minTop ? minTop : preferred;
      final double maxHeight =
          (screen.height - safe.bottom - margin - top).clamp(120.0, 360.0);
      return Positioned(
        left: left,
        top: top,
        width: cardMaxWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: child,
            ),
          ),
        ),
      );
    }

    // Bottom-nav / lower CTAs: pin coach card in upper band — never cover hole.
    // Tight height (no expanding Align) so empty maxHeight band cannot steal taps.
    // Scroll when card taller than band (equip modal mid-screen → ~13px overflow).
    if (bottomHeavy) {
      final double maxBottom = (anchorRect.top - clearance)
          .clamp(safe.top + 120, screen.height - safe.bottom - margin);
      final double top = safe.top + 16;
      final double maxHeight = (maxBottom - top).clamp(120.0, 320.0);
      return Positioned(
        left: left,
        top: top,
        width: cardMaxWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cardMaxWidth, maxHeight: maxHeight),
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: child,
            ),
          ),
        ),
      );
    }

    final double spaceBelow =
        screen.height - safe.bottom - margin - (anchorRect.bottom + margin);
    final double spaceAbove = anchorRect.top - safe.top - (margin * 2);
    final bool placeAbove = spaceBelow < spaceAbove || spaceBelow < 160;

    if (placeAbove) {
      final double regionBottom = screen.height - anchorRect.top + clearance;
      final double maxHeight =
          (anchorRect.top - clearance - safe.top - margin).clamp(100.0, 360.0);
      // Too little room above a mid hole → fall back to top pin (tall-hole style).
      if (maxHeight < 200) {
        final double top = safe.top + 12;
        final double pinnedMax =
            (screen.height - safe.bottom - 96 - top).clamp(220.0, 360.0);
        return Positioned(
          left: left,
          top: top,
          width: cardMaxWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: pinnedMax),
            child: Align(
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      }
      return Positioned(
        left: left,
        top: safe.top + margin,
        bottom: regionBottom,
        width: cardMaxWidth,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: child,
            ),
          ),
        ),
      );
    }

    final double maxHeight =
        (screen.height - safe.bottom - margin - anchorRect.bottom - margin)
            .clamp(100.0, 360.0);
    return Positioned(
      left: left,
      top: anchorRect.bottom + margin,
      bottom: safe.bottom + margin,
      width: cardMaxWidth,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: child,
          ),
        ),
      ),
    );
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
                    AppColors.spaceNavy.withValues(alpha: 0.94),
                  ],
                ),
                border: Border.all(
                  color: AppColors.cyberFuchsia.withValues(alpha: 0.45),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                    // No IconButton.tooltip — TutorialHost sits above
                    // Navigator Overlay (MaterialApp.builder), Tooltip → crash.
                    Semantics(
                      button: true,
                      label: skipAllLabel,
                      child: IconButton(
                        onPressed: onSkipAll,
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppColors.mutedTitanium.withValues(alpha: 0.8),
                          size: 18,
                        ),
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
