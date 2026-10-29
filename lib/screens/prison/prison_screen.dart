import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../theme/app_spacing.dart';
import '../restriction/restriction_timer_mixin.dart';
import 'widgets/prison_bail_panel.dart';
import 'widgets/prison_cell_painter.dart';
import 'widgets/prison_lighting.dart';

/// AAA Dark Gothic Prison Screen for Incarcerated Players.
///
/// Features gritty atmospheric cell visuals, real-time sentence countdown,
/// warden notices decree board, escape & labor activity bento grid,
/// bail payment workflows, and responsive adaptive layout.
class PrisonScreen extends ConsumerStatefulWidget {
  const PrisonScreen({super.key});

  @override
  ConsumerState<PrisonScreen> createState() => _PrisonScreenState();
}

class _PrisonScreenState extends ConsumerState<PrisonScreen>
    with RestrictionTimerMixin<PrisonScreen> {
  bool _paying = false;
  bool _noticesExpanded = true;
  bool _scavenging = false;
  bool _exercising = false;

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
      HapticFeedback.vibrate();
      await PrisonGothicDialog.showInsufficientGems(
        context,
        bailCost: bailCost,
        playerGems: profile.gems,
      );
      return;
    }

    final bool? confirm = await PrisonGothicDialog.showBailConfirm(
      context,
      bailCost: bailCost,
      playerGems: profile.gems,
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
        HapticFeedback.heavyImpact();
        AppMessenger.showSuccess(context, 'Kefalet kabul edildi. Zindandan serbest kaldın!');
      }
    } catch (e) {
      setState(() => _paying = false);
      if (mounted) {
        HapticFeedback.vibrate();
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
        HapticFeedback.mediumImpact();
        final bool released = res['released'] == true;
        final int usesLeft = (res['uses_left'] as num?)?.toInt() ?? 0;
        AppMessenger.showSuccess(
          context,
          released
              ? '🎉 Ceza süresi bitti — özgürsün!'
              : '⏳ Hücre emeği onaylandı! Ceza süresi 30 dakika kısaldı. (Kalan hak: $usesLeft)',
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
        HapticFeedback.vibrate();
        AppMessenger.showError(
          context,
          'Gardiyanı ikna etmek için altın yetersiz. Gerekli: $cost altın',
        );
      }
      return;
    }

    final bool? confirm = await UniversalGameDialog.show(
      context,
      title: context.l10n.sys2_guard_bribe_title,
      message: '${context.l10n.sys2_guard_bribe_body}\n\nİkna Bedeli: $cost altın',
      confirmLabel: context.l10n.sys2_guard_bribe_confirm,
      cancelLabel: 'Geri Çekil',
      accent: AppColors.liquidGold,
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
          (res['message'] ?? res['error'] ?? 'Gardiyan rüşveti reddetti')
              .toString(),
        );
      } else if (res['bribed'] == true) {
        HapticFeedback.mediumImpact();
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
          (res['message'] ?? res['error'] ?? 'Lonca avukatı atanamadı')
              .toString(),
        );
      } else {
        HapticFeedback.heavyImpact();
        AppMessenger.showSuccess(context, context.l10n.sys2_guild_lawyer_ok);
      }
      startRestrictionTimer();
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'Lonca avukatı atanamadı.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _attemptEscape() async {
    final bool? confirm = await UniversalGameDialog.show(
      context,
      title: 'Zindan Firarı Girişimi',
      message:
          'Zindan parmaklıklarını zorlayarak kaçmaya kalkışacaksın.\n\n⚠️ UYARI: Başarısız olursan gardiyanlar yakalayacak ve cezaya +15 dakika tecrit süresi eklenecektir!\n\nFirar etmeyi denemek istiyor musun?',
      confirmLabel: 'Firarı Dene',
      cancelLabel: 'Geri Çekil',
      accent: AppColors.mysticRuby,
    );
    if (confirm != true) return;

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
        if (!success) {
          AppMessenger.showError(context, message);
        } else if (escaped) {
          HapticFeedback.heavyImpact();
          AppMessenger.showSuccess(context, context.l10n.prison_escape_ok);
        } else {
          HapticFeedback.vibrate();
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

  Future<void> _searchCellCracks() async {
    if (_scavenging || _paying) return;
    setState(() => _scavenging = true);
    HapticFeedback.mediumImpact();

    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;

    final List<String> discoveries = <String>[
      'Taş blokların arasındaki yarığı yokladın: Eski bir mahkûmun duvara kazıdığı gizli çentikleri inceledin.',
      'Ranzanın altındaki harç döküntülerini karıştırdın: Paslı bir tel parçası buldun ancak gardiyan ayak sesini duyunca geri bıraktın.',
      'Havalandırma mazgalına kulak kabarttın: Gardiyanların nöbet değişim saatlerini öğrendin.',
      'Hücre köşesindeki çatlağı aradın: Kurumuş ekmek kabuğu ve bir avuç taş tozu çıktı.',
    ];
    final String lore = discoveries[Random().nextInt(discoveries.length)];

    setState(() => _scavenging = false);
    HapticFeedback.selectionClick();
    AppMessenger.show(context, lore);
  }

  Future<void> _doInmateWorkout() async {
    if (_exercising || _paying) return;
    setState(() => _exercising = true);
    HapticFeedback.heavyImpact();

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final List<String> workouts = <String>[
      'Taş zeminde 50 şınav ve parmaklıkta barfiks çektin. Demirler bedenini hapsedebilir ama iradeni asla!',
      'Gölge boksu yaparak gardiyanların dikkatini ölçtün. Zihnin berraklaştı ve tecrit baskısı azaldı.',
      'Duvara karşı esneme hareketleri yaptın. Hükümlü kondisyonun zirvede kalıyor.',
    ];
    final String lore = workouts[Random().nextInt(workouts.length)];

    setState(() => _exercising = false);
    HapticFeedback.selectionClick();
    AppMessenger.showSuccess(context, lore);
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
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 1. Background dungeon cell atmosphere: cold stone brick textures & dust motes
          Positioned.fill(
            child: PrisonCellAtmosphere(
              isInPrison: inPrison,
              showBars: false,
              showDust: true,
              showBricks: true,
            ),
          ),
          // 2. Torch lighting, dynamic illumination & interactive prison content
          Positioned.fill(
            child: PrisonLighting(
              enabled: inPrison,
              child: RestrictionScreenScaffold(
                child: profile == null
                    ? const RestrictionLoadingCard()
                    : inPrison
                        ? _buildInPrison(profile)
                        : _buildFree(),
              ),
            ),
          ),
          // 3. Foreground 3D wrought iron bars with cylindrical depth & metallic rim sheen
          if (inPrison)
            const Positioned.fill(
              child: PrisonForegroundBarsOverlay(
                isInPrison: true,
                barsOpacity: 0.35,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFree() {
    final bool prisonCoach =
        ref.watch(tutorialProvider).activeStep?.id == 'prison_escape';
    Widget card = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const PrisonFreeStatusCard(),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            context.go(AppRoutes.home);
          },
          icon: const Icon(Icons.castle_rounded, size: 18),
          label: const Text(
            'Krallığa Geri Dön',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentTeal,
            foregroundColor: AppColors.carbonVoid,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: BorderSide(
                color: AppColors.accentTeal.withValues(alpha: 0.8),
                width: 1.2,
              ),
            ),
            elevation: 4,
          ),
        ),
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 1. Gritty Gothic Cell Header Badge
        _CellSecurityStatusCard(
          cellCode: 'HÜCRE C-4 • AĞIR TECRİT',
          securityStatus: 'YÜKSEK GÜVENLİK',
          inmateId: '#${(profile.id).hashCode.abs() % 9000 + 1000}',
        ),
        const SizedBox(height: AppSpacing.md),

        // 2. Dark Fantasy Gothic Glass Sentence Duration Card
        PrisonSentenceDurationCard(
          countdown: formatRestrictionCountdown(restrictionRemainingDuration),
          releaseLabel: formatRestrictionRelease(releaseTime),
          progress: restrictionProgress(),
          reasonLabel: 'Hüküm Sebebi:',
          reasonValue: labelPrisonReason(profile.prisonReason),
          remainingDuration: restrictionRemainingDuration,
          statusChip: canAfford ? null : 'Elmas Yetersiz',
        ),
        const SizedBox(height: AppSpacing.md),

        // 3. Dark Fantasy Gothic Glass Bail Payment Card
        PrisonBailActionCard(
          bailCost: bailCost,
          playerGems: profile.gems,
          loading: _paying,
          onPayBail: () async {
            await TutorialTriggers.onAnchorTap(
              ref,
              TutorialAnchorId.prisonBailBtn,
            );
            await _payBail();
          },
          wrap: (Widget child) => TutorialAnchorScope(
            id: TutorialAnchorId.prisonBailBtn,
            child: child,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // 4. Warden Notices & Dungeon Decree Plaque
        _WardenNoticeCard(
          expanded: _noticesExpanded,
          onToggle: () {
            HapticFeedback.selectionClick();
            setState(() => _noticesExpanded = !_noticesExpanded);
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // 5. Responsive Labor & Time Reduction Inmate Action Bento Grid
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            final int crossAxisCount = width > 600 ? 3 : 2;
            final double childAspectRatio = width > 600 ? 1.5 : (width < 360 ? 1.18 : 1.32);

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: childAspectRatio,
              children: <Widget>[
                // Guard Bribe Action
                PrisonLaborActionTile(
                  title: 'Gardiyanı İkna',
                  subtitle: context.l10n.sys2_guard_bribe_cost(guardCost),
                  icon: Icons.handshake_outlined,
                  accent: AppColors.liquidGold,
                  badge: 'Altın',
                  loading: _paying,
                  onTap: _paying ? null : _bribeGuard,
                ),

                // Guild Lawyer Action
                PrisonLaborActionTile(
                  title: context.l10n.sys2_guild_lawyer_btn,
                  subtitle: 'Lonca Savunması',
                  icon: Icons.gavel_rounded,
                  accent: AppColors.accentCyan,
                  badge: 'Lonca',
                  loading: _paying,
                  onTap: _paying ? null : _useGuildLawyer,
                ),

                // Labor / Ad Reduction Action
                if (MockAdService.allowMockReward)
                  PrisonLaborActionTile(
                    title: 'Hücre Emeği',
                    subtitle: '−30 Dk İndirim',
                    icon: Icons.play_circle_rounded,
                    accent: AppColors.warningSolar,
                    badge: 'Reklam',
                    loading: _paying,
                    onTap: _paying ? null : _watchAdToReduce,
                    wrap: (Widget child) => TutorialAnchorScope(
                      id: TutorialAnchorId.prisonAdTimerBtn,
                      onTutorialTap: () => TutorialTriggers.onAnchorTap(
                        ref,
                        TutorialAnchorId.prisonAdTimerBtn,
                      ),
                      child: child,
                    ),
                  ),

                // Escape Attempt Action
                PrisonLaborActionTile(
                  title: 'Zindan Firarı',
                  subtitle: 'Risk (+15dk Ceza)',
                  icon: Icons.directions_run_rounded,
                  accent: AppColors.mysticRuby,
                  badge: 'Tehlikeli',
                  loading: _paying,
                  onTap: _paying ? null : _attemptEscape,
                ),

                // Inmate Cell Scavenging Activity
                PrisonLaborActionTile(
                  title: 'Zula Arama',
                  subtitle: 'Duvar Çatlakları',
                  icon: Icons.search_rounded,
                  accent: AppColors.accentPurple,
                  badge: 'Keşif',
                  loading: _scavenging,
                  onTap: _scavenging ? null : _searchCellCracks,
                ),

                // Inmate Workout Activity
                PrisonLaborActionTile(
                  title: 'Hücre Antrenmanı',
                  subtitle: 'Kondisyon & Moral',
                  icon: Icons.fitness_center_rounded,
                  accent: AppColors.accentTeal,
                  badge: 'Disiplin',
                  loading: _exercising,
                  onTap: _exercising ? null : _doInmateWorkout,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // 6. Incarcerated Ward Panel Footer
        const WardPanel(
          wardType: 'prison',
          accent: AppColors.coralFlare,
        ),
      ],
    );
  }
}

/// Atmospheric Incarceration Status & Cell Security Tier Header.
class _CellSecurityStatusCard extends StatelessWidget {
  const _CellSecurityStatusCard({
    required this.cellCode,
    required this.securityStatus,
    required this.inmateId,
  });

  final String cellCode;
  final String securityStatus;
  final String inmateId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCC090C16),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.coralFlare.withValues(alpha: 0.35),
          width: 1.1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Pulsing Security Warning Beacon
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.coralFlare,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.coralFlare.withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    cellCode,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    securityStatus,
                    style: const TextStyle(
                      color: AppColors.coralFlare,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              'MAHKÛM: $inmateId',
              style: const TextStyle(
                color: AppColors.mutedTitanium,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Weathered Gothic Brass & Iron Warden Decree Bulletin Plaque.
class _WardenNoticeCard extends StatelessWidget {
  const _WardenNoticeCard({
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE00C0F19),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.32),
          width: 1.1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: 0.06),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header Bar with Toggle
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.liquidGold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: AppColors.liquidGold,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'BAŞGARDİYAN TALİMATNAMESİ',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Kraliyet Zindan Hüküm & Güvenlik Bülteni',
                          style: TextStyle(
                            color: AppColors.mutedTitanium,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.mutedTitanium,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Notice Body
          if (expanded) ...<Widget>[
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildNoticeItem(
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.mysticRuby,
                    title: 'Firar Yasağı:',
                    body:
                        'Kaçış girişimleri affedilmez. Yakalanan her mahkûmun zindan cezasına +15 dakika tecrit süresi ilave edilir.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildNoticeItem(
                    icon: Icons.diamond_outlined,
                    color: AppColors.accentTeal,
                    title: 'Kefalet Tahliyesi:',
                    body:
                        'Kraliyet hazinesine kefalet bedeli ödeyerek derhal ve lekesiz tahliye olabilirsiniz.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildNoticeItem(
                    icon: Icons.handshake_outlined,
                    color: AppColors.liquidGold,
                    title: 'Nöbetçi Rüşveti:',
                    body:
                        'Vardiya amiri altın karşılığında tecrit süresini kısaltabilir; ancak yeterli altınınız olmalıdır.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: const Color(0xFF07090F),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: const Text(
                      '«Bu soğuk taşlar krallığın adaletidir. Buradan çıkış ya kraliyet kefaletiyle ya da sabırla olur.»\n— Başgardiyan Demirbilek Kurt',
                      style: TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoticeItem({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.3,
              ),
              children: <TextSpan>[
                TextSpan(
                  text: '$title ',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
