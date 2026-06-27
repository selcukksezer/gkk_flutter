import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../l10n/l10n.dart';
import '../../models/guild_war_model.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/guild_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import 'guild_war_defense_sheet.dart';
import 'widgets/guild_war_design.dart';
import 'widgets/guild_war_season_header.dart';
import 'widgets/guild_war_skeleton.dart';
import 'widgets/guild_war_tab_bar.dart';
import 'widgets/kingdom_election_panel.dart';
import 'widgets/ranking_podium.dart';
import 'widgets/territory_card.dart';
import 'widgets/territory_map_view.dart';
import 'widgets/tournament_card.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

class GuildWarHubScreen extends ConsumerStatefulWidget {
  const GuildWarHubScreen({super.key});

  @override
  ConsumerState<GuildWarHubScreen> createState() => _GuildWarHubScreenState();
}

class _GuildWarHubScreenState extends ConsumerState<GuildWarHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _territoryMapView = true;

  static const List<String> _tabLabels = <String>['Sıralama', 'Turnuva', 'Bölge', 'Krallık'];
  static const List<String> _tabIcons = <String>['🏅', '🏆', '🗺', '👑'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(guildProvider.notifier).loadGuild();
      ref.read(guildWarProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(guildWarProvider.notifier).loadAll();
  }

  int? _myRank(List<GuildWarRanking> rankings, String? guildName) {
    if (guildName == null) return null;
    for (final GuildWarRanking r in rankings) {
      if (r.guildName == guildName) return r.rank;
    }
    return null;
  }

  int? _myPoints(List<GuildWarRanking> rankings, String? guildName) {
    if (guildName == null) return null;
    for (final GuildWarRanking r in rankings) {
      if (r.guildName == guildName) return r.points;
    }
    return null;
  }

  Future<void> _joinTournament(String id) async {
    final String? error = await ref.read(guildWarProvider.notifier).joinTournament(id);
    if (!mounted) return;
    if (error != null) {
      AppMessenger.showError(context, error);
    } else {
      AppMessenger.showSuccess(context, 'Turnuvaya kaydoldun!');
    }
  }

  Future<void> _attackTerritory(TerritoryData territory) async {
    final bool? confirmed = await WarDialog.confirm(
      context: context,
      title: '⚔ Bölge Saldırısı',
      message: '${territory.name} bölgesine saldırmak istediğine emin misin?',
      confirmLabel: 'Saldır',
      accent: WarPalette.ruby,
    );
    if (confirmed != true) return;

    final GuildWarAttackResult? result =
        await ref.read(guildWarProvider.notifier).attackTerritory(territory.id);
    if (!mounted || result == null) return;

    if (result.error != null) {
      AppMessenger.showError(context, result.error!);
      return;
    }

    context.push(AppRoutes.guildWarBattleResult, extra: result).then((_) => _refresh());
  }

  Future<void> _addDefense(TerritoryData territory) async {
    final int? gems = await showGuildWarDefenseSheet(context);
    if (gems == null || gems <= 0) return;

    final String? error = await ref.read(guildWarProvider.notifier).addDefense(territory.id, gems);
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
    final profile = ref.watch(playerProvider).profile;
    final guildState = ref.watch(guildProvider);
    final String? guildId = guildState.guild?.guildId ?? profile?.guildId;
    final String? guildName = guildState.guild?.name ?? profile?.guildName;

    Future<void> logout() async => performLogout(ref);

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.screenTitleGuildWar, onLogout: logout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.guildWar, onLogout: logout),
      body: WarBackdrop(
        child: warState.isLoading
            ? const GuildWarSkeleton()
            : NestedScrollView(
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) => <Widget>[
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          GuildWarSeasonHeader(
                            season: warState.season,
                            myRank: _myRank(warState.rankings, guildName),
                            myPoints: _myPoints(warState.rankings, guildName),
                            guildName: guildName,
                          ),
                          if (guildId == null) _NoGuildBanner(onFindGuild: () => context.go(AppRoutes.guild)),
                          if (warState.error != null) _ErrorBanner(message: warState.error!),
                          GuildWarTabBar(
                            controller: _tabController,
                            tabs: _tabLabels,
                            icons: _tabIcons,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.base,
                              AppSpacing.sm,
                              AppSpacing.base,
                              AppSpacing.xs,
                            ),
                            child: WarOutlineButton(
                              label: 'Savaş Kayıtları',
                              icon: Icons.history_rounded,
                              onPressed: () => context.push(AppRoutes.guildWarLogs),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _scrollTab(child: RankingPodium(rankings: warState.rankings, highlightGuildName: guildName)),
                    _scrollTab(child: _buildTournamentsList(warState.tournaments, guildId)),
                    _scrollTab(child: _buildTerritoriesContent(warState.territories, guildId)),
                    _scrollTab(child: const KingdomElectionPanel()),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _scrollTab({required Widget child}) {
    return Builder(
      builder: (BuildContext context) => RefreshIndicator(
        color: WarPalette.gold,
        backgroundColor: WarPalette.navy,
        onRefresh: _refresh,
        child: CustomScrollView(
          key: PageStorageKey<Object>(child.runtimeType),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.sm,
                AppSpacing.base,
                warBottomInset(context),
              ),
              sliver: SliverToBoxAdapter(child: child),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentsList(List<GuildWarTournament> tournaments, String? guildId) {
    if (tournaments.isEmpty) {
      return const WarEmptyTab(
        icon: '🏆',
        message: 'Aktif turnuva yok. Yeni sezon başladığında burada görünecek.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
              onJoin: guildId != null && tournaments[i].isActive
                  ? () => _joinTournament(tournaments[i].id)
                  : null,
              onDetail: () => context.push('${AppRoutes.guildWar}/tournament/${tournaments[i].id}'),
            ),
          ),
      ],
    );
  }

  Widget _buildTerritoriesContent(List<TerritoryData> territories, String? guildId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
                      onAttack: !isOwner && guildId != null ? () => _attackTerritory(t) : null,
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
          'Veri yüklenemedi. Aşağı çekerek yenile.',
          style: const TextStyle(color: WarPalette.ruby, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
