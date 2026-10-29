import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// 2027 Aion 2 Mobile — Pulsing Ethereal Lock-in Aura.
/// Displays an undulating runic energy aura and a glowing lock-in seal banner
/// when a player confirms / locks their trade offer.
class TradeLockInAura extends StatefulWidget {
  const TradeLockInAura({
    super.key,
    required this.child,
    required this.isLockedIn,
    this.auraColor = AppColors.toxicNeon,
    this.secondaryColor = AppColors.liquidGold,
    this.lockLabel = 'KİLİTLENDİ',
    this.unlockedLabel = 'DÜZENLENİYOR',
    this.showBanner = true,
  });

  final Widget child;
  final bool isLockedIn;
  final Color auraColor;
  final Color secondaryColor;
  final String lockLabel;
  final String unlockedLabel;
  final bool showBanner;

  @override
  State<TradeLockInAura> createState() => _TradeLockInAuraState();
}

class _TradeLockInAuraState extends State<TradeLockInAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
    if (widget.isLockedIn) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant TradeLockInAura oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLockedIn != oldWidget.isLockedIn) {
      if (widget.isLockedIn) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLockedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.showBanner) _buildStatusHeader(isLocked: false, pulse: 0.0),
          widget.child,
        ],
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (BuildContext context, Widget? child) {
        final double pulse = _pulseAnimation.value;
        final double auraAlpha = 0.25 + (0.35 * pulse);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.auraColor.withValues(alpha: auraAlpha),
                blurRadius: 18 + (12 * pulse),
                spreadRadius: 1.5 + (2.0 * pulse),
              ),
              BoxShadow(
                color: widget.secondaryColor.withValues(alpha: auraAlpha * 0.45),
                blurRadius: 28,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.showBanner) _buildStatusHeader(isLocked: true, pulse: pulse),
              CustomPaint(
                foregroundPainter: _AuraBorderPulsePainter(
                  accent: widget.auraColor,
                  pulse: pulse,
                ),
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader({required bool isLocked, required double pulse}) {
    final Color badgeColor = isLocked ? widget.auraColor : AppColors.mutedTitanium;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: isLocked
              ? <Color>[
                  widget.auraColor.withValues(alpha: 0.28),
                  AppColors.carbonVoid.withValues(alpha: 0.85),
                  widget.auraColor.withValues(alpha: 0.22),
                ]
              : <Color>[
                  AppColors.darkObsidian.withValues(alpha: 0.6),
                  AppColors.carbonVoid.withValues(alpha: 0.7),
                ],
        ),
        border: Border.all(
          color: isLocked
              ? widget.auraColor.withValues(alpha: 0.5 + (0.35 * pulse))
              : AppColors.darkObsidian,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            isLocked ? Icons.lock : Icons.lock_open,
            size: 13,
            color: badgeColor,
          ),
          const SizedBox(width: 6),
          Text(
            isLocked ? widget.lockLabel : widget.unlockedLabel,
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          if (isLocked) ...<Widget>[
            const SizedBox(width: 6),
            Icon(Icons.auto_awesome, size: 11, color: widget.auraColor.withValues(alpha: 0.9)),
          ],
        ],
      ),
    );
  }
}

class _AuraBorderPulsePainter extends CustomPainter {
  const _AuraBorderPulsePainter({required this.accent, required this.pulse});
  final Color accent;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );

    final Paint borderPulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 + (0.8 * pulse)
      ..color = accent.withValues(alpha: 0.45 + (0.45 * pulse));

    canvas.drawRRect(rrect, borderPulsePaint);
  }

  @override
  bool shouldRepaint(covariant _AuraBorderPulsePainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.accent != accent;
}

/// Aion 2 Mobile — Center Nexus Dual Lock-in Indicator.
/// Visually bridges You and Partner's offer status with runic interlocking energy.
class TradeDualLockIndicator extends StatelessWidget {
  const TradeDualLockIndicator({
    super.key,
    required this.myConfirmed,
    required this.partnerConfirmed,
    this.myName = 'Sen',
    this.partnerName = 'Karşı Taraf',
  });

  final bool myConfirmed;
  final bool partnerConfirmed;
  final String myName;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final bool bothConfirmed = myConfirmed && partnerConfirmed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.carbonVoid.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: bothConfirmed
              ? AppColors.toxicNeon.withValues(alpha: 0.7)
              : AppColors.darkObsidian.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: bothConfirmed
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.toxicNeon.withValues(alpha: 0.28),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        children: <Widget>[
          // My Status
          Expanded(
            child: Row(
              children: <Widget>[
                _buildLockIcon(myConfirmed, AppColors.liquidGold),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        myName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        myConfirmed ? 'Kilitlendi' : 'Bekleniyor',
                        style: TextStyle(
                          color: myConfirmed ? AppColors.toxicNeon : AppColors.mutedTitanium,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Center Nexus Sigil
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bothConfirmed
                  ? AppColors.toxicNeon.withValues(alpha: 0.2)
                  : AppColors.darkObsidian,
              border: Border.all(
                color: bothConfirmed
                    ? AppColors.toxicNeon.withValues(alpha: 0.8)
                    : AppColors.mutedTitanium.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              bothConfirmed ? Icons.vpn_key : Icons.sync_alt,
              size: 15,
              color: bothConfirmed ? AppColors.toxicNeon : AppColors.mutedTitanium,
            ),
          ),

          // Partner Status
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        partnerName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        partnerConfirmed ? 'Kilitlendi' : 'Bekleniyor',
                        style: TextStyle(
                          color: partnerConfirmed ? AppColors.toxicNeon : AppColors.mutedTitanium,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _buildLockIcon(partnerConfirmed, AppColors.toxicNeon),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockIcon(bool locked, Color accent) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: locked ? accent.withValues(alpha: 0.2) : AppColors.darkObsidian,
        border: Border.all(
          color: locked ? accent : AppColors.mutedTitanium.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Icon(
          locked ? Icons.check : Icons.lock_open,
          size: 13,
          color: locked ? accent : AppColors.mutedTitanium,
        ),
      ),
    );
  }
}
