import 'package:flutter/material.dart';

/// Hide soft keyboard by removing primary focus.
void dismissKeyboard([BuildContext? context]) {
  final FocusNode? focus = FocusManager.instance.primaryFocus;
  if (focus != null && focus.hasFocus) {
    focus.unfocus();
  }
}

/// Tap empty/non-field area → keyboard down. Interactive children keep priority.
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({
    super.key,
    required this.child,
    this.behavior = HitTestBehavior.translucent,
  });

  final Widget child;
  final HitTestBehavior behavior;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: behavior,
      onTap: dismissKeyboard,
      child: child,
    );
  }
}
