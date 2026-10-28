import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/gkk_tab_bar.dart';
import '../../components/common/gkk_tab_page_shell.dart';
import '../../components/common/inline_error_retry.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/matchmaking/matchmaking_offer.dart';
import '../../core/utils/combat_restriction.dart';
import '../../components/layout/game_screen_background.dart';
import '../../models/mekan_model.dart';
import '../../providers/mekan_provider.dart';
import '../../providers/player_provider.dart';
import 'widgets/mekan_arena_bet_sheet.dart';
import 'widgets/mekan_arena_fighter_card.dart';
import 'widgets/mekan_arena_rank_row.dart';
import 'widgets/mekan_design.dart';
import 'widgets/mekan_pit_arena_stage.dart';
import 'widgets/mekan_scaffold.dart';
import 'mekan_arena_battle_screen.dart';

class MekanArenaScreen extends ConsumerStatefulWidget {
  const MekanArenaScreen({super.key, required this.mekanId});
  final String mekanId;

  @override
  ConsumerState<MekanArenaScreen> createState() => _MekanArenaScreenState();
}

class _MekanArenaScreenState extends ConsumerState<MekanArenaScreen> with SingleTickerProviderStateMixin {
  static const int _energyCost = 15;

  List<ArenaOpponent> _opponents = <ArenaOpponent>[];
  List<ArenaRankRow> _ranking = <ArenaRankRow>[];
  ArenaWeeklyRewardStatus? _weeklyReward;
  bool _claimingReward = false;
  bool _loading = true;
  bool _refreshingOffers = false;
  int _refreshInSec = 0;
  Timer? _refreshTicker;
  String? _loadError;
  String? _blockedMessage;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _refreshTicker?.cancel();
    _tab.dispose();
    super.dispose();
  }

  MekanRepository get _repo => ref.read(mekanRepositoryProvider);

  void _armRefreshCooldown(int seconds) {
    _refreshTicker?.cancel();
    _refreshInSec = seconds < 0 ? 0 : seconds;
    if (_refreshInSec <= 0) return;
    _refreshTicker = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _refreshInSec -= 1;
        if (_refreshInSec <= 0) {
          _refreshInSec = 0;
          t.cancel();
        }
      });
    });
  }

  List<ArenaOpponent> _mapOffers(MatchmakingOffersResult result) {
    return result.offers
        .map(
          (MatchmakingOffer o) => ArenaOpponent(
            offerId: o.offerId,
            authId: o.authId,
            username: o.username,
            level: o.level,
            pvpRating: o.pvpRating,
            power: o.power > 0 ? o.power : (o.attack + o.defense),
          ),
        )
        .toList();
  }

  Future<void> _load({bool offersOnly = false}) async {
    if (!mounted) return;
    setState(() {
      if (!offersOnly) {
        _loading = true;
        _loadError = null;
        _blockedMessage = null;
      } else {
        _refreshingOffers = true;
      }
    });
    try {
      if (!offersOnly) {
        final Mekan? mekan = await _repo.fetchMekan(widget.mekanId);
        if (!mounted) return;
        if (mekan == null) {
          setState(() {
            _loading = false;
            _blockedMessage = 'Mekân bulunamadı.';
          });
          return;
        }
        if (mekan.raidClosed) {
          setState(() {
            _loading = false;
            _blockedMessage = 'Polis baskını nedeniyle arena geçici olarak kapalı.';
          });
          return;
        }
        if (!mekan.isOpen) {
          setState(() {
            _loading = false;
            _blockedMessage = 'Mekân kapalı — arena şu an kullanılamıyor.';
          });
          return;
        }
      }

      final MatchmakingOffersResult offerRes = await _repo.fetchArenaOpponentOffers();
      List<ArenaRankRow> rank = _ranking;
      ArenaWeeklyRewardStatus? weeklyReward = _weeklyReward;
      if (!offersOnly) {
        try {
          rank = await _repo.fetchArenaRanking(limit: 50);
        } catch (_) {}
        try {
          weeklyReward = await _repo.fetchArenaWeeklyRewardStatus();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _opponents = _mapOffers(offerRes);
          if (!offersOnly) {
            _ranking = rank;
            _weeklyReward = weeklyReward;
          }
          _loading = false;
          _refreshingOffers = false;
        });
        _armRefreshCooldown(offerRes.refreshInSec);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshingOffers = false;
          if (!offersOnly) {
            _loadError = userFacingErrorMessage(e, fallback: 'Arena yüklenemedi.');
          }
        });
        if (offersOnly) {
          AppMessenger.showError(
            context,
            userFacingErrorMessage(e, fallback: 'Rakip listesi yenilenemedi.'),
          );
        }
      }
    }
  }

  Future<void> _refreshOffers() async {
    if (_refreshInSec > 0 || _refreshingOffers) {
      if (_refreshInSec > 0) {
        AppMessenger.showError(context, 'Yenileme $_refreshInSec sn sonra.');
      }
      return;
    }
    final profile = ref.read(playerProvider).profile;
    final String? combatBlock = combatRestrictionForProfile(
      health: profile?.health ?? 0,
      maxHealth: profile?.maxHealth ?? 0,
      hospitalUntil: profile?.hospitalUntil,
      prisonUntil: profile?.prisonUntil,
    );
    if (combatBlock != null) {
      AppMessenger.showError(context, combatBlock);
      return;
    }
    await _load(offersOnly: true);
  }

  Future<void> _openBetSheet(ArenaOpponent opp) async {
    final profile = ref.read(playerProvider).profile;
    final String? combatBlock = combatRestrictionForProfile(
      health: profile?.health ?? 0,
      maxHealth: profile?.maxHealth ?? 0,
      hospitalUntil: profile?.hospitalUntil,
      prisonUntil: profile?.prisonUntil,
    );
    if (combatBlock != null) {
      AppMessenger.showError(context, combatBlock);
      return;
    }
    final int energy = profile?.energy ?? 0;
    if (energy < _energyCost) {
      AppMessenger.showError(context, 'Enerji yetersiz ($_energyCost gerekli)');
      return;
    }
    final int gold = profile?.gold ?? 0;
    final int? wager = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MekanArenaBetSheet(opponent: opp, myGold: gold),
    );
    if (!mounted || wager == null) return;

    final bool? finished = await MekanArenaBattleScreen.open(
      context,
      args: MekanArenaBattleArgs(
        mekanId: widget.mekanId,
        opponent: opp,
        wager: wager,
      ),
    );
    if (!mounted) return;
    if (finished == true) {
      await ref.read(playerProvider.notifier).loadProfile();
      await _load();
    }
  }

  Widget _blockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MekanEmpty(
          icon: Icons.lock_rounded,
          title: 'Arena kapalı',
          message: _blockedMessage ?? 'Bu mekânda arena kullanılamıyor.',
          accent: MekanPalette.ruby,
          action: NeonButton(
            label: 'Geri dön',
            icon: Icons.arrow_back_rounded,
            accent: MekanPalette.ruby,
            expand: false,
            onPressed: () => context.pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final int energy = profile?.energy ?? 0;
    final String? combatBlock = combatRestrictionForProfile(
      health: profile?.health ?? 0,
      maxHealth: profile?.maxHealth ?? 0,
      hospitalUntil: profile?.hospitalUntil,
      prisonUntil: profile?.prisonUntil,
    );

    return MekanSubScaffold(
      title: 'PvP Arena',
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.ruby))
          : _blockedMessage != null
              ? _blockedView()
              : _loadError != null
                  ? InlineErrorRetry(message: _loadError!, onRetry: _load)
                  : Column(
                      children: <Widget>[
                        _arenaHeader(energy),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: MekanPitArenaStage(
                            playerName: profile?.username ?? 'Savaşçı',
                            opponentName: _opponents.isNotEmpty
                                ? _opponents.first.username
                                : 'Kafes Şampiyonu',
                            height: 158,
                            previewMode: true,
                          ),
                        ),
                        GkkTabBar(
                          controller: _tab,
                          isScrollable: false,
                          padding: EdgeInsets.zero,
                          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          tabs: <Widget>[
                            GkkTabBar.labeledTab(
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.sports_mma_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('Dövüş'),
                                ],
                              ),
                            ),
                            GkkTabBar.labeledTab(
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.leaderboard_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text('Sıralama'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tab,
                            children: <Widget>[
                              GkkTabPageShell(
                                tabIndex: 0,
                                sectionTitle: 'Arena Dövüşleri',
                                sectionAccent: MekanPalette.ruby,
                                child: _fightTab(energy, combatBlock),
                              ),
                              GkkTabPageShell(
                                tabIndex: 1,
                                sectionTitle: 'Arena Sıralaması',
                                sectionAccent: MekanPalette.gold,
                                child: _rankingTab(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _arenaHeader(int energy) {
    final bool hasEnergy = energy >= _energyCost;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: NeonPanel(
        accent: MekanPalette.ruby,
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MekanPalette.ruby.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[BoxShadow(color: MekanPalette.ruby.withValues(alpha: 0.4), blurRadius: 14)],
              ),
              child: const Icon(Icons.sports_mma_rounded, color: MekanPalette.ruby, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'BAHİSLİ ARENA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: MekanPalette.textHi,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Altın yatır, kazan veya kaybet',
                    style: TextStyle(fontSize: 12, color: MekanPalette.textMid),
                  ),
                ],
              ),
            ),
            GlowChip(
              icon: Icons.bolt_rounded,
              label: '$energy / $_energyCost',
              color: hasEnergy ? MekanPalette.neon : MekanPalette.ruby,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fightTab(int energy, String? combatBlock) {
    final bool hasEnergy = energy >= _energyCost;
    final bool canFight = hasEnergy && combatBlock == null;
    return RefreshIndicator(
      color: MekanPalette.ruby,
      backgroundColor: MekanPalette.navy,
      onRefresh: () => _refreshOffers(),
      child: _opponents.isEmpty
          ? ListView(
              children: <Widget>[
                if (combatBlock != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      combatBlock,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: MekanPalette.ruby, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                MekanEmpty(
                  icon: Icons.person_off_outlined,
                  title: 'Rakip yok',
                  message: combatBlock ??
                      (_refreshInSec > 0
                          ? 'Yeni teklifler $_refreshInSec sn sonra.'
                          : 'Şu an dövüşülebilecek oyuncu bulunamadı.'),
                  accent: MekanPalette.ruby,
                  action: NeonButton(
                    label: _refreshInSec > 0
                        ? 'Bekle ($_refreshInSec)'
                        : 'Yenile',
                    icon: Icons.refresh_rounded,
                    accent: MekanPalette.ruby,
                    expand: false,
                    onPressed: combatBlock != null ||
                            _refreshInSec > 0 ||
                            _refreshingOffers
                        ? null
                        : _refreshOffers,
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: GameScrollLayout.fromLTRB(context, left: 14, top: 8, right: 14),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _opponents.length + 1 + (combatBlock != null ? 1 : 0),
              separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int i) {
                int idx = i;
                if (combatBlock != null) {
                  if (idx == 0) {
                    return Text(
                      combatBlock,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: MekanPalette.ruby, fontSize: 13),
                    );
                  }
                  idx -= 1;
                }
                if (idx == 0) {
                  return Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Rastgele rakipler',
                          style: TextStyle(
                            fontSize: 12,
                            color: MekanPalette.textMid,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: combatBlock != null ||
                                _refreshInSec > 0 ||
                                _refreshingOffers
                            ? null
                            : _refreshOffers,
                        icon: _refreshingOffers
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          _refreshInSec > 0 ? '$_refreshInSec sn' : 'Yenile',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  );
                }
                final ArenaOpponent o = _opponents[idx - 1];
                return MekanArenaFighterCard(
                  opponent: o,
                  enabled: canFight && o.offerId.isNotEmpty,
                  onFight: () => _openBetSheet(o),
                );
              },
            ),
    );
  }

  Future<void> _claimWeeklyReward() async {
    if (_claimingReward) return;
    setState(() => _claimingReward = true);
    try {
      final int gold = await _repo.claimArenaWeeklyReward();
      if (!mounted) return;
      await ref.read(playerProvider.notifier).loadProfile();
      AppMessenger.show(context, '🏆 Haftalık arena ödülü: +$gold altın!');
      await _load();
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(
          context,
          userFacingErrorMessage(e, fallback: 'Ödül alınamadı.'),
        );
      }
    } finally {
      if (mounted) setState(() => _claimingReward = false);
    }
  }

  Widget _weeklyRewardBanner() {
    final ArenaWeeklyRewardStatus? status = _weeklyReward;
    if (status == null) return const SizedBox.shrink();
    if (status.canClaim) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: NeonPanel(
          accent: MekanPalette.gold,
          child: Row(
            children: <Widget>[
              const Icon(Icons.emoji_events_rounded, color: MekanPalette.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '#${status.rank} sıra — ${status.rewardGold} altın ödülün hazır!',
                  style: const TextStyle(color: MekanPalette.textHi, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: _claimingReward ? null : _claimWeeklyReward,
                child: _claimingReward
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Al'),
              ),
            ],
          ),
        ),
      );
    }
    if (status.claimOpen && status.rewardGold == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Text(
          'Haftalık ödül penceresi açık (Pzt–Çar). Top 50\'de değilsen ödül yok.',
          style: TextStyle(color: MekanPalette.textMid.withValues(alpha: 0.9), fontSize: 11),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _rankingTab() {
    final String myId = ref.read(playerProvider).profile?.authId ?? '';
    return RefreshIndicator(
      color: MekanPalette.gold,
      backgroundColor: MekanPalette.navy,
      onRefresh: _load,
      child: _ranking.isEmpty
          ? ListView(
              children: <Widget>[
                _weeklyRewardBanner(),
                const SizedBox(height: 80),
                const MekanEmpty(
                  icon: Icons.leaderboard_outlined,
                  title: 'Sıralama boş',
                  message: 'Henüz arena sıralaması oluşmadı.',
                  accent: MekanPalette.gold,
                ),
              ],
            )
          : ListView.builder(
              padding: GameScrollLayout.fromLTRB(context, left: 14, top: 8, right: 14),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _ranking.length + 1,
              itemBuilder: (BuildContext context, int i) {
                if (i == 0) return _weeklyRewardBanner();
                final ArenaRankRow r = _ranking[i - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MekanArenaRankRow(row: r, isMe: r.authId == myId),
                );
              },
            ),
    );
  }
}
