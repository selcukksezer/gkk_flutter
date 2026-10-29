import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'widgets/mekan_scaffold.dart';
import 'widgets/mekan_theme.dart';
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
    HapticFeedback.lightImpact();
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
    HapticFeedback.mediumImpact();
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
    final int gold = profile?.gold ?? 0;
    final String myId = profile?.authId ?? '';
    final ArenaRankRow? myRank = _ranking.where((ArenaRankRow r) => r.authId == myId).firstOrNull;
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
                        _arenaHeader(energy: energy, gold: gold, myRank: myRank),
                        GkkTabBar(
                          controller: _tab,
                          isScrollable: false,
                          padding: EdgeInsets.zero,
                          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
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
                                child: _rankingTab(myId: myId, myRank: myRank),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _arenaHeader({
    required int energy,
    required int gold,
    required ArenaRankRow? myRank,
  }) {
    final bool hasEnergy = energy >= _energyCost;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: NeonPanel(
        accent: MekanPalette.ruby,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MekanPalette.ruby.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: MekanPalette.ruby.withValues(alpha: 0.45),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.sports_mma_rounded, color: MekanPalette.ruby, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text(
                            'YERALTI ARENASI',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: MekanPalette.textHi,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: MekanPalette.ruby.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'PvP',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: MekanPalette.ruby,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Bahisli düellolar • Puan kazan veya kaybet',
                        style: TextStyle(fontSize: 11.5, color: MekanPalette.textMid),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Arena Rehberi',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.help_outline_rounded, size: 20, color: MekanPalette.titanium),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showArenaInfoDialog();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: MekanPalette.void_.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _headerStatChip(
                      icon: Icons.bolt_rounded,
                      label: 'Enerji (15/Maç)',
                      value: '$energy / $_energyCost',
                      color: hasEnergy ? MekanPalette.neon : MekanPalette.ruby,
                    ),
                  ),
                  Container(width: 1, height: 22, color: Colors.white.withValues(alpha: 0.08)),
                  Expanded(
                    child: _headerStatChip(
                      icon: Icons.paid_rounded,
                      label: 'Mevcut Bakiye',
                      value: formatMekanGold(gold),
                      color: MekanPalette.gold,
                    ),
                  ),
                  Container(width: 1, height: 22, color: Colors.white.withValues(alpha: 0.08)),
                  Expanded(
                    child: _headerStatChip(
                      icon: Icons.emoji_events_rounded,
                      label: myRank != null ? '${myRank.wins}G / ${myRank.losses}M' : 'Durum',
                      value: myRank != null ? '#${myRank.rank} (${myRank.pvpRating})' : 'Derecesiz',
                      color: myRank != null ? MekanPalette.aqua : MekanPalette.textLow,
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

  Widget _headerStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12.5, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: MekanPalette.textLow,
          ),
        ),
      ],
    );
  }

  void _showArenaInfoDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(ctx).bottom + 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    MekanPalette.surfaceHi.withValues(alpha: 0.96),
                    MekanPalette.void_.withValues(alpha: 0.98),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: MekanPalette.ruby.withValues(alpha: 0.8), width: 1.5),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: MekanPalette.ruby.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MekanPalette.textLow.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MekanPalette.ruby.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: MekanPalette.ruby, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Arena & Bahis Rehberi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: MekanPalette.textHi,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ruleCard(
                    icon: Icons.sports_mma_rounded,
                    accent: MekanPalette.ruby,
                    title: 'Dövüş & Enerji',
                    desc: 'Her arena dövüşü 15 Enerji harcar. Eşleştirme havuzunda rating puanınıza yakın gladyatörler listelenir.',
                  ),
                  const SizedBox(height: 9),
                  _ruleCard(
                    icon: Icons.paid_rounded,
                    accent: MekanPalette.gold,
                    title: 'Bahis & Ödül Havuzu',
                    desc: 'Kazanan gladyatör toplam bahis havuzunun %92\'sini alır. %8 mekan komisyonu olarak kesilir. Dostluk maçında (0 Altın) altın riski yoktur.',
                  ),
                  const SizedBox(height: 9),
                  _ruleCard(
                    icon: Icons.trending_up_rounded,
                    accent: MekanPalette.aqua,
                    title: 'PvP Rating (ELO)',
                    desc: 'Kazanılan maçlar rating puanınızı yükseltir, mağlubiyetler düşürür. Güçlü rakipleri yenmek daha çok puan kazandırır.',
                  ),
                  const SizedBox(height: 9),
                  _ruleCard(
                    icon: Icons.emoji_events_rounded,
                    accent: MekanPalette.amethyst,
                    title: 'Haftalık Lig Ödülleri',
                    desc: 'Haftayı ilk 50\'de tamamlayan dövüşçüler Pazartesi–Çarşamba günleri arasında sıralamalarına göre altın ödüllerini toplar.',
                  ),
                  const SizedBox(height: 18),
                  NeonButton(
                    label: 'Anladım',
                    icon: Icons.check_rounded,
                    accent: MekanPalette.ruby,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ruleCard({
    required IconData icon,
    required Color accent,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: MekanPalette.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: accent, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MekanPalette.textMid,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _combatBlockBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MekanPalette.ruby.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: MekanPalette.ruby.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: MekanPalette.ruby, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'DÖVÜŞ KISITLAMASI AKTİF',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: MekanPalette.ruby,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MekanPalette.textHi,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
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
              padding: GameScrollLayout.fromLTRB(context, left: 14, top: 10, right: 14),
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                if (combatBlock != null) ...<Widget>[
                  _combatBlockBanner(combatBlock),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 24),
                MekanEmpty(
                  icon: Icons.radar_rounded,
                  title: 'Eşleştirme Bekleniyor',
                  message: combatBlock ??
                      (_refreshInSec > 0
                          ? 'Uygun seviyedeki rakipler taranıyor. Yeni liste $_refreshInSec sn içinde hazır.'
                          : 'Şu an arenada dövüşülebilecek rakip bulunamadı. Listeyi tazeleyin.'),
                  accent: MekanPalette.ruby,
                  action: NeonButton(
                    label: _refreshInSec > 0 ? 'Bekle ($_refreshInSec sn)' : 'Havuzu Yenile',
                    icon: _refreshInSec > 0 ? Icons.timer_outlined : Icons.sync_rounded,
                    accent: MekanPalette.ruby,
                    expand: false,
                    onPressed: combatBlock != null || _refreshInSec > 0 || _refreshingOffers
                        ? null
                        : _refreshOffers,
                  ),
                ),
              ],
            )
          : ListView(
              padding: GameScrollLayout.fromLTRB(context, left: 14, top: 8, right: 14),
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                if (combatBlock != null) ...<Widget>[
                  _combatBlockBanner(combatBlock),
                  const SizedBox(height: 4),
                ],
                _matchmakingPoolHeader(canFight),
                const SizedBox(height: 10),
                ..._opponents.map((ArenaOpponent o) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MekanArenaFighterCard(
                      opponent: o,
                      enabled: canFight && o.offerId.isNotEmpty,
                      onFight: () => _openBetSheet(o),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                _arenaTipsFooter(),
                const SizedBox(height: 12),
              ],
            ),
    );
  }

  Widget _matchmakingPoolHeader(bool canFight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MekanPalette.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MekanPalette.ruby.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.radar_rounded, size: 16, color: MekanPalette.ruby),
          ),
          const SizedBox(width: 8),
          const Text(
            'EŞLEŞTİRME HAVUZU',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: MekanPalette.textHi,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: MekanPalette.void_.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              '${_opponents.length}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: MekanPalette.ruby,
              ),
            ),
          ),
          const Spacer(),
          _refreshingOffers
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.ruby),
                )
              : PressableScale(
                  enabled: canFight && _refreshInSec == 0,
                  onTap: canFight && _refreshInSec == 0 ? _refreshOffers : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _refreshInSec > 0
                          ? MekanPalette.void_.withValues(alpha: 0.4)
                          : MekanPalette.ruby.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _refreshInSec > 0
                            ? Colors.white.withValues(alpha: 0.1)
                            : MekanPalette.ruby.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _refreshInSec > 0 ? Icons.timer_outlined : Icons.refresh_rounded,
                          size: 13,
                          color: _refreshInSec > 0 ? MekanPalette.titanium : MekanPalette.ruby,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _refreshInSec > 0 ? '$_refreshInSec sn' : 'Yenile',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _refreshInSec > 0 ? MekanPalette.titanium : MekanPalette.ruby,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _arenaTipsFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MekanPalette.void_.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.tips_and_updates_outlined, size: 16, color: MekanPalette.gold),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Galip gelen havuzun %92\'sini alır. Sıralamanı yükselterek haftalık ligden pay kap!',
              style: TextStyle(
                fontSize: 11,
                color: MekanPalette.textLow,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _claimWeeklyReward() async {
    if (_claimingReward) return;
    HapticFeedback.heavyImpact();
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
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: NeonPanel(
          accent: MekanPalette.gold,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MekanPalette.gold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: MekanPalette.gold.withValues(alpha: 0.4), blurRadius: 10),
                  ],
                ),
                child: const Icon(Icons.emoji_events_rounded, color: MekanPalette.gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'HAFTALIK ARENA ÖDÜLÜ',
                      style: TextStyle(
                        color: MekanPalette.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${status.rank} Sıra • +${formatMekanGold(status.rewardGold)} Altın Hazır!',
                      style: const TextStyle(
                        color: MekanPalette.textHi,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              NeonButton(
                label: 'Ödülü Al',
                icon: Icons.check_circle_rounded,
                accent: MekanPalette.gold,
                busy: _claimingReward,
                expand: false,
                onPressed: _claimingReward ? null : _claimWeeklyReward,
              ),
            ],
          ),
        ),
      );
    }
    if (status.claimOpen && status.rewardGold == 0) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MekanPalette.void_.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.calendar_month_rounded, size: 16, color: MekanPalette.titanium),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Haftalık lig dönemi açık (Pzt–Çar). Top 50\'deysen ödülünü buradan toplayabilirsin.',
                style: TextStyle(color: MekanPalette.textMid, fontSize: 11, height: 1.3),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _podiumView(List<ArenaRankRow> ranking) {
    if (ranking.length < 3) return const SizedBox.shrink();
    final ArenaRankRow first = ranking[0];
    final ArenaRankRow second = ranking[1];
    final ArenaRankRow third = ranking[2];

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 14),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            MekanPalette.gold.withValues(alpha: 0.12),
            MekanPalette.surfaceHi.withValues(alpha: 0.5),
            MekanPalette.void_.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MekanPalette.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: <Widget>[
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.military_tech_rounded, size: 16, color: MekanPalette.gold),
              SizedBox(width: 6),
              Text(
                'ELİT GLADYATÖRLER KÜRSÜSÜ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: MekanPalette.gold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: _podiumPillar(
                  row: second,
                  accent: const Color(0xFFC0C7D4),
                  rankTitle: '#2 GÜMÜŞ',
                  icon: Icons.shield_rounded,
                  height: 84,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _podiumPillar(
                  row: first,
                  accent: MekanPalette.gold,
                  rankTitle: '#1 ŞAMPİYON',
                  icon: Icons.workspace_premium_rounded,
                  height: 108,
                  isCenter: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _podiumPillar(
                  row: third,
                  accent: MekanPalette.coral,
                  rankTitle: '#3 BRONZ',
                  icon: Icons.military_tech_rounded,
                  height: 72,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _podiumPillar({
    required ArenaRankRow row,
    required Color accent,
    required String rankTitle,
    required IconData icon,
    required double height,
    bool isCenter = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: isCenter ? 26 : 20, color: accent),
        const SizedBox(height: 4),
        Text(
          row.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isCenter ? 13 : 11.5,
            fontWeight: FontWeight.w900,
            color: MekanPalette.textHi,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.emoji_events_rounded, size: 11, color: accent),
            const SizedBox(width: 2),
            Text(
              '${row.pvpRating}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                accent.withValues(alpha: isCenter ? 0.35 : 0.2),
                accent.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(
              top: BorderSide(color: accent, width: isCenter ? 2.5 : 1.5),
              left: BorderSide(color: accent.withValues(alpha: 0.3)),
              right: BorderSide(color: accent.withValues(alpha: 0.3)),
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                rankTitle,
                style: TextStyle(
                  fontSize: isCenter ? 11 : 9.5,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${row.wins}G / ${row.losses}M',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: MekanPalette.textLow,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _myRankSpotlight(ArenaRankRow? myRank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: myRank != null
            ? MekanPalette.aqua.withValues(alpha: 0.1)
            : MekanPalette.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: myRank != null
              ? MekanPalette.aqua.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (myRank != null ? MekanPalette.aqua : MekanPalette.textLow).withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              myRank != null ? Icons.person_pin_rounded : Icons.person_outline_rounded,
              color: myRank != null ? MekanPalette.aqua : MekanPalette.textLow,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  myRank != null ? 'SENİN ARENA DERECEN' : 'DERECE DIŞISIN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: myRank != null ? MekanPalette.aqua : MekanPalette.textMid,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  myRank != null
                      ? '#${myRank.rank} Sıra • ${myRank.pvpRating} RP • ${myRank.wins}G / ${myRank.losses}M'
                      : 'Arena dövüşleri kazanarak ilk 50 sıralamasına gir ve ödül topla!',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MekanPalette.textHi,
                  ),
                ),
              ],
            ),
          ),
          if (myRank != null && myRank.weeklyReward > 0) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MekanPalette.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MekanPalette.gold.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: <Widget>[
                  const Text(
                    'Ödül',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: MekanPalette.gold),
                  ),
                  Text(
                    formatMekanGold(myRank.weeklyReward),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: MekanPalette.neon),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rankingTab({
    required String myId,
    required ArenaRankRow? myRank,
  }) {
    return RefreshIndicator(
      color: MekanPalette.gold,
      backgroundColor: MekanPalette.navy,
      onRefresh: _load,
      child: _ranking.isEmpty
          ? ListView(
              padding: GameScrollLayout.fromLTRB(context, left: 14, top: 10, right: 14),
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                _weeklyRewardBanner(),
                _myRankSpotlight(myRank),
                const SizedBox(height: 40),
                const MekanEmpty(
                  icon: Icons.leaderboard_outlined,
                  title: 'Sıralama boş',
                  message: 'Henüz arena sıralaması oluşmadı.',
                  accent: MekanPalette.gold,
                ),
              ],
            )
          : ListView(
              padding: GameScrollLayout.fromLTRB(context, left: 14, top: 8, right: 14),
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                _weeklyRewardBanner(),
                _myRankSpotlight(myRank),
                if (_ranking.length >= 3) _podiumView(_ranking),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: MekanPalette.gold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'TÜM GLADYATÖRLER (TOP 50)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: MekanPalette.textMid,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._ranking.map((ArenaRankRow r) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MekanArenaRankRow(row: r, isMe: r.authId == myId),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
