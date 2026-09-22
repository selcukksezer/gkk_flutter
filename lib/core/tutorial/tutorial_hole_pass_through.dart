import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lets hits inside [hole] fall through to widgets below this subtree.
///
/// [hole] must be in this widget's **local** coordinates (same space as
/// [TutorialInputGate] / overlay paint), not global screen coords.
class TutorialHolePassThrough extends SingleChildRenderObjectWidget {
  const TutorialHolePassThrough({
    super.key,
    required this.hole,
    super.child,
  });

  final Rect hole;

  @override
  RenderHolePassThrough createRenderObject(BuildContext context) {
    return RenderHolePassThrough(hole: hole);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderHolePassThrough renderObject,
  ) {
    renderObject.hole = hole;
  }
}

class RenderHolePassThrough extends RenderProxyBox {
  RenderHolePassThrough({required Rect hole}) : _hole = hole;

  Rect _hole;
  set hole(Rect value) {
    if (_hole == value) return;
    _hole = value;
    markNeedsPaint();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Local coords — do NOT convert to global.
    if (_hole.contains(position)) {
      return false;
    }
    return super.hitTest(result, position: position);
  }
}
