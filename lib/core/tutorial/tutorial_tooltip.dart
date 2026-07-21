import 'package:flutter/material.dart';

class TutorialTooltipCard extends StatelessWidget {
  const TutorialTooltipCard({
    super.key,
    required this.title,
    required this.body,
    required this.stepIndex,
    required this.stepTotal,
    required this.onSkipAll,
    this.onDismiss,
    this.primaryLabel,
    this.onPrimary,
    this.showLater = true,
  });

  final String title;
  final String body;
  final int stepIndex;
  final int stepTotal;
  final VoidCallback onSkipAll;
  final VoidCallback? onDismiss;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool showLater;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF141B2A).withValues(alpha: 0.98),
            const Color(0xFF0B1018).withValues(alpha: 0.98),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFF5C842).withValues(alpha: 0.35),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$stepIndex / $stepTotal',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              TextButton(onPressed: onSkipAll, child: const Text('Tümünü Atla')),
              const Spacer(),
              if (showLater && onDismiss != null)
                TextButton(
                  onPressed: onDismiss,
                  child: Text(primaryLabel == null ? 'Tamam' : 'Sonra'),
                ),
              if (primaryLabel != null && onPrimary != null) ...<Widget>[
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF5C842),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(primaryLabel!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Positions tooltip near anchor rect.
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
    if (top + 180 > screen.height) {
      top = anchorRect.top - margin - 180;
    }
    if (top < margin) top = margin;

    double left = anchorRect.center.dx - 160;
    left = left.clamp(margin, screen.width - 320 - margin);

    return Positioned(
      left: left,
      top: top,
      child: child,
    );
  }
}
