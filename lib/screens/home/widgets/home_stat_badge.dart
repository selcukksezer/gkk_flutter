import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/reputation_tier.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../mekans/widgets/mekan_design.dart';

enum _HomeStatBadgeKind { power, reputation }

/// Premium neon stat badge for the home hero showcase (POWER / REP).
class HomeStatBadge extends StatelessWidget {
  const HomeStatBadge.power({
    super.key,
    required this.value,
    this.compact = false,
    this.onTap,
    this.showPopoverOnTap = true,
  })  : _kind = _HomeStatBadgeKind.power,
        reputation = 0;

  const HomeStatBadge.reputation({
    super.key,
    required this.reputation,
    this.compact = false,
    this.onTap,
    this.showPopoverOnTap = false,
  })  : _kind = _HomeStatBadgeKind.reputation,
        value = null;

  final _HomeStatBadgeKind _kind;
  final String? value;
  final int reputation;
  final bool compact;
  final VoidCallback? onTap;
  final bool showPopoverOnTap;

  static String _compact(int v) {
    if (v >= 1000000000) {
      return '${(v / 1000000000).toStringAsFixed(1)}B';
    }
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  /// Displays the Aion 2 Dark Fantasy Combat Power detail popover.
  static void showPowerDetailPopover(BuildContext context, String value) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) =>
          _PowerDetailPopover(powerValue: value),
    );
  }

  /// Displays the Aion 2 Dark Fantasy Reputation Tier detail popover.
  static void showReputationDetailPopover(
      BuildContext context, int reputation) {
    HapticFeedback.selectionClick();
    final int rep = reputation.clamp(0, 999999999);
    final ReputationTier tier = reputationTierFor(rep);
    final ReputationTierProgress progress = reputationTierProgressFor(rep);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _ReputationDetailPopover(
        reputation: rep,
        tier: tier,
        progress: progress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_kind) {
      case _HomeStatBadgeKind.power:
        return _NeonStatBadgeShell(
          label: 'POWER',
          icon: Icons.bolt_rounded,
          accent: AppColors.cyberFuchsia,
          accentSecondary: AppColors.mysticRuby,
          value: value ?? '0',
          compact: compact,
          onTap: () {
            if (onTap != null) {
              onTap!();
            } else if (showPopoverOnTap) {
              showPowerDetailPopover(context, value ?? '0');
            }
          },
        );
      case _HomeStatBadgeKind.reputation:
        final int rep = reputation.clamp(0, 999999999);
        final ReputationTier tier = reputationTierFor(rep);
        final ReputationTierProgress progress = reputationTierProgressFor(rep);
        final int pct = (progress.progress * 100).round().clamp(0, 100);
        return _NeonStatBadgeShell(
          label: 'REP',
          icon: Icons.military_tech_rounded,
          accent: AppColors.accentPurple,
          accentSecondary: AppColors.accentPurpleDim,
          value: _compact(rep),
          subtitle: tier.title,
          subtitleColor: tier.color,
          progress: progress.progress,
          progressLabel: pct >= 100 ? 'MAX' : '$pct%',
          compact: compact,
          onTap: () {
            if (onTap != null) {
              onTap!();
            } else if (showPopoverOnTap) {
              showReputationDetailPopover(context, rep);
            } else {
              context.push(AppRoutes.reputation);
            }
          },
        );
    }
  }
}

class _NeonStatBadgeShell extends StatelessWidget {
  const _NeonStatBadgeShell({
    required this.label,
    required this.accent,
    required this.accentSecondary,
    required this.value,
    this.icon,
    this.subtitle,
    this.subtitleColor,
    this.progress,
    this.progressLabel,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color accent;
  final Color accentSecondary;
  final String value;
  final String? subtitle;
  final Color? subtitleColor;
  final double? progress;
  final String? progressLabel;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Size screenSize =
        MediaQuery.maybeSizeOf(context) ?? const Size(390, 844);
    final bool isNarrowScreen = screenSize.width <= 390;
    final bool isUltraNarrow = screenSize.width < 360;

    final double outerRadius = compact ? (isUltraNarrow ? 10.0 : 12.0) : 16.0;
    final double innerRadius = compact ? (isUltraNarrow ? 8.8 : 10.6) : 14.6;

    final EdgeInsets contentPadding = compact
        ? EdgeInsets.symmetric(
            horizontal: isUltraNarrow ? 6.5 : (isNarrowScreen ? 8.0 : 9.5),
            vertical: isUltraNarrow ? 3.5 : (isNarrowScreen ? 4.5 : 5.5),
          )
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    final double labelSize = compact
        ? (isUltraNarrow ? 7.8 : (isNarrowScreen ? 8.2 : 8.8))
        : 10.0;
    final double valueSize = compact
        ? (isUltraNarrow ? 11.5 : (isNarrowScreen ? 12.2 : 13.0))
        : 15.0;
    final double minWidth = compact
        ? (isUltraNarrow ? 56.0 : (isNarrowScreen ? 62.0 : 68.0))
        : 78.0;
    final double maxWidth = compact
        ? (isUltraNarrow ? 84.0 : (isNarrowScreen ? 90.0 : 96.0))
        : double.infinity;

    final Widget badge = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: maxWidth,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFFFFF2B2).withValues(alpha: 0.85),
              accent.withValues(alpha: 0.95),
              accentSecondary.withValues(alpha: 0.65),
              Colors.white.withValues(alpha: 0.30),
              accent.withValues(alpha: 0.45),
            ],
            stops: const <double>[0.0, 0.28, 0.65, 0.88, 1.0],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: compact ? 0.36 : 0.48),
              blurRadius: compact ? 10 : 16,
              spreadRadius: compact ? -2.0 : -1.5,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            if (!compact)
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 26,
                spreadRadius: 2,
              ),
          ],
        ),
        padding: EdgeInsets.all(compact ? 1.1 : 1.4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.spaceNavy.withValues(alpha: 0.82),
                    AppColors.carbonVoid.withValues(alpha: 0.92),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.6,
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: compact ? 13 : 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.white.withValues(alpha: compact ? 0.16 : 0.22),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _AionGlassOrnamentPainter(
                        accentColor: accent,
                        compact: compact,
                      ),
                    ),
                  ),
                  Padding(
                    padding: contentPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (icon != null) ...<Widget>[
                              Icon(
                                icon,
                                size: compact ? (isUltraNarrow ? 9.0 : 10.0) : 12.0,
                                color: accent,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: accent.withValues(alpha: 0.9),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              SizedBox(width: compact ? 2.5 : 4.0),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.micro.copyWith(
                                  fontSize: labelSize,
                                  color: AppColors.textPrimary.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: compact ? 0.9 : 1.4,
                                  height: 1,
                                  shadows: <Shadow>[
                                    Shadow(color: accent.withValues(alpha: 0.85), blurRadius: 6),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 1 : 2),
                        Text(
                          value,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h3.copyWith(
                            fontSize: valueSize,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            shadows: <Shadow>[
                              Shadow(
                                color: accent.withValues(alpha: 0.85),
                                blurRadius: compact ? 8 : 12,
                              ),
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.60),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        if (subtitle != null) ...<Widget>[
                          SizedBox(height: compact ? 2 : 3),
                          if (compact && progressLabel != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.micro.copyWith(
                                      fontSize: isUltraNarrow ? 7.5 : 8.0,
                                      color: subtitleColor ?? accent,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                Text(
                                  ' · ',
                                  style: AppTextStyles.micro.copyWith(
                                    fontSize: isUltraNarrow ? 7.5 : 8.0,
                                    color: AppColors.mutedTitanium,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  progressLabel!,
                                  style: AppTextStyles.micro.copyWith(
                                    fontSize: isUltraNarrow ? 7.5 : 8.0,
                                    color: AppColors.mutedTitanium,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.micro.copyWith(
                                color: subtitleColor ?? accent,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                        ],
                        if (!compact && progress != null && progressLabel != null) ...<Widget>[
                          const SizedBox(height: 5),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: SizedBox(
                                    height: 3,
                                    child: LinearProgressIndicator(
                                      value: progress!.clamp(0.0, 1.0),
                                      backgroundColor:
                                          AppColors.darkObsidian.withValues(alpha: 0.85),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        accent.withValues(alpha: 0.95),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                progressLabel!,
                                style: AppTextStyles.micro.copyWith(
                                  color: AppColors.mutedTitanium,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (compact && progress != null) ...<Widget>[
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: SizedBox(
                              height: 2,
                              child: LinearProgressIndicator(
                                value: progress!.clamp(0.0, 1.0),
                                backgroundColor:
                                    AppColors.darkObsidian.withValues(alpha: 0.85),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent.withValues(alpha: 0.95),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return badge;
    return PressableScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap!();
      },
      child: badge,
    );
  }
}

class _AionGlassOrnamentPainter extends CustomPainter {
  const _AionGlassOrnamentPainter({
    required this.accentColor,
    required this.compact,
  });

  final Color accentColor;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dotPaint = Paint()
      ..color = AppColors.mutedTitanium.withValues(alpha: compact ? 0.05 : 0.08);
    final double spacing = compact ? 10.0 : 13.0;
    for (double y = spacing / 2; y < size.height; y += spacing) {
      final bool odd = ((y / spacing).floor()) % 2 == 1;
      for (double x = odd ? spacing : spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.7, dotPaint);
      }
    }

    final Paint linePaint = Paint()
      ..color = accentColor.withValues(alpha: compact ? 0.35 : 0.45)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    final double corner = compact ? 4.0 : 6.0;
    // Top-Left
    canvas.drawLine(const Offset(4, 2), Offset(4 + corner, 2), linePaint);
    canvas.drawLine(const Offset(2, 4), Offset(2, 4 + corner), linePaint);

    // Top-Right
    canvas.drawLine(Offset(size.width - 4, 2), Offset(size.width - 4 - corner, 2), linePaint);
    canvas.drawLine(Offset(size.width - 2, 4), Offset(size.width - 2, 4 + corner), linePaint);

    // Bottom-Left
    canvas.drawLine(Offset(4, size.height - 2), Offset(4 + corner, size.height - 2), linePaint);
    canvas.drawLine(Offset(2, size.height - 4), Offset(2, size.height - 4 - corner), linePaint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - 4, size.height - 2),
        Offset(size.width - 4 - corner, size.height - 2), linePaint);
    canvas.drawLine(Offset(size.width - 2, size.height - 4),
        Offset(size.width - 2, size.height - 4 - corner), linePaint);

    // Cardinal rune tick marks in celestial gold
    final Paint tickPaint = Paint()
      ..color = const Color(0xFFFFDF70).withValues(alpha: compact ? 0.25 : 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double midX = size.width * 0.5;
    canvas.drawLine(Offset(midX - 3, 1.2), Offset(midX + 3, 1.2), tickPaint);
    canvas.drawLine(Offset(midX - 3, size.height - 1.2), Offset(midX + 3, size.height - 1.2), tickPaint);
  }

  @override
  bool shouldRepaint(_AionGlassOrnamentPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor || oldDelegate.compact != compact;
}

/// Aion 2 Dark Fantasy Combat Power Detail Modal Sheet.
class _PowerDetailPopover extends StatelessWidget {
  const _PowerDetailPopover({required this.powerValue});

  final String powerValue;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xF4121826),
                  Color(0xFA080B12),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: AppColors.cyberFuchsia.withValues(alpha: 0.75),
                  width: 1.5,
                ),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.cyberFuchsia.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: -4,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.mutedTitanium.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: <Color>[
                            AppColors.cyberFuchsia,
                            AppColors.mysticRuby,
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.cyberFuchsia.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'SAVAŞ GÜCÜ',
                            style: AppTextStyles.h3.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'AION COMBAT POTENTIAL',
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 9,
                              color: AppColors.mutedTitanium,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.mutedTitanium,
                      splashRadius: 18,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: <Color>[
                        AppColors.cyberFuchsia.withValues(alpha: 0.16),
                        AppColors.mysticRuby.withValues(alpha: 0.08),
                        AppColors.carbonVoid.withValues(alpha: 0.60),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: AppColors.cyberFuchsia.withValues(alpha: 0.45),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.cyberFuchsia.withValues(alpha: 0.16),
                        blurRadius: 18,
                        spreadRadius: -3,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.auto_awesome,
                                size: 10,
                                color: AppColors.cyberFuchsia.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'TOPLAM KOMBAT SKORU',
                                style: AppTextStyles.micro.copyWith(
                                  fontSize: 9,
                                  color: AppColors.mutedTitanium,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            powerValue,
                            style: AppTextStyles.h1.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              height: 1.1,
                              shadows: <Shadow>[
                                Shadow(
                                  color: AppColors.cyberFuchsia.withValues(alpha: 0.85),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.cyberFuchsia.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.cyberFuchsia.withValues(alpha: 0.60),
                          ),
                        ),
                        child: Text(
                          'AKTİF DERECE',
                          style: AppTextStyles.micro.copyWith(
                            color: AppColors.cyberFuchsia,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _StatPopoverRow(
                  icon: Icons.shield_rounded,
                  title: 'Ekipman Tabanı',
                  desc: 'Kuşanılan silah, zırh ve aksesuarların baz gücü.',
                  value: '+68%',
                  accentColor: AppColors.cyberFuchsia,
                ),
                const SizedBox(height: 8),
                const _StatPopoverRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Efsun ve Kutsama',
                  desc: 'Ekipman seviye yükseltmeleri ve ilave soket taşları.',
                  value: '+22%',
                  accentColor: AppColors.cyberFuchsia,
                ),
                const SizedBox(height: 8),
                const _StatPopoverRow(
                  icon: Icons.military_tech_rounded,
                  title: 'Unvan ve İtibar',
                  desc: 'Aktif krallık rütbesi ve kazanılan itibar çarpanı.',
                  value: '+10%',
                  accentColor: AppColors.cyberFuchsia,
                ),
                const SizedBox(height: 8),
                const _StatPopoverRow(
                  icon: Icons.local_fire_department_rounded,
                  title: 'Elemental Rezonans',
                  desc: 'Karanlık ve aydınlık element sinerji bonusu.',
                  value: 'Aktif',
                  accentColor: AppColors.cyberFuchsia,
                ),
                const SizedBox(height: 16),
                PressableScale(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop();
                    context.push(AppRoutes.character);
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: <Color>[
                          AppColors.cyberFuchsia,
                          AppColors.mysticRuby,
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.cyberFuchsia.withValues(alpha: 0.40),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.shield_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'EKİPMAN VE KARAKTERİ İNCELE',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            letterSpacing: 0.8,
                          ),
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
    );
  }
}

/// Aion 2 Dark Fantasy Reputation Tier Detail Modal Sheet.
class _ReputationDetailPopover extends StatelessWidget {
  const _ReputationDetailPopover({
    required this.reputation,
    required this.tier,
    required this.progress,
  });

  final int reputation;
  final ReputationTier tier;
  final ReputationTierProgress progress;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final int pct = (progress.progress * 100).round().clamp(0, 100);

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xF4121826),
                  Color(0xFA080B12),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: tier.color.withValues(alpha: 0.80),
                  width: 1.5,
                ),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: tier.color.withValues(alpha: 0.28),
                  blurRadius: 30,
                  spreadRadius: -4,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.mutedTitanium.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tier.color.withValues(alpha: 0.22),
                        border: Border.all(color: tier.color.withValues(alpha: 0.70)),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: tier.color.withValues(alpha: 0.45),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.military_tech_rounded,
                        color: tier.color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'İTİBAR VE UNVAN',
                            style: AppTextStyles.h3.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'REPUTATION STANDING',
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 9,
                              color: AppColors.mutedTitanium,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.mutedTitanium,
                      splashRadius: 18,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: <Color>[
                        tier.color.withValues(alpha: 0.18),
                        tier.color.withValues(alpha: 0.06),
                        AppColors.carbonVoid.withValues(alpha: 0.60),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: tier.color.withValues(alpha: 0.55),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: tier.color.withValues(alpha: 0.18),
                        blurRadius: 18,
                        spreadRadius: -3,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            tier.title,
                            style: AppTextStyles.h2.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: tier.color,
                              shadows: <Shadow>[
                                Shadow(
                                  color: tier.color.withValues(alpha: 0.80),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: tier.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: tier.color.withValues(alpha: 0.40),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '$reputation REP',
                              style: AppTextStyles.h3.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'KADEME İLERLEMESİ',
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 9,
                              color: AppColors.mutedTitanium,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            pct >= 100 ? 'MAKSİMUM' : '$pct%',
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 9,
                              color: tier.color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: SizedBox(
                          height: 5,
                          child: LinearProgressIndicator(
                            value: progress.progress.clamp(0.0, 1.0),
                            backgroundColor:
                                AppColors.darkObsidian.withValues(alpha: 0.85),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              tier.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _StatPopoverRow(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Aktif Kademe Unvanı',
                  desc: '${tier.title} derecesi krallık genelinde tanınmaktadır.',
                  value: tier.title,
                  accentColor: tier.color,
                ),
                const SizedBox(height: 8),
                _StatPopoverRow(
                  icon: Icons.trending_up_rounded,
                  title: 'Sonraki Aşama Hedefi',
                  desc: progress.nextTierTitle == 'Maksimum'
                      ? 'Maksimum kademeye ulaşıldı.'
                      : '${progress.nextTierTitle} derecesine ilerleniyor.',
                  value: progress.nextTierTitle,
                  accentColor: tier.color,
                ),
                const SizedBox(height: 8),
                _StatPopoverRow(
                  icon: Icons.stars_rounded,
                  title: 'Kademe Ayrıcalıkları',
                  desc: 'Özel mekan erişimleri, tüccar indirimleri ve unvan aurası.',
                  value: 'Aktif',
                  accentColor: tier.color,
                ),
                const SizedBox(height: 8),
                _StatPopoverRow(
                  icon: Icons.history_edu_rounded,
                  title: 'İtibar Kazanım Kaynakları',
                  desc: 'Zindan bossları, lonca fetihleri ve haftalık görevler.',
                  value: 'Haftalık',
                  accentColor: tier.color,
                ),
                const SizedBox(height: 16),
                PressableScale(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop();
                    context.push(AppRoutes.reputation);
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: <Color>[
                          tier.color,
                          tier.color.withValues(alpha: 0.75),
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: tier.color.withValues(alpha: 0.40),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.military_tech_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'İTİBAR MERKEZİNE GİT',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            letterSpacing: 0.8,
                          ),
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
    );
  }
}

class _StatPopoverRow extends StatelessWidget {
  const _StatPopoverRow({
    required this.icon,
    required this.title,
    required this.desc,
    this.value,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String desc;
  final String? value;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final Color accent = accentColor ?? AppColors.mutedTitanium;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.075),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Icon(
              icon,
              size: 15,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  desc,
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.mutedTitanium,
                    fontSize: 8.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (value != null) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: accent.withValues(alpha: 0.40),
                  width: 0.7,
                ),
              ),
              child: Text(
                value!,
                style: AppTextStyles.micro.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 9.0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
