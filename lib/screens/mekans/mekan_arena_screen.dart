import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../providers/mekan_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/pvp_provider.dart';
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
    setState(() => _loading = true);
    try {
      final List<ArenaOpponent> opp = await _repo.fetchArenaOpponents();
      List<ArenaRankRow> rank = <ArenaRankRow>[];
      try {
        rank = await _repo.fetchArenaRanking(limit: 50);
      } catch (_) {/* ranking RPC optional */}
      if (mounted) {
        setState(() {
          _opponents = opp;
          _ranking = rank;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBetSheet(ArenaOpponent opp) async {
    final int energy = ref.read(playerProvider).profile?.energy ?? 0;
    if (energy < _energyCost) {
      AppMessenger.showError(context, 'Enerji yetersiz ($_energyCost gerekli)');
      return;
    }
    final int gold = ref.read(playerProvider).profile?.gold ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BetSheet(
        opponent: opp,
        myGold: gold,
        onFight: (int wager) => _fight(opp, wager),
      ),
    );
  }

  Future<void> _fight(ArenaOpponent opp, int wager) async {
    try {
      final Map<String, dynamic> res =
          await _repo.pvpBet(mekanId: widget.mekanId, defenderId: opp.authId, wager: wager);
      if (!mounted) return;
      await ref.read(playerProvider.notifier).loadProfile();
      ref.read(pvpDashboardProvider.notifier).load();
      ref.read(pvpHistoryProvider.notifier).load();
      final bool won = res['won'] == true;
      final int net = (res['net_win'] as num?)?.toInt() ?? 0;
      final bool hospital = res['hospitalized'] == true;
      await _showResult(won: won, net: net, hospital: hospital, opp: opp);
      await _load();
    } catch (e) {
      if (mounted) AppMessenger.showError(context, '$e');
    }
  }

  Future<void> _showResult({
    required bool won,
    required int net,
    required bool hospital,
    required ArenaOpponent opp,
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
              Icon(won ? Icons.emoji_events_rounded : Icons.sentiment_very_dissatisfied_rounded, color: c, size: 64),
              const SizedBox(height: 12),
              Text(won ? 'ZAFER!' : 'YENILGI',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c, letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Text('${opp.username} ile maç',
                  style: const TextStyle(fontSize: 13, color: MekanPalette.textMid)),
              const SizedBox(height: 16),
              if (won)
                GoldPriceBadge(amount: net)
              else
                const Text('Bahsi kaybettin', style: TextStyle(fontSize: 14, color: MekanPalette.textMid, fontWeight: FontWeight.w700)),
              if (hospital) ...<Widget>[
                const SizedBox(height: 12),
                const GlowChip(icon: Icons.local_hospital_rounded, label: 'Hastaneye kaldirildin', color: MekanPalette.ruby),
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

  @override
  Widget build(BuildContext context) {
    final int energy = ref.watch(playerProvider).profile?.energy ?? 0;

    return MekanSubScaffold(
      title: 'PvP Arena',
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.ruby))
          : Column(
              children: <Widget>[
                _arenaHeader(energy),
                Material(
                  color: MekanPalette.void_.withValues(alpha: 0.6),
                  child: TabBar(
                    controller: _tab,
                    indicatorColor: MekanPalette.ruby,
                    labelColor: MekanPalette.ruby,
                    unselectedLabelColor: MekanPalette.textLow,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    tabs: const <Tab>[
                      Tab(text: 'Dovus', icon: Icon(Icons.sports_mma_rounded, size: 18)),
                      Tab(text: 'Siralama', icon: Icon(Icons.leaderboard_rounded, size: 18)),
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
                  Text('BAHISLI ARENA',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: MekanPalette.textHi, letterSpacing: 0.5)),
                  Text('Altin yatir, kazan veya kaybet',
                      style: TextStyle(fontSize: 12, color: MekanPalette.textMid)),
                ],
              ),
            ),
            GlowChip(
              icon: Icons.bolt_rounded,
              label: '$energy',
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
                  message: 'Su an dovusulebilecek oyuncu bulunamadi.',
                  accent: MekanPalette.ruby,
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _opponents.length,
              separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int i) {
                final ArenaOpponent o = _opponents[i];
                return _FighterCard(
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
                  title: 'Siralama bos',
                  message: 'Henuz arena sıralamasi olusmadi.',
                  accent: MekanPalette.gold,
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _ranking.length,
              itemBuilder: (BuildContext context, int i) {
                final ArenaRankRow r = _ranking[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RankRow(row: r, isMe: r.authId == myId),
                );
              },
            ),
    );
  }
}

class _FighterCard extends StatelessWidget {
  const _FighterCard({required this.opponent, required this.enabled, required this.onFight});
  final ArenaOpponent opponent;
  final bool enabled;
  final VoidCallback onFight;

  @override
  Widget build(BuildContext context) {
    return NeonPanel(
      accent: MekanPalette.amethyst,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[MekanPalette.amethyst.withValues(alpha: 0.4), MekanPalette.amethyst.withValues(alpha: 0.1)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: MekanPalette.amethyst.withValues(alpha: 0.6)),
            ),
            alignment: Alignment.center,
            child: Text(
              opponent.username.isNotEmpty ? opponent.username[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MekanPalette.textHi),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(opponent.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: MekanPalette.textHi)),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    GlowChip(icon: Icons.military_tech_rounded, label: 'Lv ${opponent.level}', color: MekanPalette.aqua),
                    const SizedBox(width: 6),
                    GlowChip(icon: Icons.emoji_events_rounded, label: '${opponent.pvpRating}', color: MekanPalette.gold),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          NeonButton(
            label: 'Dovus',
            icon: Icons.sports_mma_rounded,
            accent: MekanPalette.ruby,
            expand: false,
            onPressed: enabled ? onFight : null,
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.row, required this.isMe});
  final ArenaRankRow row;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final Color rankColor = switch (row.rank) {
      1 => MekanPalette.gold,
      2 => const Color(0xFFC0C7D4),
      3 => MekanPalette.coral,
      _ => MekanPalette.textLow,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? MekanPalette.aqua.withValues(alpha: 0.12) : MekanPalette.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMe ? MekanPalette.aqua : Colors.white.withValues(alpha: 0.06), width: isMe ? 1.4 : 1),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Text('#${row.rank}',
                style: TextStyle(fontSize: row.rank <= 3 ? 16 : 13, fontWeight: FontWeight.w900, color: rankColor)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(isMe ? '${row.username} (Sen)' : row.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: MekanPalette.textHi)),
                Text('${row.wins}G / ${row.losses}M',
                    style: const TextStyle(fontSize: 11, color: MekanPalette.textLow, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.emoji_events_rounded, size: 14, color: MekanPalette.gold),
                  const SizedBox(width: 3),
                  Text('${row.pvpRating}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: MekanPalette.gold)),
                ],
              ),
              if (row.weeklyReward > 0)
                Text('Odul: ${row.weeklyReward >= 1000000 ? '${(row.weeklyReward / 1000000).toStringAsFixed(1)}M' : '${(row.weeklyReward / 1000).toStringAsFixed(0)}K'}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: MekanPalette.neon)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BetSheet extends StatefulWidget {
  const _BetSheet({required this.opponent, required this.myGold, required this.onFight});
  final ArenaOpponent opponent;
  final int myGold;
  final Future<void> Function(int wager) onFight;

  @override
  State<_BetSheet> createState() => _BetSheetState();
}

class _BetSheetState extends State<_BetSheet> {
  static const List<int> _presets = <int>[10000, 50000, 100000, 500000, 1000000, 5000000];
  int _wager = 10000;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.viewInsetsOf(context).bottom + 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[MekanPalette.surfaceHi, MekanPalette.void_],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: MekanPalette.ruby, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(width: 44, height: 4, decoration: BoxDecoration(color: MekanPalette.textLow, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text('${widget.opponent.username} ile bahis',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: MekanPalette.textHi)),
          const SizedBox(height: 4),
          const Text('15 enerji harcanir. Kazanan havuzun %92sini alir.',
              style: TextStyle(fontSize: 12, color: MekanPalette.textMid)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((int p) {
              final bool sel = _wager == p;
              final bool affordable = widget.myGold >= p;
              return PressableScale(
                onTap: affordable ? () => setState(() => _wager = p) : null,
                child: Opacity(
                  opacity: affordable ? 1 : 0.4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: sel ? MekanPalette.goldGrad : null,
                      color: sel ? null : MekanPalette.void_.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? MekanPalette.gold : Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      p >= 1000000 ? '${(p / 1000000).toStringAsFixed(0)}M' : '${(p / 1000).toStringAsFixed(0)}K',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: sel ? const Color(0xFF2A1E00) : MekanPalette.textHi,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          NeonButton(
            label: 'Dovus Basla',
            icon: Icons.sports_mma_rounded,
            accent: MekanPalette.ruby,
            busy: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              await widget.onFight(_wager);
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
