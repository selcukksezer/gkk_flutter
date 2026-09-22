import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/common/universal_game_dialog.dart';
import '../../components/restriction/restriction_screen_ui.dart';
import '../../components/restriction/ward_panel.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/restriction_reason_labels.dart';
import '../../core/utils/restriction_time.dart';
import '../../core/utils/system2_restriction_math.dart';
import '../../l10n/l10n.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_track.dart';
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

    setState(() => _paying = true);
    String? challengeToken;
    try {
      final dynamic challenge = await SupabaseService.client.rpc(
        'issue_ad_timer_challenge',
        params: <String, dynamic>{
          'p_timer': 'prison',
          'p_placement': 'prison_timer',
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
        setState(() => _paying = false);
      }
    }

    final String token = challengeToken;
    if (!mounted) return;

    final AdResult adResult = await AdService.instance
        .showRewardedAd(context, placement: 'prison_timer');
    if (adResult != AdResult.rewarded) {
      if (mounted) {
        setState(() => _paying = false);
        AppMessenger.show(context, 'Reklam tamamlanmadı.');
      }
      return;
    }

    try {
      final dynamic res = await SupabaseService.client.rpc(
        'reduce_timer_with_ad',
        params: <String, dynamic>{
          'p_timer': 'prison',
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

  Future<void> _bribeGuard() async {
    if (_paying) return;
    final int mins =
        max(1, (restrictionRemainingDuration.inSeconds / 60).ceil());
    final int cost = System2RestrictionMath.prisonGuardBribeCost(mins);
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    if (profile == null) return;
    if (profile.gold < cost) {
      if (mounted) {
        AppMessenger.showError(
          context,
          'Yetersiz altın. Gerekli: $cost',
        );
      }
      return;
    }

    final bool? confirm = await UniversalGameDialog.show(
      context,
      title: context.l10n.sys2_guard_bribe_title,
      message: '${context.l10n.sys2_guard_bribe_body}\n\nMaliyet: $cost altın',
      confirmLabel: context.l10n.sys2_guard_bribe_confirm,
      cancelLabel: 'İptal',
    );
    if (confirm != true) return;

    setState(() => _paying = true);
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('bribe_prison_guard');
      final Map<String, dynamic> res = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      await ref.read(playerProvider.notifier).loadProfile();
      if (!mounted) return;
      if (res['success'] != true) {
        AppMessenger.showError(
          context,
          (res['message'] ?? res['error'] ?? 'Gardiyan ikna başarısız')
              .toString(),
        );
      } else if (res['bribed'] == true) {
        final int cut = (res['cut_minutes'] as num?)?.toInt() ?? 0;
        AppMessenger.showSuccess(
          context,
          context.l10n.sys2_guard_bribe_ok(cut),
        );
      } else {
        AppMessenger.showError(context, context.l10n.sys2_guard_bribe_fail);
      }
      startRestrictionTimer();
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Gardiyan ikna başarısız.');
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _useGuildLawyer() async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('use_guild_lawyer');
      final Map<String, dynamic> res = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      await ref.read(playerProvider.notifier).loadProfile();
      if (!mounted) return;
      if (res['success'] != true) {
        AppMessenger.showError(
          context,
          (res['message'] ?? res['error'] ?? 'Avukat kullanılamadı')
              .toString(),
        );
      } else {
        AppMessenger.showSuccess(context, context.l10n.sys2_guild_lawyer_ok);
      }
      startRestrictionTimer();
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'Avukat kullanılamadı.');
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

      // RPC: success=true means call ok; escape outcome is [escaped].
      if (mounted) {
        if (!success) {
          AppMessenger.showError(context, message);
        } else if (escaped) {
          AppMessenger.showSuccess(context, context.l10n.prison_escape_ok);
        } else {
          final int? minutes = _escapePenaltyMinutes(message);
          AppMessenger.showError(
            context,
            minutes != null
                ? context.l10n.prison_escape_fail(minutes)
                : message,
            title: context.l10n.escape_fail_title,
          );
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
        child: profile == null
            ? const RestrictionLoadingCard()
            : inPrison
                ? _buildInPrison(profile)
                : _buildFree(),
      ),
    );
  }

  Widget _buildFree() {
    final bool prisonCoach =
        ref.watch(tutorialProvider).activeStep?.id == 'prison_escape';
    Widget card = RestrictionFreeCard(
      emoji: '🕊️',
      title: 'Özgürsün',
      message: 'Şu an cezaevinde değilsin.',
      accent: RestrictionScreenUi.healAccent,
      detail: 'Yasalara uyduğun sürece özgür kalırsın.',
    );
    if (prisonCoach) {
      card = TutorialAnchorScope(
        id: TutorialAnchorId.prisonBailBtn,
        child: GestureDetector(
          onTap: () => unawaited(
            TutorialTriggers.onAnchorTap(ref, TutorialAnchorId.prisonBailBtn),
          ),
          behavior: HitTestBehavior.opaque,
          child: card,
        ),
      );
    }
    return card;
  }

  Widget _buildInPrison(PlayerProfile profile) {
    final DateTime? releaseTime = parseRestrictionUntil(profile.prisonUntil);
    final int bailCost = _bailCost();
    final bool canAfford = profile.gems >= bailCost;
    final int remMins =
        max(1, (restrictionRemainingDuration.inSeconds / 60).ceil());
    final int guardCost = System2RestrictionMath.prisonGuardBribeCost(remMins);

    final List<RestrictionActionTile> tiles = <RestrictionActionTile>[
      RestrictionActionTile(
        label: context.l10n.sys2_guard_bribe_cost(guardCost),
        subtitle: 'Altın · ikna',
        icon: Icons.handshake_outlined,
        accent: AppColors.liquidGold,
        loading: _paying,
        onPressed: _paying ? null : _bribeGuard,
      ),
      RestrictionActionTile(
        label: context.l10n.sys2_guild_lawyer_btn,
        subtitle: 'Lonca klinik',
        icon: Icons.gavel_rounded,
        accent: AppColors.accentCyan,
        loading: _paying,
        onPressed: _paying ? null : _useGuildLawyer,
      ),
      if (MockAdService.allowMockReward)
        RestrictionActionTile(
          label: 'Reklam (−30dk)',
          subtitle: 'Günlük hak',
          icon: Icons.play_circle_rounded,
          accent: AppColors.liquidGold,
          loading: _paying,
          onPressed: _paying ? null : _watchAdToReduce,
          wrap: (Widget child) => TutorialAnchorScope(
            id: TutorialAnchorId.prisonAdTimerBtn,
            onTutorialTap: () => TutorialTriggers.onAnchorTap(
              ref,
              TutorialAnchorId.prisonAdTimerBtn,
            ),
            child: child,
          ),
        ),
      RestrictionActionTile(
        label: 'Kaçış dene',
        subtitle: 'Risk · +15dk',
        icon: Icons.directions_run_rounded,
        accent: RestrictionScreenUi.hospitalAccent,
        loading: _paying,
        onPressed: _paying ? null : _attemptEscape,
      ),
    ];

    return RestrictionActivePanel(
      accent: RestrictionScreenUi.prisonAccent,
      emoji: '⛓️',
      title: 'Hapishanedesin',
      reasonLabel: 'Gerekçe:',
      reasonValue: labelPrisonReason(profile.prisonReason),
      releaseLabel: formatRestrictionRelease(releaseTime),
      countdown: formatRestrictionCountdown(restrictionRemainingDuration),
      progress: restrictionProgress(),
      statusChip: canAfford ? null : 'Elmas yetersiz',
      extraInfo: canAfford
          ? null
          : const Center(
              child: RestrictionShopLink(message: 'Elmas → Dükkan'),
            ),
      primaryAction: RestrictionActionTile(
        label: 'Kefalet ($bailCost Elmas)',
        icon: Icons.paid_rounded,
        accent: canAfford
            ? RestrictionScreenUi.prisonAccent
            : AppColors.darkObsidian,
        filled: true,
        loading: _paying,
        onPressed: (!_paying && canAfford)
            ? () async {
                await TutorialTriggers.onAnchorTap(
                  ref,
                  TutorialAnchorId.prisonBailBtn,
                );
                await _payBail();
              }
            : null,
        wrap: (Widget child) => TutorialAnchorScope(
          id: TutorialAnchorId.prisonBailBtn,
          child: child,
        ),
      ),
      actionTiles: tiles,
      footer: WardPanel(
        wardType: 'prison',
        accent: RestrictionScreenUi.prisonAccent,
      ),
    );
  }
}
