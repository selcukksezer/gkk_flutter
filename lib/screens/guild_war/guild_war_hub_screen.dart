import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../l10n/l10n.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../models/guild_war_model.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/guild_provider.dart';
import '../../providers/guild_vault_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/dungeon_siege_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../core/utils/combat_restriction.dart';
import '../../utils/logout_helper.dart';
import 'guild_war_defense_sheet.dart';
import '../../components/common/gkk_tab_page_shell.dart';
import '../../components/layout/game_screen_background.dart';
import 'widgets/guild_war_design.dart';
import 'widgets/guild_war_season_header.dart';
import 'widgets/guild_war_skeleton.dart';
import 'widgets/guild_war_tab_bar.dart';
import 'widgets/kingdom_election_panel.dart';
import 'widgets/ranking_podium.dart';
import 'widgets/territory_card.dart';
import 'widgets/territory_map_view.dart';
import 'widgets/tournament_card.dart';
import 'widgets/live_clash_banner.dart';
import 'widgets/faction_crest_painter.dart';
import 'widgets/territory_guild_duel_panel.dart';
import '../dungeon/widgets/dungeon_siege_design.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

class GuildWarHubScreen extends ConsumerStatefulWidget {
  const GuildWarHubScreen({super.key});

  @override
  ConsumerState<GuildWarHubScreen> createState() => _GuildWarHubScreenState();
}

class _GuildWarHubScreenState extends ConsumerState<GuildWarHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _kingdomRefreshToken = 0;
  bool _territoryMapView = true;
  LiveGuildWarClash? _liveClash;
  int _kingdomSubTab = 0;
  String _territoryFilter = 'all';
  Timer? _tickerTimer;
  int _tickerIndex = 0;

  final List<_KingdomDuelItem> _declaredDuels = <_KingdomDuelItem>[
    const _KingdomDuelItem(
      id: 'duel_1',
      challengerGuild: 'Gölge Muhafızları',
      targetGuild: 'Ejder Süvarileri',
      wagerGold: 50000,
      wagerPoints: 1200,
      declarationMessage: 'Sınır boyundaki kadim kale için şeref mücadelesine davetlisiniz!',
      scheduledTime: 'Bugün 21:00',
      status: 'Kabul Edildi',
      isAccepted: true,
    ),
    const _KingdomDuelItem(
      id: 'duel_2',
      challengerGuild: 'Kızıl Şafak',
      targetGuild: 'Ak Lejyon',
      wagerGold: 25000,
      wagerPoints: 800,
      declarationMessage: 'Haftalık lig zirvesi için hesaplaşma vakti geldi.',
      scheduledTime: 'Yarın 20:30',
      status: 'Onay Bekliyor',
      isAccepted: false,
    ),
  ];

  static const List<String> _tabLabels = <String>['Sıralama', 'Turnuva', 'Bölge', 'Krallık'];
  static const List<String> _tabIcons = <String>['🏅', '🏆', '🗺', '👑'];
  static const List<String> _tabSectionTitles = <String>[
    'Lonca Sıralaması',
    'Aktif Turnuvalar',
    'Bölge Haritası',
    'Krallık',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _tickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _tickerIndex++);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait<void>(<Future<void>>[
        ref.read(guildProvider.notifier).loadGuild(),
        ref.read(guildWarProvider.notifier).loadAll(),
        ref.read(guildVaultProvider.notifier).load(),
        ref.read(dungeonSiegeProvider.notifier).loadHub(silent: true),
      ]);
      await _loadClash();
      if (mounted) {
        await TutorialTriggers.onRouteEnter(ref, AppRoutes.guildWar);
      }
    });
  }

  Future<void> _loadClash() async {
    final String? guildId = ref.read(playerProvider).profile?.guildId;
    final LiveGuildWarClash? clash =
        await ref.read(guildWarProvider.notifier).loadLiveClash(guildId: guildId);
    if (!mounted) return;
    setState(() => _liveClash = clash);
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _declareDuel({
    required String challengerGuild,
    required String targetGuild,
    required int wagerGold,
    required int wagerPoints,
    required String message,
  }) {
    setState(() {
      _declaredDuels.insert(
        0,
        _KingdomDuelItem(
          id: 'duel_${DateTime.now().millisecondsSinceEpoch}',
          challengerGuild: challengerGuild,
          targetGuild: targetGuild,
          wagerGold: wagerGold,
          wagerPoints: wagerPoints,
          declarationMessage: message.trim().isEmpty
              ? 'Şeref ve sancak hakkı için savaş ilan ediyoruz!'
              : message.trim(),
          scheduledTime: '2 saat sonra',
          status: 'Meydan Okundu',
          isAccepted: false,
        ),
      );
    });
  }

  Future<void> _showDeclareDuelDialog(
    BuildContext context,
    List<GuildWarRanking> rankings,
    String? myGuildName,
  ) async {
    if (myGuildName == null || myGuildName.isEmpty) {
      AppMessenger.showError(context, 'Düello ilan etmek için bir loncada olmalısın.');
      return;
    }

    final List<String> opponentCandidates = rankings
        .map((GuildWarRanking r) => r.guildName)
        .where((String name) => name.isNotEmpty && name != myGuildName && name != '—')
        .toList();

    if (opponentCandidates.isEmpty) {
      opponentCandidates.addAll(<String>[
        'Ejder Muhafızları',
        'Gölge Tarikatı',
        'Kuzey Lejyonu',
        'Demir Muhafızlar',
      ]);
    }

    String selectedOpponent = opponentCandidates.first;
    int selectedWager = 25000;
    final TextEditingController messageController = TextEditingController(
      text: 'Krallık şerefi ve sancak egemenliği için meydan okuyoruz!',
    );

    final bool? declared = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            return AlertDialog(
              backgroundColor: WarPalette.obsidian,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: WarPalette.ruby.withValues(alpha: 0.6), width: 1.5),
              ),
              title: const Row(
                children: <Widget>[
                  Text('⚔️', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Krallık Düellosu İlan Et',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Meydan Okuyan: $myGuildName',
                      style: const TextStyle(
                        color: WarPalette.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hedef Lonca',
                      style: TextStyle(color: WarPalette.titanium, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: WarPalette.navy,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: WarPalette.ruby.withValues(alpha: 0.4)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedOpponent,
                          dropdownColor: WarPalette.obsidian,
                          isExpanded: true,
                          items: opponentCandidates.map((String guild) {
                            return DropdownMenuItem<String>(
                              value: guild,
                              child: Text(
                                guild,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? val) {
                            if (val != null) {
                              setModalState(() => selectedOpponent = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Düello Bahsi (Altın)',
                      style: TextStyle(color: WarPalette.titanium, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <int>[10000, 25000, 50000].map((int wager) {
                        final bool active = selectedWager == wager;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: WarPressable(
                              onTap: () => setModalState(() => selectedWager = wager),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: active
                                      ? WarPalette.gold.withValues(alpha: 0.2)
                                      : WarPalette.navy,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: active ? WarPalette.gold : WarPalette.titanium.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '${wager ~/ 1000}k',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: active ? WarPalette.gold : WarPalette.titanium,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Savaş Fermanı / Meydan Okuma Mesajı',
                      style: TextStyle(color: WarPalette.titanium, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: messageController,
                      maxLines: 2,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: WarPalette.navy,
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: WarPalette.titanium.withValues(alpha: 0.4)),
                        ),
                        hintText: 'Meydan okuma mesajını yaz...',
                        hintStyle: TextStyle(color: WarPalette.titanium.withValues(alpha: 0.5), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('İptal', style: TextStyle(color: WarPalette.titanium)),
                ),
                WarGoldButton(
                  label: 'Savaş İlan Et',
                  icon: Icons.flag_rounded,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        );
      },
    );

    if (declared == true && mounted) {
      _declareDuel(
        challengerGuild: myGuildName,
        targetGuild: selectedOpponent,
        wagerGold: selectedWager,
        wagerPoints: (selectedWager * 0.05).round(),
        message: messageController.text,
      );
      AppMessenger.showSuccess(context, '⚔️ $selectedOpponent loncasına resmi düello ilan edildi!');
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _kingdomRefreshToken++);
    await Future.wait<void>(<Future<void>>[
      ref.read(guildWarProvider.notifier).loadAll(),
      ref.read(guildVaultProvider.notifier).load(),
      _loadClash(),
    ]);
  }

  GuildWarRanking? _findMyRanking(
    List<GuildWarRanking> rankings,
    String? guildId,
    String? guildName,
  ) {
    if (guildId != null) {
      for (final GuildWarRanking entry in rankings) {
        if (entry.guildId == guildId) return entry;
      }
    }
    if (guildName != null) {
      for (final GuildWarRanking entry in rankings) {
        if (entry.guildName == guildName) return entry;
      }
    }
    return null;
  }

  Future<void> _joinTournament(String id) async {
    if (!mounted) return;
    final String? error = await ref.read(guildWarProvider.notifier).joinTournament(id);
    if (!mounted) return;
    if (error != null) {
      AppMessenger.showError(context, error);
    } else {
      AppMessenger.showSuccess(context, 'Turnuvaya kaydoldun!');
    }
  }

  Future<void> _attackTerritory(TerritoryData territory) async {
    final profile = ref.read(playerProvider).profile;
    final String? combatBlock = combatRestrictionMessage(
      hospitalUntil: profile?.hospitalUntil,
      prisonUntil: profile?.prisonUntil,
      health: profile?.health,
      maxHealth: profile?.maxHealth,
    );
    if (combatBlock != null) {
      AppMessenger.showError(context, combatBlock);
      return;
    }

    await context.push('${AppRoutes.guildWar}/territory/${territory.id}/attack');
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _addDefense(TerritoryData territory) async {
    final profile = ref.read(playerProvider).profile;
    final int? gems = await showGuildWarDefenseSheet(
      context,
      minDefenseGems: territory.minDefenseGems,
      playerGems: profile?.gems,
    );
    if (gems == null || gems <= 0) return;
    if (!mounted) return;

    final String? error =
        await ref.read(guildWarProvider.notifier).addDefense(territory.id, gems);
    if (!mounted) return;
    if (error != null) {
      AppMessenger.showError(context, error);
    } else {
      AppMessenger.showSuccess(context, 'Savunma eklendi!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final GuildWarState warState = ref.watch(guildWarProvider);
    final siegeState = ref.watch(dungeonSiegeProvider);
    final siegeStatus = siegeState.status;
    final profile = ref.watch(playerProvider).profile;
    final guildState = ref.watch(guildProvider);
    final String? guildId = guildState.guild?.guildId ?? profile?.guildId;
    final String? guildName = guildState.guild?.name ?? profile?.guildName;
    final GuildWarRanking? myRanking = _findMyRanking(warState.rankings, guildId, guildName);
    final bool combatLocked = isCombatRestricted(
      hospitalUntil: profile?.hospitalUntil,
      prisonUntil: profile?.prisonUntil,
    );

    Future<void> logout() async => performLogout(ref);

    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.screenTitleGuildWar,
        onLogout: logout,
        trailingActions: <Widget>[
          IconButton(
            tooltip: 'Savaş Kayıtları',
            onPressed: () => context.push(AppRoutes.guildWarLogs),
            icon: const Icon(Icons.history_rounded, color: AppColors.liquidGold, size: 22),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.guildWar, onLogout: logout),
      body: WarBackdrop(
        child: warState.isLoading
            ? const GuildWarSkeleton()
            : RefreshIndicator(
                color: WarPalette.gold,
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: GuildWarSeasonHeader(
                        season: warState.season,
                        myRank: myRanking?.rank,
                        myPoints: myRanking?.rankScore ?? myRanking?.points,
                        guildName: guildName,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.xs, AppSpacing.base, 0),
                        child: _WarRoomCommandHeader(
                          season: warState.season,
                          territoryCount: warState.territories.length,
                          activeTournamentCount: warState.tournaments.where((GuildWarTournament t) => t.isActive).length,
                          isClashLive: _liveClash?.isLive ?? false,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.xs, AppSpacing.base, 0),
                        child: _WarRoomLiveTicker(
                          tickerIndex: _tickerIndex,
                          liveClash: _liveClash,
                          onTap: () {
                            if (_liveClash?.isLive == true && _liveClash?.tournamentId != null) {
                              context.push('${AppRoutes.guildWar}/tournament/${_liveClash!.tournamentId}');
                            } else {
                              context.push(AppRoutes.guildWarLogs);
                            }
                          },
                        ),
                      ),
                    ),
                    if (_liveClash != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
                          child: LiveClashBanner(
                            clash: _liveClash!,
                            onRally: _liveClash!.matchId == null
                                ? null
                                : () async {
                                    final String? err = await ref
                                        .read(guildWarProvider.notifier)
                                        .rallyClash(_liveClash!.matchId!);
                                    if (!mounted) return;
                                    if (err != null) {
                                      AppMessenger.showError(context, err);
                                    } else {
                                      AppMessenger.showSuccess(context, 'Rally kaydı alındı!');
                                      await _loadClash();
                                    }
                                  },
                            onOpenPvp: () => context.push(AppRoutes.pvp),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
                        child: SiegeHubEntryCard(
                          siegeActive: siegeStatus.siegeActive,
                          inPrimeWindow: siegeStatus.inPrimeWindow,
                          sessionCount: siegeStatus.sessions.length,
                          unreadNotifications: siegeState.unreadNotificationCount,
                          onTap: () => context.push(AppRoutes.dungeonSiegeHub),
                        ),
                      ),
                    ),
                    if (guildId == null)
                      SliverToBoxAdapter(
                        child: _NoGuildBanner(onFindGuild: () => context.go(AppRoutes.guild)),
                      ),
                    if (warState.error != null)
                      SliverToBoxAdapter(child: _ErrorBanner(message: warState.error!)),
                    SliverToBoxAdapter(
                      child: GuildWarTabBar(
                        controller: _tabController,
                        tabs: _tabLabels,
                        icons: _tabIcons,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        child: GkkTabSectionTitle(
                          _tabSectionTitles[_tabController.index],
                          accent: WarPalette.gold,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                        child: _buildActiveTabContent(
                          warState: warState,
                          guildId: guildId,
                          guildName: guildName,
                          combatLocked: combatLocked,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: GameScrollLayout.bottomSpacer(context)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActiveTabContent({
    required GuildWarState warState,
    required String? guildId,
    required String? guildName,
    required bool combatLocked,
  }) {
    final Widget tabChild;
    switch (_tabController.index) {
      case 0:
        tabChild = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SeasonRankingsSpotlight(
              myRanking: _findMyRanking(warState.rankings, guildId, guildName),
              guildName: guildName,
              totalGuildsCount: warState.rankings.length,
            ),
            const SizedBox(height: AppSpacing.sm),
            RankingPodium(
              rankings: warState.rankings,
              highlightGuildName: guildName,
              highlightGuildId: guildId,
              onRefresh: _refresh,
            ),
          ],
        );
        break;
      case 1:
        tabChild = _buildTournamentsList(
          warState.tournaments,
          guildId,
          combatLocked: combatLocked,
        );
        break;
      case 2:
        tabChild = _buildTerritoriesContent(
          warState.territories,
          guildId,
          combatLocked: combatLocked,
        );
        break;
      case 3:
      default:
        tabChild = _buildKingdomTabContent(
          rankings: warState.rankings,
          guildId: guildId,
          guildName: guildName,
          combatLocked: combatLocked,
        );
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_tabController.index),
        child: tabChild,
      ),
    );
  }

  Widget _buildTournamentsList(
    List<GuildWarTournament> tournaments,
    String? guildId, {
    required bool combatLocked,
  }) {
    if (tournaments.isEmpty) {
      return const WarEmptyTab(
        icon: '🏆',
        message: 'Aktif turnuva yok. Yeni sezon başladığında burada görünecek.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (combatLocked)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Hastane/hapisteyken turnuvaya katılamazsın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: WarPalette.ruby, fontSize: 12),
            ),
          ),
        const WarSectionHeader(
          title: 'Aktif Turnuvalar',
          subtitle: 'Loncanı kaydet, ödül havuzundan pay al',
          accent: WarPalette.fuchsia,
        ),
        for (int i = 0; i < tournaments.length; i++)
          WarFadeSlide(
            index: i,
            child: TournamentCard(
              tournament: tournaments[i],
              onJoin: !combatLocked &&
                      guildId != null &&
                      tournaments[i].isActive
                  ? () => _joinTournament(tournaments[i].id)
                  : null,
              onDetail: () => context.push('${AppRoutes.guildWar}/tournament/${tournaments[i].id}'),
            ),
          ),
      ],
    );
  }

  Widget _buildTerritoriesContent(
    List<TerritoryData> territories,
    String? guildId, {
    required bool combatLocked,
  }) {
    final vault = ref.watch(guildVaultProvider);
    final List<TerritoryData> owned = guildId == null
        ? const <TerritoryData>[]
        : territories
            .where((TerritoryData t) => t.ownerGuildId == guildId)
            .toList(growable: false);
    final int totalTradeIncome = owned.fold<int>(
      0,
      (int sum, TerritoryData t) => sum + t.tradeIncome,
    );
    final int hourlyIncome = owned.fold<int>(
      0,
      (int sum, TerritoryData t) => sum + (t.tradeIncomeHourly > 0 ? t.tradeIncomeHourly.round() : (t.tradeIncome / 24).round()),
    );
    final int vaultItems = vault.items.length;

    final int totalCount = territories.length;
    final int myCount = owned.length;
    final int neutralCount = territories
        .where((TerritoryData t) => t.ownerGuildId == null || t.ownerGuildId!.isEmpty)
        .length;
    final int enemyCount = (totalCount - myCount - neutralCount).clamp(0, totalCount);

    final List<TerritoryData> filteredTerritories = switch (_territoryFilter) {
      'owned' => territories.where((TerritoryData t) => t.ownerGuildId == guildId).toList(),
      'enemy' => territories.where((TerritoryData t) => t.ownerGuildId != null && t.ownerGuildId!.isNotEmpty && t.ownerGuildId != guildId).toList(),
      'neutral' => territories.where((TerritoryData t) => t.ownerGuildId == null || t.ownerGuildId!.isEmpty).toList(),
      _ => territories,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TerritoryDominanceControlCard(
          totalTerritories: totalCount,
          ownedCount: myCount,
          enemyCount: enemyCount,
          neutralCount: neutralCount,
          activeFilter: _territoryFilter,
          onFilterChanged: (String filter) => setState(() => _territoryFilter = filter),
          mapView: _territoryMapView,
          onToggleMapView: (bool map) => setState(() => _territoryMapView = map),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (owned.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: WarNeonCard(
              accent: WarPalette.gold,
              child: Row(
                children: <Widget>[
                  const Text('💰', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${owned.length} bölge · $totalTradeIncome altın/gün (~$hourlyIncome/saat)',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kasa: ${vault.vaultGold}g · Gelir otomatik · Günlük vergi %5',
                          style: const TextStyle(color: WarPalette.titanium, fontSize: 11),
                        ),
                        if (vaultItems > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Kasada $vaultItems bölge eşyası',
                              style: const TextStyle(color: WarPalette.neon, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.guildVault),
                    child: const Text('Kasa'),
                  ),
                ],
              ),
            ),
          ),
        if (combatLocked)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Hastane/hapisteyken bölgeye saldıramazsın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: WarPalette.ruby, fontSize: 12),
            ),
          ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _territoryMapView ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: TerritoryMapView(
            territories: filteredTerritories,
            playerGuildId: guildId,
            onTerritoryTap: (TerritoryData t) =>
                context.push('${AppRoutes.guildWar}/territory/${t.id}'),
          ),
          secondChild: filteredTerritories.isEmpty
              ? const WarEmptyTab(
                  icon: '🗺',
                  message: 'Bu filtreye uygun bölge bulunamadı.',
                )
              : Column(
                  children: <Widget>[
                    const WarSectionHeader(
                      title: 'Bölge Listesi',
                      subtitle: 'Saldır veya savunma güçlendir',
                      accent: WarPalette.ruby,
                    ),
                    for (final TerritoryData t in filteredTerritories)
                      Builder(
                        builder: (BuildContext context) {
                          final bool isOwner = t.ownerGuildId == guildId;
                          return TerritoryCard(
                            territory: t,
                            isOwner: isOwner,
                            onTap: () => context.push('${AppRoutes.guildWar}/territory/${t.id}'),
                            onAttack: !combatLocked && !isOwner && guildId != null
                                ? () => _attackTerritory(t)
                                : null,
                            onAddDefense: isOwner ? () => _addDefense(t) : null,
                          );
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildKingdomTabContent({
    required List<GuildWarRanking> rankings,
    required String? guildId,
    required String? guildName,
    required bool combatLocked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: WarFilterChip(
                  label: '👑 Seçim & Ferman',
                  selected: _kingdomSubTab == 0,
                  onTap: () => setState(() => _kingdomSubTab = 0),
                  accent: WarPalette.gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: WarFilterChip(
                  label: '⚔️ Krallık Düelloları (${_declaredDuels.length})',
                  selected: _kingdomSubTab == 1,
                  onTap: () => setState(() => _kingdomSubTab = 1),
                  accent: WarPalette.ruby,
                ),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _kingdomSubTab == 0
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: KingdomElectionPanel(refreshToken: _kingdomRefreshToken),
          secondChild: _buildKingdomDuelsSection(
            rankings: rankings,
            guildId: guildId,
            guildName: guildName,
            combatLocked: combatLocked,
          ),
        ),
      ],
    );
  }

  Widget _buildKingdomDuelsSection({
    required List<GuildWarRanking> rankings,
    required String? guildId,
    required String? guildName,
    required bool combatLocked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        WarNeonCard(
          accent: WarPalette.ruby,
          glow: true,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Text('⚔️', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Krallık Şeref Düelloları',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Loncalar arası resmi savaş ilanı ve sancak mücadelesi',
                          style: TextStyle(color: WarPalette.titanium, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              WarGoldButton(
                label: 'Düello İlan Et',
                icon: Icons.flag_rounded,
                expand: true,
                onPressed: combatLocked
                    ? null
                    : () => _showDeclareDuelDialog(context, rankings, guildName),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const WarSectionHeader(
          title: 'Aktif Meydan Okumalar',
          subtitle: 'Resmi krallık düello bildirgeleri',
          accent: WarPalette.ruby,
        ),
        const SizedBox(height: 6),
        if (_declaredDuels.isEmpty)
          const WarEmptyTab(
            icon: '⚔️',
            message: 'Şu anda aktif düello bulunmuyor. Loncanla ilk savaşı ilan et!',
          )
        else
          for (final _KingdomDuelItem duel in _declaredDuels)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _KingdomDuelCard(
                duel: duel,
                isMyGuildInvolved: guildName != null &&
                    (duel.challengerGuild == guildName || duel.targetGuild == guildName),
                onAccept: duel.isAccepted || guildName != duel.targetGuild
                    ? null
                    : () {
                        setState(() {
                          final int idx = _declaredDuels.indexWhere((_KingdomDuelItem d) => d.id == duel.id);
                          if (idx >= 0) {
                            _declaredDuels[idx] = duel.copyWith(status: 'Kabul Edildi', isAccepted: true);
                          }
                        });
                        AppMessenger.showSuccess(context, '⚔️ Düello meydan okuması kabul edildi! Savaş saati belirlendi.');
                      },
              ),
            ),
      ],
    );
  }
}

class _NoGuildBanner extends StatelessWidget {
  const _NoGuildBanner({required this.onFindGuild});

  final VoidCallback onFindGuild;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      child: WarDottedPanel(
        borderColor: WarPalette.coral.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Text('⚠️', style: TextStyle(fontSize: 22)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loncaya üye değilsin',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Savaşa katılmak ve bölge ele geçirmek için bir loncaya katıl.',
              style: TextStyle(fontSize: 11, color: WarPalette.titanium, height: 1.35),
            ),
            const SizedBox(height: 10),
            WarGoldButton(label: 'Lonca Bul', onPressed: onFindGuild, icon: Icons.groups_rounded),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      child: WarDottedPanel(
        borderColor: WarPalette.ruby.withValues(alpha: 0.4),
        child: Text(
          message,
          style: const TextStyle(color: WarPalette.ruby, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _KingdomDuelItem {
  final String id;
  final String challengerGuild;
  final String targetGuild;
  final int wagerGold;
  final int wagerPoints;
  final String declarationMessage;
  final String scheduledTime;
  final String status;
  final bool isAccepted;

  const _KingdomDuelItem({
    required this.id,
    required this.challengerGuild,
    required this.targetGuild,
    required this.wagerGold,
    required this.wagerPoints,
    required this.declarationMessage,
    required this.scheduledTime,
    required this.status,
    required this.isAccepted,
  });

  _KingdomDuelItem copyWith({
    String? status,
    bool? isAccepted,
  }) {
    return _KingdomDuelItem(
      id: id,
      challengerGuild: challengerGuild,
      targetGuild: targetGuild,
      wagerGold: wagerGold,
      wagerPoints: wagerPoints,
      declarationMessage: declarationMessage,
      scheduledTime: scheduledTime,
      status: status ?? this.status,
      isAccepted: isAccepted ?? this.isAccepted,
    );
  }
}

class _WarRoomCommandHeader extends StatelessWidget {
  const _WarRoomCommandHeader({
    required this.season,
    required this.territoryCount,
    required this.activeTournamentCount,
    required this.isClashLive,
  });

  final GuildWarSeason? season;
  final int territoryCount;
  final int activeTournamentCount;
  final bool isClashLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: WarPalette.obsidian,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WarPalette.ruby.withValues(alpha: 0.35), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: WarPalette.ruby.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isClashLive ? WarPalette.ruby : WarPalette.gold,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: isClashLive
                          ? WarPalette.ruby.withValues(alpha: 0.8)
                          : WarPalette.gold.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isClashLive
                      ? 'DEFCON 1 // AKTİF SAVAŞ SEFERBERLİĞİ'
                      : 'STRATEJİK KOMUTA MERKEZİ · DEFCON 2',
                  style: TextStyle(
                    color: isClashLive ? WarPalette.ruby : WarPalette.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: WarPalette.navy,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: WarPalette.titanium.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'SEZON ${season?.season ?? 1} · H${season?.week ?? 1}',
                  style: const TextStyle(
                    color: WarPalette.titanium,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildMetricItem(
                  icon: '🗺️',
                  label: 'Bölgeler',
                  value: '$territoryCount Alan',
                ),
              ),
              Container(width: 1, height: 24, color: WarPalette.titanium.withValues(alpha: 0.2)),
              Expanded(
                child: _buildMetricItem(
                  icon: '⚔️',
                  label: 'Turnuvalar',
                  value: '$activeTournamentCount Aktif',
                ),
              ),
              Container(width: 1, height: 24, color: WarPalette.titanium.withValues(alpha: 0.2)),
              Expanded(
                child: _buildMetricItem(
                  icon: isClashLive ? '🔥' : '🛡️',
                  label: 'Savaş Hattı',
                  value: isClashLive ? 'Çatışma' : 'Teyakkuz',
                  highlight: isClashLive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      children: <Widget>[
        Text(
          '$icon $value',
          style: TextStyle(
            color: highlight ? WarPalette.ruby : AppColors.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(color: WarPalette.titanium, fontSize: 10),
        ),
      ],
    );
  }
}

class _WarRoomLiveTicker extends StatelessWidget {
  const _WarRoomLiveTicker({
    required this.tickerIndex,
    this.liveClash,
    this.onTap,
  });

  final int tickerIndex;
  final LiveGuildWarClash? liveClash;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final List<String> announcements = <String>[];
    if (liveClash != null && liveClash!.isLive) {
      announcements.add(
        '⚔️ CANLI CLASH: ${liveClash!.guild1Name ?? 'Lonca 1'} (${liveClash!.guild1Score}) VS (${liveClash!.guild2Score}) ${liveClash!.guild2Name ?? 'Lonca 2'}',
      );
    } else {
      announcements.add('⚔️ Haftalık Lonca Ligi: Turnuva eşleşmeleri ve kayıtlar devam ediyor.');
    }
    announcements.add('🏰 Uçurum Bastionu: Savunma barikatları güçlendirildi, garnizon hazır!');
    announcements.add('👑 Krallık Fermanı: Şampiyon loncalar şeref düellosuna davet edildi.');
    announcements.add('🗺️ Bölge Hakimiyeti: Stratejik kaleler için sınır çatışmaları yoğunlaştı.');

    final String text = announcements[tickerIndex % announcements.length];

    return WarPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: WarPalette.navy,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: WarPalette.gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: WarPalette.ruby.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: WarPalette.ruby.withValues(alpha: 0.6)),
              ),
              child: const Text(
                'CANLI HAT',
                style: TextStyle(
                  color: WarPalette.ruby,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  text,
                  key: ValueKey<String>(text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: WarPalette.gold, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TerritoryDominanceControlCard extends StatelessWidget {
  const _TerritoryDominanceControlCard({
    required this.totalTerritories,
    required this.ownedCount,
    required this.enemyCount,
    required this.neutralCount,
    required this.activeFilter,
    required this.onFilterChanged,
    required this.mapView,
    required this.onToggleMapView,
  });

  final int totalTerritories;
  final int ownedCount;
  final int enemyCount;
  final int neutralCount;
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;
  final bool mapView;
  final ValueChanged<bool> onToggleMapView;

  @override
  Widget build(BuildContext context) {
    final double myPct = totalTerritories > 0 ? (ownedCount / totalTerritories) * 100 : 0.0;
    final double enemyPct = totalTerritories > 0 ? (enemyCount / totalTerritories) * 100 : 0.0;
    final double neutralPct = totalTerritories > 0 ? (neutralCount / totalTerritories) * 100 : 0.0;

    return WarNeonCard(
      accent: WarPalette.neon,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🗺️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'BÖLGE HÂKİMİYET ORANLARI',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Text(
                '$totalTerritories Bölge Toplam',
                style: const TextStyle(color: WarPalette.titanium, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 12,
              child: Row(
                children: <Widget>[
                  if (ownedCount > 0)
                    Expanded(
                      flex: (myPct * 10).round().clamp(1, 1000),
                      child: Container(
                        color: WarPalette.gold,
                      ),
                    ),
                  if (enemyCount > 0)
                    Expanded(
                      flex: (enemyPct * 10).round().clamp(1, 1000),
                      child: Container(
                        color: WarPalette.ruby,
                      ),
                    ),
                  if (neutralCount > 0)
                    Expanded(
                      flex: (neutralPct * 10).round().clamp(1, 1000),
                      child: Container(
                        color: WarPalette.titanium.withValues(alpha: 0.35),
                      ),
                    ),
                  if (totalTerritories == 0)
                    Expanded(
                      child: Container(color: WarPalette.titanium.withValues(alpha: 0.2)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _buildLegend(
                color: WarPalette.gold,
                label: 'Loncan',
                pct: myPct,
                count: ownedCount,
              ),
              _buildLegend(
                color: WarPalette.ruby,
                label: 'Rakipler',
                pct: enemyPct,
                count: enemyCount,
              ),
              _buildLegend(
                color: WarPalette.titanium,
                label: 'Bağımsız',
                pct: neutralPct,
                count: neutralCount,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: WarPalette.titanium.withValues(alpha: 0.2)),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      WarFilterChip(
                        label: 'Tümü ($totalTerritories)',
                        selected: activeFilter == 'all',
                        onTap: () => onFilterChanged('all'),
                        accent: WarPalette.gold,
                      ),
                      const SizedBox(width: 6),
                      WarFilterChip(
                        label: 'Loncamız ($ownedCount)',
                        selected: activeFilter == 'owned',
                        onTap: () => onFilterChanged('owned'),
                        accent: WarPalette.gold,
                      ),
                      const SizedBox(width: 6),
                      WarFilterChip(
                        label: 'Düşman ($enemyCount)',
                        selected: activeFilter == 'enemy',
                        onTap: () => onFilterChanged('enemy'),
                        accent: WarPalette.ruby,
                      ),
                      const SizedBox(width: 6),
                      WarFilterChip(
                        label: 'Sahipsiz ($neutralCount)',
                        selected: activeFilter == 'neutral',
                        onTap: () => onFilterChanged('neutral'),
                        accent: WarPalette.titanium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Harita Görünümü',
                    icon: Icon(
                      Icons.map_rounded,
                      size: 20,
                      color: mapView ? WarPalette.neon : WarPalette.titanium.withValues(alpha: 0.5),
                    ),
                    onPressed: () => onToggleMapView(true),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'Liste Görünümü',
                    icon: Icon(
                      Icons.view_list_rounded,
                      size: 20,
                      color: !mapView ? WarPalette.gold : WarPalette.titanium.withValues(alpha: 0.5),
                    ),
                    onPressed: () => onToggleMapView(false),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend({
    required Color color,
    required String label,
    required double pct,
    required int count,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: %${pct.toStringAsFixed(0)} ($count)',
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SeasonRankingsSpotlight extends StatelessWidget {
  const _SeasonRankingsSpotlight({
    this.myRanking,
    this.guildName,
    required this.totalGuildsCount,
  });

  final GuildWarRanking? myRanking;
  final String? guildName;
  final int totalGuildsCount;

  @override
  Widget build(BuildContext context) {
    final int rank = myRanking?.rank ?? 0;
    final int score = myRanking?.rankScore ?? myRanking?.points ?? 0;
    final int wins = myRanking?.wins ?? 0;
    final int losses = myRanking?.losses ?? 0;
    final int totalMatches = wins + losses;
    final double winRate = totalMatches > 0 ? (wins / totalMatches) * 100 : 0.0;

    final String tierTitle;
    final String tierIcon;
    final Color tierColor;

    if (rank == 1) {
      tierTitle = 'Kadim Hükümdar';
      tierIcon = '👑';
      tierColor = WarPalette.gold;
    } else if (rank == 2 || rank == 3) {
      tierTitle = 'Elit Elmas';
      tierIcon = '💎';
      tierColor = WarPalette.neon;
    } else if (rank > 3 && rank <= 10) {
      tierTitle = 'Usta Savaşçı';
      tierIcon = '⚔️';
      tierColor = WarPalette.fuchsia;
    } else if (rank > 10) {
      tierTitle = 'Lonca Birliği';
      tierIcon = '🛡️';
      tierColor = WarPalette.solar;
    } else {
      tierTitle = 'Derecesiz';
      tierIcon = '🏳️';
      tierColor = WarPalette.titanium;
    }

    return WarNeonCard(
      accent: tierColor,
      glow: rank > 0 && rank <= 3,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(tierIcon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          guildName ?? 'Loncan',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: tierColor.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            tierTitle.toUpperCase(),
                            style: TextStyle(
                              color: tierColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rank > 0
                          ? 'Mevcut Sıra: #$rank / $totalGuildsCount lonca · $score Sezon Puanı'
                          : 'Sıralama dışı · Sezon maçlarına katılarak puan topla',
                      style: const TextStyle(color: WarPalette.titanium, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: WarPalette.navy,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: WarPalette.titanium.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildStatPill(label: 'Galibiyet', value: '$wins G'),
                Container(width: 1, height: 16, color: WarPalette.titanium.withValues(alpha: 0.3)),
                _buildStatPill(label: 'Mağlubiyet', value: '$losses M'),
                Container(width: 1, height: 16, color: WarPalette.titanium.withValues(alpha: 0.3)),
                _buildStatPill(label: 'Kazanma Oranı', value: '%${winRate.toStringAsFixed(0)}'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '🏆 1. Sıra Ödülü: 100.000 Altın + Krallık Fermanı Yetkisi + Efsanevi Sancak',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: WarPalette.gold.withValues(alpha: 0.9),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({required String label, required String value}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: WarPalette.titanium, fontSize: 9.5),
        ),
      ],
    );
  }
}

class _KingdomDuelCard extends StatelessWidget {
  const _KingdomDuelCard({
    required this.duel,
    required this.isMyGuildInvolved,
    this.onAccept,
  });

  final _KingdomDuelItem duel;
  final bool isMyGuildInvolved;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final bool accepted = duel.isAccepted;

    return WarNeonCard(
      accent: accepted ? WarPalette.neon : WarPalette.ruby,
      glow: isMyGuildInvolved,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              WarStatusPill(
                label: duel.status,
                color: accepted ? WarPalette.neon : WarPalette.solar,
                pulse: !accepted,
              ),
              const Spacer(),
              const Icon(Icons.timer_outlined, size: 14, color: WarPalette.titanium),
              const SizedBox(width: 4),
              Text(
                duel.scheduledTime,
                style: const TextStyle(color: WarPalette.titanium, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TerritoryGuildDuelPanel(
            attacker: GuildWarGuildBrief(id: duel.challengerGuild, name: duel.challengerGuild),
            defender: GuildWarGuildBrief(id: duel.targetGuild, name: duel.targetGuild),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: WarPalette.navy,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: WarPalette.titanium.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '💰 Bahis: ${duel.wagerGold} Altın',
                  style: const TextStyle(color: WarPalette.gold, fontSize: 11, fontWeight: FontWeight.w800),
                ),
                Text(
                  '⭐ Prestij: +${duel.wagerPoints}',
                  style: const TextStyle(color: WarPalette.fuchsia, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (duel.declarationMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '“${duel.declarationMessage}”',
                style: TextStyle(
                  color: WarPalette.titanium.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (onAccept != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: WarGoldButton(
                label: 'Meydan Okumayı Kabul Et',
                icon: Icons.check_circle_rounded,
                onPressed: onAccept,
              ),
            ),
        ],
      ),
    );
  }
}

