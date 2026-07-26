import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/services/supabase_service.dart';
import '../../models/dungeon_model.dart';
import '../../models/dungeon_siege_model.dart';
import '../../models/guild_war_model.dart';
import '../../providers/dungeon_provider.dart';
import '../../providers/dungeon_siege_provider.dart';
import '../../providers/guild_war_provider.dart';
import '../../providers/player_provider.dart';
import '../guild_war/guild_war_defense_sheet.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import 'dungeon_zone_data.dart';
import 'widgets/dungeon_siege_design.dart';
import 'widgets/dungeon_siege_panel.dart';

class DungeonSiegeHubScreen extends ConsumerStatefulWidget {
  const DungeonSiegeHubScreen({super.key});

  @override
  ConsumerState<DungeonSiegeHubScreen> createState() => _DungeonSiegeHubScreenState();
}

class _DungeonSiegeHubScreenState extends ConsumerState<DungeonSiegeHubScreen> {
  Timer? _pollTimer;
  bool _handledDeepLink = false;
  bool _entranceDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh(silent: false);
      await _maybeOpenDeepLinkedPanel();
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.dungeonSiegeHub);
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      unawaited(ref.read(dungeonSiegeProvider.notifier).loadHub(silent: true));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.dungeon);
    }
  }

  Future<void> _refresh({bool silent = true}) async {
    if (!silent) {
      await ref.read(dungeonProvider.notifier).loadDungeons();
    }
    await ref.read(dungeonSiegeProvider.notifier).loadHub(silent: silent);
    if (mounted && !_entranceDone && ref.read(dungeonSiegeProvider).hub != null) {
      setState(() => _entranceDone = true);
    }
  }

  Widget _section(int index, Widget child) {
    if (_entranceDone) return child;
    return SiegeFadeSlide(index: index, child: child);
  }

  Future<void> _maybeOpenDeepLinkedPanel() async {
    if (_handledDeepLink || !mounted) return;
    final String? dungeonId = GoRouterState.of(context).uri.queryParameters['dungeon_id'];
    if (dungeonId == null || dungeonId.isEmpty) return;
    _handledDeepLink = true;
    await _openSiegePanelForDungeonId(dungeonId);
  }

  Future<void> _openSiegePanelForDungeonId(String dungeonId) async {
    if (!mounted) return;

    await ref.read(dungeonProvider.notifier).loadDungeons();

    List<DungeonData> dungeons = ref.read(dungeonProvider).dungeons;
    DungeonData? dungeon;
    for (final DungeonData d in dungeons) {
      if (d.dungeonId == dungeonId) {
        dungeon = d;
        break;
      }
    }

    if (dungeon == null) {
      try {
        final dynamic raw = await SupabaseService.client.rpc(
          'get_dungeon_by_id',
          params: <String, dynamic>{'p_dungeon_id': dungeonId},
        );
        if (raw is Map && raw['success'] == true && raw['dungeon'] is Map) {
          dungeon = DungeonData.fromJson(
            Map<String, dynamic>.from(raw['dungeon'] as Map),
          );
        }
      } catch (_) {
        // fall through to capstone fallback
      }
    }

    if (dungeon == null) {
      final DungeonSiegeHub hub = ref.read(dungeonSiegeProvider).hub ?? DungeonSiegeHub.empty();
      for (final DungeonSiegeTerritoryLink link in hub.territories) {
        if (link.siegeDungeonId == dungeonId) {
          final String? capstone = siegeCapstoneForZone(link.zoneNumber);
          if (capstone != null && capstone != dungeonId) {
            return _openSiegePanelForDungeonId(capstone);
          }
        }
      }
    }

    if (dungeon == null && !mounted) return;
    if (dungeon == null) {
      AppMessenger.show(context, 'Zindan bulunamadı: $dungeonId');
      return;
    }
    if (!mounted) return;
    await showDungeonSiegePanel(context: context, ref: ref, dungeon: dungeon);
  }

  String _dungeonName(String dungeonId) {
    for (final DungeonData d in ref.watch(dungeonProvider).dungeons) {
      if (d.dungeonId == dungeonId) return d.name;
    }
    return dungeonId.toUpperCase();
  }

  Future<void> _addGemDefense(String territoryId) async {
    final profile = ref.read(playerProvider).profile;
    final territories = ref.read(guildWarProvider).territories;
    TerritoryData? territory;
    for (final TerritoryData t in territories) {
      if (t.id == territoryId) {
        territory = t;
        break;
      }
    }
    final GuildWarDefenseRequest? req = await showGuildWarDefenseSheet(
      context,
      minDefenseGems: territory?.minDefenseGems ?? 5,
      vaultGold: territory?.vaultSummary?.vaultGold,
      playerGems: profile?.gems,
    );
    if (req == null || req.amount <= 0 || !mounted) return;

    final String? error = req.mode == GuildWarDefenseMode.gems
        ? await ref.read(guildWarProvider.notifier).addDefense(territoryId, req.amount)
        : await ref.read(guildWarProvider.notifier).addDefenseGold(territoryId, req.amount);
    if (!mounted) return;
    if (error != null) {
      AppMessenger.showError(context, error);
    } else {
      AppMessenger.showSuccess(context, '💎 Prime savunma eklendi!');
      await _refresh(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DungeonSiegeState siegeState = ref.watch(dungeonSiegeProvider);
    final DungeonSiegeHub hub = siegeState.hub ?? DungeonSiegeHub.empty();
    final DungeonSiegeStatus status = hub.status;
    final String? myGuildId = ref.watch(playerProvider).profile?.guildId;
    int slideIndex = 0;

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.carbonVoid,
        appBar: GameTopBar(
          title: 'Kuşatma Merkezi',
          onLogout: () async => performLogout(ref),
        ),
        extendBody: true,
        bottomNavigationBar: GameBottomBar(
          currentRoute: AppRoutes.dungeonSiegeHub,
          onLogout: () async => performLogout(ref),
        ),
        body: SiegeBackdrop(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
                child: SiegePressable(
                  onTap: _goBack,
                  child: SiegeNeonCard(
                    accent: SiegePalette.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: SiegePalette.gold),
                        SizedBox(width: 6),
                        Text(
                          'Geri',
                          style: TextStyle(
                            color: SiegePalette.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: SiegePalette.gold,
                  backgroundColor: SiegePalette.navy,
                  onRefresh: () => _refresh(silent: siegeState.hub != null),
                  child: siegeState.hubLoading && siegeState.hub == null
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: SiegePalette.gold),
                        )
                      : ListView(
                          padding: GameScrollLayout.padding(context, top: AppSpacing.sm),
                          children: <Widget>[
                            _section(
                              slideIndex++,
                              TutorialAnchorScope(
                                id: TutorialAnchorId.siegeHubPanel,
                                child: _HubStatusCard(
                                  status: status,
                                  weekKey: hub.weekKey,
                                ),
                              ),
                            ),
                    if (siegeState.errorMessage != null) ...<Widget>[
                      GameScrollLayout.sectionSpacer,
                      _section(
                        slideIndex++,
                        SiegeEmptyTab(icon: '⚠️', message: siegeState.errorMessage!),
                      ),
                    ],
                    if (siegeState.notifications.isNotEmpty) ...<Widget>[
                      GameScrollLayout.sectionSpacer,
                      _section(
                        slideIndex++,
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: SiegeSectionHeader(
                                title: 'Bildirimler',
                                subtitle: 'Kuşatma olayları',
                                accent: SiegePalette.solar,
                              ),
                            ),
                            if (siegeState.unreadNotificationCount > 0)
                              SiegeOutlineButton(
                                label: 'Okundu',
                                expand: false,
                                accent: SiegePalette.gold,
                                icon: Icons.done_all_rounded,
                                onPressed: () async {
                                  await ref.read(dungeonSiegeProvider.notifier).markAllNotificationsRead();
                                },
                              ),
                          ],
                        ),
                      ),
                      GameScrollLayout.titleSpacer,
                      ...siegeState.notifications.take(8).map(
                            (DungeonSiegeNotification n) => Padding(
                              key: ValueKey<String>('notif-${n.id}'),
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _section(
                                slideIndex++,
                                _NotificationTile(
                                  notification: n,
                                  onTap: () async {
                                    await ref.read(dungeonSiegeProvider.notifier).markNotificationRead(n.id);
                                    final String? dungeonId = n.dungeonIdFromPayload;
                                    if (dungeonId != null && dungeonId.isNotEmpty && mounted) {
                                      await _openSiegePanelForDungeonId(dungeonId);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                    ],
                    GameScrollLayout.sectionSpacer,
                    _section(
                      slideIndex++,
                      const SiegeSectionHeader(
                        title: 'Aktif Kuşatmalar',
                        subtitle: 'Prime time oturumları',
                        accent: SiegePalette.ruby,
                      ),
                    ),
                    GameScrollLayout.titleSpacer,
                    if (status.sessions.isEmpty)
                      _section(
                        slideIndex++,
                        const SiegeEmptyTab(
                          icon: '🏰',
                          message: 'Prime time\'da oturumlar burada görünür.',
                        ),
                      )
                    else
                      ...status.sessions.map(
                        (DungeonSiegeSession session) => Padding(
                          key: ValueKey<String>('session-${session.sessionId}'),
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _section(
                            slideIndex++,
                            _SessionCard(
                              session: session,
                              myGuildId: myGuildId,
                              dungeonName: _dungeonName(session.dungeonId),
                              onTap: () => _openSiegePanelForDungeonId(session.dungeonId),
                            ),
                          ),
                        ),
                      ),
                    GameScrollLayout.sectionSpacer,
                    _section(
                      slideIndex++,
                      const SiegeSectionHeader(
                        title: 'Zindan Bölgeleri',
                        subtitle: 'Zindan sekmeleri ↔ kuşatma ↔ lonca savaşı',
                        accent: SiegePalette.gold,
                      ),
                    ),
                    GameScrollLayout.titleSpacer,
                    ...kDungeonZones.map(
                        (DungeonZone zone) {
                          DungeonSiegeTerritoryLink? link;
                          for (final DungeonSiegeTerritoryLink t in hub.territories) {
                            if (t.zoneNumber == zone.number) {
                              link = t;
                              break;
                            }
                          }
                          final String capstoneId =
                              link?.siegeDungeonId ?? siegeCapstoneForZone(zone.number) ?? '';
                          return Padding(
                            key: ValueKey<String>('siege-zone-${zone.number}'),
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _section(
                              slideIndex++,
                              _TerritoryRow(
                                zone: zone,
                                link: link,
                                capstoneId: capstoneId,
                                dungeonName: _dungeonName(capstoneId),
                                siegeActive: status.siegeActive,
                                isOwner: link?.ownerGuildId != null &&
                                    myGuildId != null &&
                                    link!.ownerGuildId == myGuildId,
                                onAddDefense: link?.territoryId != null &&
                                        status.siegeActive &&
                                        link?.ownerGuildId != null &&
                                        myGuildId != null &&
                                        link!.ownerGuildId == myGuildId
                                    ? () => _addGemDefense(link!.territoryId!)
                                    : null,
                                onTap: link?.territoryId != null && link!.territoryId!.isNotEmpty
                                    ? () => context.push('${AppRoutes.guildWarTerritory}/${link!.territoryId}')
                                    : capstoneId.isNotEmpty
                                        ? () => _openSiegePanelForDungeonId(capstoneId)
                                        : null,
                              ),
                            ),
                          );
                        },
                      ),
                    GameScrollLayout.sectionSpacer,
                    _section(
                      slideIndex++,
                      const SiegeSectionHeader(
                        title: 'Haftalık Sıralama',
                        subtitle: 'Slot + meydan okuma puanı',
                        accent: SiegePalette.neon,
                      ),
                    ),
                    GameScrollLayout.titleSpacer,
                    if (hub.leaderboard.isEmpty)
                      _section(
                        slideIndex++,
                        const SiegeEmptyTab(
                          icon: '🏆',
                          message: 'Bu hafta henüz puan yok.',
                        ),
                      )
                    else
                      ...hub.leaderboard.take(10).map(
                            (DungeonSiegeLeaderboardEntry entry) => Padding(
                              key: ValueKey<String>('lb-${entry.rank}-${entry.playerId ?? entry.playerName}'),
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _section(
                                slideIndex++,
                                _LeaderboardRow(entry: entry),
                              ),
                            ),
                          ),
                    GameScrollLayout.sectionSpacer,
                    _section(
                      slideIndex++,
                      const SiegeSectionHeader(
                        title: 'Son Düellolar',
                        subtitle: 'Son 24 saat',
                        accent: SiegePalette.coral,
                      ),
                    ),
                    GameScrollLayout.titleSpacer,
                    if (hub.recentChallenges.isEmpty)
                      _section(
                        slideIndex++,
                        const SiegeEmptyTab(
                          icon: '⚔',
                          message: 'Henüz meydan okuma yok.',
                        ),
                      )
                    else
                      ...hub.recentChallenges.take(12).map(
                            (DungeonSiegeRecentChallenge row) => Padding(
                              key: ValueKey<String>('challenge-${row.id}'),
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _section(
                                slideIndex++,
                                _ChallengeRow(challenge: row),
                              ),
                            ),
                          ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final DungeonSiegeNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = notification.isUnread ? SiegePalette.solar : SiegePalette.titanium;
    return SiegeNeonCard(
      accent: accent,
      glow: notification.isUnread,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: notification.isUnread ? SiegePalette.solar : SiegePalette.titanium.withValues(alpha: 0.4),
              boxShadow: notification.isUnread
                  ? <BoxShadow>[BoxShadow(color: SiegePalette.solar.withValues(alpha: 0.5), blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  notification.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notification.body,
                  style: const TextStyle(color: SiegePalette.titanium, fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.7), size: 18),
        ],
      ),
    );
  }
}

class _HubStatusCard extends StatelessWidget {
  const _HubStatusCard({required this.status, required this.weekKey});

  final DungeonSiegeStatus status;
  final String weekKey;

  @override
  Widget build(BuildContext context) {
    final Color accent = status.siegeActive ? SiegePalette.neon : SiegePalette.titanium;
    return SiegeHeroBanner(
      accent: status.siegeActive ? SiegePalette.fuchsia : SiegePalette.ruby,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      SiegePalette.fuchsia.withValues(alpha: 0.35),
                      SiegePalette.gold.withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SiegePalette.fuchsia.withValues(alpha: 0.5)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: SiegePalette.fuchsia.withValues(alpha: 0.22), blurRadius: 14),
                  ],
                ),
                child: const Text('🏰', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'KUŞATMA MERKEZİ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: SiegePalette.titanium,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      status.siegeActive ? 'Prime Time Aktif' : 'Prime Time Kapalı',
                      style: TextStyle(
                        color: accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (weekKey.isNotEmpty)
                SiegeStatusPill(label: weekKey, color: SiegePalette.gold),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              SiegeStatChip(
                emoji: status.siegeActive ? '⚡' : (status.inPrimeWindow ? '🔥' : '🌙'),
                label: status.siegeActive
                    ? 'Kuşatma aktif'
                    : (status.inPrimeWindow ? 'Prime time' : 'Prime dışı'),
                accent: status.siegeActive ? SiegePalette.neon : SiegePalette.titanium,
              ),
              SiegeStatChip(
                emoji: '🎯',
                label: '${status.sessions.length} oturum',
                accent: SiegePalette.gold,
              ),
              if (status.inPrimeWindow)
                const SiegeStatChip(emoji: '🔥', label: 'Prime penceresi', accent: SiegePalette.coral),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status.siegeActive
                ? 'Hold bonusları + bölge rezerv slotları şu an devrede.'
                : status.inPrimeWindow
                    ? 'Prime time penceresindesin — oturumlar kısa sürede açılır.'
                    : 'Prime time dışında slot ve hold kapalı; prime saatlerde tekrar dene.',
            style: const TextStyle(color: SiegePalette.titanium, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.dungeonName,
    required this.onTap,
    this.myGuildId,
  });

  final DungeonSiegeSession session;
  final String dungeonName;
  final VoidCallback onTap;
  final String? myGuildId;

  @override
  Widget build(BuildContext context) {
    final int occupied = session.slots.where((DungeonSiegeSlot s) => s.isOccupied).length;
    final DungeonSiegeHold? hold = session.hold;
    final bool hasHold = hold != null && hold.holdId.isNotEmpty;
    final Color accent = hasHold ? SiegePalette.ruby : SiegePalette.fuchsia;

    return SiegeNeonCard(
      accent: accent,
      glow: hasHold,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  dungeonName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              SiegeTag(label: 'Z${session.zoneNumber}', accent: SiegePalette.gold, compact: true),
              const SizedBox(width: 6),
              SiegeStatChip(
                emoji: '👥',
                label: '$occupied/${session.slots.length}',
                accent: SiegePalette.neon,
              ),
              const Icon(Icons.chevron_right_rounded, color: SiegePalette.titanium, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(session.dungeonId, style: TextStyle(color: SiegePalette.titanium.withValues(alpha: 0.7), fontSize: 10)),
          if (session.territoryDefensePower > 0 && session.territoryDefenseMaxBonusPercent > 0) ...<Widget>[
            const SizedBox(height: 8),
            SiegeStatChip(
              emoji: '🛡',
              label: session.receivesTerritoryDefenseBonus(myGuildId)
                  ? 'Loncan +${session.territoryDefenseSiegeBonusPercent}% slot savunma'
                  : 'Owner +${session.territoryDefenseMaxBonusPercent}% slot savunma',
              accent: session.receivesTerritoryDefenseBonus(myGuildId)
                  ? SiegePalette.neon
                  : SiegePalette.gold,
            ),
          ],
          if (session.territoryOwnerGuildName != null &&
              session.territoryOwnerGuildName!.isNotEmpty &&
              session.territoryOwnerGuildName != 'Sahipsiz') ...<Widget>[
            const SizedBox(height: 8),
            SiegeStatChip(
              emoji: '🛡',
              label: session.territoryOwnerGuildName!,
              accent: SiegePalette.gold,
            ),
          ],
          if (hasHold) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'HOLD · ${hold.guildName ?? 'Lonca'} · ${hold.breakProgress}/${hold.breakRequired}',
              style: const TextStyle(
                color: SiegePalette.ruby,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TerritoryRow extends StatelessWidget {
  const _TerritoryRow({
    required this.zone,
    required this.capstoneId,
    required this.dungeonName,
    this.link,
    this.onTap,
    this.onAddDefense,
    this.isOwner = false,
    this.siegeActive = false,
  });

  final DungeonZone zone;
  final DungeonSiegeTerritoryLink? link;
  final String capstoneId;
  final String dungeonName;
  final VoidCallback? onTap;
  final VoidCallback? onAddDefense;
  final bool isOwner;
  final bool siegeActive;

  @override
  Widget build(BuildContext context) {
    final String? warTerritory = link?.territoryName;
    final String owner = link?.ownerGuildName ?? 'Sahipsiz';
    final String defenseLine = link != null && link!.defensePower > 0
        ? ' · ${DungeonSiegeConfig.territoryDefenseSummary(link!.defensePower)}'
        : '';
    final String gemLine = link != null && link!.gemDefenseBoost > 0
        ? ' · 💎+${link!.gemDefenseBoost} prime'
        : '';
    final String subtitle = warTerritory != null && warTerritory.isNotEmpty
        ? 'Lonca: $warTerritory · $owner$defenseLine$gemLine · Kuşatma: $dungeonName'
        : 'Lonca savaşı bölgesi yok · Kuşatma: $dungeonName ($capstoneId)';

    return SiegeNeonCard(
      accent: zone.color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  zone.color.withValues(alpha: 0.28),
                  SiegePalette.navy,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: zone.color.withValues(alpha: 0.5)),
            ),
            child: Icon(zone.icon, size: 16, color: zone.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Bölge ${zone.number} · ${zone.name}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: SiegePalette.titanium, fontSize: 10),
                ),
              ],
            ),
          ),
          if (onAddDefense != null) ...<Widget>[
            const SizedBox(width: 8),
            SiegePressable(
              onTap: onAddDefense,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SiegePalette.neon.withValues(alpha: 0.45)),
                  color: SiegePalette.neon.withValues(alpha: 0.12),
                ),
                child: const Text(
                  '💎 Savun',
                  style: TextStyle(color: SiegePalette.neon, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ] else if (isOwner && !siegeActive) ...<Widget>[
            const SizedBox(width: 8),
            const SiegeStatChip(emoji: '⏳', label: 'Prime bekle', accent: SiegePalette.titanium),
          ],
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: SiegePalette.titanium, size: 18),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final DungeonSiegeLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color rankColor = entry.rank <= 3 ? SiegePalette.gold : SiegePalette.titanium;
    return SiegeNeonCard(
      accent: rankColor,
      glow: entry.rank <= 3,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.playerName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                if (entry.guildName != null)
                  Text(entry.guildName!, style: const TextStyle(color: SiegePalette.titanium, fontSize: 10)),
              ],
            ),
          ),
          Text(
            '${entry.points}p · ${entry.slotMinutes}dk',
            style: const TextStyle(color: SiegePalette.neon, fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({required this.challenge});

  final DungeonSiegeRecentChallenge challenge;

  @override
  Widget build(BuildContext context) {
    return SiegeNeonCard(
      accent: challenge.youWereInvolved ? SiegePalette.fuchsia : SiegePalette.obsidian,
      glow: challenge.youWereInvolved,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          Text(challenge.youWereInvolved ? '⚔' : '🗡', style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${challenge.challengerName} vs ${challenge.defenderName}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            challenge.winnerName,
            style: TextStyle(
              color: challenge.youWereInvolved ? SiegePalette.gold : SiegePalette.titanium,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
