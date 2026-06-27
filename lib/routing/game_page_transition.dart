import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

const Duration kGameTransitionDuration = Duration(milliseconds: 360);

/// RPG-style fade-through-dark-veil transition. Replaces default mobile slide.
Page<T> buildGamePage<T>({
  required GoRouterState state,
  required Widget child,
  bool instant = false,
}) {
  if (instant) {
    return NoTransitionPage<T>(
      key: state.pageKey,
      child: child,
    );
  }

  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: kGameTransitionDuration,
    reverseTransitionDuration: kGameTransitionDuration,
    transitionsBuilder: _gameTransitionBuilder,
  );
}

Widget _gameTransitionBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (BuildContext context, Widget? _) {
      // Transition done — plain child, no overlay stack blocking touches.
      if (animation.status == AnimationStatus.completed ||
          animation.status == AnimationStatus.dismissed) {
        return child;
      }

      final double t = animation.value;
      // If the route is rebuilt before the first animation tick (common during
      // startup redirect churn), opacity stays at 0 and the screen looks black.
      if (t == 0 && animation.status == AnimationStatus.forward) {
        return child;
      }
      final double veilOpacity = t <= 0.45 ? t / 0.45 : (1 - t) / 0.55;
      final double contentOpacity = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
      final double scale = 0.97 + (0.03 * contentOpacity);
      final double glowOpacity =
          ((veilOpacity - 0.55) * 2.2).clamp(0.0, 1.0) * 0.12;

      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Veil below — visual only, never steals touches.
          IgnorePointer(
            child: ColoredBox(
              color: AppColors.bgDeep.withValues(alpha: veilOpacity.clamp(0.0, 1.0)),
            ),
          ),
          if (glowOpacity > 0)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.gold.withValues(alpha: glowOpacity),
                      Colors.transparent,
                    ],
                    radius: 1.1,
                  ),
                ),
              ),
            ),
          // Content on top — receives all pointer events.
          Opacity(
            opacity: contentOpacity,
            child: Transform.scale(scale: scale, child: child),
          ),
        ],
      );
    },
  );
}

/// [GoRoute] with game page transition applied.
GoRoute gameRoute({
  required String path,
  required Widget Function(BuildContext context, GoRouterState state) build,
  bool instant = false,
  List<RouteBase> routes = const <RouteBase>[],
}) {
  return GoRoute(
    path: path,
    routes: routes,
    pageBuilder: (BuildContext context, GoRouterState state) {
      return buildGamePage<void>(
        state: state,
        instant: instant,
        child: build(context, state),
      );
    },
  );
}
