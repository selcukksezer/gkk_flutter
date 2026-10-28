import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/common/universal_game_dialog.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/services/graphics_quality_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/utils/player_health.dart';
import '../../../core/utils/power_formula.dart';
import '../../../core/utils/restriction_reason_labels.dart';
import '../../../core/utils/restriction_time.dart';
import '../../../core/utils/system2_restriction_math.dart';
import '../../../l10n/l10n.dart';
import '../../../models/moradon_models.dart';
import '../../../models/player_model.dart';
import '../../../providers/graphics_quality_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/restriction_ward_world_provider.dart';
import '../../../routing/app_router.dart';
import '../moradon/character_skeletal_rig.dart';
import '../moradon/moradon_v5_layers.dart';
import 'character_inspect_sheet.dart';

/// Full-screen 2.5D interactive Hospital Sanctum or Prison Dungeon displayed
/// directly on [HomeScreen] whenever the player has an active restriction.
///
/// Renders:
/// 1. Room NPCs ("ordaki insanlar": Healers in Hospital, Warden/Guards in Prison)
/// 2. ONLY currently ONLINE fellow patients/inmates (`OnlineWardPeer`)
/// 3. Live countdown, quick release/timer-reduction actions, and Ward Chat.
class RestrictionWorldHomeView extends ConsumerStatefulWidget {
  final WardWorldMode mode;
  final PlayerProfile profile;
  final InventoryState inventoryState;
  final int totalPower;
  final Future<void> Function()? onRefresh;

  const RestrictionWorldHomeView({
    super.key,
    required this.mode,
    required this.profile,
    required this.inventoryState,
    required this.totalPower,
    this.onRefresh,
  });

  @override
  ConsumerState<RestrictionWorldHomeView> createState() =>
      _RestrictionWorldHomeViewState();
}

class _RestrictionWorldHomeViewState
    extends ConsumerState<RestrictionWorldHomeView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientCtrl;
  final Map<String, ui.Image> _charAtlases = <String, ui.Image>{};
  int? _loadedAtlasTargetWidth = -999;
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();

  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  bool _actionBusy = false;
  bool _chatSending = false;
  bool _drawerOpen = false;
  int _drawerTab = 0; // 0 = Çevrimiçi Koğuş, 1 = Koğuş Sohbeti
  final bool _is3dPerspective = true;

  bool get _isHospital => widget.mode == WardWorldMode.hospital;

  Color get _accent =>
      _isHospital ? const Color(0xFF34D399) : const Color(0xFFF59E0B);

  Color get _secondaryAccent =>
      _isHospital ? const Color(0xFF38BDF8) : const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
      value: 0.25,
    );
    if (!GraphicsQualityService.instance.profile.isLow) {
      _ambientCtrl.repeat();
    }
    unawaited(_preloadAtlases());
    _startClock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(restrictionWardWorldProvider.notifier).bindSession(
            mode: widget.mode,
            profile: widget.profile,
            totalPower: widget.totalPower,
          );
    });
  }

  @override
  void didUpdateWidget(covariant RestrictionWorldHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.profile.id != widget.profile.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(restrictionWardWorldProvider.notifier).bindSession(
              mode: widget.mode,
              profile: widget.profile,
              totalPower: widget.totalPower,
            );
      });
    }
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  Future<void> _preloadAtlases() async {
    _loadedAtlasTargetWidth =
        GraphicsQualityService.instance.profile.charAtlasTargetWidth;
    final Map<String, ui.Image> shared =
        await GraphicsQualityService.instance.loadSharedCharacterAtlases();
    if (!mounted || shared.isEmpty) return;
    setState(() {
      _charAtlases
        ..clear()
        ..addAll(shared);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _ambientCtrl.dispose();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  Duration get _remaining {
    final String? raw =
        _isHospital ? widget.profile.hospitalUntil : widget.profile.prisonUntil;
    if (raw == null) return Duration.zero;
    final DateTime? until = DateTime.tryParse(raw)?.toLocal();
    if (until == null) return Duration.zero;
    final Duration diff = until.difference(_now);
    return diff.isNegative ? Duration.zero : diff;
  }

  String _resolveClassKey(String rawClass) {
    final String lower = rawClass.toLowerCase();
    if (lower.contains('golge') || lower.contains('shadow')) return 'golge';
    if (lower.contains('simyaci') || lower.contains('alchemist')) {
      return 'simyaci';
    }
    return 'savasci';
  }

  String _classDisplayTr(String rawClass) {
    final String key = _resolveClassKey(rawClass);
    return switch (key) {
      'golge' => 'Gölge',
      'simyaci' => 'Simyacı',
      _ => 'Savaşçı',
    };
  }

  int _localGlowLevel() {
    int maxEnh = 0;
    for (final item in widget.inventoryState.equippedItems.values) {
      final int enh = item?.enhancementLevel ?? 0;
      if (enh > maxEnh) {
        maxEnh = enh;
      }
    }
    return maxEnh;
  }

  Color _glowColor(int level) {
    if (level >= 10) return const Color(0xFFF43F5E);
    if (level == 9) return const Color(0xFFFBBF24);
    if (level == 8) return const Color(0xFFC084FC);
    if (level == 7) return const Color(0xFF38BDF8);
    return _accent;
  }

  // ── Restriction Release / Reduction RPC Actions ─────────────────────────────

  int _hospitalGemCost() =>
      math.max(1, (_remaining.inSeconds / 60).ceil() * 3);

  int _prisonBailCost() => math.max(1, (_remaining.inSeconds / 60).ceil());

  int _prisonBribeGoldCost() {
    final int mins = math.max(1, (_remaining.inSeconds / 60).ceil());
    return System2RestrictionMath.prisonGuardBribeCost(mins);
  }

  Future<void> _reloadPlayerAndPeers() async {
    await ref.read(playerProvider.notifier).loadProfile();
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
    if (mounted) {
      unawaited(
        ref
            .read(restrictionWardWorldProvider.notifier)
            .refreshOnlinePeers(silent: true),
      );
    }
  }

  Future<void> _handleHospitalDischarge() async {
    if (_actionBusy) return;
    final PlayerProfile profile = widget.profile;
    final int freeLeft =
        freeHospitalDischargesRemaining(profile.hospitalLifetimeCount);
    final bool isFree = canFreeHospitalDischarge(profile.hospitalLifetimeCount);

    if (isFree) {
      final bool? ok = await UniversalGameDialog.show(
        context,
        title: 'Ücretsiz Taburcu',
        message:
            'Ücretsiz taburcu hakkını kullanmak istiyor musun? (Kalan hak: $freeLeft)',
        confirmLabel: 'Taburcu Ol',
        cancelLabel: 'İptal',
      );
      if (ok != true) return;
    } else {
      final int cost = _hospitalGemCost();
      if (profile.gems < cost) {
        if (!mounted) return;
        final bool? goShop = await UniversalGameDialog.show(
          context,
          title: 'Yetersiz Elmas',
          message:
              'Hemen taburcu olmak için $cost 💎 gerekiyor. Mevcut: ${profile.gems.toInt()} 💎',
          confirmLabel: 'Mağazaya Git',
          cancelLabel: 'İptal',
        );
        if (goShop == true && mounted) {
          context.push(AppRoutes.shop);
        }
        return;
      }
      final bool? ok = await UniversalGameDialog.show(
        context,
        title: 'Hemen Taburcu Ol',
        message: '$cost 💎 harcayarak şifahaneden hemen çıkmak istiyor musun?',
        confirmLabel: 'Onayla',
        cancelLabel: 'İptal',
      );
      if (ok != true) return;
    }

    setState(() => _actionBusy = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc('heal_with_gems');
      final Map<String, dynamic> res = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final bool wasFree = res['was_free'] == true;
      if (res['success'] != true && !wasFree) {
        throw Exception(res['error'] ?? 'Taburcu olunamadı');
      }
      await _reloadPlayerAndPeers();
      if (!mounted) return;
      final PlayerProfile? after = ref.read(playerProvider).profile;
      final String woundedHint = after != null && after.maxHealth > 0
          ? ' (Can: ${formatHealthRatio(after.health, after.maxHealth)})'
          : '';
      AppMessenger.showSuccess(
        context,
        wasFree
            ? 'Ücretsiz taburcu oldun!$woundedHint'
            : 'Şifahaneden taburcu oldun!$woundedHint',
      );
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Taburcu olunamadı. Tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _handleDoctorVisit() async {
    if (_actionBusy) return;
    final bool? ok = await UniversalGameDialog.show(
      context,
      title: context.l10n.sys2_doctor_visit_title,
      message: context.l10n.sys2_doctor_visit_body,
      confirmLabel: context.l10n.sys2_doctor_visit_confirm,
      cancelLabel: 'İptal',
    );
    if (ok != true) return;

    setState(() => _actionBusy = true);
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('attempt_doctor_visit');
      final Map<String, dynamic> res = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      await _reloadPlayerAndPeers();
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
        AppMessenger.showSuccess(
          context,
          released
              ? context.l10n.sys2_doctor_released
              : (cut > 0
                  ? context.l10n.sys2_doctor_cut(cut)
                  : context.l10n.sys2_doctor_noop),
        );
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Doktor ziyareti başarısız.');
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _handleGuildSupport() async {
    if (_actionBusy) return;
    if (widget.profile.guildId == null || widget.profile.guildId!.isEmpty) {
      AppMessenger.show(
        context,
        _isHospital
            ? 'Lonca kliniği için bir loncaya üye olmalısın.'
            : 'Lonca avukatı için bir loncaya üye olmalısın.',
      );
      return;
    }

    setState(() => _actionBusy = true);
    try {
      final String rpcName =
          _isHospital ? 'use_guild_doctor' : 'use_guild_lawyer';
      final dynamic raw = await SupabaseService.client.rpc(rpcName);
      final Map<String, dynamic> res = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      await _reloadPlayerAndPeers();
      if (!mounted) return;
      if (res['success'] != true) {
        AppMessenger.showError(
          context,
          (res['message'] ?? res['error'] ?? 'Lonca desteği kullanılamadı')
              .toString(),
        );
      } else {
        AppMessenger.showSuccess(
          context,
          _isHospital
              ? context.l10n.sys2_guild_doctor_ok
              : context.l10n.sys2_guild_lawyer_ok,
        );
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Lonca desteği kullanılamadı.');
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _handlePrisonBail() async {
    if (_actionBusy) return;
    final int cost = _prisonBailCost();
    if (widget.profile.gems < cost) {
      final bool? goShop = await UniversalGameDialog.show(
        context,
        title: 'Yetersiz Elmas',
        message:
            'Kefalet için $cost 💎 gerekiyor. Mevcut: ${widget.profile.gems.toInt()} 💎',
        confirmLabel: 'Mağazaya Git',
        cancelLabel: 'İptal',
      );
      if (goShop == true && mounted) {
        context.push(AppRoutes.shop);
      }
      return;
    }

    final bool? ok = await UniversalGameDialog.show(
      context,
      title: 'Kefalet Öde',
      message: '$cost 💎 harcayarak zindandan hemen çıkmak istiyor musun?',
      confirmLabel: 'Kefalet Öde',
      cancelLabel: 'İptal',
    );
    if (ok != true) return;

    setState(() => _actionBusy = true);
    try {
      await SupabaseService.client.rpc(
        'release_from_prison',
        params: <String, dynamic>{'p_use_bail': true},
      );
      await _reloadPlayerAndPeers();
      if (mounted) {
        AppMessenger.showSuccess(context, 'Kefalet ödendi — özgürsün!');
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Kefalet ödenemedi. Tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _handleGuardBribe() async {
    if (_actionBusy) return;
    final int cost = _prisonBribeGoldCost();
    if (widget.profile.gold < cost) {
      AppMessenger.showError(context, 'Yetersiz altın. Gerekli: $cost 🪙');
      return;
    }

    final bool? ok = await UniversalGameDialog.show(
      context,
      title: context.l10n.sys2_guard_bribe_title,
      message: '${context.l10n.sys2_guard_bribe_body}\n\nMaliyet: $cost altın',
      confirmLabel: context.l10n.sys2_guard_bribe_confirm,
      cancelLabel: 'İptal',
    );
    if (ok != true) return;

    setState(() => _actionBusy = true);
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('bribe_prison_guard');
      final Map<String, dynamic> res = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      await _reloadPlayerAndPeers();
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
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Gardiyan ikna başarısız.');
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _handleAdReduction() async {
    if (_actionBusy) return;
    final String timerType = _isHospital ? 'hospital' : 'prison';
    final String placement = '${timerType}_timer';

    setState(() => _actionBusy = true);
    String? token;
    try {
      final dynamic challenge = await SupabaseService.client.rpc(
        'issue_ad_timer_challenge',
        params: <String, dynamic>{
          'p_timer': timerType,
          'p_placement': placement,
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
      token = challenge['challenge_token']?.toString();
      if (token == null || token.isEmpty) {
        AppMessenger.showError(context, 'Reklam doğrulama başarısız.');
        return;
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'Reklam açılamadı.');
      return;
    } finally {
      if (mounted && token == null) {
        setState(() => _actionBusy = false);
      }
    }

    if (!mounted) return;
    final AdResult adResult = await AdService.instance.showRewardedAd(
      context,
      placement: placement,
    );
    if (adResult != AdResult.rewarded) {
      if (mounted) {
        setState(() => _actionBusy = false);
        AppMessenger.show(context, 'Reklam tamamlanmadı.');
      }
      return;
    }

    try {
      final dynamic res = await SupabaseService.client.rpc(
        'reduce_timer_with_ad',
        params: <String, dynamic>{
          'p_timer': timerType,
          'p_challenge_token': token,
        },
      );
      await _reloadPlayerAndPeers();
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        final bool released = res['released'] == true;
        final int usesLeft = (res['uses_left'] as num?)?.toInt() ?? 0;
        AppMessenger.showSuccess(
          context,
          released
              ? (_isHospital ? '🎉 Taburcu oldun!' : '🎉 Süre bitti — özgürsün!')
              : '⏳ Süre 30 dk kısaldı! (Kalan hak: $usesLeft)',
        );
      } else {
        final String msg = res is Map
            ? (res['message'] ?? res['error'] ?? 'İşlem başarısız').toString()
            : 'İşlem başarısız';
        AppMessenger.showError(context, msg);
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'İşlem başarısız.');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _handleEscapeAttempt() async {
    if (_actionBusy) return;
    final bool? ok = await UniversalGameDialog.show(
      context,
      title: _isHospital ? 'Gizli Kaçış Dene (%20)' : 'Zindandan Firar Dene (%20)',
      message: _isHospital
          ? 'Nöbetçilere görünmeden şifahaneden kaçmayı denemek istiyor musun? Yakalanırsan süren uzar!'
          : 'Gardiyanları atlatıp parmaklıklardan firar denemek istiyor musun? Yakalanırsan cezan uzar!',
      confirmLabel: 'Şansımı Dene',
      cancelLabel: 'Vazgeç',
    );
    if (ok != true) return;

    setState(() => _actionBusy = true);
    try {
      final String rpcName =
          _isHospital ? 'attempt_hospital_escape' : 'attempt_prison_escape';
      final dynamic raw = await SupabaseService.client.rpc(rpcName);
      final Map<String, dynamic> res = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      await _reloadPlayerAndPeers();
      if (!mounted) return;

      final bool success = res['success'] == true;
      final bool escaped = res['escaped'] == true;
      final String msg =
          (res['message'] ?? res['error'] ?? 'İşlem tamamlandı').toString();

      if (!success) {
        AppMessenger.showError(context, msg);
      } else if (escaped) {
        AppMessenger.showSuccess(
          context,
          _isHospital
              ? context.l10n.hospital_escape_ok
              : context.l10n.prison_escape_ok,
        );
      } else {
        AppMessenger.showError(
          context,
          msg,
          title: context.l10n.escape_fail_title,
        );
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'Kaçış denemesi başarısız.');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _sendChat() async {
    final String txt = _chatCtrl.text.trim();
    if (txt.isEmpty || _chatSending) return;
    setState(() => _chatSending = true);
    _chatCtrl.clear();
    final String? err = await ref
        .read(restrictionWardWorldProvider.notifier)
        .sendWardChatMessage(txt);
    if (!mounted) return;
    setState(() => _chatSending = false);
    if (err != null) {
      AppMessenger.showError(context, err);
    } else if (_chatScrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollCtrl.hasClients) {
          _chatScrollCtrl.animateTo(
            _chatScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final GraphicsProfile gfx = ref.watch(graphicsQualityProvider).profile;
    if (gfx.isLow && _ambientCtrl.isAnimating) {
      _ambientCtrl.stop();
      _ambientCtrl.value = 0.25;
    } else if (!gfx.isLow && !_ambientCtrl.isAnimating) {
      _ambientCtrl.repeat();
    }
    if (_loadedAtlasTargetWidth != gfx.charAtlasTargetWidth) {
      unawaited(_preloadAtlases());
    }

    final RestrictionWardWorldState worldState =
        ref.watch(restrictionWardWorldProvider);
    final RestrictionWardWorldNotifier notifier =
        ref.read(restrictionWardWorldProvider.notifier);

    // Strict render-time online + unexpired filter: zero offline or expired peers!
    final List<OnlineWardPeer> onlinePeers = worldState.onlinePeers.values
        .where((OnlineWardPeer p) => p.isStrictOnlineAndActive(_now))
        .toList()
      ..sort((OnlineWardPeer a, OnlineWardPeer b) {
        if (a.sameGuild != b.sameGuild) return a.sameGuild ? -1 : 1;
        return a.untilTs.compareTo(b.untilTs);
      });

    final Size viewport = MediaQuery.sizeOf(context);
    final double topInset = MediaQuery.paddingOf(context).top + 10;
    final double bottomInset = MediaQuery.paddingOf(context).bottom + 90;

    return Stack(
      children: <Widget>[
        // 1. Interactive 2.5D Hospital Sanctum / Prison Cellblock World
        Positioned.fill(
          child: _buildWorldViewport(
            viewport: viewport,
            worldState: worldState,
            notifier: notifier,
            onlinePeers: onlinePeers,
          ),
        ),

        // 2. Top Status & Online Peers Header
        Positioned(
          top: topInset,
          left: 12,
          right: 12,
          child: _buildTopHeader(
            onlinePeers: onlinePeers,
            loadingPeers: worldState.loadingPeers,
            notifier: notifier,
          ),
        ),

        // 3. Selected NPC or Online Fellow Player Inspect Card
        if (worldState.selectedPeer != null || worldState.selectedNpc != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: bottomInset + (_drawerOpen ? 292 : 98),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: worldState.selectedPeer != null
                    ? _buildOnlinePeerInspectCard(
                        worldState.selectedPeer!,
                        notifier,
                      )
                    : _buildNpcInspectCard(
                        worldState.selectedNpc!,
                        notifier,
                      ),
              ),
            ),
          ),

        // 4. Collapsible Online Koğuş Roster & Live Ward Chat Drawer
        if (_drawerOpen)
          Positioned(
            left: 12,
            right: 12,
            bottom: bottomInset + 90,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: _buildOnlineWardDrawer(
                  onlinePeers: onlinePeers,
                  messages: worldState.chatMessages,
                  notifier: notifier,
                ),
              ),
            ),
          ),

        // 5. Bottom Release Actions & Quick Chat Dock
        Positioned(
          left: 10,
          right: 10,
          bottom: bottomInset,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: _buildBottomActionDock(onlineCount: onlinePeers.length),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorldViewport({
    required Size viewport,
    required RestrictionWardWorldState worldState,
    required RestrictionWardWorldNotifier notifier,
    required List<OnlineWardPeer> onlinePeers,
  }) {
    const double worldW = RestrictionWardWorldState.worldWidth;
    const double worldH = RestrictionWardWorldState.worldHeight;

    // Cover-scale math so 1920x1080 fills screen without black bars and follows hero on narrow viewports
    final double scale = math.max(
      viewport.width / worldW,
      viewport.height / worldH,
    );
    final double scaledW = worldW * scale;
    final double scaledH = worldH * scale;

    final double desiredLeft = viewport.width / 2 - worldState.playerX * scale;
    final double minLeft = math.min(0.0, viewport.width - scaledW);
    final double camLeft = desiredLeft.clamp(minLeft, 0.0);

    final double desiredTop = viewport.height * 0.54 - worldState.playerY * scale;
    final double minTop = math.min(0.0, viewport.height - scaledH);
    final double camTop = desiredTop.clamp(minTop, 0.0);

    return ColoredBox(
      color: const Color(0xFF05070D),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (TapUpDetails details) {
          final Offset local = details.localPosition;
          final double wx = (local.dx - camLeft) / scale;
          final double wy = (local.dy - camTop) / scale;
          notifier.moveToWorldPoint(Offset(wx, wy));
        },
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Positioned(
              left: camLeft,
              top: camTop,
              width: scaledW,
              height: scaledH,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: worldW,
                  height: worldH,
                  child: AnimatedBuilder(
                    animation: _ambientCtrl,
                    builder: (BuildContext context, _) {
                      final double phase = _ambientCtrl.value;
                      final GraphicsProfile gfx =
                          GraphicsQualityService.instance.profile;
                      final Widget canvas = _buildWorldCanvas(
                        phase: phase,
                        worldState: worldState,
                        notifier: notifier,
                        onlinePeers: onlinePeers,
                        gfx: gfx,
                      );
                      if (!_is3dPerspective || !gfx.enable3dPerspective) {
                        return canvas;
                      }
                      final double moveRoll = worldState.isMoving
                          ? (worldState.facingRight ? -0.008 : 0.008)
                          : math.sin(phase * math.pi * 2) * 0.003;
                      final double pitch =
                          0.064 + math.cos(phase * math.pi * 2) * 0.006;
                      return Transform(
                        alignment: const Alignment(0, 0.22),
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.00058)
                          ..rotateX(pitch)
                          ..rotateZ(moveRoll)
                          ..multiply(
                            Matrix4.diagonal3Values(1.045, 1.055, 1.0),
                          ),
                        child: canvas,
                      );
                    },
                  ),
                ),
              ),
            ),
            // Subtle top & bottom cinematic vignette so HUD text pops crisply
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.56),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.68),
                      ],
                      stops: const <double>[0.0, 0.20, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorldCanvas({
    required double phase,
    required RestrictionWardWorldState worldState,
    required RestrictionWardWorldNotifier notifier,
    required List<OnlineWardPeer> onlinePeers,
    required GraphicsProfile gfx,
  }) {
    const double worldH = RestrictionWardWorldState.worldHeight;

    final List<_WardDepthEntity> depthEntities = <_WardDepthEntity>[];

    // 1. Room Staff NPCs ("ordaki insanlar")
    for (final WardWorldNpc npc in worldState.npcs) {
      depthEntities.add(
        _WardDepthEntity(
          yDepth: npc.y,
          child: _buildNpcEntity(
            npc: npc,
            selected: worldState.selectedNpcId == npc.id,
            phase: phase,
            notifier: notifier,
          ),
        ),
      );
    }

    // 2. ONLY Currently ONLINE Fellow Patients / Inmates (capped per tier!)
    final int peerCap = gfx.isLow ? 8 : 24;
    for (final OnlineWardPeer peer in onlinePeers.take(peerCap)) {
      depthEntities.add(
        _WardDepthEntity(
          yDepth: peer.y,
          child: _buildOnlinePeerEntity(
            peer: peer,
            worldState: worldState,
            notifier: notifier,
            phase: phase,
          ),
        ),
      );
    }

    // 3. Local Player Hero
    depthEntities.add(
      _WardDepthEntity(
        yDepth: worldState.playerY + 0.5,
        child: _buildLocalHeroEntity(
          worldState: worldState,
          phase: phase,
        ),
      ),
    );

    depthEntities.sort(
      (_WardDepthEntity a, _WardDepthEntity b) =>
          a.yDepth.compareTo(b.yDepth),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Background 2.5D Royal Infirmary or Citadel Prison Dungeon (downsampled per tier!)
        Positioned.fill(
          child: RepaintBoundary(
            child: Image.asset(
              widget.mode.backgroundAsset,
              fit: BoxFit.cover,
              cacheWidth: gfx.moradonMapCacheWidth,
              filterQuality: gfx.filterQuality,
              errorBuilder: (BuildContext ctx, Object err, StackTrace? st) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: <Color>[
                        _accent.withValues(alpha: 0.22),
                        const Color(0xFF090D16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Tap-to-move destination ring on the stone flagstones
        if (worldState.moveRingPosition != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WardMoveRipplePainter(
                  target: worldState.moveRingPosition!,
                  phase: phase,
                  color: _accent,
                ),
              ),
            ),
          ),

        // Y-depth sorted NPCs, Online Fellow Players, and Local Hero
        for (final _WardDepthEntity e in depthEntities) e.child,

        // Foreground atmospheric healing motes (Hospital) or torch embers (Prison)
        if (gfx.enableWeatherAndAtmosphere)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(
                  RestrictionWardWorldState.worldWidth,
                  worldH,
                ),
                painter: _WardAtmospherePainter(
                  isHospital: _isHospital,
                  phase: phase,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNpcEntity({
    required WardWorldNpc npc,
    required bool selected,
    required double phase,
    required RestrictionWardWorldNotifier notifier,
  }) {
    final double bobY = math.sin(phase * math.pi * 2) * 3.0;
    return Positioned(
      left: npc.x - 105,
      bottom: RestrictionWardWorldState.worldHeight - npc.y,
      width: 210,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => notifier.interactWithNpc(npc),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Transform.translate(
              offset: Offset(0, bobY),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xE60B1120),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: npc.accentColor.withValues(alpha: 0.85),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  '${npc.badgeEmoji} NPC · ${npc.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: npc.accentColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            _OutlinedWorldLabel(
              text: '[${npc.name}]',
              fontSize: 12,
              color: selected ? Colors.white : const Color(0xFFFEF08A),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: npc.spriteWidth + 24,
              height: npc.spriteHeight + 8,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 68,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: RadialGradient(
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.80),
                            npc.accentColor.withValues(
                              alpha: selected ? 0.50 : 0.22,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scaleX: npc.facingRight ? 1.0 : -1.0,
                    scaleY: 1.0 + 0.012 * math.sin(phase * math.pi * 2),
                    alignment: Alignment.bottomCenter,
                    child: Image.asset(
                      npc.assetPath,
                      width: npc.spriteWidth,
                      height: npc.spriteHeight,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        _isHospital
                            ? Icons.medical_services_rounded
                            : Icons.shield_rounded,
                        size: 56,
                        color: npc.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlinePeerEntity({
    required OnlineWardPeer peer,
    required RestrictionWardWorldState worldState,
    required RestrictionWardWorldNotifier notifier,
    required double phase,
  }) {
    final MoradonChatBubble? bubble = worldState.chatBubbles[peer.userId];
    final bool hasBubble = bubble != null && !bubble.isExpired;
    final bool isSelected = worldState.selectedPeerId == peer.userId;
    final bool isMoving =
        (peer.targetX - peer.x).abs() > 2.5 ||
        (peer.targetY - peer.y).abs() > 2.5;
    final String classKey = _resolveClassKey(peer.characterClass);
    final Duration left = peer.remainingAt(_now);

    return Positioned(
      key: ValueKey<String>('online_ward_peer_${peer.userId}'),
      left: peer.x - 115,
      bottom: RestrictionWardWorldState.worldHeight - peer.y,
      width: 230,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => notifier.selectPeer(peer),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (hasBubble) _buildSpeechBubble(bubble.message),
            // Live Online + Remaining Restriction Timer Pill
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xEB09121F),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.78),
                  width: 0.9,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ÇEVRİMİÇİ · ⏳ ${formatRestrictionCountdown(left)}',
                    style: const TextStyle(
                      color: Color(0xFFBBF7D0),
                      fontSize: 9.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (peer.guildName != null && peer.guildName!.isNotEmpty)
              _OutlinedWorldLabel(
                text: '<${peer.guildName}>',
                fontSize: 10.2,
                color: peer.sameGuild
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFF93C5FD),
              ),
            _OutlinedWorldLabel(
              text: 'Lv.${peer.level} ${peer.displayName}',
              fontSize: 11.8,
              color: isSelected
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFFF8FAFC),
            ),
            CharacterNameplatePowerBadge(
              power: peer.power,
              isHighlighted: isSelected,
            ),
            const SizedBox(height: 2),
            _buildAtlasCharacterSprite(
              classKey: classKey,
              facingRight: peer.facingRight,
              facingBack: peer.facingBack,
              isMoving: isMoving,
              walkPhase: peer.walkPhase,
              idlePhase: (phase + peer.userId.hashCode * 0.13) % 1.0,
              glowColor: _accent,
              weaponVisual: MoradonWeaponVisual.none,
              isLocal: false,
              isSelected: isSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalHeroEntity({
    required RestrictionWardWorldState worldState,
    required double phase,
  }) {
    final PlayerProfile me = widget.profile;
    final MoradonChatBubble? bubble = worldState.chatBubbles[me.id];
    final bool hasBubble = bubble != null && !bubble.isExpired;
    final String classKey =
        _resolveClassKey(me.characterClass?.name ?? 'savasci');
    final int glowLvl = _localGlowLevel();
    final Color glowColor = _glowColor(glowLvl);
    final (MoradonWeaponVisual weaponVis, String _) = resolveEquippedWeaponSpec(
      inventoryState: widget.inventoryState,
      classKey: classKey,
      glowLevel: glowLvl,
    );

    return Positioned(
      key: const ValueKey<String>('local_ward_hero'),
      left: worldState.playerX - 120,
      bottom: RestrictionWardWorldState.worldHeight - worldState.playerY,
      width: 240,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (hasBubble) _buildSpeechBubble(bubble.message),
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: const Color(0xEB0B1324),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.9),
                  width: 1.0,
                ),
              ),
              child: Text(
                _isHospital
                    ? '🏥 TEDAVİDE · ${formatRestrictionCountdown(_remaining)}'
                    : '⛓️ MAHKUM · ${formatRestrictionCountdown(_remaining)}',
                style: TextStyle(
                  color: _accent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (me.guildName != null && me.guildName!.isNotEmpty)
              _OutlinedWorldLabel(
                text: '<${me.guildName}>',
                fontSize: 10.5,
                color: const Color(0xFF86EFAC),
              ),
            _OutlinedWorldLabel(
              text: '★ Lv.${me.level} ${me.username}',
              fontSize: 12.5,
              color: const Color(0xFFFDE047),
            ),
            CharacterNameplatePowerBadge(
              power: widget.totalPower,
              isLocal: true,
            ),
            const SizedBox(height: 2),
            _buildAtlasCharacterSprite(
              classKey: classKey,
              facingRight: worldState.facingRight,
              facingBack: worldState.facingBack,
              isMoving: worldState.isMoving,
              walkPhase: worldState.walkPhase,
              idlePhase: phase,
              glowColor: glowColor,
              weaponVisual: weaponVis,
              glowLevel: glowLvl,
              isLocal: true,
              isSelected: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAtlasCharacterSprite({
    required String classKey,
    required bool facingRight,
    required bool facingBack,
    required bool isMoving,
    required double walkPhase,
    required double idlePhase,
    required Color glowColor,
    required MoradonWeaponVisual weaponVisual,
    int glowLevel = 0,
    required bool isLocal,
    required bool isSelected,
  }) {
    final Size boxSize = isLocal ? const Size(110, 134) : const Size(102, 124);
    final ui.Image? atlas = _charAtlases[classKey];

    return SizedBox(
      width: boxSize.width,
      height: boxSize.height,
      child: atlas == null
          ? Center(
              child: Container(
                width: 46,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xCC0F172A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isLocal
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF4ADE80),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: isLocal
                      ? const Color(0xFFFDE047)
                      : const Color(0xFF86EFAC),
                  size: 28,
                ),
              ),
            )
          : CustomPaint(
              size: boxSize,
              painter: _WardCharacterAtlasPainter(
                atlas: atlas,
                classKey: classKey,
                facingRight: facingRight,
                facingBack: facingBack,
                isMoving: isMoving,
                walkPhase: walkPhase,
                idlePhase: idlePhase,
                glowColor: glowColor,
                glowLevel: glowLevel,
                weaponVisual: weaponVisual,
                isLocal: isLocal,
                isSelected: isSelected,
              ),
            ),
    );
  }

  Widget _buildSpeechBubble(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xF20F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _accent.withValues(alpha: 0.72),
          width: 1.0,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        message,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── HUD Widgets ─────────────────────────────────────────────────────────────

  Widget _buildTopHeader({
    required List<OnlineWardPeer> onlinePeers,
    required bool loadingPeers,
    required RestrictionWardWorldNotifier notifier,
  }) {
    final String reasonText = _isHospital
        ? labelHospitalReason(widget.profile.hospitalReason)
        : labelPrisonReason(widget.profile.prisonReason);
    final String titleText =
        _isHospital ? 'KRALİYET ŞİFAHANESİ' : 'KRALİYET ZİNDANI';
    final String onlineLabel = _isHospital
        ? '${onlinePeers.length} Çevrimiçi Hasta'
        : '${onlinePeers.length} Çevrimiçi Mahkum';

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      spacing: 8,
      children: <Widget>[
        // Left: Restriction Banner + Live Countdown
        TutorialAnchorScope(
          id: TutorialAnchorId.homeHero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xEE090E1A),
                  _accent.withValues(alpha: 0.16),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _accent.withValues(alpha: 0.65),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _accent.withValues(alpha: 0.55)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _isHospital ? '🏥' : '⛓️',
                    style: const TextStyle(fontSize: 19),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              titleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _accent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _secondaryAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              formatRestrictionCountdown(_remaining),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                fontFeatures: <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reasonText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right: Wallet + Online Fellow Players Button
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xE60B1120),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '🪙 ${widget.profile.gold}',
                    style: const TextStyle(
                      color: Color(0xFFFDE047),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '💎 ${widget.profile.gems.toInt()}',
                    style: const TextStyle(
                      color: Color(0xFF7DD3FC),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              key: const ValueKey<String>('toggle_online_ward_roster_btn'),
              onTap: () {
                setState(() {
                  if (_drawerOpen && _drawerTab == 0) {
                    _drawerOpen = false;
                  } else {
                    _drawerOpen = true;
                    _drawerTab = 0;
                  }
                });
                unawaited(notifier.refreshOnlinePeers(silent: true));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xEE091520),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.78),
                    width: 1.15,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.22),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      onlineLabel,
                      style: const TextStyle(
                        color: Color(0xFFDCFCE7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (loadingPeers) ...<Widget>[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: Color(0xFF4ADE80),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOnlinePeerInspectCard(
    OnlineWardPeer peer,
    RestrictionWardWorldNotifier notifier,
  ) {
    final Duration left = peer.remainingAt(_now);
    final String reasonLabel = _isHospital
        ? labelHospitalReason(peer.reason)
        : labelPrisonReason(peer.reason);
    final double maxH =
        (MediaQuery.sizeOf(context).height * 0.56).clamp(180.0, 430.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SingleChildScrollView(
        child: CharacterInspectPanel(
          seed: InspectedCharacterData.seedFromWardPeer(
            peer: peer,
            statusBadgeText:
                '${_isHospital ? "🏥 Tedavide" : "⛓️ Mahkum"} • $reasonLabel • Kalan süre: ${formatRestrictionCountdown(left)}',
            statusBadgeColor: _accent,
          ),
          onClose: notifier.clearSelections,
        ),
      ),
    );
  }

  Widget _buildNpcInspectCard(
    WardWorldNpc npc,
    RestrictionWardWorldNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
      decoration: BoxDecoration(
        color: const Color(0xF20B1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: npc.accentColor.withValues(alpha: 0.78),
          width: 1.2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Text(npc.badgeEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${npc.name} · ${npc.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: npc.accentColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  npc.quote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: notifier.clearSelections,
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineWardDrawer({
    required List<OnlineWardPeer> onlinePeers,
    required List<WardChatMessage> messages,
    required RestrictionWardWorldNotifier notifier,
  }) {
    return Container(
      height: 274,
      decoration: BoxDecoration(
        color: const Color(0xF4090E1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha: 0.55), width: 1.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: <Widget>[
          // Drawer Header Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _buildDrawerTabChip(
                          index: 0,
                          label: _isHospital
                              ? '🟢 Çevrimiçi Hastalar (${onlinePeers.length})'
                              : '🟢 Çevrimiçi Mahkumlar (${onlinePeers.length})',
                        ),
                        const SizedBox(width: 6),
                        _buildDrawerTabChip(
                          index: 1,
                          label: '💬 Koğuş Sohbeti (${messages.length})',
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: () {
                    unawaited(notifier.refreshOnlinePeers());
                    unawaited(notifier.loadWardChatHistory());
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => setState(() => _drawerOpen = false),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.white70,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x26FFFFFF)),
          Expanded(
            child: _drawerTab == 0
                ? _buildOnlineRosterList(onlinePeers, notifier)
                : _buildWardChatBody(messages),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTabChip({required int index, required String label}) {
    final bool active = _drawerTab == index;
    return GestureDetector(
      onTap: () => setState(() => _drawerTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? _accent.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? _accent.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineRosterList(
    List<OnlineWardPeer> onlinePeers,
    RestrictionWardWorldNotifier notifier,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      children: <Widget>[
        // Self row (always online while viewing)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '★ Lv.${widget.profile.level} ${widget.profile.username} · ⚡ ${formatCharacterPower(widget.totalPower)} Güç',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFDE047),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatRestrictionCountdown(_remaining),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (onlinePeers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.wifi_tethering_rounded,
                  color: Colors.white.withValues(alpha: 0.38),
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  _isHospital
                      ? 'Şu an senin dışında çevrimiçi hasta yok.'
                      : 'Şu an senin dışında çevrimiçi mahkum yok.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Çevrimdışı oyuncular gizlenir; biri çevrimiçi düştüğünde burada ve odada anında belirir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          )
        else
          for (final OnlineWardPeer peer in onlinePeers)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () {
                  notifier.moveToWorldPoint(Offset(peer.x - 70, peer.y + 15));
                  notifier.selectPeer(peer);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lv.${peer.level} ${peer.displayName} · ⚡ ${formatCharacterPower(peer.power)} Güç · ${_classDisplayTr(peer.characterClass)}${peer.guildName != null ? ' <${peer.guildName}>' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '⏳ ${formatRestrictionCountdown(peer.remainingAt(_now))}',
                        style: const TextStyle(
                          color: Color(0xFF86EFAC),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildWardChatBody(List<WardChatMessage> messages) {
    return Column(
      children: <Widget>[
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    _isHospital
                        ? 'Koğuş sohbetinde henüz mesaj yok. İlk mesajı yaz!'
                        : 'Hücre sohbetinde henüz mesaj yok. İlk mesajı yaz!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11.5,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (BuildContext context, int i) {
                    final WardChatMessage m = messages[i];
                    final bool isMe = m.senderId == widget.profile.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: RichText(
                        text: TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '${m.senderName}: ',
                              style: TextStyle(
                                color: isMe
                                    ? const Color(0xFFFDE047)
                                    : _accent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: m.content,
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _chatCtrl,
                    onSubmitted: (_) => _sendChat(),
                    maxLength: 180,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: _isHospital
                          ? 'Çevrimiçi hastalara seslen...'
                          : 'Çevrimiçi mahkumlara seslen...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 11.5,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _chatSending ? null : _sendChat,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: const Color(0xFF061018),
                  minimumSize: const Size(64, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text(
                  'Gönder',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionDock({required int onlineCount}) {
    final bool canFree =
        _isHospital &&
        canFreeHospitalDischarge(widget.profile.hospitalLifetimeCount);

    final List<_QuickWardAction> actions = _isHospital
        ? <_QuickWardAction>[
            _QuickWardAction(
              icon: '💚',
              label: canFree
                  ? 'Ücretsiz Çık'
                  : 'Taburcu (💎 ${_hospitalGemCost()})',
              primary: true,
              onTap: _handleHospitalDischarge,
            ),
            _QuickWardAction(
              icon: '🩺',
              label: 'Doktor Çağır',
              onTap: _handleDoctorVisit,
            ),
            _QuickWardAction(
              icon: '🏛️',
              label: 'Lonca Kliniği',
              onTap: _handleGuildSupport,
            ),
            _QuickWardAction(
              icon: '🎬',
              label: 'Reklam (-30dk)',
              onTap: _handleAdReduction,
            ),
            _QuickWardAction(
              icon: '🏃',
              label: 'Gizli Kaçış',
              onTap: _handleEscapeAttempt,
            ),
          ]
        : <_QuickWardAction>[
            _QuickWardAction(
              icon: '💎',
              label: 'Kefalet (${_prisonBailCost()} 💎)',
              primary: true,
              onTap: _handlePrisonBail,
            ),
            _QuickWardAction(
              icon: '🪙',
              label: 'Gardiyan İkna (${_prisonBribeGoldCost()})',
              onTap: _handleGuardBribe,
            ),
            _QuickWardAction(
              icon: '⚖️',
              label: 'Lonca Avukatı',
              onTap: _handleGuildSupport,
            ),
            _QuickWardAction(
              icon: '🎬',
              label: 'Reklam (-30dk)',
              onTap: _handleAdReduction,
            ),
            _QuickWardAction(
              icon: '🗝️',
              label: 'Firar Dene',
              onTap: _handleEscapeAttempt,
            ),
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEB080D18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _accent.withValues(alpha: 0.45),
          width: 1.1,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final _QuickWardAction act in actions) ...<Widget>[
              _buildActionChip(act),
              const SizedBox(width: 7),
            ],
            // Quick Chat & Online Roster Toggle
            _buildActionChip(
              _QuickWardAction(
                icon: '💬',
                label: 'Koğuş Sohbeti ($onlineCount Online)',
                onTap: () {
                  setState(() {
                    if (_drawerOpen && _drawerTab == 1) {
                      _drawerOpen = false;
                    } else {
                      _drawerOpen = true;
                      _drawerTab = 1;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(_QuickWardAction act) {
    return GestureDetector(
      onTap: _actionBusy ? null : act.onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: _actionBusy ? 0.55 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: act.primary
                ? LinearGradient(
                    colors: <Color>[
                      _accent.withValues(alpha: 0.92),
                      _secondaryAccent.withValues(alpha: 0.82),
                    ],
                  )
                : null,
            color: act.primary ? null : const Color(0xFF131C2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: act.primary
                  ? Colors.white.withValues(alpha: 0.35)
                  : _accent.withValues(alpha: 0.32),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(act.icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                act.label,
                style: TextStyle(
                  color: act.primary ? const Color(0xFF041016) : Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickWardAction {
  final String icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _QuickWardAction({
    required this.icon,
    required this.label,
    this.primary = false,
    required this.onTap,
  });
}

class _WardDepthEntity {
  final double yDepth;
  final Widget child;

  const _WardDepthEntity({required this.yDepth, required this.child});
}

class _OutlinedWorldLabel extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;

  const _OutlinedWorldLabel({
    required this.text,
    required this.fontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1.15,
        shadows: const <Shadow>[
          Shadow(color: Colors.black, offset: Offset(-1.2, -1.2), blurRadius: 1.5),
          Shadow(color: Colors.black, offset: Offset(1.2, -1.2), blurRadius: 1.5),
          Shadow(color: Colors.black, offset: Offset(-1.2, 1.2), blurRadius: 1.5),
          Shadow(color: Colors.black, offset: Offset(1.2, 1.2), blurRadius: 1.5),
          Shadow(color: Colors.black87, offset: Offset(0, 2.5), blurRadius: 4),
        ],
      ),
    );
  }
}

class _WardMoveRipplePainter extends CustomPainter {
  final Offset target;
  final double phase;
  final Color color;

  const _WardMoveRipplePainter({
    required this.target,
    required this.phase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 2; i++) {
      final double t = (phase * 2.0 + i * 0.5) % 1.0;
      final Rect oval = Rect.fromCenter(
        center: target,
        width: 22.0 + t * 50.0,
        height: 11.0 + t * 24.0,
      );
      canvas.drawOval(
        oval,
        Paint()
          ..color = color.withValues(alpha: (1.0 - t) * 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 - t,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WardMoveRipplePainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.phase != phase;
}

class _WardAtmospherePainter extends CustomPainter {
  final bool isHospital;
  final double phase;

  const _WardAtmospherePainter({
    required this.isHospital,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint additive = Paint()..blendMode = BlendMode.plus;

    if (isHospital) {
      // Gentle rising emerald & golden restoration motes across the infirmary
      for (int i = 0; i < 18; i++) {
        final double t = (phase + i / 18.0) % 1.0;
        final double x =
            380.0 + ((i * 197) % 1180) + math.sin(phase * math.pi * 2 + i) * 18;
        final double y = 890.0 - t * 380.0;
        final Color c = i.isEven
            ? const Color(0xFF34D399)
            : const Color(0xFFFDE68A);
        additive.color = c.withValues(alpha: (1.0 - t) * 0.42);
        canvas.drawCircle(Offset(x, y), 2.2, additive);
      }
    } else {
      // Flickering amber brazier embers & cold dungeon dust motes
      const List<Offset> braziers = <Offset>[
        Offset(876, 336),
        Offset(1258, 502),
      ];
      for (int b = 0; b < braziers.length; b++) {
        final double flicker =
            0.5 + 0.5 * math.sin(phase * math.pi * 6 + b * 1.9);
        final Rect glow = Rect.fromCenter(
          center: braziers[b],
          width: 170 + flicker * 26,
          height: 170 + flicker * 26,
        );
        canvas.drawOval(
          glow,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(
              colors: <Color>[
                const Color(0xFFF97316).withValues(alpha: 0.16 + flicker * 0.08),
                Colors.transparent,
              ],
            ).createShader(glow),
        );
      }
      for (int i = 0; i < 14; i++) {
        final double t = (phase + i / 14.0) % 1.0;
        final double x =
            460.0 + ((i * 211) % 980) + math.cos(phase * math.pi * 2 + i) * 16;
        final double y = 880.0 - t * 340.0;
        additive.color = const Color(0xFFFBBF24).withValues(
          alpha: (1.0 - t) * 0.34,
        );
        canvas.drawCircle(Offset(x, y), 1.9, additive);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WardAtmospherePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.isHospital != isHospital;
}

class _WardCharacterAtlasPainter extends CustomPainter {
  final ui.Image atlas;
  final String classKey;
  final bool facingRight;
  final bool facingBack;
  final bool isMoving;
  final double walkPhase;
  final double idlePhase;
  final Color glowColor;
  final int glowLevel;
  final MoradonWeaponVisual weaponVisual;
  final bool isLocal;
  final bool isSelected;

  const _WardCharacterAtlasPainter({
    required this.atlas,
    required this.classKey,
    required this.facingRight,
    required this.facingBack,
    required this.isMoving,
    required this.walkPhase,
    required this.idlePhase,
    required this.glowColor,
    required this.glowLevel,
    required this.weaponVisual,
    required this.isLocal,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2.0;
    final double groundY = size.height - 6.0;

    // 1. Contact shadow
    final double strideSpread =
        isMoving ? (0.92 + 0.16 * math.sin(walkPhase).abs()) : 1.0;
    final Rect shadowRect = Rect.fromCenter(
      center: Offset(cx, groundY),
      width: (isLocal ? 64.0 : 56.0) * strideSpread,
      height: 20.0,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.black.withValues(alpha: 0.78),
            Colors.transparent,
          ],
        ).createShader(shadowRect),
    );

    // 2. Selection / Online / Local Hero ground ring
    final Color ringColor = isSelected
        ? const Color(0xFF4ADE80)
        : (isLocal ? const Color(0xFFFBBF24) : const Color(0xFF22C55E));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY),
        width: isLocal ? 60.0 : 52.0,
        height: 19.0,
      ),
      Paint()
        ..color = ringColor.withValues(alpha: isLocal || isSelected ? 0.78 : 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isLocal || isSelected ? 1.9 : 1.3,
    );

    // 3. 60 FPS Segmented Skeletal Locomotion Rig
    paintSegmentedCharacterRig(
      canvas: canvas,
      size: size,
      atlas: atlas,
      classKey: classKey,
      facingRight: facingRight,
      facingBack: facingBack,
      isMoving: isMoving,
      walkPhase: walkPhase,
      idlePhase: idlePhase,
      glowColor: glowColor,
      glowLevel: glowLevel,
      weaponVisual: weaponVisual,
    );
  }

  @override
  bool shouldRepaint(covariant _WardCharacterAtlasPainter oldDelegate) {
    return oldDelegate.atlas != atlas ||
        oldDelegate.classKey != classKey ||
        oldDelegate.facingRight != facingRight ||
        oldDelegate.facingBack != facingBack ||
        oldDelegate.isMoving != isMoving ||
        oldDelegate.walkPhase != walkPhase ||
        oldDelegate.idlePhase != idlePhase ||
        oldDelegate.isSelected != isSelected;
  }
}
