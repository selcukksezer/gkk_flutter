import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../routing/app_router.dart';
import 'tutorial_anchor_registry.dart';
import 'tutorial_controller.dart';
import 'tutorial_hand.dart';
import 'tutorial_input_gate.dart';
import 'tutorial_l10n.dart';
import 'tutorial_navigation.dart';
import 'tutorial_spotlight_layer.dart';
import 'tutorial_tooltip.dart';
import 'tutorial_track.dart';
import 'tutorial_track_registry.dart';

/// Global spotlight tutorial overlay host (v3).
class TutorialHost extends ConsumerStatefulWidget {
  const TutorialHost({
    super.key,
    required this.child,
    required this.router,
  });

  final Widget child;
  final GoRouter router;

  @override
  ConsumerState<TutorialHost> createState() => _TutorialHostState();
}

class _TutorialHostState extends ConsumerState<TutorialHost> {
  String? _syncedRoute;

  @override
  void initState() {
    super.initState();
    TutorialNavigationBridge.register(_navigateToRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tutorialProvider.notifier).initialize();
    });
    TutorialAnchorRegistry.instance.addListener(_onAnchorsChanged);
  }

  @override
  void dispose() {
    TutorialNavigationBridge.register(null);
    TutorialAnchorRegistry.instance.removeListener(_onAnchorsChanged);
    super.dispose();
  }

  Future<void> _navigateToRoute(String route) async {
    if (!mounted) return;
    if (route == AppRoutes.home) {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  void _onAnchorsChanged() {
    if (mounted) setState(() {});
  }

  void _syncRoute(String route) {
    if (_syncedRoute == route) return;
    _syncedRoute = route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(tutorialProvider.notifier).onRouteEnter(route);
    });
  }

  /// GoRouter.state throws before the first match exists (startup).
  String? _activeRoutePath() {
    final RouteMatchList config = widget.router.routerDelegate.currentConfiguration;
    if (config.isEmpty) return null;
    final String path = config.fullPath;
    if (path.isEmpty) return AppRoutes.splash;
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.router.routerDelegate,
      builder: (BuildContext context, Widget? _) {
        final String? route = _activeRoutePath();
        if (route != null) {
          _syncRoute(route);
        }

        final TutorialState tutorial = ref.watch(tutorialProvider);
        final TutorialStepV2? step = tutorial.activeStep;
        final String? trackId = tutorial.activeTrackId;
        final String? pausedHint =
            ref.read(tutorialProvider.notifier).pausedRouteHint;

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            widget.child,
            if (tutorial.overlayPaused &&
                step != null &&
                pausedHint != null)
              TutorialPausedBanner(
                routeLabel: pausedHint,
                onNavigate: () => ref
                    .read(tutorialProvider.notifier)
                    .navigateToActiveStepRoute(),
                onSkipAll: () => ref.read(tutorialProvider.notifier).skipAll(),
                skipAllLabel: context.l10n.tutSkipAll,
              ),
            if (step != null && trackId != null && !tutorial.overlayPaused)
              _SpotlightOverlay(
                step: step,
                trackId: trackId,
                wrongTapShake: tutorial.wrongTapShake,
                onSkipAll: () => ref.read(tutorialProvider.notifier).skipAll(),
                onDismiss: () =>
                    ref.read(tutorialProvider.notifier).completeActiveManual(),
                onWrongTap: () =>
                    ref.read(tutorialProvider.notifier).registerWrongTap(),
                onPrimary: () =>
                    ref.read(tutorialProvider.notifier).completeActiveManual(),
                onHighlightTap: () {
                  final String? anchorId = step.anchorId;
                  if (anchorId == null) return;
                  ref.read(tutorialProvider.notifier).onAnchorTap(anchorId);
                },
              ),
          ],
        );
      },
    );
  }
}

class _SpotlightOverlay extends StatefulWidget {
  const _SpotlightOverlay({
    required this.step,
    required this.trackId,
    required this.wrongTapShake,
    required this.onSkipAll,
    required this.onDismiss,
    required this.onWrongTap,
    required this.onPrimary,
    required this.onHighlightTap,
  });

  final TutorialStepV2 step;
  final String trackId;
  final int wrongTapShake;
  final VoidCallback onSkipAll;
  final VoidCallback onDismiss;
  final VoidCallback onWrongTap;
  final VoidCallback onPrimary;
  final VoidCallback onHighlightTap;

  @override
  State<_SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<_SpotlightOverlay>
    with SingleTickerProviderStateMixin {
  int _waitFrames = 0;
  late final AnimationController _enterCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void initState() {
    super.initState();
    _kickAnchorWait();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SpotlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.id != widget.step.id ||
        oldWidget.step.anchorId != widget.step.anchorId) {
      _waitFrames = 0;
      _enterCtrl.forward(from: 0);
      _kickAnchorWait();
    }
  }

  void _kickAnchorWait() {
    if (!widget.step.needsAnchor) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final String? anchorId = widget.step.anchorId;
      if (anchorId == null) return;
      final Rect? hole = TutorialAnchorRegistry.instance.rectFor(
        anchorId,
        padding: const EdgeInsets.all(4),
      );
      if (hole != null) {
        if (_waitFrames != 0) setState(() => _waitFrames = 0);
        return;
      }
      if (_waitFrames < 60) {
        _waitFrames++;
        TutorialAnchorRegistry.instance.scheduleRefresh();
        setState(() {});
        _kickAnchorWait();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final TutorialTrack? track =
        TutorialTrackRegistry.trackById(widget.trackId);
    final int total = track?.steps.length ?? 1;
    final int index = (track?.steps
                .indexWhere((TutorialStepV2 s) => s.id == widget.step.id) ??
            0) +
        1;

    final String title = TutorialL10n.title(context, widget.step);
    final String body = TutorialL10n.body(context, widget.step);
    final String? primaryLabel =
        TutorialL10n.primaryLabel(context, widget.step);
    final String skipAllLabel = context.l10n.tutSkipAll;

    final bool narrative = widget.step.mode == TutorialMode.narrative ||
        widget.step.mode == TutorialMode.waitEvent;

    final Widget card = FadeTransition(
      opacity: CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic)),
        child: TutorialTooltipCard(
          title: title,
          body: body,
          stepIndex: index,
          stepTotal: total,
          onSkipAll: widget.onSkipAll,
          skipAllLabel: skipAllLabel,
          onDismiss: widget.step.mode == TutorialMode.waitEvent
              ? null
              : widget.onDismiss,
          showLater: widget.step.mode != TutorialMode.waitEvent,
          primaryLabel: primaryLabel ??
              (widget.step.mode == TutorialMode.waitEvent
                  ? null
                  : context.l10n.tutContinue),
          onPrimary: widget.step.mode == TutorialMode.waitEvent
              ? null
              : widget.onPrimary,
          accent: narrative ? const Color(0xFFE01E5A) : const Color(0xFFFFB800),
        ),
      ),
    );

    if (narrative) {
      return Material(
        color: Colors.black.withValues(alpha: 0.62),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: card,
            ),
          ),
        ),
      );
    }

    final Rect? hole = widget.step.anchorId == null
        ? null
        : TutorialAnchorRegistry.instance.rectFor(
            widget.step.anchorId!,
            padding: const EdgeInsets.all(4),
          );

    if (hole == null) {
      return Material(
        color: Colors.black.withValues(alpha: 0.62),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: card,
            ),
          ),
        ),
      );
    }

    return TutorialInputGate(
      hole: hole,
      onWrongTap: widget.onWrongTap,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          TutorialSpotlightLayer(hole: hole),
          Positioned(
            left: hole.center.dx - 14,
            top: hole.center.dy - 28,
            child: const TutorialHandHint(),
          ),
          if (widget.step.mode == TutorialMode.highlightOnly)
            Positioned.fromRect(
              rect: hole,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onHighlightTap,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          TutorialTooltipPositioned(anchorRect: hole, child: card),
        ],
      ),
    );
  }
}
