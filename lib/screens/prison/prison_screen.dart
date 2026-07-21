import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/restriction/restriction_screen_ui.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/supabase_service.dart';
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

class PrisonScreen extends ConsumerStatefulWidget {
  const PrisonScreen({super.key});

  @override
  ConsumerState<PrisonScreen> createState() => _PrisonScreenState();
}

class _PrisonScreenState extends ConsumerState<PrisonScreen>
    with RestrictionTimerMixin<PrisonScreen> {
  bool _paying = false;

  @override
  String? readRestrictionUntil() =>
      ref.read(playerProvider).profile?.prisonUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      startRestrictionTimer();
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.prison);
    });
  }

  int _bailCost() => max(1, (restrictionRemainingDuration.inSeconds / 60).ceil());

  Future<void> _payBail() async {
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    if (profile == null) return;

    final int bailCost = _bailCost();
    if (profile.gems < bailCost) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: AppColors.spaceNavy,
          title: const Text('Yetersiz Elmas'),
          content: Text(
            'Kefalet için $bailCost 💎 gerekiyor. Mevcut: ${profile.gems} 💎',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go(AppRoutes.shop);
              },
              child: const Text('Dükkana Git'),
            ),
          ],
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.spaceNavy,
        title: const Text('Kefalet Öde'),
        content: Text(
          '$bailCost 💎 harcayarak serbest kalmak istiyor musunuz?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _paying = true);
    try {
      await SupabaseService.client.rpc(
        'release_from_prison',
        params: <String, dynamic>{'p_use_bail': true},
      );
      await ref.read(playerProvider.notifier).loadProfile();
      restrictionTimer?.cancel();
      setState(() {
        _paying = false;
        restrictionRemainingDuration = Duration.zero;
      });
      if (mounted) {
        AppMessenger.showSuccess(context, 'Serbest kaldın.');
      }
    } catch (e) {
      setState(() => _paying = false);
      if (mounted) {
        AppMessenger.showError(context, 'Kefalet ödenemedi. Tekrar dene.');
      }
    }
  }

  Future<void> _watchAdToReduce() async {
    if (_paying) return;

    final AdResult adResult = await AdService.instance
        .showRewardedAd(context, placement: 'prison_timer');
    if (adResult != AdResult.rewarded) {
      if (mounted) AppMessenger.show(context, 'Reklam tamamlanmadı.');
      return;
    }

    setState(() => _paying = true);
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'reduce_timer_with_ad',
        params: <String, dynamic>{'p_timer': 'prison'},
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
              ? '🎉 Süre bitti — özgürsün!'
              : '⏳ Süre 30 dakika kısaldı! (Kalan hak: $usesLeft)',
        );
      }
      await ref.read(playerProvider.notifier).loadProfile();
      startRestrictionTimer();
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'İşlem başarısız.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _attemptEscape() async {
    setState(() => _paying = true);
    try {
      final dynamic rawResponse =
          await SupabaseService.client.rpc('attempt_prison_escape');
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
        _paying = false;
        if (escaped) {
          restrictionRemainingDuration = Duration.zero;
          restrictionTimer?.cancel();
        } else {
          updateRestrictionRemaining(isFirst: true);
        }
      });
    } catch (e) {
      setState(() => _paying = false);
      if (mounted) {
        AppMessenger.showError(context, 'Kaçış denemesi başarısız.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerProvider);
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    final bool inPrison = restrictionActive;

    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.cezaevi,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.prison,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      body: RestrictionScreenScaffold(
        child: inPrison && profile != null
            ? _buildInPrison(profile)
            : _buildFree(),
      ),
    );
  }

  Widget _buildFree() {
    return RestrictionFreeCard(
      emoji: '🕊️',
      title: 'Özgürsün',
      message: 'Şu an cezaevinde değilsin.',
      accent: RestrictionScreenUi.healAccent,
      detail: 'Yasalara uyduğun sürece özgür kalırsın.',
    );
  }

  Widget _buildInPrison(PlayerProfile profile) {
    final DateTime? releaseTime = parseRestrictionUntil(profile.prisonUntil);
    final int bailCost = _bailCost();
    final bool canAfford = profile.gems >= bailCost;

    return RestrictionActivePanel(
      accent: RestrictionScreenUi.prisonAccent,
      emoji: '⛓️',
      title: 'Hapishanedesin',
      reasonLabel: 'Gerekçe:',
      reasonValue: labelPrisonReason(profile.prisonReason),
      releaseLabel: formatRestrictionRelease(releaseTime),
      countdown: formatRestrictionCountdown(restrictionRemainingDuration),
      progress: restrictionProgress(),
      extraInfo: Text(
        '💎 Mevcut: ${profile.gems} elmas',
        style: const TextStyle(
          color: RestrictionScreenUi.gemAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: <Widget>[
        RestrictionFilledButton(
          label: 'Kefalet Öde ($bailCost Elmas)',
          color: canAfford
              ? RestrictionScreenUi.prisonAccent
              : AppColors.darkObsidian,
          icon: Icons.paid_rounded,
          loading: _paying,
          onPressed: (!_paying && canAfford) ? _payBail : null,
        ),
        if (!canAfford) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Yeterli elmasın yok (${profile.gems} / $bailCost)',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RestrictionScreenUi.hospitalAccent,
              fontSize: 12,
            ),
          ),
          const Center(
            child: RestrictionShopLink(
              message: 'Elmas satın al → Dükkan',
            ),
          ),
        ],
        const SizedBox(height: 10),
        RestrictionOutlineButton(
          label: 'Reklam İzle — Süreni 30 DK Kısalt',
          borderColor: AppColors.liquidGold,
          foregroundColor: AppColors.liquidGold,
          icon: Icons.play_circle_rounded,
          loading: _paying,
          onPressed: _paying ? null : _watchAdToReduce,
        ),
        const RestrictionSectionDivider(),
        RestrictionOutlineButton(
          label: 'Hapishaneden Kaçmayı Dene',
          borderColor: RestrictionScreenUi.hospitalAccent,
          icon: Icons.directions_run_rounded,
          loading: _paying,
          onPressed: _paying ? null : _attemptEscape,
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
