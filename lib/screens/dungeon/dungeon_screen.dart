import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/utils/effective_luck.dart';
import '../../core/utils/power_formula.dart';
import '../../models/dungeon_model.dart';
import '../../models/dungeon_siege_model.dart';
import '../../models/dungeon_siege_prime_timer.dart';
import '../../utils/logout_helper.dart';
import '../../models/player_model.dart';
import '../../providers/dungeon_provider.dart';
import '../../providers/dungeon_siege_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../core/tutorial/tutorial_anchor_registry.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../components/common/gkk_tab_page_shell.dart';
import 'dungeon_zone_data.dart';
import 'widgets/dungeon_card.dart';
import 'widgets/dungeon_confirm_entry_dialog.dart';
import 'widgets/dungeon_loot_dialog.dart';
import 'widgets/dungeon_restriction_strip.dart';
import 'widgets/dungeon_state_widgets.dart';
import 'widgets/dungeon_siege_panel.dart';
import 'widgets/dungeon_zone_3d_diorama.dart';
import 'widgets/dungeon_zone_tab_bar.dart';
import 'widgets/featured_cave_dungeon_card.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import '../../l10n/l10n.dart';

class DungeonScreen extends ConsumerStatefulWidget {
  const DungeonScreen({super.key});

  @override
  ConsumerState<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends ConsumerState<DungeonScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _siegePollTimer;

  int get _selectedZone => _tabController.index == 0
      ? 0
      : kDungeonZones[_tabController.index - 1].number;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kDungeonZones.length + 1, vsync: this);
    _tabController.addListener(() {
      if (!mounted || _tabController.indexIsChanging) return;
      setState(() {});

      final TutorialState tut = ref.read(tutorialProvider);
      if (tut.activeTrackId != TutorialTrackId.dungeon) return;
      if (tut.activeStep?.id == 'dungeon_pick_zone' && _tabController.index == 1) {
        unawaited(
          TutorialTriggers.onAnchorTap(ref, TutorialAnchorId.dungeonZone1Tab),
        );
      }
    });
    ref.listenManual<TutorialState>(tutorialProvider, (
      TutorialState? prev,
      TutorialState next,
    ) {
      if (next.activeTrackId != TutorialTrackId.dungeon) return;
      final String? stepId = next.activeStep?.id;
      if (stepId == null) return;
      if (stepId == 'dungeon_intro' || stepId == 'dungeon_pick_zone') {
        if (_tabController.index != 0) {
          _tabController.animateTo(0);
        }
        TutorialAnchorRegistry.instance.scheduleRefresh();
      } else if (stepId == 'dungeon_enter_btn') {
        if (_tabController.index != 1) {
          _tabController.animateTo(1);
        }
        TutorialAnchorRegistry.instance.scheduleRefresh();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrapDungeonData();
      if (!mounted) return;
      _startSiegePolling();
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.dungeon);
    });
  }

  Future<void> _bootstrapDungeonData() async {
    final DungeonState dungeonState = ref.read(dungeonProvider);
    final bool hasDungeonCache =
        dungeonState.status == DungeonStatus.ready &&
        dungeonState.dungeons.isNotEmpty;
    await Future.wait<void>(<Future<void>>[
      ref.read(playerProvider.notifier).loadProfile(),
      ref.read(inventoryProvider.notifier).loadInventory(silent: true),
      ref.read(dungeonProvider.notifier).loadDungeons(silent: hasDungeonCache),
      ref.read(dungeonSiegeProvider.notifier).loadStatus(silent: true),
    ]);
  }

  @override
  void dispose() {
    _siegePollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startSiegePolling() {
    _siegePollTimer?.cancel();
    _siegePollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final DungeonSiegeStatus status = ref.read(dungeonSiegeProvider).status;
      if (status.enabled) {
        unawaited(ref.read(dungeonSiegeProvider.notifier).loadStatus(silent: true));
      }
    });
  }

  DateTime? _parseRestrictionUntil(String? raw) {
    if (raw == null) return null;
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final DateTime? parsed = DateTime.tryParse(trimmed) ??
        DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
    if (parsed == null) return null;

    if (parsed.isUtc) return parsed.toLocal();

    final bool hasTimezone = RegExp(
      r'(Z|[+\-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(trimmed);

    if (!hasTimezone) {
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      ).toLocal();
    }

    return parsed.toLocal();
  }

  bool _isRestricted(String? untilRaw) {
    final DateTime? until = _parseRestrictionUntil(untilRaw);
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  Future<void> _enterDungeon(DungeonData dungeon) async {
    final player = ref.read(playerProvider).profile;
    if (player == null) {
      _showSnack('Oyuncu bilgisi yüklenemedi.');
      return;
    }
    final DungeonZone? entryZone = zoneDataFor(zoneForDungeon(dungeon));
    if (entryZone != null && !isZoneUnlockedForLevel(entryZone, player.level)) {
      _showSnack(zoneLevelGateMessage(entryZone.requiredLevel));
      return;
    }
    if (_isRestricted(player.hospitalUntil)) {
      _showSnack('Hastanedeyken zindana giriş yapılamaz.');
      return;
    }
    if (_isRestricted(player.prisonUntil)) {
      _showSnack('Hapisteyken zindana giriş yapılamaz.');
      return;
    }
    if (player.energy < dungeon.energyCost) {
      _showSnack('Enerji yetersiz.');
      return;
    }

    final DungeonSiegeStatus siegeStatus = ref.read(dungeonSiegeProvider).status;
    if (isSiegeDungeon(dungeon.dungeonId, status: siegeStatus) &&
        siegeStatus.isBannedForDungeon(dungeon.dungeonId)) {
      _showSnack('Kuşatma kaybı banı — bu zindana giremezsin.');
      return;
    }

    final int req = dungeon.powerRequirement ?? (dungeon.requiredLevel * 500);
    final equipped = ref.read(inventoryProvider).equippedItems.values;
    final int successPct = computeDungeonSuccessPercent(
      profile: player,
      dungeonPowerRequirement: req,
      equippedItems: equipped,
    );
    final double hospitalRisk = calculateHospitalRiskPct(
      dungeonNumber: parseDungeonNumber(dungeon.dungeonId),
      successRate: successPct / 100.0,
      playerLuck: effectivePlayerLuckFromProfile(player),
    );
    final double farmPreview = calculateDungeonRewardMultiplier(
      playerLevel: player.level,
      dungeonPowerRequirement: req,
      successRate: successPct / 100.0,
      isFirstClear: !(dungeon.playerStats?.hasFirstClear ?? false),
    );

    String? siegePrimeHint;
    String? siegeNoSlotWarning;
    if (isSiegeDungeon(dungeon.dungeonId, status: siegeStatus) && siegeStatus.siegeActive) {
      final DungeonSiegeConfig siegeConfig = siegeStatus.config;
      final DungeonSiegeSession? siegeSession =
          siegeStatus.sessionForDungeon(dungeon.dungeonId);
      final bool hasSlotHere =
          siegeSession?.slots.any((DungeonSiegeSlot s) => s.isMine) ?? false;
      final bool holdBonus = siegeSession?.hold != null &&
          siegeSession!.hold!.holdId.isNotEmpty &&
          player.guildId != null &&
          siegeSession.hold!.guildId == player.guildId;

      if (hasSlotHere) {
        siegePrimeHint =
            'Kuşatma slot bonusu: ${DungeonSiegeConfig.farmBonusSummary(siegeConfig, holdBonus: holdBonus)}';
      } else {
        siegeNoSlotWarning =
            'Prime aktif — slotun yok: normal ödül alırsın. Slot al: '
            '${DungeonSiegeConfig.farmBonusSummary(siegeConfig)}';
      }
    }

    final bool siegeActiveForDialog = isSiegeDungeon(dungeon.dungeonId, status: siegeStatus) &&
        siegeStatus.siegeActive;
    String? primeTimerLabel;
    if (siegeActiveForDialog) {
      final snapshot = DungeonSiegePrimeSchedule.snapshot(
        windows: siegeStatus.config.primeWindows,
        timezone: siegeStatus.config.timezone,
        isEnabled: siegeStatus.config.isEnabled,
      );
      if (snapshot.isVisible) {
        primeTimerLabel = snapshot.formattedRemaining;
      }
    }

    final bool? confirm = await DungeonConfirmEntryDialog.show(
      context,
      dungeon: dungeon,
      hospitalRiskPct: hospitalRisk,
      rewardMultiplierPreview: farmPreview,
      siegePrimeHint: siegePrimeHint,
      siegeNoSlotWarning: siegeNoSlotWarning,
      currentEnergy: player.energy,
      primeTimerLabel: primeTimerLabel,
      siegeActive: siegeActiveForDialog,
      onConfirmTap: () => TutorialTriggers.onAnchorTap(
        ref,
        TutorialAnchorId.dungeonConfirmOk,
      ),
    );
    if (confirm != true || !mounted) return;

    final int zone = zoneForDungeon(dungeon);
    await context.push(
      '${AppRoutes.dungeonBattle}?'
      'dungeon_id=${Uri.encodeComponent(dungeon.dungeonId)}&'
      'dungeon_name=${Uri.encodeComponent(dungeon.name)}&'
      'zone=$zone&'
      'energy_cost=${dungeon.energyCost}&'
      'auto=1',
    );
    if (!mounted) return;
    await Future.wait<void>(<Future<void>>[
      ref.read(playerProvider.notifier).loadProfile(),
      ref.read(dungeonProvider.notifier).loadDungeons(silent: true),
    ]);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppMessenger.show(context, message);
  }

  String? _tutorialTargetDungeonId(List<DungeonData> dungeons) {
    for (final DungeonData dungeon in dungeons) {
      if (zoneForDungeon(dungeon) == 1) return dungeon.dungeonId;
    }
    return dungeons.isEmpty ? null : dungeons.first.dungeonId;
  }

  bool _isTutorialTargetDungeon(DungeonData dungeon, List<DungeonData> dungeons) {
    final String? targetId = _tutorialTargetDungeonId(dungeons);
    return targetId != null && dungeon.dungeonId == targetId;
  }

  Future<void> _openSiegePanel(DungeonData dungeon) async {
    await showDungeonSiegePanel(context: context, ref: ref, dungeon: dungeon);
    if (!mounted) return;
    ref.read(dungeonSiegeProvider.notifier).clearScopedDungeon();
    await ref.read(dungeonSiegeProvider.notifier).loadStatus(silent: true);
  }

  ({bool active, int occupied, bool hasMine, int slotCount}) _siegeMetaFor(String dungeonId) {
    final DungeonSiegeStatus status = ref.read(dungeonSiegeProvider).status;
    final DungeonSiegeSession? session = status.sessionForDungeon(dungeonId);
    final int occupied = session?.slots.where((DungeonSiegeSlot s) => s.isOccupied).length ?? 0;
    final bool hasMine = session?.slots.any((DungeonSiegeSlot s) => s.isMine) ?? false;
    return (
      active: status.siegeActive && isSiegeDungeon(dungeonId, status: status),
      occupied: occupied,
      hasMine: hasMine,
      slotCount: status.config.slotCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dungeonState = ref.watch(dungeonProvider);
    ref.watch(dungeonSiegeProvider);
    final playerState = ref.watch(playerProvider);
    final inventoryState = ref.watch(inventoryProvider);
    final profile = playerState.profile;

    final bool inHospital = _isRestricted(profile?.hospitalUntil);
    final bool inPrison = _isRestricted(profile?.prisonUntil);
    final bool isRestricted = inHospital || inPrison;

    final PowerBreakdown? powerBreakdown = profile != null
        ? calculateTotalPower(
            player: profile,
            equippedItems: inventoryState.equippedItems.values,
          )
        : null;
    final int playerTotalPower = profile != null
        ? resolveDungeonCombatPower(
            profile: profile,
            equippedItems: inventoryState.equippedItems.values,
          )
        : 0;

    final List<DungeonData> filtered = _selectedZone == 0
        ? dungeonState.dungeons
        : dungeonState.dungeons
            .where((DungeonData d) => zoneForDungeon(d) == _selectedZone)
            .toList();

    final DungeonZone? currentZone = zoneDataFor(_selectedZone);

    return Scaffold(
      backgroundColor: AppColors.carbonVoid,
      appBar: GameTopBar(
        title: context.l10n.zindan,
        onLogout: () async => performLogout(ref),
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.dungeon,
        onLogout: () async => performLogout(ref),
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.carbonVoid,
                    currentZone != null
                        ? Color.fromRGBO(
                            (currentZone.color.r * 255).round(),
                            (currentZone.color.g * 255).round(),
                            (currentZone.color.b * 255).round(),
                            0.04,
                          )
                        : const Color(0xFF0C1020),
                    AppColors.carbonVoid,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: <Widget>[
              if (inHospital)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: DungeonRestrictionMiniStrip(
                    hospitalUntil: profile?.hospitalUntil,
                    parseUntil: _parseRestrictionUntil,
                    onGoHospital: () => context.go(AppRoutes.hospital),
                    title: 'Hastanedesin',
                    actionLabel: 'Hastaneye Git',
                    icon: Icons.local_hospital,
                    accent: const Color(0xFFEF4444),
                  ),
                ),
              if (inPrison)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: DungeonRestrictionMiniStrip(
                    hospitalUntil: profile?.prisonUntil,
                    parseUntil: _parseRestrictionUntil,
                    onGoHospital: () => context.go(AppRoutes.prison),
                    title: 'Cezaevindesin',
                    actionLabel: 'Cezaevine Git',
                    icon: Icons.gavel_rounded,
                    accent: AppColors.warningSolar,
                    availableLabel: 'Serbest kalabilirsin',
                  ),
                ),
              DungeonZoneTabBar(
                controller: _tabController,
                dungeons: dungeonState.dungeons,
                zoneFor: zoneForDungeon,
                playerLevel: profile?.level ?? 1,
              ),
              if (currentZone != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: DungeonZoneBanner(
                    zone: currentZone,
                    dungeonCount: filtered.length,
                    playerLevel: profile?.level ?? 1,
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedBuilder(
                  animation: _tabController,
                  builder: (BuildContext context, Widget? _) {
                    final String sectionTitle = _tabController.index == 0
                        ? 'Tüm Zindanlar'
                        : currentZone?.name ?? 'Bölge $_selectedZone';
                    return GkkTabPageShell(
                      tabIndex: _tabController.index,
                      sectionTitle: sectionTitle,
                      sectionAccent: currentZone?.color ?? AppColors.liquidGold,
                      animateEntrance: false,
                      child: dungeonState.status == DungeonStatus.loading ||
                              dungeonState.status == DungeonStatus.initial
                          ? const DungeonLoadingShimmer()
                          : dungeonState.status == DungeonStatus.error &&
                                  dungeonState.dungeons.isEmpty
                              ? DungeonErrorState(
                                  message: dungeonState.errorMessage,
                                  onRetry: () => ref
                                      .read(dungeonProvider.notifier)
                                      .loadDungeons(),
                                )
                              : filtered.isEmpty
                                  ? const DungeonEmptyState()
                                  : RefreshIndicator(
                                      onRefresh: () async {
                                        await Future.wait<void>(<Future<void>>[
                                          ref
                                              .read(dungeonProvider.notifier)
                                              .loadDungeons(silent: true),
                                          ref
                                              .read(dungeonSiegeProvider.notifier)
                                              .loadStatus(silent: true),
                                        ]);
                                      },
                                      child: ListView.builder(
                                        padding: GameScrollLayout.withClearance(
                                          context,
                                          const EdgeInsets.fromLTRB(14, 0, 14, 24),
                                        ),
                                        itemCount: filtered.length + 1,
                                        itemBuilder: (BuildContext ctx, int i) {
                                          if (i == 0) {
                                            final int clearedCount = filtered
                                                .where(
                                                  (DungeonData d) =>
                                                      d.playerStats
                                                          ?.hasFirstClear ??
                                                      false,
                                                )
                                                .length;
                                            DungeonData? recommended;
                                            int? recChance;
                                            bool recCanEnter = false;
                                            for (final DungeonData cand
                                                in filtered) {
                                              final DungeonZone? cz =
                                                  zoneDataFor(
                                                zoneForDungeon(cand),
                                              );
                                              final bool unlocked = cz ==
                                                      null ||
                                                  isZoneUnlockedForLevel(
                                                    cz,
                                                    profile?.level ?? 1,
                                                  );
                                              if (!unlocked) continue;
                                              final int cReq =
                                                  cand.powerRequirement ??
                                                      (cand.requiredLevel *
                                                          500);
                                              final int pct = profile != null
                                                  ? computeDungeonSuccessPercent(
                                                      profile: profile,
                                                      dungeonPowerRequirement:
                                                          cReq,
                                                      equippedItems:
                                                          inventoryState
                                                              .equippedItems
                                                              .values,
                                                    )
                                                  : 75;
                                              if (pct >= 55) {
                                                recommended = cand;
                                                recChance = pct;
                                                recCanEnter = !isRestricted &&
                                                    profile != null &&
                                                    profile.energy >=
                                                        cand.energyCost;
                                              }
                                            }
                                            recommended ??= filtered.first;
                                            if (recChance == null) {
                                              final int fReq = recommended
                                                      .powerRequirement ??
                                                  (recommended.requiredLevel *
                                                      500);
                                              recChance = profile != null
                                                  ? computeDungeonSuccessPercent(
                                                      profile: profile,
                                                      dungeonPowerRequirement:
                                                          fReq,
                                                      equippedItems:
                                                          inventoryState
                                                              .equippedItems
                                                              .values,
                                                    )
                                                  : 60;
                                              final DungeonZone? fz =
                                                  zoneDataFor(
                                                zoneForDungeon(recommended),
                                              );
                                              recCanEnter = !isRestricted &&
                                                  profile != null &&
                                                  (fz == null ||
                                                      isZoneUnlockedForLevel(
                                                        fz,
                                                        profile.level,
                                                      )) &&
                                                  profile.energy >=
                                                      recommended.energyCost;
                                            }
                                            final DungeonData targetRec =
                                                recommended;
                                            return DungeonZone3dDiorama(
                                              selectedZone: currentZone,
                                              dungeons: filtered,
                                              recommendedDungeon: targetRec,
                                              recommendedSuccessPct: recChance,
                                              canEnterRecommended:
                                                  recCanEnter &&
                                                      !dungeonState.entering,
                                              clearedCount: clearedCount,
                                              totalCount: filtered.length,
                                              characterClass:
                                                  profile?.characterClass,
                                              playerPower: playerTotalPower,
                                              onQuickEnterRecommended: () =>
                                                  _enterDungeon(targetRec),
                                            );
                                          }
                                          final DungeonData d = filtered[i - 1];
                                          final bool isTutorialTarget =
                                              _isTutorialTargetDungeon(
                                            d,
                                            dungeonState.dungeons,
                                          );
                                          return _buildDungeonListItem(
                                            context: ctx,
                                            dungeon: d,
                                            isTutorialTarget: isTutorialTarget,
                                            zoneForDungeon: zoneForDungeon,
                                            profile: profile,
                                            powerBreakdown: powerBreakdown,
                                            playerTotalPower: playerTotalPower,
                                            isRestricted: isRestricted,
                                            inHospital: inHospital,
                                            inPrison: inPrison,
                                            dungeonState: dungeonState,
                                          );
                                        },
                                      ),
                                    ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDungeonListItem({
    required BuildContext context,
    required DungeonData dungeon,
    required bool isTutorialTarget,
    required int Function(DungeonData) zoneForDungeon,
    required PlayerProfile? profile,
    required PowerBreakdown? powerBreakdown,
    required int playerTotalPower,
    required bool isRestricted,
    required bool inHospital,
    required bool inPrison,
    required DungeonState dungeonState,
  }) {
    final int zoneNum = zoneForDungeon(dungeon);
    final DungeonZone? zData = zoneDataFor(zoneNum);
    final int playerLevel = profile?.level ?? 1;
    final bool zoneLevelLocked =
        zData != null && !isZoneUnlockedForLevel(zData, playerLevel);
    final bool canEnter = !isRestricted &&
        profile != null &&
        !zoneLevelLocked &&
        profile.energy >= dungeon.energyCost;
    final int req = dungeon.powerRequirement ?? (dungeon.requiredLevel * 500);
    final int successPct;
    String? debugText;
    if (profile != null) {
      final equipped = ref.read(inventoryProvider).equippedItems.values;
      successPct = computeDungeonSuccessPercent(
        profile: profile,
        dungeonPowerRequirement: req,
        equippedItems: equipped,
      );
      debugText = kDebugMode
          ? 'pwr:$playerTotalPower eq:${powerBreakdown?.equipmentPower ?? 0} req:$req'
          : null;
    } else {
      successPct = 5;
      debugText = kDebugMode ? 'no profile' : null;
    }

    final DungeonSiegeConfig siegeConfig = ref.read(dungeonSiegeProvider).status.config;

    if (isFeaturedCaveDungeon(dungeon)) {
      final theme = featuredCaveThemeFor(dungeon)!;
      final bool siegeDungeon =
          isSiegeDungeon(dungeon.dungeonId, status: ref.read(dungeonSiegeProvider).status);
      final ({bool active, int occupied, bool hasMine, int slotCount}) siegeMeta = siegeDungeon
          ? _siegeMetaFor(dungeon.dungeonId)
          : (active: false, occupied: 0, hasMine: false, slotCount: 5);
      return FeaturedCaveDungeonCard(
        dungeon: dungeon,
        theme: theme,
        zoneIcon: zData?.icon ?? Icons.park,
        zoneLabel: (zData?.name.split(' ').first ?? 'ZINDAN').toUpperCase(),
        zoneColor: zData?.color ?? const Color(0xFF4ADE80),
        canEnter: canEnter,
        inHospital: inHospital,
        inPrison: inPrison,
        entering: dungeonState.entering,
        successPercent: successPct,
        energyCost: dungeon.energyCost,
        minGold: dungeon.minGold,
        maxGold: dungeon.maxGold,
        powerRequirement: req,
        playerPower: playerTotalPower,
        debugText: debugText,
        siegeActive: siegeMeta.active,
        siegeOccupiedSlots: siegeMeta.occupied,
        siegeHasMySlot: siegeMeta.hasMine,
        siegeSlotCount: siegeMeta.slotCount,
        siegeConfig: siegeDungeon ? siegeConfig : null,
        onSiegeTap: siegeDungeon ? () => _openSiegePanel(dungeon) : null,
        useTutorialAnchors: isTutorialTarget,
        zoneLevelLocked: zoneLevelLocked,
        zoneRequiredLevel: zData?.requiredLevel ?? 1,
        onEnter: () async {
          if (isTutorialTarget) {
            await TutorialTriggers.onAnchorTap(
              ref,
              TutorialAnchorId.dungeonEnterBtn,
            );
          }
          await _enterDungeon(dungeon);
        },
        onLoot: () => showDialog<void>(
          context: context,
          builder: (_) => DungeonLootDialog(dungeon: dungeon, zone: zData),
        ),
      );
    }

    final bool siegeDungeon =
        isSiegeDungeon(dungeon.dungeonId, status: ref.read(dungeonSiegeProvider).status);
    final ({bool active, int occupied, bool hasMine, int slotCount}) siegeMeta = siegeDungeon
        ? _siegeMetaFor(dungeon.dungeonId)
        : (active: false, occupied: 0, hasMine: false, slotCount: 5);

    return DungeonCard(
      dungeon: dungeon,
      zone: zData,
      canEnter: canEnter,
      inHospital: inHospital,
      inPrison: inPrison,
      entering: dungeonState.entering,
      successPercent: successPct,
      playerPower: playerTotalPower,
      powerRequirement: req,
      debugText: debugText,
      siegeActive: siegeMeta.active,
      siegeOccupiedSlots: siegeMeta.occupied,
      siegeHasMySlot: siegeMeta.hasMine,
      siegeSlotCount: siegeMeta.slotCount,
      siegeConfig: siegeDungeon ? siegeConfig : null,
      onSiegeTap: siegeDungeon ? () => _openSiegePanel(dungeon) : null,
      useTutorialAnchors: isTutorialTarget,
      zoneLevelLocked: zoneLevelLocked,
      zoneRequiredLevel: zData?.requiredLevel ?? 1,
      onEnter: () async {
        if (isTutorialTarget) {
          await TutorialTriggers.onAnchorTap(ref, TutorialAnchorId.dungeonEnterBtn);
        }
        await _enterDungeon(dungeon);
      },
      onLoot: () => showDialog<void>(
        context: context,
        builder: (_) => DungeonLootDialog(dungeon: dungeon, zone: zData),
      ),
    );
  }
}
