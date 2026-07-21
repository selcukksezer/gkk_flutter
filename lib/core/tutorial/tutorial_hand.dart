import 'package:flutter/material.dart';

/// Animated tap hint over spotlight targets.
class TutorialHandHint extends StatefulWidget {
  const TutorialHandHint({super.key});

  @override
  State<TutorialHandHint> createState() => _TutorialHandHintState();
}

class _TutorialHandHintState extends State<TutorialHandHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bounce = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (BuildContext context, Widget? child) {
        return Transform.translate(
          offset: Offset(0, _bounce.value),
          child: child,
        );
      },
      child: const IgnorePointer(
        child: Text('👆', style: TextStyle(fontSize: 28)),
      ),
    );
  }
}
