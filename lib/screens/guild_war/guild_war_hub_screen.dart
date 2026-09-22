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
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
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
    switch (_tabController.index) {
      case 0:
        return RankingPodium(
          rankings: warState.rankings,
          highlightGuildName: guildName,
          highlightGuildId: guildId,
          onRefresh: _refresh,
        );
      case 1:
        return _buildTournamentsList(
          warState.tournaments,
          guildId,
          combatLocked: combatLocked,
        );
      case 2:
        return _buildTerritoriesContent(
          warState.territories,
          guildId,
          combatLocked: combatLocked,
        );
      case 3:
      default:
        return KingdomElectionPanel(refreshToken: _kingdomRefreshToken);
    }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            WarFilterChip(
              label: 'Harita',
              selected: _territoryMapView,
              onTap: () => setState(() => _territoryMapView = true),
              accent: WarPalette.neon,
            ),
            const SizedBox(width: 8),
            WarFilterChip(
              label: 'Liste',
              selected: !_territoryMapView,
              onTap: () => setState(() => _territoryMapView = false),
              accent: WarPalette.gold,
            ),
          ],
        ),
        if (_territoryMapView)
          TerritoryMapView(
            territories: territories,
            playerGuildId: guildId,
            onTerritoryTap: (TerritoryData t) =>
                context.push('${AppRoutes.guildWar}/territory/${t.id}'),
          )
        else if (territories.isEmpty)
          const WarEmptyTab(
            icon: '🗺',
            message: 'Henüz ele geçirilebilir bölge yok.',
          )
        else
          Column(
            children: <Widget>[
              const WarSectionHeader(
                title: 'Bölge Listesi',
                subtitle: 'Saldır veya savunma güçlendir',
                accent: WarPalette.ruby,
              ),
              for (final TerritoryData t in territories)
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
