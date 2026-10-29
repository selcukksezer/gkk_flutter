import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'comeback_models.dart';

/// Exclusive Comeback Buff Indicator Badge and Banner for Returning Warriors.
class ComebackBuffBadge extends StatefulWidget {
  const ComebackBuffBadge({
    super.key,
    required this.buffInfo,
    this.compact = false,
    this.onTap,
  });

  final ComebackBuffInfo buffInfo;
  final bool compact;
  final VoidCallback? onTap;

  @override
  State<ComebackBuffBadge> createState() => _ComebackBuffBadgeState();
}

class _ComebackBuffBadgeState extends State<ComebackBuffBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _showBuffDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _ComebackBuffDetailsSheet(buffInfo: widget.buffInfo),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactBadge(context);
    }
    return _buildExpandedBanner(context);
  }

  Widget _buildCompactBadge(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? () => _showBuffDetails(context),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _shimmerCtrl,
        builder: (BuildContext context, Widget? child) {
          final double t = _shimmerCtrl.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment(-1.0 + 2.0 * t, -1.0),
                end: Alignment(1.0 + 2.0 * t, 1.0),
                colors: <Color>[
                  AppColors.darkObsidian.withValues(alpha: 0.95),
                  AppColors.liquidGold.withValues(alpha: 0.25),
                  AppColors.darkObsidian.withValues(alpha: 0.95),
                ],
                stops: const <double>[0.0, 0.5, 1.0],
              ),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.7),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.22),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.warningSolar,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '+${widget.buffInfo.expBoostPercent}% EXP',
                  style: GoogleFonts.urbanist(
                    color: AppColors.liquidGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: AppColors.mutedTitanium,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.buffInfo.remainingFormatted,
                  style: GoogleFonts.urbanist(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpandedBanner(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? () => _showBuffDetails(context),
      child: AnimatedBuilder(
        animation: _shimmerCtrl,
        builder: (BuildContext context, Widget? child) {
          final double t = _shimmerCtrl.value;
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.carbonVoid.withValues(alpha: 0.88),
                      const Color(0xFF161C24).withValues(alpha: 0.94),
                    ],
                  ),
                  border: Border.all(
                    color: Color.lerp(
                      AppColors.liquidGold.withValues(alpha: 0.4),
                      AppColors.warningSolar.withValues(alpha: 0.75),
                      (math.sin(t * 2 * math.pi) + 1) / 2,
                    )!,
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: <Color>[
                                AppColors.warningSolar,
                                AppColors.liquidGold,
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.warningSolar.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.carbonVoid,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      widget.buffInfo.name,
                                      style: GoogleFonts.urbanist(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.liquidGold.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppColors.liquidGold.withValues(alpha: 0.5),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      'AKTİF BUFF',
                                      style: GoogleFonts.urbanist(
                                        color: AppColors.liquidGold,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.buffInfo.subtitle,
                                style: const TextStyle(
                                  color: AppColors.mutedTitanium,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkObsidian.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color: AppColors.mutedTitanium.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.timer_outlined,
                                color: AppColors.liquidGold,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.buffInfo.remainingFormatted,
                                style: GoogleFonts.urbanist(
                                  color: AppColors.liquidGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _BuffStatChip(
                            icon: Icons.trending_up_rounded,
                            label: '+${widget.buffInfo.expBoostPercent}% EXP',
                            color: AppColors.accentCyan,
                            tooltip: 'Canavar ve görev EXP takviyesi',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BuffStatChip(
                            icon: Icons.monetization_on_rounded,
                            label: '+${widget.buffInfo.goldBoostPercent}% Altın',
                            color: AppColors.liquidGold,
                            tooltip: 'Zindan ve yaratık altın bonusu',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BuffStatChip(
                            icon: Icons.all_inclusive_rounded,
                            label: '+${widget.buffInfo.dropRateBoostPercent}% Drop',
                            color: AppColors.cyberFuchsia,
                            tooltip: 'Nadir ekipman düşürme şansı',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BuffStatChip extends StatelessWidget {
  const _BuffStatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.urbanist(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComebackBuffDetailsSheet extends StatelessWidget {
  const _ComebackBuffDetailsSheet({required this.buffInfo});

  final ComebackBuffInfo buffInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.carbonVoid.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mutedTitanium.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.liquidGoldGradient,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.carbonVoid,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      buffInfo.name,
                      style: GoogleFonts.urbanist(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      buffInfo.subtitle,
                      style: const TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.darkObsidian.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: <Widget>[
                _detailRow('Karakter Deneyimi (EXP)', '+${buffInfo.expBoostPercent}% Hızlı Seviye Atlama', AppColors.accentCyan),
                const Divider(color: Colors.white12, height: 16),
                _detailRow('Kazanılan Altın', '+${buffInfo.goldBoostPercent}% Zindan & Görev Altını', AppColors.liquidGold),
                const Divider(color: Colors.white12, height: 16),
                _detailRow('Nadir Eşya Düşürme', '+${buffInfo.dropRateBoostPercent}% Efsanevi Ganimet Şansı', AppColors.cyberFuchsia),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Kalan Etki Süresi:',
                style: TextStyle(color: AppColors.mutedTitanium, fontSize: 13),
              ),
              Text(
                buffInfo.remainingFormatted,
                style: GoogleFonts.urbanist(
                  color: AppColors.liquidGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.liquidGold,
              foregroundColor: AppColors.carbonVoid,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Anladım',
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, Color accent) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.urbanist(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
