import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/live_ticker_model.dart';
import '../../providers/live_ticker_provider.dart';
import '../../theme/app_colors.dart';
import 'ticker_design.dart';

/// Single-line announcement strip.
/// One notice at a time → slides ~8s → after 3 global server passes, retired for everyone.
class LiveTicker extends ConsumerStatefulWidget {
  const LiveTicker({super.key});

  @override
  ConsumerState<LiveTicker> createState() => _LiveTickerState();
}

class _LiveTickerState extends ConsumerState<LiveTicker>
    with SingleTickerProviderStateMixin {
  static const Duration _passDuration = Duration(milliseconds: 8000);

  late final AnimationController _ctrl;
  String? _playingId;
  String _playingText = '';
  LiveTickerVisual _playingVisual = LiveTickerVisual.forType('ambient');
  double _textWidth = 0;
  bool _kickStarted = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _passDuration);
    _ctrl.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_onStatus);
    _ctrl.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    ref.read(liveTickerProvider.notifier).onPassComplete();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAndPlay(forceRestart: true);
    });
  }

  static const TextStyle _textStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 13,
    color: Colors.white,
    height: 1.1,
  );

  double _measureText(String text, [BuildContext? context]) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: _textStyle,
      ),
      textDirection: context != null
          ? (Directionality.maybeOf(context) ?? TextDirection.ltr)
          : TextDirection.ltr,
      textScaler: context != null
          ? (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling)
          : TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    return painter.width + 8;
  }

  void _syncAndPlay({bool forceRestart = false}) {
    final LiveTickerItem? head = ref.read(liveTickerProvider).current;
    final String nextId = head?.id ?? 'fallback:quiet';
    final String nextText =
        head?.text ?? '🌌 Kamp sessiz… yeni efsaneler yazılıyor.';
    final LiveTickerVisual nextVisual =
        head?.visual ?? LiveTickerVisual.forType('ambient');

    final bool changed = nextId != _playingId || nextText != _playingText;
    if (!changed && !forceRestart && _ctrl.isAnimating) return;

    _playingId = nextId;
    _playingText = nextText;
    _playingVisual = nextVisual;
    _textWidth = _measureText(nextText);
    _ctrl
      ..duration = _passDuration
      ..forward(from: 0);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final LiveTickerItem? current = ref.watch(
      liveTickerProvider.select((LiveTickerState s) => s.current),
    );

    final String headId = current?.id ?? 'fallback:quiet';
    final String text =
        current?.text ?? '🌌 Kamp sessiz… yeni efsaneler yazılıyor.';
    final LiveTickerVisual visual =
        current?.visual ?? LiveTickerVisual.forType('ambient');

    final double measured = _measureText(text, context);
    _textWidth = measured;

    final bool idChanged = headId != _playingId;
    if (!_kickStarted) {
      _kickStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncAndPlay(forceRestart: true);
      });
    } else if (idChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncAndPlay(forceRestart: true);
      });
    }

    if (visual.icon != _playingVisual.icon && headId == _playingId) {
      _playingVisual = visual;
    }

    return TickerGlassShell(
      accent: _playingVisual.accent,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 32,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double viewW = constraints.maxWidth;
            final double tw = _textWidth > 0 ? _textWidth : measured;

            return Row(
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.campaign_rounded,
                    size: 16,
                    color: AppColors.gold,
                  ),
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: ClipRect(
                      child: AnimatedBuilder(
                        animation: _ctrl,
                        builder: (BuildContext context, Widget? child) {
                          final double start = viewW;
                          final double end = -tw;
                          final double left = start +
                              (end - start) *
                                  Curves.linear.transform(_ctrl.value);
                          return Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              Positioned(
                                left: left,
                                top: 0,
                                bottom: 0,
                                child: child!,
                              ),
                            ],
                          );
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) => LinearGradient(
                              colors: <Color>[
                                TickerPalette.textHi,
                                _playingVisual.accent,
                                TickerPalette.textHi,
                              ],
                              stops: const <double>[0.0, 0.5, 1.0],
                            ).createShader(bounds),
                            child: Text(
                              text,
                              maxLines: 1,
                              softWrap: false,
                              style: _textStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
