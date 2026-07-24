import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/universal_game_dialog.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/restriction/restriction_screen_ui.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/power_formula.dart';
import '../../core/utils/restriction_reason_labels.dart';
import '../../core/utils/restriction_time.dart';
import '../../l10n/l10n.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
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
      if (wasFree) {
        AppMessenger.showSuccess(
          context,
          'Ücretsiz taburcu oldun. Kalan hak: ${response['free_discharges_remaining'] ?? 0}',
        );
      } else {
        AppMessenger.showSuccess(context, 'Taburcu oldun.');
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

    final AdResult adResult = await AdService.instance
        .showRewardedAd(context, placement: 'hospital_timer');
    if (adResult != AdResult.rewarded) {
      if (mounted) AppMessenger.show(context, 'Reklam tamamlanmadı.');
      return;
    }

    setState(() => _healing = true);
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'reduce_timer_with_ad',
        params: <String, dynamic>{'p_timer': 'hospital'},
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
        if (success) {
          AppMessenger.showSuccess(context, message);
        } else {
          AppMessenger.showError(context, message);
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

    return RestrictionActivePanel(
      accent: RestrictionScreenUi.hospitalAccent,
      emoji: '🏥',
      title: 'Hastanedesin',
      reasonLabel: 'Neden:',
      reasonValue: labelHospitalReason(profile.hospitalReason),
      releaseLabel: formatRestrictionRelease(releaseTime),
      countdown: formatRestrictionCountdown(restrictionRemainingDuration),
      progress: restrictionProgress(),
      extraInfo: Text(
        '⚡ Enerji: ${profile.energy}/${profile.maxEnergy}',
        style: const TextStyle(
          color: AppColors.accentCyan,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: <Widget>[
        if (canFree) ...<Widget>[
          RestrictionFilledButton(
            label: 'Ücretsiz Taburcu Ol (Kalan: $freeRemaining)',
            color: RestrictionScreenUi.healAccent,
            icon: Icons.healing_rounded,
            loading: _healing,
            onPressed: _healing ? null : () => _healWithGems(expectFree: true),
          ),
          const SizedBox(height: 8),
        ],
        RestrictionFilledButton(
          label: '$gemCost Elmas ile Taburcu Ol',
          color: RestrictionScreenUi.gemAccent,
          icon: Icons.diamond_rounded,
          loading: _healing,
          onPressed: _healing ? null : () => _healWithGems(),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Mevcut: ${profile.gems} 💎',
            style: const TextStyle(
              color: AppColors.mutedTitanium,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        RestrictionOutlineButton(
          label: 'Reklam İzle — Süreni 30 DK Kısalt',
          borderColor: AppColors.liquidGold,
          foregroundColor: AppColors.liquidGold,
          icon: Icons.play_circle_rounded,
          loading: _healing,
          onPressed: _healing ? null : _watchAdToReduce,
        ),
        const RestrictionSectionDivider(),
        RestrictionOutlineButton(
          label: 'Hastaneden Gizlice Kaç',
          borderColor: RestrictionScreenUi.hospitalAccent,
          icon: Icons.directions_run_rounded,
          loading: _healing,
          onPressed: _healing ? null : _attemptEscape,
        ),
      ],
      footer: const Text(
        'Başarırsan özgürsün, yakalanırsan +15 DK ceza alırsın!',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
      ),
    );
  }
}
