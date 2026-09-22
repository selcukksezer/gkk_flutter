import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Animated tap hint over spotlight targets — zıplayan el + nabız halkası.
class TutorialHandHint extends StatefulWidget {
  const TutorialHandHint({super.key, this.accent = AppColors.liquidGold});

  final Color accent;

  @override
  State<TutorialHandHint> createState() => _TutorialHandHintState();
}

class _TutorialHandHintState extends State<TutorialHandHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (BuildContext context, Widget? _) {
          final double t = _ctrl.value;
          // El: aşağı in-çık (0→0.5 in, 0.5→1 çık)
          final double bounce =
              t < 0.5 ? Curves.easeIn.transform(t * 2) : Curves.easeOut.transform((1 - t) * 2);
          // Halka: el "değdiği" anda (t~0.5) doğar, büyüyüp söner
          final double ringT = ((t - 0.45) / 0.55).clamp(0.0, 1.0);

          return SizedBox(
            width: 64,
            height: 72,
            child: Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                if (ringT > 0 && ringT < 1)
                  Positioned(
                    top: 26,
                    child: Container(
                      width: 14 + ringT * 30,
                      height: 14 + ringT * 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.accent
                              .withValues(alpha: (1 - ringT) * 0.7),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: bounce * 12,
                  child: const Text('👆', style: TextStyle(fontSize: 30)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
