import 'dart:math';

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
import '../../core/utils/player_health.dart';
import '../../core/utils/power_formula.dart';
import '../../core/utils/restriction_reason_labels.dart';
import '../../core/utils/restriction_time.dart';
import '../../l10n/l10n.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../restriction/restriction_timer_mixin.dart';

class HospitalScreen extends ConsumerStatefulWidget {
  const HospitalScreen({super.key});

  @override
  ConsumerState<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends ConsumerState<HospitalScreen>
    with RestrictionTimerMixin<HospitalScreen> {
  bool _healing = false;

  @override
  String? readRestrictionUntil() =>
      ref.read(playerProvider).profile?.hospitalUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      startRestrictionTimer(attachProfileListener: true);
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.hospital);
    });
  }

  int _gemHealCost() =>
      max(1, (restrictionRemainingDuration.inSeconds / 60).ceil() * 3);

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
        title: 'Ucretsiz Taburcu',
        message: freeRemaining > 0
            ? 'Ucretsiz taburcu olmak istiyor musun? (Kalan hak: $freeRemaining)'
            : 'Taburcu olmak istiyor musun?',
        confirmLabel: 'Taburcu Ol',
        cancelLabel: 'Iptal',
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
              'Bu islem icin $gemCost elmas gerekiyor. Mevcut: ${profile.gems}',
          confirmLabel: 'Dukkana Git',
          cancelLabel: 'Iptal',
        );
        if (goShop == true && mounted) {
          context.go(AppRoutes.shop);
        }
        return;
      }

      final bool? confirm = await UniversalGameDialog.show(
        context,
        title: 'Taburcu Ol',
        message: '$gemCost elmas harcayarak hemen taburcu olmak istiyor musun?',
        confirmLabel: 'Onayla',
        cancelLabel: 'Iptal',
      );
      if (confirm != true) return;
    }

    setState(() => _healing = true);
    try {
      final Map<String, dynamic> response = await _callHealRpc();
      final bool wasFree = response['was_free'] == true;
      final bool success = response['success'] == true || wasFree;
      if (!success) {
        throw Exception(response['error'] ?? 'Taburcu olunamadı');
      }

      await ref.read(playerProvider.notifier).loadProfile();
      restrictionTimer?.cancel();
      setState(() {
        _healing = false;
        restrictionRemainingDuration = Duration.zero;
      });

      if (!mounted) return;
      final PlayerProfile? after = ref.read(playerProvider).profile;
      final String woundedHint = after != null && after.maxHealth > 0
          ? ' Yarali cikis: Can ${formatHealthRatio(after.health, after.maxHealth)}.'
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
      cancelLabel: 'Iptal',
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
          (res['message'] ?? res['error'] ?? 'Doktor ziyareti basarisiz')
              .toString(),
        );
      } else {
        final int cut = (res['cut_minutes'] as num?)?.toInt() ?? 0;
        final bool released = res['released'] == true;
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
        AppMessenger.showError(context, 'Doktor ziyareti basarisiz.');
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
          (res['message'] ?? res['error'] ?? 'Klinik doktor kullanilamadi')
              .toString(),
        );
      } else {
        AppMessenger.showSuccess(context, context.l10n.sys2_guild_doctor_ok);
      }
      startRestrictionTimer();
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Klinik doktor kullanilamadi.');
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

      // RPC: success=true means call ok; escape outcome is [escaped].
      if (mounted) {
        if (!success) {
          AppMessenger.showError(context, message);
        } else if (escaped) {
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
      body: RestrictionScreenScaffold(
        child: profile == null
            ? const RestrictionLoadingCard()
            : inHospital
            ? _buildInHospital(profile)
            : _buildHealthy(),
      ),
    );
  }

  Widget _buildHealthy() {
    return RestrictionFreeCard(
      emoji: '💚',
      title: 'Sağlıklısın',
      message: 'Şu an hastanede değilsin.',
      accent: RestrictionScreenUi.healAccent,
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

    final List<RestrictionActionTile> tiles = <RestrictionActionTile>[
      RestrictionActionTile(
        label: context.l10n.sys2_doctor_visit_title,
        subtitle: 'Şans · kesinti',
        icon: Icons.medical_services_outlined,
        accent: RestrictionScreenUi.healAccent,
        loading: _healing,
        onPressed: _healing ? null : _doctorVisit,
      ),
      RestrictionActionTile(
        label: context.l10n.sys2_guild_doctor_btn,
        subtitle: 'Lonca klinik',
        icon: Icons.local_hospital_outlined,
        accent: AppColors.accentCyan,
        loading: _healing,
        onPressed: _healing ? null : _useGuildDoctor,
      ),
      if (MockAdService.allowMockReward)
        RestrictionActionTile(
          label: 'Reklam (−30dk)',
          subtitle: 'Günlük hak',
          icon: Icons.play_circle_rounded,
          accent: AppColors.liquidGold,
          loading: _healing,
          onPressed: _healing ? null : _watchAdToReduce,
          wrap: (Widget child) => TutorialAnchorScope(
            id: TutorialAnchorId.hospitalAdTimerBtn,
            onTutorialTap: () => TutorialTriggers.onAnchorTap(
              ref,
              TutorialAnchorId.hospitalAdTimerBtn,
            ),
            child: child,
          ),
        ),
      RestrictionActionTile(
        label: 'Gizli kaçış',
        subtitle: 'Risk · +15dk',
        icon: Icons.directions_run_rounded,
        accent: RestrictionScreenUi.hospitalAccent,
        loading: _healing,
        onPressed: _healing ? null : _attemptEscape,
      ),
    ];

    return RestrictionActivePanel(
      accent: RestrictionScreenUi.hospitalAccent,
      emoji: '🏥',
      title: 'Hastanedesin',
      reasonLabel: 'Neden:',
      reasonValue: labelHospitalReason(profile.hospitalReason),
      releaseLabel: formatRestrictionRelease(releaseTime),
      countdown: formatRestrictionCountdown(restrictionRemainingDuration),
      progress: restrictionProgress(),
      statusChip: '⚡ ${profile.energy}/${profile.maxEnergy}',
      primaryAction: RestrictionActionTile(
        label: canFree
            ? 'Ücretsiz Taburcu ($freeRemaining)'
            : '$gemCost Elmas · Taburcu',
        icon: canFree ? Icons.healing_rounded : Icons.diamond_rounded,
        accent: canFree
            ? RestrictionScreenUi.healAccent
            : RestrictionScreenUi.gemAccent,
        filled: true,
        loading: _healing,
        onPressed: _healing
            ? null
            : () => _healWithGems(expectFree: canFree),
      ),
      actionTiles: tiles,
      footer: WardPanel(
        wardType: 'hospital',
        accent: RestrictionScreenUi.hospitalAccent,
      ),
    );
  }
}
