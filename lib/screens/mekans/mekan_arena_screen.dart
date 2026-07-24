import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/inline_error_retry.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/utils/captcha_guard.dart';
import '../../components/layout/game_screen_background.dart';
import '../../models/mekan_model.dart';
import '../../providers/mekan_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../reputation/widgets/reputation_gain_banner.dart';
import 'widgets/mekan_arena_bet_sheet.dart';
import 'widgets/mekan_arena_fighter_card.dart';
import 'widgets/mekan_arena_rank_row.dart';
import 'widgets/mekan_design.dart';
import 'widgets/mekan_scaffold.dart';

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
  bool _loading = true;
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
    _tab.dispose();
    super.dispose();
  }

  MekanRepository get _repo => ref.read(mekanRepositoryProvider);

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
      _blockedMessage = null;
    });
    try {
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

      final List<ArenaOpponent> opp = await _repo.fetchArenaOpponents();
      List<ArenaRankRow> rank = <ArenaRankRow>[];
      try {
        rank = await _repo.fetchArenaRanking(limit: 50);
      } catch (_) {
        // Sıralama RPC isteğe bağlı.
      }
      if (mounted) {
        setState(() {
          _opponents = opp;
          _ranking = rank;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = userFacingErrorMessage(e, fallback: 'Arena yüklenemedi.');
        });
      }
    }
  }

  Future<void> _openBetSheet(ArenaOpponent opp) async {
    final int energy = ref.read(playerProvider).profile?.energy ?? 0;
    if (energy < _energyCost) {
      AppMessenger.showError(context, 'Enerji yetersiz ($_energyCost gerekli)');
      return;
    }
    final int gold = ref.read(playerProvider).profile?.gold ?? 0;
    final int? wager = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MekanArenaBetSheet(opponent: opp, myGold: gold),
    );
    if (!mounted || wager == null) return;
    await _fight(opp, wager);
  }

  Future<void> _fight(ArenaOpponent opp, int wager) async {
    try {
      final Map<String, dynamic> res =
          await _repo.pvpBet(mekanId: widget.mekanId, defenderId: opp.authId, wager: wager);
      if (!mounted) return;
      await ref.read(playerProvider.notifier).loadProfile();
      final bool won = res['won'] == true;
      final int net = (res['net_win'] as num?)?.toInt() ?? 0;
      final int repDelta = (res['rep_change'] as num?)?.toInt() ?? 0;
      final bool hospital = res['hospitalized'] == true;
      await _showResult(won: won, net: net, hospital: hospital, opp: opp, repDelta: repDelta);
      await _load();
    } catch (e) {
      if (!mounted) return;
      if (CaptchaGuard.isCaptchaRequired(e)) {
        final bool solved = await CaptchaGuard.solve(context, 'arena');
        if (solved && mounted) {
          unawaited(_fight(opp, wager));
        }
        return;
      }
      AppMessenger.showError(
        context,
        userFacingErrorMessage(e, fallback: 'Düello başlatılamadı.'),
      );
    }
  }

  Future<void> _showResult({
    required bool won,
    required int net,
    required bool hospital,
    required ArenaOpponent opp,
    int repDelta = 0,
  }) async {
    final Color c = won ? MekanPalette.neon : MekanPalette.ruby;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[MekanPalette.surfaceHi, MekanPalette.void_],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c, width: 1.6),
            boxShadow: <BoxShadow>[BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 26)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                won ? Icons.emoji_events_rounded : Icons.sentiment_very_dissatisfied_rounded,
                color: c,
                size: 64,
              ),
              const SizedBox(height: 12),
              Text(
                won ? 'ZAFER!' : 'YENİLGİ',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c, letterSpacing: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                '${opp.username} ile maç',
                style: const TextStyle(fontSize: 13, color: MekanPalette.textMid),
              ),
              const SizedBox(height: 16),
              if (won)
                GoldPriceBadge(amount: net)
              else
                const Text(
                  'Bahsi kaybettin',
                  style: TextStyle(fontSize: 14, color: MekanPalette.textMid, fontWeight: FontWeight.w700),
                ),
              if (repDelta != 0) ...<Widget>[
                const SizedBox(height: 10),
                ReputationGainBanner(
                  amount: repDelta.abs(),
                  label: repDelta > 0 ? 'İtibar kazanıldı' : 'İtibar kaybedildi',
                ),
              ],
              if (hospital) ...<Widget>[
                const SizedBox(height: 12),
                const GlowChip(
                  icon: Icons.local_hospital_rounded,
                  label: 'Hastaneye kaldırıldın',
                  color: MekanPalette.ruby,
                ),
                const SizedBox(height: 12),
                NeonButton(
                  label: 'Hastaneye Git',
                  icon: Icons.local_hospital_rounded,
                  accent: MekanPalette.ruby,
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go(AppRoutes.hospital);
                  },
                ),
              ],
              const SizedBox(height: 20),
              NeonButton(
                label: 'Devam',
                accent: c,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
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
    final int energy = ref.watch(playerProvider).profile?.energy ?? 0;

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
                        Material(
                          color: MekanPalette.void_.withValues(alpha: 0.6),
                          child: TabBar(
                            controller: _tab,
                            indicator: BoxDecoration(
                              color: MekanPalette.ruby.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: MekanPalette.ruby.withValues(alpha: 0.5),
                              ),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: MekanPalette.ruby,
                            unselectedLabelColor: MekanPalette.textLow,
                            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                            tabs: const <Tab>[
                              Tab(text: 'Dövüş', icon: Icon(Icons.sports_mma_rounded, size: 18)),
                              Tab(text: 'Sıralama', icon: Icon(Icons.leaderboard_rounded, size: 18)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tab,
                            children: <Widget>[
                              _fightTab(energy),
                              _rankingTab(),
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

  Widget _fightTab(int energy) {
    final bool hasEnergy = energy >= _energyCost;
    return RefreshIndicator(
      color: MekanPalette.ruby,
      backgroundColor: MekanPalette.navy,
      onRefresh: _load,
      child: _opponents.isEmpty
          ? ListView(
              children: const <Widget>[
                SizedBox(height: 80),
                MekanEmpty(
                  icon: Icons.person_off_outlined,
                  title: 'Rakip yok',
                  message: 'Şu an dövüşülebilecek oyuncu bulunamadı.',
                  accent: MekanPalette.ruby,
                ),
              ],
            )
          : ListView.separated(
              padding: GameScrollLayout.fromLTRB(context, left: 14, top: 8, right: 14),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _opponents.length,
              separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int i) {
                final ArenaOpponent o = _opponents[i];
                return MekanArenaFighterCard(
                  opponent: o,
                  enabled: hasEnergy,
                  onFight: () => _openBetSheet(o),
                );
              },
            ),
    );
  }

  Widget _rankingTab() {
    final String myId = ref.read(playerProvider).profile?.authId ?? '';
    return RefreshIndicator(
      color: MekanPalette.gold,
      backgroundColor: MekanPalette.navy,
      onRefresh: _load,
      child: _ranking.isEmpty
          ? ListView(
              children: const <Widget>[
                SizedBox(height: 80),
                MekanEmpty(
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
              itemCount: _ranking.length,
              itemBuilder: (BuildContext context, int i) {
                final ArenaRankRow r = _ranking[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MekanArenaRankRow(row: r, isMe: r.authId == myId),
                );
              },
            ),
    );
  }
}
