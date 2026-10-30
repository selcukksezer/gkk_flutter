import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/universal_game_dialog.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/restriction/restriction_screen_ui.dart';
import '../../components/restriction/ward_panel.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/player_health.dart';
import '../../core/utils/power_formula.dart';
import '../../core/utils/restriction_reason_labels.dart';
import '../../core/utils/restriction_time.dart';
import '../../l10n/l10n.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../restriction/restriction_timer_mixin.dart';
import 'widgets/hospital_aura_painter.dart';
import 'widgets/hospital_particles.dart';
import 'widgets/hospital_treatment_panel.dart';

/// Active navigational section tab inside the Hospital Sanctuary.
enum _HospitalTab {
  treatment,
  ward,
  codex,
}

/// AAA Hospital Sanctuary Screen featuring real-time ECG vital monitor HUD,
/// dynamic medical recovery countdown, Aion celestial aura styling,
/// liquid HP/energy physics gauges, and doctor/priest consultation cards.
class HospitalScreen extends ConsumerStatefulWidget {
  const HospitalScreen({super.key});

  @override
  ConsumerState<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends ConsumerState<HospitalScreen>
    with RestrictionTimerMixin<HospitalScreen>, TickerProviderStateMixin {
  bool _healing = false;
  _HospitalTab _currentTab = _HospitalTab.treatment;

  late final HospitalParticleController _particleController;
  late final AnimationController _ecgController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  String? readRestrictionUntil() =>
      ref.read(playerProvider).profile?.hospitalUntil;

  @override
  void initState() {
    super.initState();
    _particleController = HospitalParticleController();

    _ecgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      startRestrictionTimer(attachProfileListener: true);
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.hospital);
    });
  }

  @override
  void dispose() {
    _ecgController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  int _gemHealCost() =>
      math.max(1, (restrictionRemainingDuration.inSeconds / 60).ceil() * 3);

  Future<Map<String, dynamic>> _callHealRpc() async {
    final dynamic raw = await SupabaseService.client.rpc('heal_with_gems');
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> _healWithGems({bool expectFree = false}) async {
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    if (profile == null) return;

    final int freeRemaining =
        freeHospitalDischargesRemaining(profile.hospitalLifetimeCount);
    final bool useFree =
        expectFree || canFreeHospitalDischarge(profile.hospitalLifetimeCount);

    if (useFree) {
      final bool? confirm = await UniversalGameDialog.show(
        context,
        title: 'Ücretsiz Taburcu',
        message: freeRemaining > 0
            ? 'Kutsal ücretsiz taburcu hakkını kullanmak istiyor musun? (Kalan hak: $freeRemaining)'
            : 'Taburcu olmak istiyor musun?',
        confirmLabel: 'Taburcu Ol',
        cancelLabel: 'İptal',
      );
      if (confirm != true) return;
    } else {
      final int gemCost = _gemHealCost();
      if (profile.gems < gemCost) {
        if (!mounted) return;
        final bool? goShop = await UniversalGameDialog.show(
          context,
          title: 'Yetersiz Elmas',
          message:
              'Bu işlem için $gemCost elmas gerekiyor. Mevcut: ${profile.gems}',
          confirmLabel: 'Dükkana Git',
          cancelLabel: 'İptal',
        );
        if (goShop == true && mounted) {
          context.go(AppRoutes.shop);
        }
        return;
      }

      final bool? confirm = await UniversalGameDialog.show(
        context,
        title: 'Kutsal Taburcu',
        message:
            '$gemCost elmas harcayarak kutsal arınma ile hemen taburcu olmak istiyor musun?',
        confirmLabel: 'Onayla',
        cancelLabel: 'İptal',
      );
      if (confirm != true) return;
    }

    setState(() => _healing = true);
    _particleController.triggerBurst(count: 32);

    try {
      final Map<String, dynamic> response = await _callHealRpc();
      final bool wasFree = response['was_free'] == true;
      final bool success = response['success'] == true || wasFree;
      if (!success) {
        throw Exception(response['error'] ?? 'Taburcu olunamadı');
      }

      await ref.read(playerProvider.notifier).loadProfile();
      restrictionTimer?.cancel();
      _particleController.triggerBurst(count: 36);

      setState(() {
        _healing = false;
        restrictionRemainingDuration = Duration.zero;
      });

      if (!mounted) return;
      final PlayerProfile? after = ref.read(playerProvider).profile;
      final String woundedHint = after != null && after.maxHealth > 0
          ? ' Yaralı çıkış: Can ${formatHealthRatio(after.health, after.maxHealth)}.'
          : '';
      if (wasFree) {
        AppMessenger.showSuccess(
          context,
          'Ücretsiz taburcu oldun. Kalan hak: ${response['free_discharges_remaining'] ?? 0}.$woundedHint',
        );
      } else {
        AppMessenger.showSuccess(context, 'Taburcu oldun.$woundedHint');
      }
    } catch (e) {
      setState(() => _healing = false);
      if (mounted) {
        AppMessenger.showError(context, 'Taburcu olunamadı. Tekrar dene.');
      }
    }
  }

  Future<void> _watchAdToReduce() async {
    if (_healing) return;

    setState(() => _healing = true);
    String? challengeToken;
    try {
      final dynamic challenge = await SupabaseService.client.rpc(
        'issue_ad_timer_challenge',
        params: <String, dynamic>{
          'p_timer': 'hospital',
          'p_placement': 'hospital_timer',
        },
      );
      if (!mounted) return;
      if (challenge is! Map || challenge['success'] != true) {
        final String msg = challenge is Map
            ? (challenge['message'] ?? challenge['error'] ?? 'Reklam açılamadı')
                .toString()
            : 'Reklam açılamadı';
        AppMessenger.showError(context, msg);
        return;
      }
      challengeToken = challenge['challenge_token']?.toString();
      if (challengeToken == null || challengeToken.isEmpty) {
        AppMessenger.showError(context, 'Reklam doğrulama başarısız.');
        return;
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'Reklam açılamadı.');
      return;
    } finally {
      if (mounted && challengeToken == null) {
        setState(() => _healing = false);
      }
    }

    final String token = challengeToken;
    if (!mounted) return;

    final AdResult adResult = await AdService.instance
        .showRewardedAd(context, placement: 'hospital_timer');
    if (adResult != AdResult.rewarded) {
      if (mounted) {
        setState(() => _healing = false);
        AppMessenger.show(context, 'Reklam tamamlanmadı.');
      }
      return;
    }

    try {
      final dynamic res = await SupabaseService.client.rpc(
        'reduce_timer_with_ad',
        params: <String, dynamic>{
          'p_timer': 'hospital',
          'p_challenge_token': token,
        },
      );
      final bool ok = res is Map && res['success'] == true;
      if (!mounted) return;
      if (!ok) {
        final String msg = res is Map
            ? (res['message'] ?? res['error'] ?? 'İşlem başarısız').toString()
            : 'İşlem başarısız';
        AppMessenger.showError(context, msg);
      } else {
        final bool released = res['released'] == true;
        final int usesLeft = (res['uses_left'] as num?)?.toInt() ?? 0;
        _particleController.triggerBurst(count: 24);
        AppMessenger.showSuccess(
          context,
          released
              ? '🎉 Taburcu oldun!'
              : '⏳ Süre 30 dakika kısaldı! (Kalan hak: $usesLeft)',
        );
      }
      await ref.read(playerProvider.notifier).loadProfile();
      startRestrictionTimer();
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'İşlem başarısız.');
    } finally {
      if (mounted) setState(() => _healing = false);
    }
  }

  Future<void> _doctorVisit() async {
    if (_healing) return;
    final bool? confirm = await UniversalGameDialog.show(
      context,
      title: context.l10n.sys2_doctor_visit_title,
      message: context.l10n.sys2_doctor_visit_body,
      confirmLabel: context.l10n.sys2_doctor_visit_confirm,
      cancelLabel: 'İptal',
    );
    if (confirm != true) return;

    setState(() => _healing = true);
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('attempt_doctor_visit');
      final Map<String, dynamic> res = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      await ref.read(playerProvider.notifier).loadProfile();
      if (!mounted) return;
      if (res['success'] != true) {
        AppMessenger.showError(
          context,
          (res['message'] ?? res['error'] ?? 'Doktor ziyareti başarısız')
              .toString(),
        );
      } else {
        final int cut = (res['cut_minutes'] as num?)?.toInt() ?? 0;
        final bool released = res['released'] == true;
        _particleController.triggerBurst(count: 26);
        AppMessenger.showSuccess(
          context,
          released
              ? context.l10n.sys2_doctor_released
              : (cut > 0
                  ? context.l10n.sys2_doctor_cut(cut)
                  : context.l10n.sys2_doctor_noop),
        );
      }
      startRestrictionTimer();
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Doktor ziyareti başarısız.');
      }
    } finally {
      if (mounted) setState(() => _healing = false);
    }
  }

  Future<void> _useGuildDoctor() async {
    if (_healing) return;
    setState(() => _healing = true);
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('use_guild_doctor');
      final Map<String, dynamic> res = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      await ref.read(playerProvider.notifier).loadProfile();
      if (!mounted) return;
      if (res['success'] != true) {
        AppMessenger.showError(
          context,
          (res['message'] ?? res['error'] ?? 'Klinik doktor kullanılamadı')
              .toString(),
        );
      } else {
        _particleController.triggerBurst(count: 24);
        AppMessenger.showSuccess(context, context.l10n.sys2_guild_doctor_ok);
      }
      startRestrictionTimer();
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Klinik doktor kullanılamadı.');
      }
    } finally {
      if (mounted) setState(() => _healing = false);
    }
  }

  Future<void> _attemptEscape() async {
    setState(() => _healing = true);
    try {
      final dynamic rawResponse =
          await SupabaseService.client.rpc('attempt_hospital_escape');
      final Map<String, dynamic> response = rawResponse is Map
          ? Map<String, dynamic>.from(rawResponse)
          : <String, dynamic>{};
      await ref.read(playerProvider.notifier).loadProfile();

      final bool success = response['success'] == true;
      final bool escaped = response['escaped'] == true;
      final String message =
          (response['message'] ?? response['error'] ?? 'İşlem tamamlandı')
              .toString();

      if (mounted) {
        if (!success) {
          AppMessenger.showError(context, message);
        } else if (escaped) {
          _particleController.triggerBurst(count: 36);
          AppMessenger.showSuccess(context, context.l10n.hospital_escape_ok);
        } else {
          final int? minutes = _escapePenaltyMinutes(message);
          AppMessenger.showError(
            context,
            minutes != null
                ? context.l10n.hospital_escape_fail(minutes)
                : message,
            title: context.l10n.escape_fail_title,
          );
        }
      }

      setState(() {
        _healing = false;
        if (escaped) {
          restrictionRemainingDuration = Duration.zero;
          restrictionTimer?.cancel();
        } else {
          updateRestrictionRemaining(isFirst: true);
        }
      });
    } catch (e) {
      setState(() => _healing = false);
      if (mounted) {
        AppMessenger.showError(context, 'Kaçış denemesi başarısız.');
      }
    }
  }

  int? _escapePenaltyMinutes(String message) {
    final Match? match =
        RegExp(r'(\d+)\s*dakika', caseSensitive: false).firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerProvider);
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    final bool inHospital = restrictionActive;

    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.hastane_2,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.hospital,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          HospitalSanctuaryBackdrop(isHealing: _healing),
          RestrictionScreenScaffold(
            child: profile == null
                ? const RestrictionLoadingCard()
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 580),
                      child: inHospital
                          ? _buildInHospital(profile)
                          : _buildHealthy(profile),
                    ),
                  ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: HospitalRestorativeParticles(
                controller: _particleController,
                particleCount: 42,
                celestialGlow: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTabs() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.carbonVoid.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.borderFaint,
          width: 1.0,
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _TabButton(
              label: 'Tedavi & Vital',
              icon: Icons.healing_rounded,
              selected: _currentTab == _HospitalTab.treatment,
              accentColor: AppColors.toxicNeon,
              onTap: () => setState(() => _currentTab = _HospitalTab.treatment),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              label: 'Hasta Koğuşu',
              icon: Icons.meeting_room_rounded,
              selected: _currentTab == _HospitalTab.ward,
              accentColor: AppColors.accentCyan,
              onTap: () => setState(() => _currentTab = _HospitalTab.ward),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              label: 'Tıp Rehberi',
              icon: Icons.menu_book_rounded,
              selected: _currentTab == _HospitalTab.codex,
              accentColor: AppColors.liquidGold,
              onTap: () => setState(() => _currentTab = _HospitalTab.codex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInHospital(PlayerProfile profile) {
    final DateTime? releaseTime =
        parseRestrictionUntil(profile.hospitalUntil);
    final int gemCost = _gemHealCost();
    final bool canFree =
        canFreeHospitalDischarge(profile.hospitalLifetimeCount);
    final int freeRemaining =
        freeHospitalDischargesRemaining(profile.hospitalLifetimeCount);

    final PlayerHealthStatus status = resolveHealthStatus(
      health: profile.health,
      maxHealth: profile.maxHealth,
      restricted: true,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HospitalAltarHeader(
          inHospital: true,
          isHealing: _healing,
          remainingCountdown:
              formatRestrictionCountdown(restrictionRemainingDuration),
          energyRatio: '⚡ ${profile.energy}/${profile.maxEnergy}',
        ),
        _EcgMonitorHudCard(
          profile: profile,
          inHospital: true,
          isHealing: _healing,
          remainingDuration: restrictionRemainingDuration,
          progress: restrictionProgress(),
          releaseTime: releaseTime,
          healthStatus: status,
          ecgPhase: _ecgController.value,
          pulseAnimation: _pulseAnimation,
          onTapVital: () => _particleController.triggerBurst(count: 14),
        ),
        const SizedBox(height: 12),
        _buildSectionTabs(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_currentTab) {
            _HospitalTab.treatment => HospitalTreatmentPanel(
                key: const ValueKey<String>('hospital_treatment_panel'),
                profile: profile,
                inHospital: true,
                isHealing: _healing,
                remainingDuration: restrictionRemainingDuration,
                progress: restrictionProgress(),
                gemDischargeCost: gemCost,
                canFreeDischarge: canFree,
                freeDischargesRemaining: freeRemaining,
                onHealWithGems: () => _healWithGems(expectFree: canFree),
                onDoctorVisit: _doctorVisit,
                onGuildDoctor: _useGuildDoctor,
                onWatchAd:
                    MockAdService.allowMockReward ? _watchAdToReduce : null,
                onAttemptEscape: _attemptEscape,
                adActionWrapper: (Widget child) => TutorialAnchorScope(
                  id: TutorialAnchorId.hospitalAdTimerBtn,
                  onTutorialTap: () => TutorialTriggers.onAnchorTap(
                    ref,
                    TutorialAnchorId.hospitalAdTimerBtn,
                  ),
                  child: child,
                ),
                wardPanel: null,
              ),
            _HospitalTab.ward => _WardSectionView(
                key: const ValueKey<String>('hospital_ward_panel'),
                wardType: 'hospital',
                accent: RestrictionScreenUi.hospitalAccent,
              ),
            _HospitalTab.codex => const _HospitalCodexView(
                key: ValueKey<String>('hospital_codex_view'),
              ),
          },
        ),
      ],
    );
  }

  Widget _buildHealthy(PlayerProfile profile) {
    final PlayerHealthStatus status = resolveHealthStatus(
      health: profile.health,
      maxHealth: profile.maxHealth,
      restricted: false,
    );

    final bool isAlchemist =
        profile.characterClass == CharacterClass.alchemist;
    final double regenPerHour =
        healthRegenPercentPerHour(alchemistBonus: isAlchemist);
    final int secondsToFull = estimateSecondsToFullHealth(
      health: profile.health,
      maxHealth: profile.maxHealth,
      alchemistBonus: isAlchemist,
    );
    final String regenEta = formatRegenDuration(secondsToFull);
    final bool needsHealing =
        profile.maxHealth > 0 && profile.health < profile.maxHealth;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HospitalAltarHeader(
          inHospital: false,
          isHealing: _healing,
          energyRatio: '⚡ ${profile.energy}/${profile.maxEnergy}',
        ),
        _EcgMonitorHudCard(
          profile: profile,
          inHospital: false,
          isHealing: _healing,
          remainingDuration: Duration.zero,
          progress: 1.0,
          releaseTime: null,
          healthStatus: status,
          ecgPhase: _ecgController.value,
          pulseAnimation: _pulseAnimation,
          onTapVital: () => _particleController.triggerBurst(count: 14),
        ),
        const SizedBox(height: 12),
        _buildSectionTabs(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_currentTab) {
            _HospitalTab.treatment => Column(
                key: const ValueKey<String>('healthy_treatment_view'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SanctuaryGlassCard(
                    accent: needsHealing
                        ? AppColors.coralFlare
                        : AppColors.toxicNeon,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        LiquidRecoveryGauge(
                          title: 'Hayatiyet (Can / HP)',
                          subtitle: needsHealing
                              ? 'Doğal İyileşme: +${regenPerHour.toStringAsFixed(1)}%/saat · Tam Dolum: $regenEta'
                              : 'Bedenin kusursuz durumda. Tam güçle savaşa hazırsın.',
                          currentValue: profile.health,
                          maxValue: profile.maxHealth,
                          primaryColor: status == PlayerHealthStatus.critical
                              ? const Color(0xFFEA2143)
                              : (status == PlayerHealthStatus.wounded
                                  ? const Color(0xFFF97316)
                                  : const Color(0xFF10B981)),
                          secondaryColor: status == PlayerHealthStatus.critical
                              ? const Color(0xFF991B1B)
                              : (status == PlayerHealthStatus.wounded
                                  ? const Color(0xFFEA580C)
                                  : const Color(0xFF047857)),
                          accentGlow: needsHealing
                              ? AppColors.coralFlare
                              : AppColors.toxicNeon,
                          height: 52,
                          showThresholds: true,
                          auxiliaryTag: healthStatusLabel(status),
                          statusColor: healthStatusColor(status),
                        ),
                        const SizedBox(height: 14),
                        LiquidRecoveryGauge(
                          title: 'Astral Enerji (Mana / Energy)',
                          subtitle: 'Savaş & Zindan Keşfi Güç Rezervi',
                          currentValue: profile.energy,
                          maxValue: profile.maxEnergy,
                          primaryColor: const Color(0xFF3B82F6),
                          secondaryColor: const Color(0xFF1D4ED8),
                          accentGlow: AppColors.accentBlue,
                          height: 44,
                          auxiliaryTag:
                              '${profile.energy}/${profile.maxEnergy}',
                          statusColor: AppColors.accentBlue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StatusAilmentsPanel(
                    healthStatus: status,
                    inHospital: false,
                    hospitalReason: null,
                    energyRatio: profile.maxEnergy > 0
                        ? profile.energy / profile.maxEnergy
                        : 1.0,
                  ),
                  const SizedBox(height: 12),
                  DoctorPriestConsultationCard(
                    inHospital: false,
                    isHealing: _healing,
                    healthStatus: status,
                    gemDischargeCost: _gemHealCost(),
                    canFreeDischarge: false,
                    freeDischargesRemaining: 0,
                    onDoctorVisit: _doctorVisit,
                    onGuildDoctor: _useGuildDoctor,
                    onDischarge: () {
                      _particleController.triggerBurst(count: 24);
                      AppMessenger.showSuccess(
                        context,
                        'Kutsal sunağın ışığı bedenini kutsadı.',
                      );
                    },
                  ),
                ],
              ),
            _HospitalTab.ward => _WardSectionView(
                key: const ValueKey<String>('healthy_ward_panel'),
                wardType: 'hospital',
                accent: RestrictionScreenUi.hospitalAccent,
              ),
            _HospitalTab.codex => const _HospitalCodexView(
                key: ValueKey<String>('healthy_codex_view'),
              ),
          },
        ),
      ],
    );
  }
}

/// Animated high-tech medical ECG Vital Monitor HUD card.
class _EcgMonitorHudCard extends StatelessWidget {
  const _EcgMonitorHudCard({
    required this.profile,
    required this.inHospital,
    required this.isHealing,
    required this.remainingDuration,
    required this.progress,
    required this.releaseTime,
    required this.healthStatus,
    required this.ecgPhase,
    required this.pulseAnimation,
    this.onTapVital,
  });

  final PlayerProfile profile;
  final bool inHospital;
  final bool isHealing;
  final Duration remainingDuration;
  final double progress;
  final DateTime? releaseTime;
  final PlayerHealthStatus healthStatus;
  final double ecgPhase;
  final Animation<double> pulseAnimation;
  final VoidCallback? onTapVital;

  int _calculateBpm() {
    if (isHealing) return 60;
    if (inHospital) {
      if (healthStatus == PlayerHealthStatus.critical) return 128;
      if (healthStatus == PlayerHealthStatus.wounded) return 102;
      return 88;
    }
    return switch (healthStatus) {
      PlayerHealthStatus.critical => 124,
      PlayerHealthStatus.wounded => 98,
      PlayerHealthStatus.recovering => 84,
      PlayerHealthStatus.healthy => 72,
      PlayerHealthStatus.restricted => 90,
    };
  }

  @override
  Widget build(BuildContext context) {
    final int bpm = _calculateBpm();
    final Color monitorAccent = inHospital
        ? (healthStatus == PlayerHealthStatus.critical
            ? const Color(0xFFEA2143)
            : (healthStatus == PlayerHealthStatus.wounded
                ? const Color(0xFFF97316)
                : AppColors.mysticRuby))
        : AppColors.toxicNeon;

    final String triageCode = inHospital
        ? (healthStatus == PlayerHealthStatus.critical
            ? 'KOD KIRMIZI · ACİL TRAVMA'
            : (healthStatus == PlayerHealthStatus.wounded
                ? 'KOD SARI · AĞIR YARALI'
                : 'KOD MAVİ · MÜŞAHADE'))
        : 'KOD YEŞİL · TABURCU / AKTİF';

    final int bedIndex = (profile.id.hashCode.abs() % 12) + 1;

    return SanctuaryGlassCard(
      accent: monitorAccent,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  AnimatedBuilder(
                    animation: pulseAnimation,
                    builder: (BuildContext context, _) {
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: monitorAccent,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: monitorAccent.withValues(
                                alpha: 0.4 + 0.5 * pulseAnimation.value,
                              ),
                              blurRadius: 8 * pulseAnimation.value + 2,
                              spreadRadius: 2 * pulseAnimation.value,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ICU VİTAL MONİTÖRÜ · YATAK $bedIndex',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: monitorAccent,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: monitorAccent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: monitorAccent.withValues(alpha: 0.45),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  triageCode,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: monitorAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      inHospital
                          ? 'KALAN İYİLEŞME SÜRESİ'
                          : 'GÜNCEL KLİNİK DURUM',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inHospital
                          ? formatRestrictionCountdown(remainingDuration)
                          : '00:00:00 (SAĞLIKLI)',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: inHospital
                            ? AppColors.textPrimary
                            : AppColors.toxicNeon,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inHospital && releaseTime != null
                          ? 'Tahmini Taburcu: ${formatRestrictionRelease(releaseTime)}'
                          : (inHospital
                              ? 'İlahi arınma süreci aktif'
                              : 'Karantina veya yatış kaydı yok'),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: monitorAccent.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onTapVital,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: monitorAccent.withValues(alpha: 0.10),
                    border: Border.all(
                      color: monitorAccent.withValues(alpha: 0.30),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AnimatedBuilder(
                            animation: pulseAnimation,
                            builder: (BuildContext context, _) {
                              return Transform.scale(
                                scale: 0.9 + 0.25 * pulseAnimation.value,
                                child: Icon(
                                  Icons.favorite_rounded,
                                  size: 15,
                                  color: monitorAccent,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$bpm BPM',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: monitorAccent,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '99% SpO₂ · 120/80',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.carbonVoid.withValues(alpha: 0.95),
              border: Border.all(
                color: monitorAccent.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: CustomPaint(
                painter: _EcgWavePainter(
                  phase: ecgPhase,
                  color: monitorAccent,
                  bpm: bpm,
                  isHealing: isHealing,
                ),
              ),
            ),
          ),
          if (inHospital) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor:
                          monitorAccent.withValues(alpha: 0.15),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(monitorAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).toInt()}% İyileşme',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: monitorAccent,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// CustomPainter rendering real-time medical ECG heartbeat spikes and wave sweeps.
class _EcgWavePainter extends CustomPainter {
  _EcgWavePainter({
    required this.phase,
    required this.color,
    required this.bpm,
    required this.isHealing,
  });

  final double phase;
  final Color color;
  final int bpm;
  final bool isHealing;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double midY = height * 0.5;

    final Paint gridPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;
    for (double x = 0; x <= width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
    }
    for (double y = 0; y <= height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    final Paint axisPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(0, midY), Offset(width, midY), axisPaint);

    final Path wavePath = Path();
    const double cycleWidth = 84.0;
    wavePath.moveTo(0, midY);

    for (double x = 0; x <= width; x += 2.0) {
      final double cyclePos = (x % cycleWidth) / cycleWidth;
      double yOffset = 0.0;

      if (cyclePos > 0.12 && cyclePos <= 0.22) {
        final double pNorm = (cyclePos - 0.12) / 0.10;
        yOffset = -math.sin(pNorm * math.pi) * (height * 0.14);
      } else if (cyclePos > 0.26 && cyclePos <= 0.30) {
        final double qNorm = (cyclePos - 0.26) / 0.04;
        yOffset = math.sin(qNorm * math.pi) * (height * 0.12);
      } else if (cyclePos > 0.30 && cyclePos <= 0.38) {
        final double rNorm = (cyclePos - 0.30) / 0.08;
        if (rNorm < 0.5) {
          yOffset = -(rNorm * 2.0) * (height * 0.42);
        } else {
          yOffset = -((1.0 - rNorm) * 2.0) * (height * 0.42);
        }
      } else if (cyclePos > 0.38 && cyclePos <= 0.44) {
        final double sNorm = (cyclePos - 0.38) / 0.06;
        yOffset = math.sin(sNorm * math.pi) * (height * 0.20);
      } else if (cyclePos > 0.52 && cyclePos <= 0.68) {
        final double tNorm = (cyclePos - 0.52) / 0.16;
        yOffset = -math.sin(tNorm * math.pi) * (height * 0.18);
      }

      final double y = (midY + yOffset).clamp(2.0, height - 2.0);
      wavePath.lineTo(x, y);
    }

    final Paint tracePaint = Paint()
      ..color = color.withValues(alpha: isHealing ? 0.95 : 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(wavePath, tracePaint);

    final double sweepX = phase * width;
    final Paint cursorPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(sweepX - 35, 0),
        Offset(sweepX, 0),
        <Color>[
          Colors.transparent,
          color.withValues(alpha: 0.45),
        ],
      );
    canvas.drawRect(Rect.fromLTWH(sweepX - 35, 0, 35, height), cursorPaint);

    final Paint sparkDotPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.2);
    canvas.drawCircle(Offset(sweepX, midY), 2.2, sparkDotPaint);
  }

  @override
  bool shouldRepaint(covariant _EcgWavePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.color != color ||
        oldDelegate.bpm != bpm ||
        oldDelegate.isHealing != isHealing;
  }
}

/// Navigation section tab button.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RestrictionPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? accentColor.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? accentColor.withValues(alpha: 0.50)
                : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: selected ? accentColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inpatient Ward section view displaying bed occupancy and patient board.
class _WardSectionView extends StatelessWidget {
  const _WardSectionView({
    super.key,
    required this.wardType,
    required this.accent,
  });

  final String wardType;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SanctuaryGlassCard(
          accent: accent,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.40),
                  ),
                ),
                child: Icon(Icons.hotel_rounded, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'ICU & Gözlem Koğuşu',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hastanedeki oyuncuları incele, moral ver veya koğuşta sohbet et.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        WardPanel(
          wardType: wardType,
          accent: accent,
        ),
      ],
    );
  }
}

/// Clinical Codex view explaining hospital rules, combat trauma, and recovery formulas.
class _HospitalCodexView extends StatelessWidget {
  const _HospitalCodexView({super.key});

  @override
  Widget build(BuildContext context) {
    return SanctuaryGlassCard(
      accent: AppColors.liquidGold,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.menu_book_rounded,
                  color: AppColors.liquidGold, size: 20),
              SizedBox(width: 8),
              Text(
                'Sanctuary Tıp & Şifa Rehberi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          _CodexRuleTile(
            icon: Icons.shield_outlined,
            title: 'Savaş Travması Eşikleri',
            accent: Color(0xFFEA2143),
            description:
                'Canın %20 altına düştüğünde Kritik Travma oluşur ve savaş katılımı kilitlenir. %50 altında ise Ağır Yaralı statüsü ile PvP saldırı gücünde %5 ceza alırsın.',
          ),
          SizedBox(height: 10),
          _CodexRuleTile(
            icon: Icons.hourglass_empty_rounded,
            title: 'Doğal Can Yenilenmesi',
            accent: AppColors.toxicNeon,
            description:
                'Hastane yatışı haricinde canın saatte %5 oranında pasif yenilenir (tam dolum 20 saat). Simyacı sınıfı +%50 pasif bonus ile saatte %7.5 can tazeler.',
          ),
          SizedBox(height: 10),
          _CodexRuleTile(
            icon: Icons.medical_services_rounded,
            title: 'Başhekim & Lonca Kliniği',
            accent: AppColors.accentCyan,
            description:
                'Başhekim Alistair muayenesinde şansa bağlı süre kesintisi alabilirsin. Lonca klinikleri üyelerine özel hızlandırılmış iyileşme desteği sunar.',
          ),
          SizedBox(height: 10),
          _CodexRuleTile(
            icon: Icons.directions_run_rounded,
            title: 'Firar Girişimi & Güvenlik',
            accent: AppColors.coralFlare,
            description:
                'Hastaneden gizli kaçış riskli bir girişimdir. Başarısız olursan nöbetçiler tarafından yakalanıp +15 dakika ek yatış cezası alırsın.',
          ),
        ],
      ),
    );
  }
}

class _CodexRuleTile extends StatelessWidget {
  const _CodexRuleTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(
          color: accent.withValues(alpha: 0.28),
          width: 0.9,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
