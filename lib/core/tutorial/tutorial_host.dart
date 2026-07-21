import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tutorial_anchor_registry.dart';
import 'tutorial_controller.dart';
import 'tutorial_hand.dart';
import 'tutorial_input_gate.dart';
import 'tutorial_spotlight_layer.dart';
import 'tutorial_tooltip.dart';
import 'tutorial_track.dart';
import 'tutorial_track_registry.dart';

/// Global spotlight tutorial overlay host.
class TutorialHost extends ConsumerStatefulWidget {
  const TutorialHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TutorialHost> createState() => _TutorialHostState();
}

class _TutorialHostState extends ConsumerState<TutorialHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tutorialProvider.notifier).initialize();
    });
    TutorialAnchorRegistry.instance.addListener(_onAnchorsChanged);
  }

  @override
  void dispose() {
    TutorialAnchorRegistry.instance.removeListener(_onAnchorsChanged);
    super.dispose();
  }

  void _onAnchorsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final TutorialState tutorial = ref.watch(tutorialProvider);
    final TutorialStepV2? step = tutorial.activeStep;
    final String? trackId = tutorial.activeTrackId;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
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

class _SpotlightOverlayState extends State<_SpotlightOverlay> {
  int _waitFrames = 0;

  @override
  void initState() {
    super.initState();
    _kickAnchorWait();
  }

  @override
  void didUpdateWidget(covariant _SpotlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.id != widget.step.id ||
        oldWidget.step.anchorId != widget.step.anchorId) {
      _waitFrames = 0;
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
      // Anchor not laid out yet (dialog / list / route transition). Keep polling
      // briefly so we never flash a fake narrative "Devam" card.
      if (_waitFrames < 45) {
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

    final bool narrative = widget.step.mode == TutorialMode.narrative ||
        widget.step.mode == TutorialMode.waitEvent;

    if (narrative) {
      return Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: TutorialTooltipCard(
                title: widget.step.title,
                body: widget.step.body,
                stepIndex: index,
                stepTotal: total,
                onSkipAll: widget.onSkipAll,
                onDismiss: widget.step.mode == TutorialMode.waitEvent
                    ? null
                    : widget.onDismiss,
                showLater: widget.step.mode != TutorialMode.waitEvent,
                primaryLabel: widget.step.primaryLabel ??
                    (widget.step.mode == TutorialMode.waitEvent
                        ? null
                        : 'Devam'),
                onPrimary: widget.step.mode == TutorialMode.waitEvent
                    ? null
                    : widget.onPrimary,
              ),
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

    // Anchor missing → wait overlay (NOT narrative dismiss). Prevents messy
    // "Devam" spam while dialogs / lists mount.
    if (hole == null) {
      return Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: TutorialTooltipCard(
                title: widget.step.title,
                body: widget.step.body,
                stepIndex: index,
                stepTotal: total,
                onSkipAll: widget.onSkipAll,
                onDismiss: null,
                showLater: false,
                primaryLabel: null,
                onPrimary: null,
              ),
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
          // highlightOnly: complete on hole tap (no screen hook required).
          // spotlightTap: hole passes through to UI; screens call onAnchorTap.
          if (widget.step.mode == TutorialMode.highlightOnly)
            Positioned.fromRect(
              rect: hole,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onHighlightTap,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          TutorialTooltipPositioned(
            anchorRect: hole,
            child: TutorialTooltipCard(
              title: widget.step.title,
              body: widget.step.body,
              stepIndex: index,
              stepTotal: total,
              onSkipAll: widget.onSkipAll,
              onDismiss: null,
              showLater: false,
              primaryLabel: null,
              onPrimary: null,
            ),
          ),
        ],
      ),
    );
  }
}
