import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/utils/gold_format.dart';
import '../../../models/dungeon_model.dart';
import '../../../theme/app_colors.dart';
import '../dungeon_zone_data.dart';

/// Premium zindan giriş onayı — /tasarim: blur, dot doku, Liquid Gold CTA.
class DungeonConfirmEntryDialog extends StatefulWidget {
  const DungeonConfirmEntryDialog({
    super.key,
    required this.dungeon,
    this.hospitalRiskPct,
    this.rewardMultiplierPreview,
    this.siegePrimeHint,
    this.siegeNoSlotWarning,
    this.currentEnergy,
    this.primeTimerLabel,
    this.siegeActive = false,
    this.onConfirmTap,
  });

  final DungeonData dungeon;
  final double? hospitalRiskPct;
  final double? rewardMultiplierPreview;
  final String? siegePrimeHint;
  final String? siegeNoSlotWarning;
  final int? currentEnergy;
  final String? primeTimerLabel;
  final bool siegeActive;
  final VoidCallback? onConfirmTap;

  /// Transparent barrier + blur backdrop — tek satır caller değişimi.
  static Future<bool?> show(
    BuildContext context, {
    required DungeonData dungeon,
    double? hospitalRiskPct,
    double? rewardMultiplierPreview,
    String? siegePrimeHint,
    String? siegeNoSlotWarning,
    int? currentEnergy,
    String? primeTimerLabel,
    bool siegeActive = false,
    VoidCallback? onConfirmTap,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Zindan giriş onayı',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (
        BuildContext dialogContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return DungeonConfirmEntryDialog(
          dungeon: dungeon,
          hospitalRiskPct: hospitalRiskPct,
          rewardMultiplierPreview: rewardMultiplierPreview,
          siegePrimeHint: siegePrimeHint,
          siegeNoSlotWarning: siegeNoSlotWarning,
          currentEnergy: currentEnergy,
          primeTimerLabel: primeTimerLabel,
          siegeActive: siegeActive,
          onConfirmTap: onConfirmTap,
        );
      },
      transitionBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: child,
        );
      },
    );
  }

  @override
  State<DungeonConfirmEntryDialog> createState() => _DungeonConfirmEntryDialogState();
}

class _DungeonConfirmEntryDialogState extends State<DungeonConfirmEntryDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _confirmPressed = false;
  bool _cancelPressed = false;

  bool get _energyInsufficient =>
      widget.currentEnergy != null && widget.currentEnergy! < widget.dungeon.energyCost;

  bool get _canConfirm => !_energyInsufficient;

  bool get _hasSiegeWarning =>
      widget.siegeNoSlotWarning != null && widget.siegeNoSlotWarning!.isNotEmpty;

  bool get _hasSiegeBonus =>
      widget.siegePrimeHint != null && widget.siegePrimeHint!.isNotEmpty;

  Color get _accent =>
      _hasSiegeWarning ? AppColors.warningSolar : AppColors.liquidGold;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _scale = CurvedAnimation(parent: _entry, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));
    _entry.forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  void _pop(bool value) {
    if (!mounted) return;
    Navigator.of(context).pop(value);
  }

  void _onConfirm() {
    if (!_canConfirm) return;
    widget.onConfirmTap?.call();
    _pop(true);
  }

  Animation<double> _stagger(int index, {int total = 6}) {
    final double start = (index / total) * 0.35;
    final double end = start + 0.55;
    return CurvedAnimation(
      parent: _entry,
      curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DungeonData dungeon = widget.dungeon;
    final int zoneNum = zoneForDungeon(dungeon);
    final DungeonZone? zone = zoneDataFor(zoneNum);
    final String zoneLabel = zone?.name ?? (zoneNum > 0 ? 'Bölge $zoneNum' : 'Zindan');
    final String goldRange = formatCompactGoldRange(dungeon.minGold, dungeon.maxGold);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            onTap: () => _pop(false),
            behavior: HitTestBehavior.opaque,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: AppColors.carbonVoid.withValues(alpha: 0.72),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _entry,
              builder: (BuildContext context, Widget? child) {
                return Opacity(
                  opacity: _fade.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.88 + (0.12 * _scale.value.clamp(0.0, 1.2)),
                    child: SlideTransition(
                      position: _slide,
                      child: child,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              AppColors.spaceNavy,
                              AppColors.carbonVoid,
                            ],
                          ),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.22),
                              blurRadius: 32,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: <Widget>[
                            const Positioned.fill(
                              child: CustomPaint(
                                painter: DotGridPainter(
                                  spacing: 18,
                                  dotRadius: 1.0,
                                  dotOpacity: 0.07,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: <Color>[
                                      _accent.withValues(alpha: 0.12),
                                      _accent,
                                      AppColors.cyberFuchsia.withValues(alpha: 0.85),
                                      _accent.withValues(alpha: 0.12),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  FadeTransition(
                                    opacity: _stagger(0),
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.12),
                                        end: Offset.zero,
                                      ).animate(_stagger(0)),
                                      child: Row(
                                        children: <Widget>[
                                          Container(
                                            width: 4,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: AppColors.liquidGold,
                                              borderRadius: BorderRadius.circular(2),
                                              boxShadow: <BoxShadow>[
                                                BoxShadow(
                                                  color: AppColors.liquidGold
                                                      .withValues(alpha: 0.45),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'ZİNDAN GİRİŞİ',
                                              style: GoogleFonts.urbanist(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 2.6,
                                                color: AppColors.mutedTitanium,
                                              ),
                                            ),
                                          ),
                                          if (widget.siegeActive)
                                            _SiegeBadge(active: !_hasSiegeWarning),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FadeTransition(
                                    opacity: _stagger(1),
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.1),
                                        end: Offset.zero,
                                      ).animate(_stagger(1)),
                                      child: Text(
                                        dungeon.name,
                                        style: GoogleFonts.urbanist(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          height: 1.15,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  FadeTransition(
                                    opacity: _stagger(2),
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.08),
                                        end: Offset.zero,
                                      ).animate(_stagger(2)),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: <Widget>[
                                          _MetaPill(
                                            icon: zone?.icon ?? Icons.map_outlined,
                                            label: zoneLabel,
                                            color: zone?.color ?? AppColors.accentBlue,
                                          ),
                                          _MetaPill(
                                            icon: Icons.bolt_rounded,
                                            label: '${dungeon.energyCost} enerji',
                                            color: AppColors.warningSolar,
                                          ),
                                          if (widget.primeTimerLabel != null &&
                                              widget.primeTimerLabel!.isNotEmpty)
                                            _MetaPill(
                                              icon: Icons.schedule_rounded,
                                              label: widget.primeTimerLabel!,
                                              color: AppColors.cyberFuchsia,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FadeTransition(
                                    opacity: _stagger(3),
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.08),
                                        end: Offset.zero,
                                      ).animate(_stagger(3)),
                                      child: _RiskRewardRow(
                                        energyCost: dungeon.energyCost,
                                        goldRange: goldRange,
                                        siegeBonus: _hasSiegeBonus ? widget.siegePrimeHint : null,
                                      ),
                                    ),
                                  ),
                                  if (_hasSiegeWarning) ...<Widget>[
                                    const SizedBox(height: 12),
                                    FadeTransition(
                                      opacity: _stagger(4),
                                      child: _WarningStrip(
                                        message: widget.siegeNoSlotWarning!,
                                        accent: AppColors.warningSolar,
                                        icon: Icons.warning_amber_rounded,
                                      ),
                                    ),
                                  ] else if (_hasSiegeBonus) ...<Widget>[
                                    const SizedBox(height: 12),
                                    FadeTransition(
                                      opacity: _stagger(4),
                                      child: _WarningStrip(
                                        message: widget.siegePrimeHint!,
                                        accent: AppColors.toxicNeon,
                                        icon: Icons.military_tech_rounded,
                                      ),
                                    ),
                                  ],
                                  if (widget.hospitalRiskPct != null &&
                                      widget.hospitalRiskPct! > 0) ...<Widget>[
                                    const SizedBox(height: 10),
                                    FadeTransition(
                                      opacity: _stagger(4),
                                      child: _WarningStrip(
                                        message:
                                            'Yenilgi hastane riski: %${widget.hospitalRiskPct!.toStringAsFixed(0)}',
                                        accent: AppColors.mysticRuby,
                                        icon: Icons.local_hospital_rounded,
                                      ),
                                    ),
                                  ],
                                  if (widget.rewardMultiplierPreview != null &&
                                      widget.rewardMultiplierPreview! < 0.99) ...<Widget>[
                                    const SizedBox(height: 10),
                                    FadeTransition(
                                      opacity: _stagger(4),
                                      child: _WarningStrip(
                                        message:
                                            'Farm cezası: ×${widget.rewardMultiplierPreview!.toStringAsFixed(2)} '
                                            '(kuşatma bonusundan ayrı)',
                                        accent: AppColors.coralFlare,
                                        icon: Icons.trending_down_rounded,
                                      ),
                                    ),
                                  ],
                                  if (_energyInsufficient) ...<Widget>[
                                    const SizedBox(height: 10),
                                    FadeTransition(
                                      opacity: _stagger(4),
                                      child: _WarningStrip(
                                        message:
                                            'Enerji yetersiz — ${widget.currentEnergy}/${dungeon.energyCost}',
                                        accent: AppColors.mysticRuby,
                                        icon: Icons.battery_alert_rounded,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  FadeTransition(
                                    opacity: _stagger(5),
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.06),
                                        end: Offset.zero,
                                      ).animate(_stagger(5)),
                                      child: Text(
                                        'Operasyonu başlatmak istiyor musun?',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.urbanist(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                          color: AppColors.mutedTitanium,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  FadeTransition(
                                    opacity: _stagger(5),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: _EntryButton(
                                            label: 'İptal',
                                            filled: false,
                                            accent: AppColors.mutedTitanium,
                                            pressed: _cancelPressed,
                                            onHighlight: (bool v) =>
                                                setState(() => _cancelPressed = v),
                                            onTap: () => _pop(false),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TutorialAnchorScope(
                                            id: TutorialAnchorId.dungeonConfirmOk,
                                            child: _EntryButton(
                                              label: 'Gir',
                                              filled: true,
                                              accent: AppColors.liquidGold,
                                              enabled: _canConfirm,
                                              pressed: _confirmPressed,
                                              onHighlight: (bool v) =>
                                                  setState(() => _confirmPressed = v),
                                              onTap: _onConfirm,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SiegeBadge extends StatelessWidget {
  const _SiegeBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color =
        active ? AppColors.cyberFuchsia : AppColors.warningSolar;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.shield_moon_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            active ? 'KUŞATMA' : 'PRIME',
            style: GoogleFonts.urbanist(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkObsidian.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskRewardRow extends StatelessWidget {
  const _RiskRewardRow({
    required this.energyCost,
    required this.goldRange,
    this.siegeBonus,
  });

  final int energyCost;
  final String goldRange;
  final String? siegeBonus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatTile(
            icon: Icons.bolt_rounded,
            label: 'ENERJİ',
            value: '$energyCost',
            accent: AppColors.warningSolar,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            icon: Icons.monetization_on_rounded,
            label: 'ALTIN',
            value: goldRange,
            accent: AppColors.liquidGold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            icon: siegeBonus != null
                ? Icons.military_tech_rounded
                : Icons.inventory_2_outlined,
            label: siegeBonus != null ? 'BONUS' : 'GANIMET',
            value: siegeBonus != null ? 'SLOT+' : 'LOOT',
            accent: siegeBonus != null ? AppColors.toxicNeon : AppColors.coralFlare,
            compact: true,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkObsidian.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.mutedTitanium,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningStrip extends StatelessWidget {
  const _WarningStrip({
    required this.message,
    required this.accent,
    required this.icon,
  });

  final String message;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.urbanist(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryButton extends StatelessWidget {
  const _EntryButton({
    required this.label,
    required this.filled,
    required this.accent,
    this.onTap,
    this.pressed = false,
    this.onHighlight,
    this.enabled = true,
  });

  final String label;
  final bool filled;
  final Color accent;
  final VoidCallback? onTap;
  final bool pressed;
  final ValueChanged<bool>? onHighlight;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color effectiveAccent =
        enabled ? accent : AppColors.mutedTitanium.withValues(alpha: 0.45);

    return GestureDetector(
      onTapDown: enabled ? (_) => onHighlight?.call(true) : null,
      onTapUp: enabled ? (_) => onHighlight?.call(false) : null,
      onTapCancel: enabled ? () => onHighlight?.call(false) : null,
      onTap: enabled ? onTap : null,
      child: AnimatedScale(
        scale: pressed && enabled ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: filled && enabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.liquidGold,
                        Color.lerp(AppColors.liquidGold, AppColors.coralFlare, 0.18)!,
                      ],
                    )
                  : null,
              color: filled
                  ? (enabled ? null : AppColors.darkObsidian)
                  : AppColors.darkObsidian,
              border: filled
                  ? null
                  : Border.all(color: effectiveAccent.withValues(alpha: 0.45)),
              boxShadow: filled && enabled
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.liquidGold.withValues(alpha: 0.38),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                color: filled && enabled
                    ? AppColors.carbonVoid
                    : effectiveAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
