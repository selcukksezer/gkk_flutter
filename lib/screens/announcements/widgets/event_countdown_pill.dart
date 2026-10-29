import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';

/// Active event countdown timer pill with 2027 AAA Studio V3 standards:
/// luminous pulsing beacon, high-contrast tabular chronometer display,
/// living sonar radar waves, smooth mechanical ticks, luxury glass borders,
/// and interactive modal breakdown sheet.
class EventCountdownPill extends StatefulWidget {
  const EventCountdownPill({
    super.key,
    required this.endTime,
    this.startTime,
    this.compact = false,
    this.prefixLabel,
    this.interactive = true,
    this.onTap,
    this.eventTitle,
  });

  final DateTime endTime;
  final DateTime? startTime;
  final bool compact;
  final String? prefixLabel;
  final bool interactive;
  final VoidCallback? onTap;
  final String? eventTitle;

  @override
  State<EventCountdownPill> createState() => _EventCountdownPillState();
}

class _EventCountdownPillState extends State<EventCountdownPill>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;
  late Animation<double> _sonarExpansion;

  late AnimationController _tickController;
  late Animation<double> _tickScale;

  Timer? _timer;
  late Duration _remaining;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();

    // 1. Ambient luminous breathing & sonar radar wave controller
    _pulseController = AnimationController(
      vsync: this,
      duration: _calculatePulseDuration(_remaining),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.88, end: 1.22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _pulseOpacity = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _sonarExpansion = Tween<double>(begin: 0.2, end: 1.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    // 2. Micro tick-bounce clockwork animation (fires on every second change)
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _tickScale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.035)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.035, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 65,
      ),
    ]).animate(_tickController);

    _startTimer();
  }

  Duration _calculatePulseDuration(Duration rem) {
    if (rem.isNegative) return const Duration(milliseconds: 2000);
    // Accelerated heartbeat pulse when urgent (< 2 hours)
    if (rem.inHours < 2) return const Duration(milliseconds: 800);
    if (rem.inHours < 6) return const Duration(milliseconds: 1100);
    return const Duration(milliseconds: 1500);
  }

  void _checkPacing() {
    final Duration desired = _calculatePulseDuration(_remaining);
    if (_pulseController.duration != desired) {
      _pulseController.duration = desired;
      if (_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final Duration next = _calculateRemaining();
      setState(() {
        _remaining = next;
      });

      if (!next.isNegative) {
        _tickController.forward(from: 0.0);
        _checkPacing();
      } else {
        _timer?.cancel();
      }
    });
  }

  Duration _calculateRemaining() {
    final DateTime now = DateTime.now();
    return widget.endTime.difference(now);
  }

  @override
  void didUpdateWidget(EventCountdownPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTime != widget.endTime) {
      _remaining = _calculateRemaining();
      _checkPacing();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _tickController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.interactive) return;
    HapticFeedback.lightImpact();
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    _showDetailSheet();
  }

  void _showDetailSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _EventCountdownDetailSheet(
        startTime: widget.startTime,
        endTime: widget.endTime,
        eventTitle: widget.eventTitle ?? widget.prefixLabel,
      ),
    );
  }

  String _formatDuration(Duration d, {bool isCompact = false}) {
    if (d.isNegative) return 'Sona Erdi';
    final int days = d.inDays;
    final int hours = d.inHours % 24;
    final int minutes = d.inMinutes % 60;
    final int seconds = d.inSeconds % 60;

    if (days > 0) {
      return isCompact ? '${days}g ${hours}sa' : '${days}g ${hours}sa ${minutes}dk';
    }
    final String h = hours.toString().padLeft(2, '0');
    final String m = minutes.toString().padLeft(2, '0');
    final String s = seconds.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bool isExpired = _remaining.isNegative;
    final bool isUrgent = !isExpired && _remaining.inHours < 2;
    final bool isEndingSoon = !isExpired && _remaining.inHours < 6;

    final Color statusColor = isExpired
        ? AppColors.textDisabled
        : (isUrgent
            ? AppColors.coralFlare
            : (isEndingSoon ? AppColors.liquidGold : AppColors.toxicNeon));

    final String timeStr = _formatDuration(_remaining, isCompact: widget.compact);
    final String label = widget.prefixLabel ??
        (isExpired
            ? 'BİTTİ'
            : (isUrgent
                ? 'SON SAATLER'
                : (isEndingSoon ? 'YAKINDA BİTİYOR' : 'CANLI ETKİNLİK')));

    // Compact layout (used inside banner overlays, cards, header chips)
    if (widget.compact) {
      final Widget compactWidget = RepaintBoundary(
        child: AnimatedScale(
          scale: _isPressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      const Color(0xEE0D1424),
                      const Color(0xFA070B16),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: statusColor.withValues(alpha: isExpired ? 0.28 : 0.65),
                    width: 1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: statusColor.withValues(alpha: isExpired ? 0.03 : 0.24),
                      blurRadius: 8,
                      spreadRadius: -1,
                    ),
                    const BoxShadow(
                      color: Color(0x70000000),
                      blurRadius: 4,
                      offset: Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!isExpired) ...<Widget>[
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (BuildContext context, Widget? child) {
                          return _SonarBeacon(
                            color: statusColor,
                            scale: _pulseScale.value,
                            opacity: _pulseOpacity.value,
                            sonarExpansion: _sonarExpansion.value,
                            size: 6.0,
                          );
                        },
                      ),
                      const SizedBox(width: 5),
                    ],
                    ScaleTransition(
                      scale: _tickScale,
                      child: Text(
                        timeStr,
                        style: TextStyle(
                          color: isExpired ? AppColors.textDisabled : AppColors.textPrimary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          fontFamily: 'monospace',
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                          shadows: <Shadow>[
                            if (!isExpired)
                              Shadow(
                                color: statusColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      if (widget.interactive) {
        return GestureDetector(
          onTapDown: (_) {
            HapticFeedback.selectionClick();
            setState(() => _isPressed = true);
          },
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: Tooltip(
            message: isExpired ? 'Etkinlik sona erdi' : 'Kalan süre: $timeStr (Detaylar)',
            child: compactWidget,
          ),
        );
      }
      return compactWidget;
    }

    // Standard high-fidelity pill layout with luxury runic ornaments
    final Widget standardWidget = RepaintBoundary(
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: CustomPaint(
              foregroundPainter: _PillOrnamentPainter(
                color: statusColor.withValues(alpha: isExpired ? 0.25 : 0.60),
                accentColor: isUrgent ? AppColors.coralFlare : AppColors.liquidGold,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xF411182B),
                      Color(0xF80B101F),
                      Color(0xFD060810),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: statusColor.withValues(alpha: isExpired ? 0.32 : 0.75),
                    width: 1.15,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: statusColor.withValues(alpha: isExpired ? 0.04 : 0.32),
                      blurRadius: 12,
                      spreadRadius: -1,
                    ),
                    const BoxShadow(
                      color: Color(0x90000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!isExpired) ...<Widget>[
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (BuildContext context, Widget? child) {
                          return _SonarBeacon(
                            color: statusColor,
                            scale: _pulseScale.value,
                            opacity: _pulseOpacity.value,
                            sonarExpansion: _sonarExpansion.value,
                            size: 7.0,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                        shadows: <Shadow>[
                          Shadow(
                            color: statusColor.withValues(alpha: 0.35),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      width: 1.2,
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            statusColor.withValues(alpha: 0.1),
                            statusColor.withValues(alpha: 0.7),
                            statusColor.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    ScaleTransition(
                      scale: _tickScale,
                      child: Text(
                        timeStr,
                        style: TextStyle(
                          color: isExpired ? AppColors.textDisabled : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                          letterSpacing: 0.5,
                          shadows: <Shadow>[
                            if (!isExpired)
                              Shadow(
                                color: statusColor.withValues(alpha: 0.45),
                                blurRadius: 5,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.interactive) ...<Widget>[
                      const SizedBox(width: 5),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: statusColor.withValues(alpha: 0.8),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.interactive) {
      return GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: isExpired ? 'Etkinlik sona erdi' : 'Kalan süre: $timeStr (Detaylar)',
          child: standardWidget,
        ),
      );
    }
    return standardWidget;
  }
}

/// Luminous multi-layer radar beacon with expanding sonar wave ring.
class _SonarBeacon extends StatelessWidget {
  const _SonarBeacon({
    required this.color,
    required this.scale,
    required this.opacity,
    required this.sonarExpansion,
    required this.size,
  });

  final Color color;
  final double scale;
  final double opacity;
  final double sonarExpansion;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double outerDiameter = size * 2.2;
    return SizedBox(
      width: outerDiameter,
      height: outerDiameter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // 1. Expanding sonar radar wave
          Opacity(
            opacity: (1.0 - (sonarExpansion / 2.0)).clamp(0.0, 0.65),
            child: Container(
              width: size * (1.0 + sonarExpansion),
              height: size * (1.0 + sonarExpansion),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.55),
                  width: 0.9,
                ),
              ),
            ),
          ),
          // 2. Soft halo aura
          Container(
            width: size * 1.5 * scale,
            height: size * 1.5 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.22 * opacity),
            ),
          ),
          // 3. Radiant core dot
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: opacity),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.9),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet presenting full event schedule, real-time chronometer breakdown,
/// and elapsed progression bar.
class _EventCountdownDetailSheet extends StatefulWidget {
  const _EventCountdownDetailSheet({
    required this.endTime,
    this.startTime,
    this.eventTitle,
  });

  final DateTime endTime;
  final DateTime? startTime;
  final String? eventTitle;

  @override
  State<_EventCountdownDetailSheet> createState() => _EventCountdownDetailSheetState();
}

class _EventCountdownDetailSheetState extends State<_EventCountdownDetailSheet> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.endTime.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final Duration next = widget.endTime.difference(DateTime.now());
      setState(() {
        _remaining = next;
      });
      if (next.isNegative) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double _calculateProgress() {
    final DateTime now = DateTime.now();
    if (widget.startTime == null) {
      if (_remaining.isNegative) return 1.0;
      // Synthesize 48-hour progress for display completeness
      const int horizonHours = 48;
      final double fraction = 1.0 - (_remaining.inSeconds / (horizonHours * 3600));
      return fraction.clamp(0.05, 0.95);
    }

    final int totalMs = widget.endTime.millisecondsSinceEpoch -
        widget.startTime!.millisecondsSinceEpoch;
    if (totalMs <= 0) return 1.0;
    final int elapsedMs = now.millisecondsSinceEpoch -
        widget.startTime!.millisecondsSinceEpoch;
    return (elapsedMs / totalMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isExpired = _remaining.isNegative;
    final bool isUrgent = !isExpired && _remaining.inHours < 2;
    final bool isEndingSoon = !isExpired && _remaining.inHours < 6;

    final Color statusColor = isExpired
        ? AppColors.textDisabled
        : (isUrgent
            ? AppColors.coralFlare
            : (isEndingSoon ? AppColors.liquidGold : AppColors.toxicNeon));

    final String statusBadgeText = isExpired
        ? 'SONA ERDİ'
        : (isUrgent
            ? 'ACİL - SON SAATLER'
            : (isEndingSoon ? 'YAKINDA BİTİYOR' : 'CANLI ETKİNLİK'));

    final int days = isExpired ? 0 : _remaining.inDays;
    final int hours = isExpired ? 0 : _remaining.inHours % 24;
    final int minutes = isExpired ? 0 : _remaining.inMinutes % 60;
    final int seconds = isExpired ? 0 : _remaining.inSeconds % 60;

    final double progress = _calculateProgress();
    final int progressPercent = (progress * 100).toInt();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xF5101628),
                Color(0xF90A0E1A),
                Color(0xFD060810),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.45),
              width: 1.3,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: statusColor.withValues(alpha: 0.25),
                blurRadius: 28,
                spreadRadius: -3,
                offset: const Offset(0, -4),
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 24,
                spreadRadius: 6,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Drag Handle with Specular Gradient
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.white12,
                            Colors.white54,
                            Colors.white12,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with badge
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          isExpired
                              ? Icons.timer_off_outlined
                              : Icons.timer_outlined,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.eventTitle ?? 'Etkinlik Geri Sayımı',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'GKK Canlı Etkinlik Takibi • 2027 AAA Studio V3',
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          statusBadgeText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Event Timeline Progress Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x99131A2B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              isExpired ? 'Etkinlik Tamamlandı' : 'Etkinlik İlerlemesi',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              isExpired ? '%100' : '%$progressPercent',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: <Widget>[
                              Container(
                                height: 6,
                                width: double.infinity,
                                color: Colors.white10,
                              ),
                              FractionallySizedBox(
                                widthFactor: progress,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        statusColor.withValues(alpha: 0.6),
                                        statusColor,
                                      ],
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: statusColor.withValues(alpha: 0.7),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Digital chronometer units or expired state
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.borderFaint,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            Icons.event_busy_rounded,
                            size: 36,
                            color: AppColors.textSecondary.withValues(alpha: 0.65),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Bu etkinlik sona ermiştir',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Yeni etkinlik duyuruları ve ödüller için ana merkezi takipte kalın.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: <Widget>[
                        _buildUnitBox('GÜN', days.toString().padLeft(2, '0'), statusColor),
                        const SizedBox(width: 8),
                        _buildUnitBox('SAAT', hours.toString().padLeft(2, '0'), statusColor),
                        const SizedBox(width: 8),
                        _buildUnitBox('DAKİKA', minutes.toString().padLeft(2, '0'), statusColor),
                        const SizedBox(width: 8),
                        _buildUnitBox('SANİYE', seconds.toString().padLeft(2, '0'), statusColor),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Schedule info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x99141B2A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.borderDefault.withValues(alpha: 0.65),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        if (widget.startTime != null) ...<Widget>[
                          _buildInfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Başlangıç Tarihi',
                            value: _formatDateTimeTurkish(widget.startTime!),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: Colors.white12, height: 1),
                          ),
                        ],
                        _buildInfoRow(
                          icon: Icons.event_available_outlined,
                          label: 'Bitiş Tarihi',
                          value: _formatDateTimeTurkish(widget.endTime),
                        ),
                      ],
                    ),
                  ),

                  // Urgent notice if ending soon
                  if (isUrgent) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.coralFlare.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.coralFlare.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.coralFlare,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Etkinlik 2 saatten kısa süre sonra kapanacaktır. Ödüllerinizi almayı unutmayın!',
                              style: TextStyle(
                                color: AppColors.coralFlare.withValues(alpha: 0.95),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Dismiss button with luxury border
                  ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E283C),
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: statusColor.withValues(alpha: 0.45),
                          width: 1.1,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Anladım',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitBox(String label, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xCC162033),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.38),
            width: 1.1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accentColor.withValues(alpha: 0.10),
              blurRadius: 10,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                color: accentColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
                letterSpacing: 0.5,
                shadows: <Shadow>[
                  Shadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Custom painter rendering subtle corner rune bracket ornaments & specular edge gleam
/// for Aion 2 Dark Fantasy aesthetic.
class _PillOrnamentPainter extends CustomPainter {
  const _PillOrnamentPainter({
    required this.color,
    this.accentColor,
  });

  final Color color;
  final Color? accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double notch = 4.5;
    // Top-left
    canvas.drawLine(const Offset(notch, 1), const Offset(1, 1), paint);
    canvas.drawLine(const Offset(1, 1), const Offset(1, notch), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - notch, 1), Offset(size.width - 1, 1), paint);
    canvas.drawLine(Offset(size.width - 1, 1), Offset(size.width - 1, notch), paint);

    // Bottom-left
    canvas.drawLine(Offset(1, size.height - notch), Offset(1, size.height - 1), paint);
    canvas.drawLine(Offset(1, size.height - 1), Offset(notch, size.height - 1), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - notch, size.height - 1), Offset(size.width - 1, size.height - 1), paint);
    canvas.drawLine(Offset(size.width - 1, size.height - 1), Offset(size.width - 1, size.height - notch), paint);

    // Specular top highlight gleam
    final Paint specularPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.0),
          (accentColor ?? Colors.white).withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 1))
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(size.width * 0.25, 0.5),
      Offset(size.width * 0.75, 0.5),
      specularPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PillOrnamentPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accentColor != accentColor;
}

/// Turkish date-time formatter without external package dependencies.
String _formatDateTimeTurkish(DateTime dt) {
  const List<String> months = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  final String day = dt.day.toString();
  final String month = months[dt.month - 1];
  final String year = dt.year.toString();
  final String hour = dt.hour.toString().padLeft(2, '0');
  final String min = dt.minute.toString().padLeft(2, '0');
  return '$day $month $year, $hour:$min';
}

