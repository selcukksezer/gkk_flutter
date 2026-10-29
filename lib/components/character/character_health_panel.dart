import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/player_health.dart';
import '../../models/player_model.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../common/app_messenger.dart';
import '../common/universal_game_dialog.dart';

/// 2027 Aion 2 Obsidian-Glass & Living Bio-Glow Health Panel (V2 Polish).
///
/// AAA Mobile Architecture:
/// - Obsidian Dark Foundation (0xFF07090E - 0xFF0F141F) with anisotropic specular glass rim.
/// - True Frosted Glass Blur (BackdropFilter sigma 16.0) with internal micro-bevel sheen.
/// - Living Bio-Core: Dynamically pulsing Battle Crimson (#FFFF1744, #FFFF3366) HP core & bar,
///   Ether Cyan (#00E5FF) Mana energy reservoir, and 4000 DP Divine Awakening gauge.
/// - Emergency Low-Health Critical System (< 25%): Arrhythmic heartbeat pulse,
///   luminous perimeter warning flash, and high-urgency telemetry banner.
/// - Full SafeArea & Display Cutout protection across foldables and notched screens.
/// - Multi-tier Tactile Haptic Feedback: Heavy impact on damage/critical, medium impact
///   on regular damage/recovery, selection click on tactical quick actions.
/// - 100% preservation of server math, regen calculations, and Supabase RPC persistence.
class CharacterHealthPanel extends ConsumerStatefulWidget {
  const CharacterHealthPanel({
    super.key,
    required this.profile,
    this.inHospital = false,
    this.inPrison = false,
  });

  final PlayerProfile profile;
  final bool inHospital;
  final bool inPrison;

  @override
  ConsumerState<CharacterHealthPanel> createState() =>
      _CharacterHealthPanelState();
}

class _CharacterHealthPanelState extends ConsumerState<CharacterHealthPanel>
    with TickerProviderStateMixin {
  bool _healing = false;
  late final AnimationController _ambientPulseController;
  late final AnimationController _alarmPulseController;
  late final AnimationController _heartbeatController;

  // ── Aion 2 Obsidian & Bio-Luminescence Palette ─────────────────────────────
  static const Color _obsidianDeep = Color(0xFF07090E);
  static const Color _obsidianSurface = Color(0xFF0B0F19);
  static const Color _obsidianElevated = Color(0xFF0F141F);

  static const Color _battleCrimsonPrimary = Color(0xFFFF1744);
  static const Color _battleCrimsonSecondary = Color(0xFFFF3366);
  static const Color _battleCrimsonDark = Color(0xFF880E24);

  static const Color _etherCyanPrimary = Color(0xFF00E5FF);
  static const Color _etherCyanSecondary = Color(0xFF0091EA);

  static const Color _divineGoldPrimary = Color(0xFFFFB800);
  static const Color _divineGoldSecondary = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();

    // Breathing ambient bio-glow (2400ms cycle)
    _ambientPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // High-urgency critical alarm strobe (550ms cycle)
    _alarmPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    // Anatomical bio-heartbeat systolic/diastolic pulsation (1100ms cycle)
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _syncAlarmState();
  }

  @override
  void didUpdateWidget(covariant CharacterHealthPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final int oldHp = oldWidget.profile.health;
    final int newHp = widget.profile.health;
    final int maxHp = widget.profile.maxHealth;

    // Detect health drops (Combat Damage / Penalty triggers)
    if (newHp < oldHp && maxHp > 0) {
      final double fraction = newHp / maxHp;
      final double oldFraction = oldHp / maxHp;

      if (fraction < 0.25) {
        // Critical health drop or damage under critical threshold
        HapticFeedback.heavyImpact();
      } else if (oldFraction >= 0.25 && fraction < 0.25) {
        // Threshold crossing event
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }

    _syncAlarmState();
  }

  void _syncAlarmState() {
    final bool isLowHealth = widget.profile.maxHealth > 0 &&
        (widget.profile.health / widget.profile.maxHealth) < 0.25 &&
        !_restricted;

    if (isLowHealth) {
      if (!_alarmPulseController.isAnimating) {
        _alarmPulseController.repeat(reverse: true);
      }
    } else {
      if (_alarmPulseController.isAnimating) {
        _alarmPulseController.stop();
        _alarmPulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _ambientPulseController.dispose();
    _alarmPulseController.dispose();
    _heartbeatController.dispose();
    super.dispose();
  }

  bool get _restricted => widget.inHospital || widget.inPrison;

  PlayerHealthStatus get _status => resolveHealthStatus(
        health: widget.profile.health,
        maxHealth: widget.profile.maxHealth,
        restricted: _restricted,
      );

  bool get _canGemHeal =>
      !_restricted &&
      widget.profile.maxHealth > 0 &&
      widget.profile.health < widget.profile.maxHealth;

  int get _gemCost => gemHealthHealCost(
        health: widget.profile.health,
        maxHealth: widget.profile.maxHealth,
        level: widget.profile.level,
      );

  int get _secondsToFull => estimateSecondsToFullHealth(
        health: widget.profile.health,
        maxHealth: widget.profile.maxHealth,
        alchemistBonus:
            widget.profile.characterClass == CharacterClass.alchemist,
      );

  /// Aion 2 Divine Power (DP): 0 - 4000 gauge calculated from PvP and combat progression.
  int get _divinePower {
    final int pvpPts =
        (widget.profile.pvpWins * 40 + widget.profile.pvpRating * 1.5).round();
    return pvpPts.clamp(0, 4000);
  }

  int get _dpTier {
    final int dp = _divinePower;
    if (dp >= 4000) return 4;
    if (dp >= 3000) return 3;
    if (dp >= 2000) return 2;
    if (dp >= 1000) return 1;
    return 0;
  }

  Future<void> _healWithGems() async {
    if (!_canGemHeal || _healing) return;
    HapticFeedback.selectionClick();

    final bool? confirm = await UniversalGameDialog.show(
      context,
      title: 'Elmas ile Can Yenile',
      message:
          'Canın tamamen dolar.\nMaliyet: $_gemCost elmas\nMevcut: ${widget.profile.gems.floor()} elmas',
      confirmLabel: 'İyileştir',
      cancelLabel: 'İptal',
    );
    if (confirm != true || !mounted) return;

    setState(() => _healing = true);
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('heal_health_with_gems');
      final Map<String, dynamic> res =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (res['success'] == true) {
        HapticFeedback.heavyImpact();
        await ref.read(playerProvider.notifier).loadProfile();
        if (mounted) {
          AppMessenger.showSuccess(
            context,
            'Can yenilendi (+${res['healed'] ?? ''})',
          );
        }
      } else {
        if (mounted) {
          AppMessenger.showError(
            context,
            res['error']?.toString() ?? 'İyileştirme başarısız',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'İyileştirme başarısız');
      }
    } finally {
      if (mounted) setState(() => _healing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile.maxHealth <= 0) return const SizedBox.shrink();

    final PlayerHealthStatus status = _status;
    final Color statusColor = healthStatusColor(status);
    final bool showPenalty = hasWoundedCombatPenalty(
      health: widget.profile.health,
      maxHealth: widget.profile.maxHealth,
    );

    final double hpFraction =
        (widget.profile.health / widget.profile.maxHealth).clamp(0.0, 1.0);
    final int hpPct = (hpFraction * 100).round();
    final bool isLowHealth = hpFraction < 0.25 && !_restricted;

    final double mpFraction = widget.profile.maxEnergy > 0
        ? (widget.profile.energy / widget.profile.maxEnergy).clamp(0.0, 1.0)
        : 1.0;
    final int mpPct = (mpFraction * 100).round();

    final double dpFraction = (_divinePower / 4000.0).clamp(0.0, 1.0);
    final int dpTier = _dpTier;

    // Responsive padding and notch defense
    final EdgeInsets screenPadding = MediaQuery.paddingOf(context);

    return SafeArea(
      left: true,
      right: true,
      top: false,
      bottom: false,
      minimum: EdgeInsets.only(
        left: math.max(0.0, screenPadding.left * 0.15),
        right: math.max(0.0, screenPadding.right * 0.15),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge(
          <Listenable>[
            _ambientPulseController,
            _alarmPulseController,
            _heartbeatController,
          ],
        ),
        builder: (BuildContext context, Widget? child) {
          final double ambient = _ambientPulseController.value;
          final double alarm = isLowHealth ? _alarmPulseController.value : 0.0;
          final double heartbeat = _heartbeatController.value;

          // Systolic heartbeat pulse scale calculation: f(t) = sin(t * pi)^3
          final double heartScale = 1.0 +
              (isLowHealth ? 0.14 * math.sin(alarm * math.pi) : 0.06 * math.pow(math.sin(heartbeat * math.pi), 3));

          // Specular obsidian border colors
          final Color topBorderHighlight = isLowHealth
              ? Color.lerp(
                  _battleCrimsonPrimary.withValues(alpha: 0.65),
                  Colors.white.withValues(alpha: 0.90),
                  alarm,
                )!
              : statusColor.withValues(alpha: 0.45 + 0.25 * ambient);

          final Color bottomBorderShadow = isLowHealth
              ? _battleCrimsonDark.withValues(alpha: 0.50)
              : _obsidianDeep.withValues(alpha: 0.85);

          // Living luminescence aura
          final Color livingGlow = isLowHealth
              ? _battleCrimsonPrimary.withValues(alpha: 0.25 + 0.35 * alarm)
              : statusColor.withValues(alpha: 0.08 + 0.12 * ambient);

          return ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: DecoratedBox(
                // Outer Specular Border Decoration
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      topBorderHighlight,
                      bottomBorderShadow,
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    // Living Bio-Glow Shadow
                    BoxShadow(
                      color: livingGlow,
                      blurRadius: isLowHealth ? 22 + 12 * alarm : 16 + 8 * ambient,
                      spreadRadius: isLowHealth ? 1.5 * alarm : 0.0,
                      offset: const Offset(0, 4),
                    ),
                    // Deep Obsidian Void Occlusion
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  margin: EdgeInsets.all(isLowHealth ? 1.5 : 1.2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusLg - (isLowHealth ? 1.5 : 1.2),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        _obsidianElevated.withValues(
                          alpha: isLowHealth ? 0.90 : 0.84,
                        ),
                        _obsidianSurface.withValues(
                          alpha: isLowHealth ? 0.93 : 0.88,
                        ),
                        _obsidianDeep.withValues(
                          alpha: isLowHealth ? 0.96 : 0.92,
                        ),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      // Internal Specular Refraction Top-Bevel Line
                      Positioned(
                        top: 0,
                        left: 16,
                        right: 16,
                        height: 1.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Colors.transparent,
                                isLowHealth
                                    ? _battleCrimsonPrimary.withValues(
                                        alpha: 0.70 + 0.30 * alarm,
                                      )
                                    : Colors.white.withValues(
                                        alpha: 0.25 + 0.15 * ambient,
                                      ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Card Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                        child: _buildPanelContent(
                          context,
                          status: status,
                          statusColor: statusColor,
                          showPenalty: showPenalty,
                          hpFraction: hpFraction,
                          hpPct: hpPct,
                          mpFraction: mpFraction,
                          mpPct: mpPct,
                          dpFraction: dpFraction,
                          dpTier: dpTier,
                          isLowHealth: isLowHealth,
                          heartScale: heartScale,
                          alarm: alarm,
                          ambient: ambient,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPanelContent(
    BuildContext context, {
    required PlayerHealthStatus status,
    required Color statusColor,
    required bool showPenalty,
    required double hpFraction,
    required int hpPct,
    required double mpFraction,
    required int mpPct,
    required double dpFraction,
    required int dpTier,
    required bool isLowHealth,
    required double heartScale,
    required double alarm,
    required double ambient,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // ── Header: Living Bio-Core + Telemetry & State Badge ───────────────
        Row(
          children: <Widget>[
            // Pulsing Living Bio-Core Orb
            _buildLivingBioCoreOrb(
              isLowHealth: isLowHealth,
              statusColor: statusColor,
              scale: heartScale,
              alarm: alarm,
              ambient: ambient,
            ),
            const SizedBox(width: 10),

            // Header Title & Subsystem Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          'YAŞAMSAL GÖSTERGELER',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.textPrimary,
                            letterSpacing: 0.9,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '· VITALS',
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLowHealth
                        ? 'KRİTİK CAN · ACİL MÜDAHALE GEREKİYOR'
                        : 'AİON 2 SAVAŞ & BİYOMETRİK VERİLERİ',
                    style: AppTextStyles.micro.copyWith(
                      color: isLowHealth
                          ? _battleCrimsonPrimary
                          : AppColors.mutedTitanium,
                      fontWeight: FontWeight.w800,
                      fontSize: 9.5,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Bio-Status Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.55),
                  width: 1.1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.20),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Pulsing status beacon light
                  Container(
                    width: 6.5,
                    height: 6.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLowHealth
                          ? Color.lerp(_battleCrimsonPrimary, Colors.white, alarm)
                          : statusColor,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: isLowHealth ? _battleCrimsonPrimary : statusColor,
                          blurRadius: isLowHealth ? 6 + 4 * alarm : 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5.5),
                  Text(
                    healthStatusLabel(status).toUpperCase(),
                    style: AppTextStyles.micro.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 1. Living HP Bar (Battle Crimson Bio-Glow) ──────────────────────
        _buildTacticalSegmentedBar(
          title: 'HP (SAĞLIK)',
          currentValue: widget.profile.health,
          maxValue: widget.profile.maxHealth,
          fraction: hpFraction,
          percentLabel: '%$hpPct',
          segmentCount: 10,
          gradientColors: isLowHealth
              ? const <Color>[_battleCrimsonPrimary, _battleCrimsonSecondary]
              : <Color>[statusColor, statusColor.withValues(alpha: 0.85)],
          icon: Icons.favorite_rounded,
          iconColor: isLowHealth ? _battleCrimsonPrimary : statusColor,
          glowColor: isLowHealth
              ? _battleCrimsonPrimary.withValues(alpha: 0.70)
              : statusColor.withValues(alpha: 0.40),
          isGlowing: true,
          trackHeight: 10,
        ),
        const SizedBox(height: 9),

        // ── 2. Living MP Bar (Ether Cyan Energy Surge) ──────────────────────
        _buildTacticalSegmentedBar(
          title: 'MP (MANA / ENERJİ)',
          currentValue: widget.profile.energy,
          maxValue: widget.profile.maxEnergy,
          fraction: mpFraction,
          percentLabel: '%$mpPct',
          segmentCount: 8,
          gradientColors: const <Color>[
            _etherCyanPrimary,
            _etherCyanSecondary,
          ],
          icon: Icons.bolt_rounded,
          iconColor: _etherCyanPrimary,
          glowColor: _etherCyanPrimary.withValues(alpha: 0.45),
          isGlowing: true,
          trackHeight: 9,
        ),
        const SizedBox(height: 9),

        // ── 3. Divine Power (DP) 4000 Awakening Gauge ───────────────────────
        _buildTacticalSegmentedBar(
          title: 'DP (DİVİNE POWER · İLAHİ GÜÇ)',
          currentValue: _divinePower,
          maxValue: 4000,
          fraction: dpFraction,
          percentLabel: dpTier > 0
              ? 'Kademe $dpTier Uyanış'
              : '%${(dpFraction * 100).round()}',
          segmentCount: 4,
          gradientColors: const <Color>[
            _divineGoldPrimary,
            _divineGoldSecondary,
          ],
          icon: Icons.flare_rounded,
          iconColor: _divineGoldPrimary,
          glowColor: _divineGoldPrimary.withValues(alpha: 0.55),
          isGlowing: dpTier > 0,
          trackHeight: 9,
          trailingBadge: dpTier > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        _divineGoldPrimary.withValues(alpha: 0.30),
                        _divineGoldSecondary.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _divineGoldPrimary.withValues(alpha: 0.70),
                      width: 0.9,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _divineGoldPrimary.withValues(alpha: 0.25),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    'KADEME $dpTier UYANIŞ',
                    style: AppTextStyles.micro.copyWith(
                      color: _divineGoldPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 8.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 10),

        // ── Critical Low Health Warning Banner (< 25% Alert) ────────────────
        if (isLowHealth) ...<Widget>[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  _battleCrimsonPrimary.withValues(alpha: 0.20 + 0.10 * alarm),
                  _battleCrimsonDark.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: Color.lerp(
                  _battleCrimsonPrimary.withValues(alpha: 0.50),
                  _battleCrimsonPrimary,
                  alarm,
                )!,
                width: 1.1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _battleCrimsonPrimary.withValues(alpha: 0.18 * alarm),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: _battleCrimsonPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ACİL UYARI: Can seviyesi %25 altına indi! Sonraki darbede ölümcül yara alabilirsin.',
                    style: AppTextStyles.micro.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Status Descriptive Tip
        Text(
          healthStatusTip(status),
          style: AppTextStyles.micro.copyWith(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),

        // Passive Regen Telemetry (when wounded)
        if (!_restricted &&
            widget.profile.health < widget.profile.maxHealth) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const Icon(
                Icons.schedule_rounded,
                size: 13,
                color: AppColors.mutedTitanium,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Tam dolma: ~${formatRegenDuration(_secondsToFull)} '
                  '(${healthRegenPercentPerHour(alchemistBonus: widget.profile.characterClass == CharacterClass.alchemist).toStringAsFixed(1)}%/sa)',
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.mutedTitanium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Combat Penalty Indicator
        if (showPenalty) ...<Widget>[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warningSolar.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.warningSolar.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              '⚠️ Yaralı cezası: PvP gücü -${(woundedPvpPowerPenalty * 100).round()}%',
              style: AppTextStyles.micro.copyWith(
                color: AppColors.warningSolar,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // ── Mobile Quick-Action Buttons (Glassmorphic Tactile) ───────────────
        Row(
          children: <Widget>[
            // Inventory / Potions Quick Action
            Expanded(
              child: _TactileObsidianButton(
                label: 'İksirler',
                icon: Icons.local_drink_rounded,
                accent: AppColors.accentCyan,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppRoutes.inventory);
                },
              ),
            ),
            const SizedBox(width: 8),

            // Hospital / Prison or Gem Instant Heal
            if (_restricted)
              Expanded(
                child: _TactileObsidianButton(
                  label: widget.inHospital ? 'Hastane' : 'Hapishane',
                  icon: Icons.local_hospital_rounded,
                  accent: AppColors.mysticRuby,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push(
                      widget.inHospital
                          ? AppRoutes.hospital
                          : AppRoutes.prison,
                    );
                  },
                ),
              )
            else
              Expanded(
                child: _TactileObsidianButton(
                  label: _canGemHeal ? 'Elmas ($_gemCost)' : 'Tam Dolu',
                  icon: Icons.diamond_rounded,
                  accent: AppColors.liquidGold,
                  loading: _healing,
                  onTap: _canGemHeal && widget.profile.gems >= _gemCost
                      ? _healWithGems
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Living Bio-Core Orb with multi-ring pulsation and heartbeat scaling.
  Widget _buildLivingBioCoreOrb({
    required bool isLowHealth,
    required Color statusColor,
    required double scale,
    required double alarm,
    required double ambient,
  }) {
    final Color coreColor = isLowHealth ? _battleCrimsonPrimary : statusColor;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              coreColor.withValues(alpha: 0.35 + 0.25 * (isLowHealth ? alarm : ambient)),
              coreColor.withValues(alpha: 0.10),
              _obsidianDeep.withValues(alpha: 0.85),
            ],
            stops: const <double>[0.3, 0.7, 1.0],
          ),
          border: Border.all(
            color: Color.lerp(
              coreColor.withValues(alpha: 0.60),
              Colors.white,
              isLowHealth ? 0.35 * alarm : 0.15 * ambient,
            )!,
            width: 1.3,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: coreColor.withValues(
                alpha: isLowHealth ? 0.45 + 0.30 * alarm : 0.25 + 0.15 * ambient,
              ),
              blurRadius: isLowHealth ? 12 + 6 * alarm : 8 + 4 * ambient,
              spreadRadius: isLowHealth ? 1.0 * alarm : 0.0,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.favorite_rounded,
            size: 16,
            color: isLowHealth
                ? Color.lerp(_battleCrimsonPrimary, _battleCrimsonSecondary, alarm)
                : statusColor,
          ),
        ),
      ),
    );
  }

  /// Tactical Segmented Bar with dual-layer ghost damage lag and laser-cut dividers.
  Widget _buildTacticalSegmentedBar({
    required String title,
    required int currentValue,
    required int maxValue,
    required double fraction,
    required String percentLabel,
    required int segmentCount,
    required List<Color> gradientColors,
    required IconData icon,
    required Color iconColor,
    required Color glowColor,
    bool isGlowing = false,
    double trackHeight = 9.0,
    Widget? trailingBadge,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Title Row
        Row(
          children: <Widget>[
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                title,
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailingBadge != null) trailingBadge,
            const Spacer(),
            Text(
              '$currentValue / $maxValue ($percentLabel)',
              style: AppTextStyles.micro.copyWith(
                color: AppColors.mutedTitanium,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),

        // Segmented Track Stack
        ClipRRect(
          borderRadius: BorderRadius.circular(4.5),
          child: SizedBox(
            height: trackHeight,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // 1. Obsidian Void Background Track
                const ColoredBox(
                  color: _obsidianDeep,
                ),

                // 2. Damage / Heal Ghost Trail Lag Bar (750ms easeOutQuad)
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeOutQuad,
                  tween: Tween<double>(begin: 0.0, end: fraction),
                  builder: (BuildContext context, double ghostFraction, _) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ghostFraction,
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    );
                  },
                ),

                // 3. Active Living Gradient Bar (350ms easeOutCubic)
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0.0, end: fraction),
                  builder: (BuildContext context, double activeFraction, _) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: activeFraction,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: isGlowing
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: glowColor,
                                    blurRadius: 8,
                                    spreadRadius: 0.5,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  },
                ),

                // 4. Tactical Segment Dividers (Laser-cut notches)
                Row(
                  children: List<Widget>.generate(
                    segmentCount - 1,
                    (int index) => Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 1.5,
                          height: trackHeight,
                          color: _obsidianDeep.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ),
                ),

                // 5. Specular Top Rim Glaze Line
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1.0,
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tactile Obsidian-Glass Mobile Button with specular highlight and haptic response.
class _TactileObsidianButton extends StatelessWidget {
  const _TactileObsidianButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.accent,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.liquidGold;
    final bool enabled = onTap != null && !loading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        splashColor: color.withValues(alpha: 0.20),
        highlightColor: color.withValues(alpha: 0.10),
        child: Ink(
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      color.withValues(alpha: 0.24),
                      const Color(0xFF0F141F).withValues(alpha: 0.85),
                      const Color(0xFF07090E).withValues(alpha: 0.95),
                    ],
                  )
                : null,
            color: enabled ? null : const Color(0xFF07090E).withValues(alpha: 0.55),
            border: Border.all(
              color: enabled
                  ? color.withValues(alpha: 0.65)
                  : AppColors.mutedTitanium.withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: <Widget>[
              // Specular Top Glaze
              if (enabled)
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  height: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          color.withValues(alpha: 0.60),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              // Button Content
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (loading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    else
                      Icon(
                        icon,
                        size: 15,
                        color: enabled ? color : AppColors.mutedTitanium,
                      ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        label,
                        style: AppTextStyles.micro.copyWith(
                          color: enabled ? color : AppColors.mutedTitanium,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          fontSize: 10.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
