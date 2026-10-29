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
import '../../models/dungeon_siege_prime_timer.dart';
import '../../models/guild_war_model.dart';
import '../../models/player_model.dart';
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
  Timer? _secondTicker;
  bool _handledDeepLink = false;
  bool _entranceDone = false;
  String _sessionFilter = 'all'; // 'all', 'hold', 'free', 'my_guild'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh(silent: false);
      await _maybeOpenDeepLinkedPanel();
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.dungeonSiegeHub);
    });
    // Server polling every 15 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      unawaited(ref.read(dungeonSiegeProvider.notifier).loadHub(silent: true));
    });
    // Local second ticker for live prime countdown clocks
    _secondTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _secondTicker?.cancel();
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

  String _findRecommendedSiegeDungeon(DungeonSiegeStatus status, int playerLevel) {
    // If player holds a slot somewhere, recommend that dungeon
    if (status.mySlotGlobalDungeonId != null && status.mySlotGlobalDungeonId!.isNotEmpty) {
      return status.mySlotGlobalDungeonId!;
    }
    // Check if there is an active session in a zone unlocked for the player
    for (final DungeonSiegeSession s in status.sessions) {
      final DungeonZone? z = zoneDataFor(s.zoneNumber);
      if (z != null && isZoneUnlockedForLevel(z, playerLevel)) {
        return s.dungeonId;
      }
    }
    // Otherwise recommend highest unlocked capstone
    for (int zoneNum = 7; zoneNum >= 1; zoneNum--) {
      final DungeonZone? z = zoneDataFor(zoneNum);
      if (z != null && isZoneUnlockedForLevel(z, playerLevel)) {
        final String? capstone = siegeCapstoneForZone(zoneNum);
        if (capstone != null && capstone.isNotEmpty) return capstone;
      }
    }
    return 'dng_010';
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
    final int? gems = await showGuildWarDefenseSheet(
      context,
      minDefenseGems: territory?.minDefenseGems ?? 5,
      playerGems: profile?.gems,
    );
    if (gems == null || gems <= 0 || !mounted) return;

    final String? error =
        await ref.read(guildWarProvider.notifier).addDefense(territoryId, gems);
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
    final PlayerProfile? profile = ref.watch(playerProvider).profile;
    final String? myGuildId = profile?.guildId;
    final int playerLevel = profile?.level ?? 1;

    // Filter sessions
    final List<DungeonSiegeSession> allSessions = status.sessions;
    final List<DungeonSiegeSession> filteredSessions = allSessions.where((DungeonSiegeSession s) {
      switch (_sessionFilter) {
        case 'hold':
          return s.hold != null && s.hold!.holdId.isNotEmpty;
        case 'free':
          return s.slots.any((DungeonSiegeSlot slot) => !slot.isOccupied);
        case 'my_guild':
          if (myGuildId == null) return false;
          return s.slots.any((DungeonSiegeSlot slot) => slot.guildId == myGuildId) ||
              (s.hold != null && s.hold!.guildId == myGuildId);
        case 'all':
        default:
          return true;
      }
    }).toList();

    final int holdCount = allSessions.where((DungeonSiegeSession s) => s.hold != null && s.hold!.holdId.isNotEmpty).length;
    final int freeCount = allSessions.where((DungeonSiegeSession s) => s.slots.any((DungeonSiegeSlot slot) => !slot.isOccupied)).length;
    final int myGuildCount = myGuildId == null
        ? 0
        : allSessions.where((DungeonSiegeSession s) =>
            s.slots.any((DungeonSiegeSlot slot) => slot.guildId == myGuildId) ||
            (s.hold != null && s.hold!.guildId == myGuildId)).length;

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
              // Top back bar with liquid gold highlight
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
                child: Row(
                  children: <Widget>[
                    SiegePressable(
                      onTap: _goBack,
                      child: SiegeNeonCard(
                        accent: SiegePalette.gold,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: SiegePalette.gold),
                            SizedBox(width: 6),
                            Text(
                              'Zindanlara Dön',
                              style: TextStyle(
                                color: SiegePalette.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: SiegePalette.obsidian.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: SiegePalette.titanium.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.shield_outlined, size: 13, color: SiegePalette.gold),
                          const SizedBox(width: 5),
                          Text(
                            profile?.guildName != null ? 'Lonca: ${profile!.guildName}' : 'Loncasız Savaşçı',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                            // 1. Prime-Time Battle Timers & Hero Card
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

                            // Error notification banner if any
                            if (siegeState.errorMessage != null) ...<Widget>[
                              GameScrollLayout.sectionSpacer,
                              _section(
                                slideIndex++,
                                SiegeEmptyTab(icon: '⚠️', message: siegeState.errorMessage!),
                              ),
                            ],

                            // 2. Assault Preparation UI (Saldırı Hazırlığı & Savaş Odası)
                            GameScrollLayout.sectionSpacer,
                            _section(
                              slideIndex++,
                              _AssaultPreparationCard(
                                status: status,
                                profile: profile,
                                onQuickAssault: () {
                                  final String target = _findRecommendedSiegeDungeon(status, playerLevel);
                                  _openSiegePanelForDungeonId(target);
                                },
                              ),
                            ),

                            // 3. Siege Reward Multipliers (Kuşatma Ganimet & Çarpanları)
                            GameScrollLayout.sectionSpacer,
                            _section(
                              slideIndex++,
                              _SiegeMultipliersCard(config: status.config),
                            ),

                            // 4. Fortress Defense Status Overview (Bölge Kaleleri & Hâkimiyet)
                            GameScrollLayout.sectionSpacer,
                            _section(
                              slideIndex++,
                              _FortressOverviewCard(
                                territories: hub.territories,
                                myGuildId: myGuildId,
                              ),
                            ),

                            // Notifications
                            if (siegeState.notifications.isNotEmpty) ...<Widget>[
                              GameScrollLayout.sectionSpacer,
                              _section(
                                slideIndex++,
                                Row(
                                  children: <Widget>[
                                    const Expanded(
                                      child: SiegeSectionHeader(
                                        title: 'Bildirimler',
                                        subtitle: 'Kuşatma olayları & savunma raporları',
                                        accent: SiegePalette.solar,
                                      ),
                                    ),
                                    if (siegeState.unreadNotificationCount > 0)
                                      SiegeOutlineButton(
                                        label: 'Tümünü Oku',
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
                              ...siegeState.notifications.take(6).map(
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

                            // 5. Active Siege Sessions (Aktif Kuşatmalar)
                            GameScrollLayout.sectionSpacer,
                            _section(
                              slideIndex++,
                              Row(
                                children: <Widget>[
                                  const Expanded(
                                    child: SiegeSectionHeader(
                                      title: 'Aktif Kuşatmalar',
                                      subtitle: 'Prime time oturumları & slot düelloları',
                                      accent: SiegePalette.ruby,
                                    ),
                                  ),
                                  if (status.siegeActive)
                                    const SiegeStatusPill(label: 'CANLI ÇATIŞMA', color: SiegePalette.ruby, pulse: true),
                                ],
                              ),
                            ),
                            GameScrollLayout.titleSpacer,

                            // Session filter bar
                            _section(
                              slideIndex++,
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: <Widget>[
                                    _FilterChip(
                                      label: 'Tümü (${allSessions.length})',
                                      selected: _sessionFilter == 'all',
                                      accent: SiegePalette.gold,
                                      onTap: () => setState(() => _sessionFilter = 'all'),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterChip(
                                      label: 'Çekişmeli / Hold ($holdCount)',
                                      selected: _sessionFilter == 'hold',
                                      accent: SiegePalette.ruby,
                                      onTap: () => setState(() => _sessionFilter = 'hold'),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterChip(
                                      label: 'Açık Slotlar ($freeCount)',
                                      selected: _sessionFilter == 'free',
                                      accent: SiegePalette.neon,
                                      onTap: () => setState(() => _sessionFilter = 'free'),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterChip(
                                      label: 'Loncam ($myGuildCount)',
                                      selected: _sessionFilter == 'my_guild',
                                      accent: SiegePalette.fuchsia,
                                      onTap: () => setState(() => _sessionFilter = 'my_guild'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (filteredSessions.isEmpty)
                              _section(
                                slideIndex++,
                                SiegeEmptyTab(
                                  icon: '🏰',
                                  message: _sessionFilter == 'all'
                                      ? (status.siegeActive
                                          ? 'Kuşatma bossu içeren aktif oturum bulunamadı.'
                                          : 'Prime time penceresi dışında slotlar kapalıdır. Program saatlerini incele.')
                                      : 'Seçili filtreye uygun kuşatma oturumu bulunamadı.',
                                ),
                              )
                            else
                              ...filteredSessions.map(
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

                            // 6. Dungeon Zones & Fortress Citadels (Zindan Bölgeleri & Kaleler)
                            GameScrollLayout.sectionSpacer,
                            _section(
                              slideIndex++,
                              const SiegeSectionHeader(
                                title: 'Zindan Bölgeleri',
                                subtitle: 'Bölge kalesi ↔ Lonca savunması ↔ Kuşatma bossu',
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
                                final bool isOwner = link?.ownerGuildId != null &&
                                    myGuildId != null &&
                                    link!.ownerGuildId == myGuildId;

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
                                      isOwner: isOwner,
                                      onAddDefense: link?.territoryId != null &&
                                              status.siegeActive &&
                                              isOwner
                                          ? () => _addGemDefense(link!.territoryId!)
                                          : null,
                                      onTap: () {
                                        if (capstoneId.isNotEmpty) {
                                          _openSiegePanelForDungeonId(capstoneId);
                                        } else if (link?.territoryId != null && link!.territoryId!.isNotEmpty) {
                                          context.push('${AppRoutes.guildWarTerritory}/${link!.territoryId}');
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),

                            // 7. Weekly Leaderboard (Haftalık Sıralama)
                            GameScrollLayout.sectionSpacer,
                            _section(
                              slideIndex++,
                              const SiegeSectionHeader(
                                title: 'Haftalık Kuşatma Sıralaması',
                                subtitle: 'Kazanılan slot dakikaları & düello zaferleri',
                                accent: SiegePalette.neon,
                              ),
                            ),
                            GameScrollLayout.titleSpacer,
                            if (hub.leaderboard.isEmpty)
                              _section(
                                slideIndex++,
                                const SiegeEmptyTab(
                                  icon: '🏆',
                                  message: 'Bu hafta henüz sıralama puanı kaydedilmedi.',
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

                            // 8. Recent Challenges (Son Düellolar)
                            GameScrollLayout.sectionSpacer,
                            _section(
                              slideIndex++,
                              const SiegeSectionHeader(
                                title: 'Son Düellolar',
                                subtitle: 'Son 24 saatteki slot mücadeleleri',
                                accent: SiegePalette.coral,
                              ),
                            ),
                            GameScrollLayout.titleSpacer,
                            if (hub.recentChallenges.isEmpty)
                              _section(
                                slideIndex++,
                                const SiegeEmptyTab(
                                  icon: '⚔',
                                  message: 'Son 24 saatte düello gerçekleşmedi.',
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

// ---------------------------------------------------------------------------
// 1. PRIME-TIME TIMERS & HERO CARD
// ---------------------------------------------------------------------------
class _HubStatusCard extends StatelessWidget {
  const _HubStatusCard({required this.status, required this.weekKey});

  final DungeonSiegeStatus status;
  final String weekKey;

  @override
  Widget build(BuildContext context) {
    final DungeonSiegePrimeTimerSnapshot timerSnapshot = DungeonSiegePrimeSchedule.snapshot(
      windows: status.config.primeWindows,
      timezone: status.config.timezone,
      isEnabled: status.config.isEnabled,
    );

    final bool isLive = status.siegeActive;
    final Color accent = isLive ? SiegePalette.fuchsia : (status.inPrimeWindow ? SiegePalette.coral : SiegePalette.gold);

    return SiegeHeroBanner(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      accent.withValues(alpha: 0.38),
                      SiegePalette.gold.withValues(alpha: 0.16),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: accent.withValues(alpha: 0.6)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: accent.withValues(alpha: 0.30), blurRadius: 16),
                  ],
                ),
                child: Text(
                  isLive ? '🔥' : '🏰',
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Text(
                          'KUŞATMA MERKEZİ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: SiegePalette.titanium,
                            letterSpacing: 1.4,
                          ),
                        ),
                        if (weekKey.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SiegePalette.gold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: SiegePalette.gold.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              weekKey,
                              style: const TextStyle(
                                color: SiegePalette.gold,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLive
                          ? 'Prime Time Kuşatması Aktif!'
                          : (status.inPrimeWindow ? 'Prime Penceresi Açık' : 'Prime Time Bekleniyor'),
                      style: TextStyle(
                        color: isLive ? SiegePalette.neon : AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              SiegeStatusPill(
                label: isLive ? 'CANLI' : 'BEKLEMEDE',
                color: isLive ? SiegePalette.ruby : SiegePalette.titanium,
                pulse: isLive,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Glowing Countdown Timer Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.18),
                  SiegePalette.obsidian.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              boxShadow: isLive
                  ? <BoxShadow>[
                      BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 3)),
                    ]
                  : null,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  timerSnapshot.mode == DungeonSiegePrimeTimerMode.untilEnd
                      ? Icons.timer_rounded
                      : Icons.hourglass_top_rounded,
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timerSnapshot.mode == DungeonSiegePrimeTimerMode.untilEnd
                        ? 'Kuşatma Kapanışına Kalan Süre'
                        : (timerSnapshot.mode == DungeonSiegePrimeTimerMode.untilStart
                            ? 'Bir Sonraki Prime Kuşatma Başlangıcı'
                            : 'Kuşatma Takvimi Europe/Istanbul'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: SiegePalette.void_.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    timerSnapshot.isVisible
                        ? timerSnapshot.formattedRemaining
                        : (isLive ? 'Aktif' : 'Plan Dışı'),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Schedule Timetable Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              SiegeStatChip(
                emoji: '⏰',
                label: '19:00 - 21:00 (Akşam)',
                accent: SiegePalette.gold,
              ),
              SiegeStatChip(
                emoji: '🌙',
                label: '22:00 - 00:00 (Gece)',
                accent: SiegePalette.gold,
              ),
              SiegeStatChip(
                emoji: '⚔️',
                label: '${status.sessions.length} Aktif Oturum',
                accent: isLive ? SiegePalette.neon : SiegePalette.titanium,
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            isLive
                ? 'Prime time devrede! Hold bonusları, bölge savunma kalkanı ve rezerv slotlar aktif.'
                : 'Prime time dışında slot kazanımı kapalıdır. Lonca kalesini güçlendir ve saldırıya hazırlan.',
            style: const TextStyle(color: SiegePalette.titanium, fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. ASSAULT PREPARATION UI (Saldırı Hazırlığı & Savaş Odası)
// ---------------------------------------------------------------------------
class _AssaultPreparationCard extends StatelessWidget {
  const _AssaultPreparationCard({
    required this.status,
    required this.profile,
    required this.onQuickAssault,
  });

  final DungeonSiegeStatus status;
  final PlayerProfile? profile;
  final VoidCallback onQuickAssault;

  @override
  Widget build(BuildContext context) {
    final int playerPower = profile?.power ?? 0;
    final int playerGold = profile?.gold ?? 0;
    final int cost = status.config.challengeGoldCost;
    final bool canAfford = playerGold >= cost;
    final bool isShadow = profile?.characterClass == CharacterClass.shadow;
    final bool holdsSlot = status.holdsSlotElsewhere || (status.mySlotGlobalDungeonId != null && status.mySlotGlobalDungeonId!.isNotEmpty);

    return SiegeNeonCard(
      accent: SiegePalette.coral,
      glow: true,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: SiegePalette.coral.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SiegePalette.coral.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.flash_on_rounded, color: SiegePalette.coral, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'SALDIRI ODASI & HAZIRLIK',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Kuşatma savaşçısı hazır bulunuşluk durumu',
                      style: TextStyle(fontSize: 10.5, color: SiegePalette.titanium),
                    ),
                  ],
                ),
              ),
              if (holdsSlot)
                const SiegeStatusPill(label: 'SLOT SENDE', color: SiegePalette.neon)
              else if (status.isBanned)
                const SiegeStatusPill(label: 'BAN CEZASI', color: SiegePalette.ruby)
              else
                const SiegeStatusPill(label: 'HAZIR', color: SiegePalette.gold),
            ],
          ),

          const SizedBox(height: 12),

          // Readiness Grid
          Row(
            children: <Widget>[
              // Player Combat Power
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SiegePalette.void_.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SiegePalette.titanium.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'SAVAS GUCUN',
                        style: TextStyle(color: SiegePalette.titanium, fontSize: 9.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$playerPower',
                        style: const TextStyle(
                          color: SiegePalette.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (isShadow)
                        const Text(
                          '🗡️ +%15 Gölge Bonusu',
                          style: TextStyle(color: SiegePalette.fuchsia, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Challenge Cost Check
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SiegePalette.void_.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: canAfford
                          ? SiegePalette.neon.withValues(alpha: 0.3)
                          : SiegePalette.ruby.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'DUELLO BEDELI',
                        style: TextStyle(color: SiegePalette.titanium, fontSize: 9.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(cost / 1000).round()}k Altın',
                        style: TextStyle(
                          color: canAfford ? SiegePalette.neon : SiegePalette.ruby,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        canAfford ? '✓ Yeterli bakiye' : '✗ Bakiye yetersiz',
                        style: TextStyle(
                          color: canAfford ? SiegePalette.neon : SiegePalette.ruby,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Tactical Launch Button
          SiegePressable(
            onTap: onQuickAssault,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[SiegePalette.ruby, SiegePalette.coral],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: SiegePalette.ruby.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.colorize_rounded, size: 16, color: AppColors.textPrimary),
                  const SizedBox(width: 8),
                  Text(
                    holdsSlot ? 'Kuşatma Slotunu Yönet' : 'Kuşatma Zindanına Hücum Et',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. SIEGE REWARD MULTIPLIERS (Kuşatma Ganimet & Çarpanları)
// ---------------------------------------------------------------------------
class _SiegeMultipliersCard extends StatelessWidget {
  const _SiegeMultipliersCard({required this.config});

  final DungeonSiegeConfig config;

  @override
  Widget build(BuildContext context) {
    final int lootPct = (config.lootBonusPct * 100).round();
    final int goldPct = (config.goldBonusPct * 100).round();
    final int holdExtra = (config.holdBonusPct * 100).round();
    final int repRun = DungeonSiegeConfig.repPerRun(config);

    return SiegeNeonCard(
      accent: SiegePalette.gold,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: SiegePalette.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: SiegePalette.gold, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'KUŞATMA GANİMET & ÖDÜL ÇARPANLARI',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SiegeTag(label: 'ÇARPANLAR', accent: SiegePalette.gold, compact: true),
            ],
          ),

          const SizedBox(height: 12),

          // 4-Quadrant Multipliers
          Row(
            children: <Widget>[
              // Loot Multiplier
              Expanded(
                child: _MultiplierBox(
                  icon: '🎁',
                  title: 'Nadir Eşya / Loot',
                  value: '+$lootPct%',
                  sub: 'Hold ile +${lootPct + holdExtra}%',
                  accent: SiegePalette.neon,
                ),
              ),
              const SizedBox(width: 8),
              // Gold Multiplier
              Expanded(
                child: _MultiplierBox(
                  icon: '💰',
                  title: 'Altın Kazanımı',
                  value: '+$goldPct%',
                  sub: 'Hold ile +${goldPct + holdExtra}%',
                  accent: SiegePalette.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              // Lonca İtibarı
              Expanded(
                child: _MultiplierBox(
                  icon: '🏆',
                  title: 'Lonca İtibarı',
                  value: '+$repRun Puan',
                  sub: 'Koşu başına kazanım',
                  accent: SiegePalette.fuchsia,
                ),
              ),
              const SizedBox(width: 8),
              // Citadel Defense Shield
              Expanded(
                child: _MultiplierBox(
                  icon: '🛡️',
                  title: 'Kale Kalkanı',
                  value: '+%25 Max',
                  sub: 'Bölge sahibi loncaya',
                  accent: SiegePalette.solar,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SiegePalette.void_.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SiegePalette.titanium.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.info_outline_rounded, size: 14, color: SiegePalette.titanium),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Kuşatma slotu kazanan savaşçılar zindanı temizlediklerinde bu bonusları otomatik toplar. Loncanız 3+ slot tutarsa Hold Bonusu devreye girer.',
                    style: TextStyle(color: SiegePalette.titanium.withValues(alpha: 0.9), fontSize: 10, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiplierBox extends StatelessWidget {
  const _MultiplierBox({
    required this.icon,
    required this.title,
    required this.value,
    required this.sub,
    required this.accent,
  });

  final String icon;
  final String title;
  final String value;
  final String sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SiegePalette.navy.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SiegePalette.titanium, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: SiegePalette.titanium.withValues(alpha: 0.7), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. FORTRESS DEFENSE STATUS OVERVIEW (Bölge Kaleleri & Hâkimiyet)
// ---------------------------------------------------------------------------
class _FortressOverviewCard extends StatelessWidget {
  const _FortressOverviewCard({
    required this.territories,
    this.myGuildId,
  });

  final List<DungeonSiegeTerritoryLink> territories;
  final String? myGuildId;

  @override
  Widget build(BuildContext context) {
    int totalDefensePower = 0;
    int myGuildOwned = 0;
    int claimedFortresses = 0;

    for (final DungeonSiegeTerritoryLink t in territories) {
      totalDefensePower += t.defensePower;
      if (t.ownerGuildId != null && t.ownerGuildId!.isNotEmpty) {
        claimedFortresses++;
        if (myGuildId != null && t.ownerGuildId == myGuildId) {
          myGuildOwned++;
        }
      }
    }

    return SiegeNeonCard(
      accent: SiegePalette.neon,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: SiegePalette.neon.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.castle_rounded, color: SiegePalette.neon, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'KALE SAVUNMA STATÜSÜ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      '7 Bölge kalesinin garnizon güç dengesi',
                      style: TextStyle(fontSize: 10, color: SiegePalette.titanium),
                    ),
                  ],
                ),
              ),
              SiegeTag(label: '7 BÖLGE', accent: SiegePalette.neon, compact: true),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: <Widget>[
              Expanded(
                child: _FortressStat(
                  label: 'Loncanızın',
                  value: '$myGuildOwned Kale',
                  color: myGuildOwned > 0 ? SiegePalette.neon : SiegePalette.titanium,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FortressStat(
                  label: 'Zaptedilen',
                  value: '$claimedFortresses/7 Kale',
                  color: SiegePalette.gold,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _FortressStat(
                  label: 'Toplam Güç',
                  value: '$totalDefensePower',
                  color: SiegePalette.coral,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FortressStat extends StatelessWidget {
  const _FortressStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: SiegePalette.void_.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: SiegePalette.titanium, fontSize: 9.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. SESSION CARD (Aktif Kuşatma Oturumu)
// ---------------------------------------------------------------------------
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
    final int totalSlots = session.slots.length;
    final DungeonSiegeHold? hold = session.hold;
    final bool hasHold = hold != null && hold.holdId.isNotEmpty;
    final Color accent = hasHold ? SiegePalette.ruby : SiegePalette.fuchsia;
    final bool receivesDefenseBonus = session.receivesTerritoryDefenseBonus(myGuildId);

    return SiegeNeonCard(
      accent: accent,
      glow: hasHold,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            children: <Widget>[
              SiegeTag(label: 'BÖLGE ${session.zoneNumber}', accent: SiegePalette.gold, compact: true),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dungeonName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              SiegeStatChip(
                emoji: '👥',
                label: '$occupied/$totalSlots Slot',
                accent: occupied >= totalSlots ? SiegePalette.ruby : SiegePalette.neon,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: SiegePalette.titanium, size: 20),
            ],
          ),

          const SizedBox(height: 8),

          // Visual Slot Occupancy Indicator
          Row(
            children: List<Widget>.generate(totalSlots, (int idx) {
              final bool isSlotOccupied = idx < session.slots.length && session.slots[idx].isOccupied;
              final bool isMySlot = idx < session.slots.length && session.slots[idx].isMine;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: idx < totalSlots - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isMySlot
                        ? SiegePalette.gold
                        : (isSlotOccupied ? SiegePalette.ruby : SiegePalette.navy.withValues(alpha: 0.8)),
                    boxShadow: isMySlot || isSlotOccupied
                        ? <BoxShadow>[
                            BoxShadow(
                              color: (isMySlot ? SiegePalette.gold : SiegePalette.ruby).withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),

          // Territory Defense & Citadel Bonuses
          if (session.territoryDefensePower > 0) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (receivesDefenseBonus ? SiegePalette.neon : SiegePalette.gold).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (receivesDefenseBonus ? SiegePalette.neon : SiegePalette.gold).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.shield_rounded,
                    size: 13,
                    color: receivesDefenseBonus ? SiegePalette.neon : SiegePalette.gold,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      receivesDefenseBonus
                          ? 'Loncanız +${session.territoryDefenseSiegeBonusPercent}% Slot Savunma Bonusu Alıyor'
                          : (session.territoryOwnerGuildName != null
                              ? 'Owner [${session.territoryOwnerGuildName}] +${session.territoryDefenseMaxBonusPercent}% Savunma Gücü'
                              : 'Bölge Savunması: ${session.territoryDefensePower} Güç'),
                      style: TextStyle(
                        color: receivesDefenseBonus ? SiegePalette.neon : SiegePalette.gold,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Active Hold Alert Banner
          if (hasHold) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SiegePalette.ruby.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SiegePalette.ruby.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.warning_amber_rounded, size: 14, color: SiegePalette.ruby),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'HOLD: ${hold.guildName ?? 'Lonca'} · Kırılma İlerlemesi: ${hold.breakProgress}/${hold.breakRequired}',
                      style: const TextStyle(
                        color: SiegePalette.ruby,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
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
}

// ---------------------------------------------------------------------------
// 6. TERRITORY ROW (Bölge Kalesi & Kuşatma Bossu)
// ---------------------------------------------------------------------------
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
    final String owner = link?.ownerGuildName ?? 'Sahipsiz Kale';
    final int defensePower = link?.defensePower ?? 0;
    final int gemBoost = link?.gemDefenseBoost ?? 0;
    final double defenseRatio = (defensePower / 4000.0).clamp(0.0, 1.0);

    String rating = 'C-Kademe';
    Color ratingColor = SiegePalette.titanium;
    if (defensePower >= 3000) {
      rating = 'S-Kademe';
      ratingColor = SiegePalette.gold;
    } else if (defensePower >= 2000) {
      rating = 'A-Kademe';
      ratingColor = SiegePalette.coral;
    } else if (defensePower >= 1000) {
      rating = 'B-Kademe';
      ratingColor = SiegePalette.neon;
    }

    return SiegeNeonCard(
      accent: zone.color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Top row: Zone Banner + Rating + Owner
          Row(
            children: <Widget>[
              // Glowing heraldic crest
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      zone.color.withValues(alpha: 0.35),
                      SiegePalette.navy,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: zone.color.withValues(alpha: 0.6)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: zone.color.withValues(alpha: 0.22), blurRadius: 8),
                  ],
                ),
                child: Icon(zone.icon, size: 18, color: zone.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'BÖLGE ${zone.number} · ${zone.name}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: ratingColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: ratingColor.withValues(alpha: 0.45)),
                          ),
                          child: Text(
                            rating,
                            style: TextStyle(color: ratingColor, fontSize: 8.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hâkimiyet: $owner · Kuşatma: $dungeonName',
                      style: const TextStyle(color: SiegePalette.titanium, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (onAddDefense != null) ...<Widget>[
                SiegePressable(
                  onTap: onAddDefense,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SiegePalette.neon.withValues(alpha: 0.55)),
                      gradient: LinearGradient(
                        colors: <Color>[
                          SiegePalette.neon.withValues(alpha: 0.22),
                          SiegePalette.navy,
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: SiegePalette.neon.withValues(alpha: 0.25), blurRadius: 8),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('💎', style: TextStyle(fontSize: 11)),
                        SizedBox(width: 4),
                        Text(
                          'Savun',
                          style: TextStyle(color: SiegePalette.neon, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (isOwner && !siegeActive) ...<Widget>[
                const SiegeStatChip(emoji: '⏳', label: 'Prime Bekle', accent: SiegePalette.titanium),
              ] else ...<Widget>[
                const Icon(Icons.chevron_right_rounded, color: SiegePalette.titanium, size: 20),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Defense Progress Bar
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: defenseRatio,
                    minHeight: 5,
                    backgroundColor: SiegePalette.obsidian,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      defenseRatio > 0.65
                          ? SiegePalette.neon
                          : (defenseRatio > 0.3 ? SiegePalette.gold : SiegePalette.coral),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '🛡️ $defensePower / 4000',
                style: const TextStyle(
                  color: SiegePalette.titanium,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (gemBoost > 0) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  '💎+$gemBoost',
                  style: const TextStyle(color: SiegePalette.neon, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. FILTER CHIP
// ---------------------------------------------------------------------------
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = SiegePalette.gold,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SiegePressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? accent.withValues(alpha: 0.22) : SiegePalette.obsidian.withValues(alpha: 0.5),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.7) : SiegePalette.titanium.withValues(alpha: 0.2),
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 8),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : SiegePalette.titanium,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. NOTIFICATION TILE
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// 9. LEADERBOARD ROW
// ---------------------------------------------------------------------------
class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final DungeonSiegeLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final bool isTop3 = entry.rank <= 3;
    final Color rankColor = entry.rank == 1
        ? SiegePalette.gold
        : (entry.rank == 2 ? SiegePalette.fuchsia : (entry.rank == 3 ? SiegePalette.neon : SiegePalette.titanium));

    return SiegeNeonCard(
      accent: rankColor,
      glow: isTop3,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Text(
              entry.rank == 1 ? '👑 #1' : (entry.rank == 2 ? '⭐ #2' : (entry.rank == 3 ? '🗡️ #3' : '#${entry.rank}')),
              style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.playerName,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                if (entry.guildName != null && entry.guildName!.isNotEmpty)
                  Text(
                    entry.guildName!,
                    style: const TextStyle(color: SiegePalette.titanium, fontSize: 10),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${entry.points} Puan',
                style: const TextStyle(color: SiegePalette.neon, fontWeight: FontWeight.w900, fontSize: 12),
              ),
              Text(
                '${entry.slotMinutes} dk · ${entry.challengesWon} Zafer',
                style: TextStyle(color: SiegePalette.titanium.withValues(alpha: 0.8), fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 10. RECENT CHALLENGE ROW
// ---------------------------------------------------------------------------
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
          Text(challenge.youWereInvolved ? '⚔️' : '🗡️', style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${challenge.challengerName} vs ${challenge.defenderName}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Zindan: ${challenge.dungeonId}',
                  style: TextStyle(color: SiegePalette.titanium.withValues(alpha: 0.7), fontSize: 9.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (challenge.youWereInvolved ? SiegePalette.gold : SiegePalette.neon).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (challenge.youWereInvolved ? SiegePalette.gold : SiegePalette.neon).withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              '🏆 ${challenge.winnerName}',
              style: TextStyle(
                color: challenge.youWereInvolved ? SiegePalette.gold : SiegePalette.neon,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
