import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Blocks taps outside the spotlight hole; hole area passes through to UI below.
///
/// Stack order is critical: tap-blockers sit UNDER [child] so coach card
/// buttons (Devam / Sonra) always receive hits. Empty areas fall through the
/// (mostly IgnorePointer) child stack to the blockers.
class TutorialInputGate extends StatelessWidget {
  const TutorialInputGate({
    super.key,
    required this.hole,
    required this.onWrongTap,
    required this.child,
  });

  final Rect? hole;
  final VoidCallback onWrongTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final Rect? target = hole;

    final List<Widget> blockers;
    if (target == null) {
      blockers = <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              onWrongTap();
            },
            child: const SizedBox.expand(),
          ),
        ),
      ];
    } else {
      blockers = <Widget>[
        _DimTapBlock(
          rect: Rect.fromLTWH(0, 0, size.width, target.top),
          onTap: onWrongTap,
        ),
        _DimTapBlock(
          rect: Rect.fromLTWH(
            0,
            target.bottom,
            size.width,
            size.height - target.bottom,
          ),
          onTap: onWrongTap,
        ),
        _DimTapBlock(
          rect: Rect.fromLTWH(0, target.top, target.left, target.height),
          onTap: onWrongTap,
        ),
        _DimTapBlock(
          rect: Rect.fromLTWH(
            target.right,
            target.top,
            size.width - target.right,
            target.height,
          ),
          onTap: onWrongTap,
        ),
      ];
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Blockers first (bottom) — child/coach card last (top) so Devam works.
        ...blockers,
        child,
      ],
    );
  }
}

class _DimTapBlock extends StatelessWidget {
  const _DimTapBlock({required this.rect, required this.onTap});

  final Rect rect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (rect.width <= 0 || rect.height <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned.fromRect(
      rect: rect,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: const ColoredBox(color: Colors.transparent),
      ),
    );
  }
}
