import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/gkk_tab_page_shell.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/tutorial/tutorial_anchor_registry.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/effective_luck.dart';
import '../../core/utils/gold_format.dart';
import '../../core/utils/power_formula.dart';
import '../../l10n/l10n.dart';
import '../../models/dungeon_model.dart';
import '../../models/dungeon_siege_model.dart';
import '../../models/dungeon_siege_prime_timer.dart';
import '../../models/player_model.dart';
import '../../providers/dungeon_provider.dart';
import '../../providers/dungeon_siege_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/logout_helper.dart';
import 'dungeon_zone_data.dart';
import 'widgets/dungeon_card.dart';
import 'widgets/dungeon_cave_theme.dart';
import 'widgets/dungeon_cinematic_atmosphere.dart';
import 'widgets/dungeon_confirm_entry_dialog.dart';
import 'widgets/dungeon_loot_dialog.dart';
import 'widgets/dungeon_restriction_strip.dart';
import 'widgets/dungeon_siege_panel.dart';
import 'widgets/dungeon_state_widgets.dart';
import 'widgets/dungeon_zone_tab_bar.dart';
import 'widgets/featured_cave_dungeon_card.dart';

/// Difficulty filtering options for the dungeon hub.
enum DungeonDifficultyFilter {
  all('Tümü', Icons.apps_rounded, Color(0xFF94A3B8)),
  normal('Normal', Icons.shield_outlined, Color(0xFF22C55E)),
  heroic('Kahraman', Icons.military_tech_outlined, Color(0xFFF59E0B)),
  mythic('Efsanevi', Icons.whatshot_rounded, Color(0xFFEF4444)),
  boss('Boss', Icons.dangerous_rounded, Color(0xFFA855F7));

  const DungeonDifficultyFilter(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

/// Returns the dark fantasy tier title for a dungeon zone.
String tierNameForZone(int zoneNumber) {
  switch (zoneNumber) {
    case 1:
      return 'KADEME I • ACEMİ';
    case 2:
      return 'KADEME II • DERİNLİK';
    case 3:
      return 'KADEME III • KOR ATEŞ';
    case 4:
      return 'KADEME IV • FIRTINA';
    case 5:
      return 'KADEME V • CEHENNEM';
    case 6:
      return 'KADEME VI • KAOS';
    case 7:
      return 'KADEME VII • EFSANEVİ';
    default:
      return 'KADEME I • BAŞLANGIÇ';
  }
}

class DungeonScreen extends ConsumerStatefulWidget {
  const DungeonScreen({super.key});

  @override
  ConsumerState<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends ConsumerState<DungeonScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _portalAnimController;
  late AnimationController _particleAnimController;
  late AnimationController _transitionController;

  Timer? _siegePollTimer;
  Timer? _keyRefillTimer;
  int _keyRefillSeconds = 168; // 2m 48s countdown

  DungeonDifficultyFilter _selectedDifficulty = DungeonDifficultyFilter.all;
  bool _isWarping = false;
  DungeonData? _warpingDungeon;

  late final List<_DungeonAmbientParticle> _ambientParticles = _initAmbientParticles();

  static List<_DungeonAmbientParticle> _initAmbientParticles() {
    final math.Random rnd = math.Random(1337);
    const List<Color> palette = <Color>[
      Color(0xFFF5C842), // Liquid gold
      Color(0xFF38BDF8), // Mystic cyan
      Color(0xFFA855F7), // Abyssal purple
      Color(0xFF4ADE80), // Emerald
      Color(0xFFF97316), // Solar ember
    ];
    return List<_DungeonAmbientParticle>.generate(26, (int i) {
      return _DungeonAmbientParticle(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        radius: 1.1 + rnd.nextDouble() * 2.2,
        speed: 0.12 + rnd.nextDouble() * 0.28,
        swayPhase: rnd.nextDouble() * 2 * math.pi,
        swaySpeed: 0.4 + rnd.nextDouble() * 0.8,
        color: palette[i % palette.length],
        alpha: 0.22 + rnd.nextDouble() * 0.45,
      );
    });
  }

  int get _selectedZone => _tabController.index == 0
      ? 0
      : kDungeonZones[_tabController.index - 1].number;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kDungeonZones.length + 1, vsync: this);
    _portalAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _particleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

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
      _startKeyRefillTimer();
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
    _keyRefillTimer?.cancel();
    _siegePollTimer?.cancel();
    _tabController.dispose();
    _portalAnimController.dispose();
    _particleAnimController.dispose();
    _transitionController.dispose();
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

  void _startKeyRefillTimer() {
    _keyRefillTimer?.cancel();
    _keyRefillTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_keyRefillSeconds > 0) {
          _keyRefillSeconds--;
        } else {
          _keyRefillSeconds = 180; // 3 minute refill loop
        }
      });
    });
  }

  String _formatRefillTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _calculateDailyBossKeys(List<DungeonData> dungeons) {
    int maxLimit = 3;
    int usedAttempts = 0;
    for (final DungeonData d in dungeons) {
      if (d.isBoss) {
        maxLimit = d.dailyBossLimit;
        final int attempts = d.playerStats?.todayBossAttempts ?? 0;
        if (attempts > usedAttempts) usedAttempts = attempts;
      }
    }
    final int remaining = maxLimit - usedAttempts;
    return remaining < 0 ? 0 : remaining;
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

  bool _matchesDifficulty(DungeonData d, DungeonDifficultyFilter filter) {
    switch (filter) {
      case DungeonDifficultyFilter.all:
        return true;
      case DungeonDifficultyFilter.normal:
        return !d.isBoss && d.difficulty.toLowerCase() == 'easy';
      case DungeonDifficultyFilter.heroic:
        return !d.isBoss && d.difficulty.toLowerCase() == 'medium';
      case DungeonDifficultyFilter.mythic:
        return !d.isBoss && d.difficulty.toLowerCase() == 'hard';
      case DungeonDifficultyFilter.boss:
        return d.isBoss || d.difficulty.toLowerCase().contains('dungeon');
    }
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

    // Cinematic smooth transition into battle
    setState(() {
      _isWarping = true;
      _warpingDungeon = dungeon;
    });

    try {
      await _transitionController.forward(from: 0.0);
      await Future<void>.delayed(const Duration(milliseconds: 140));
    } catch (_) {
      // Ignored if cancelled
    }
    if (!mounted) return;

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

    setState(() {
      _isWarping = false;
      _warpingDungeon = null;
    });
    _transitionController.reset();

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

  void _showRulesSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _DungeonRulesSheet(),
    );
  }

  void _showTierDetailsDialog(DungeonZone zone, List<DungeonData> zoneDungeons) {
    final int playerLevel = ref.read(playerProvider).profile?.level ?? 1;
    showDialog<void>(
      context: context,
      builder: (_) => _DungeonTierDetailsDialog(
        zone: zone,
        playerLevel: playerLevel,
        dungeons: zoneDungeons,
      ),
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

    // First filter by selected zone
    final List<DungeonData> zoneDungeons = _selectedZone == 0
        ? dungeonState.dungeons
        : dungeonState.dungeons
            .where((DungeonData d) => zoneForDungeon(d) == _selectedZone)
            .toList();

    // Map difficulty counts for current zone selection
    final Map<DungeonDifficultyFilter, int> difficultyCounts = <DungeonDifficultyFilter, int>{
      DungeonDifficultyFilter.all: zoneDungeons.length,
      DungeonDifficultyFilter.normal:
          zoneDungeons.where((DungeonData d) => _matchesDifficulty(d, DungeonDifficultyFilter.normal)).length,
      DungeonDifficultyFilter.heroic:
          zoneDungeons.where((DungeonData d) => _matchesDifficulty(d, DungeonDifficultyFilter.heroic)).length,
      DungeonDifficultyFilter.mythic:
          zoneDungeons.where((DungeonData d) => _matchesDifficulty(d, DungeonDifficultyFilter.mythic)).length,
      DungeonDifficultyFilter.boss:
          zoneDungeons.where((DungeonData d) => _matchesDifficulty(d, DungeonDifficultyFilter.boss)).length,
    };

    // Apply difficulty filter
    final List<DungeonData> filtered = zoneDungeons
        .where((DungeonData d) => _matchesDifficulty(d, _selectedDifficulty))
        .toList();

    final DungeonZone? currentZone = zoneDataFor(_selectedZone);
    final int bossKeysAvailable = _calculateDailyBossKeys(dungeonState.dungeons);

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
          // Deep atmospheric background
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
                            0.05,
                          )
                        : const Color(0xFF0C1020),
                    AppColors.carbonVoid,
                  ],
                ),
              ),
            ),
          ),

          // Cinematic mist atmosphere
          Positioned.fill(
            child: DungeonCinematicAtmosphere(
              theme: CaveCardTheme.cyberCave,
              showTorches: false,
              showArena3D: false,
              showMist: true,
              showDecals: false,
              showDynamicShadows: false,
              intensityMultiplier: 0.65,
            ),
          ),

          // Ambient floating particles field
          Positioned.fill(
            child: _DungeonAmbientParticleField(
              animation: _particleAnimController,
              particles: _ambientParticles,
            ),
          ),

          // Main content column
          Column(
            children: <Widget>[
              if (inHospital)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
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
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
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

              // Key Counters & Resource HUD bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                child: _DungeonKeyResourceStrip(
                  energy: profile?.energy ?? 0,
                  maxEnergy: profile?.maxEnergy ?? 100,
                  bossKeys: bossKeysAvailable,
                  refillTimeLabel: _formatRefillTime(_keyRefillSeconds),
                  onInfoTap: _showRulesSheet,
                ),
              ),

              // Zone Navigation Tabs
              DungeonZoneTabBar(
                controller: _tabController,
                dungeons: dungeonState.dungeons,
                zoneFor: zoneForDungeon,
                playerLevel: profile?.level ?? 1,
              ),

              // Chapter Showcase & Tier Unlock Hero Card
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: _DungeonChapterHubCard(
                  zone: currentZone,
                  playerLevel: profile?.level ?? 1,
                  dungeonsInZone: zoneDungeons,
                  portalAnimation: _portalAnimController,
                  onOpenDetails: currentZone != null
                      ? () => _showTierDetailsDialog(currentZone, zoneDungeons)
                      : null,
                ),
              ),

              // Difficulty Selector Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                child: _DungeonDifficultyBar(
                  selected: _selectedDifficulty,
                  counts: difficultyCounts,
                  onSelect: (DungeonDifficultyFilter filter) {
                    setState(() {
                      _selectedDifficulty = filter;
                    });
                  },
                ),
              ),

              // Main Dungeon Cards List
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
                                  ? _DungeonEmptyDifficultyState(
                                      difficulty: _selectedDifficulty,
                                      onReset: () {
                                        setState(() {
                                          _selectedDifficulty = DungeonDifficultyFilter.all;
                                        });
                                      },
                                    )
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
                                        itemCount: filtered.length,
                                        itemBuilder: (BuildContext ctx, int i) {
                                          final DungeonData d = filtered[i];
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

          // Smooth Battle Entry Warp Overlay
          if (_isWarping && _warpingDungeon != null)
            Positioned.fill(
              child: _DungeonWarpOverlay(
                animation: _transitionController,
                dungeon: _warpingDungeon!,
                zone: zoneDataFor(zoneForDungeon(_warpingDungeon!)),
              ),
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

// ─────────────────────────────────────────────────────────────────────────────
// DARK FANTASY GLASSMORPHIC HUB WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Ambient floating dust and magical embers particle model.
class _DungeonAmbientParticle {
  const _DungeonAmbientParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.swayPhase,
    required this.swaySpeed,
    required this.color,
    required this.alpha,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double swayPhase;
  final double swaySpeed;
  final Color color;
  final double alpha;
}

class _DungeonAmbientParticleField extends StatelessWidget {
  const _DungeonAmbientParticleField({
    required this.animation,
    required this.particles,
  });

  final Animation<double> animation;
  final List<_DungeonAmbientParticle> particles;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? _) {
          return CustomPaint(
            painter: _DungeonParticlePainter(
              progress: animation.value,
              particles: particles,
            ),
          );
        },
      ),
    );
  }
}

class _DungeonParticlePainter extends CustomPainter {
  const _DungeonParticlePainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_DungeonAmbientParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _DungeonAmbientParticle p in particles) {
      final double y = ((p.y - progress * p.speed) % 1.0) * size.height;
      final double sway = math.sin((progress * p.swaySpeed * 2 * math.pi) + p.swayPhase) * 16.0;
      final double x = (p.x * size.width + sway).clamp(0.0, size.width);

      final double normY = y / size.height;
      final double edgeFade = (normY < 0.12
              ? normY / 0.12
              : normY > 0.88
                  ? (1.0 - normY) / 0.12
                  : 1.0)
          .clamp(0.0, 1.0);
      final double currentAlpha = (p.alpha * edgeFade).clamp(0.0, 1.0);

      final Paint paint = Paint()
        ..color = p.color.withValues(alpha: currentAlpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DungeonParticlePainter old) => old.progress != progress;
}

/// Rotating glowing runic portal disc with multi-layered concentric circles.
class _AnimatedPortalDisc extends StatelessWidget {
  const _AnimatedPortalDisc({
    required this.animation,
    required this.color,
    this.size = 52,
    this.isLocked = false,
  });

  final Animation<double> animation;
  final Color color;
  final double size;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? _) {
        return CustomPaint(
          size: Size(size, size),
          painter: _DungeonRunicPortalPainter(
            rotation: animation.value * 2 * math.pi,
            color: color,
            isLocked: isLocked,
          ),
        );
      },
    );
  }
}

class _DungeonRunicPortalPainter extends CustomPainter {
  const _DungeonRunicPortalPainter({
    required this.rotation,
    required this.color,
    required this.isLocked,
  });

  final double rotation;
  final Color color;
  final bool isLocked;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 2;
    final Color activeColor = isLocked ? const Color(0xFF64748B) : color;

    // Outer subtle ambient glow
    final Paint glowPaint = Paint()
      ..color = activeColor.withValues(alpha: isLocked ? 0.08 : 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius - 1, glowPaint);

    // Outer runic ring
    final Paint outerRingPaint = Paint()
      ..color = activeColor.withValues(alpha: isLocked ? 0.35 : 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawCircle(center, radius, outerRingPaint);

    // 12 Ancient runic tick marks
    const int runeCount = 12;
    final Paint tickPaint = Paint()
      ..color = activeColor.withValues(alpha: isLocked ? 0.4 : 0.9)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < runeCount; i++) {
      final double angle = rotation + (i * 2 * math.pi / runeCount);
      final double innerR = radius - (i % 3 == 0 ? 5.5 : 3.5);
      final Offset p1 = Offset(center.dx + innerR * math.cos(angle), center.dy + innerR * math.sin(angle));
      final Offset p2 = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Inner counter-rotating geometric star (6 spokes)
    final double innerRadius = radius * 0.68;
    final Paint starPaint = Paint()
      ..color = activeColor.withValues(alpha: isLocked ? 0.25 : 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 6; i++) {
      final double angle = -rotation * 0.8 + (i * 2 * math.pi / 6);
      final Offset p = Offset(center.dx + innerRadius * math.cos(angle), center.dy + innerRadius * math.sin(angle));
      canvas.drawLine(center, p, starPaint);
    }

    // Portal core vortex
    final Paint corePaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        innerRadius * 0.75,
        <Color>[
          isLocked ? const Color(0x3364748B) : activeColor.withValues(alpha: 0.55),
          isLocked ? const Color(0x110F172A) : activeColor.withValues(alpha: 0.15),
          Colors.transparent,
        ],
        <double>[0.0, 0.65, 1.0],
      );
    canvas.drawCircle(center, innerRadius * 0.75, corePaint);

    // Center jewel / rune core
    final Paint centerDotPaint = Paint()
      ..color = isLocked ? const Color(0xFFEF4444) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, isLocked ? 2.5 : 3.0, centerDotPaint);
  }

  @override
  bool shouldRepaint(_DungeonRunicPortalPainter old) =>
      old.rotation != rotation || old.color != color || old.isLocked != isLocked;
}

/// Dark fantasy glassmorphic Key Counter, Energy & Refill HUD strip.
class _DungeonKeyResourceStrip extends StatelessWidget {
  const _DungeonKeyResourceStrip({
    required this.energy,
    required this.maxEnergy,
    required this.bossKeys,
    required this.refillTimeLabel,
    required this.onInfoTap,
  });

  final int energy;
  final int maxEnergy;
  final int bossKeys;
  final String refillTimeLabel;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xD90C1322),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.liquidGold.withValues(alpha: 0.28),
              width: 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              // Boss Dungeon Keys Counter
              _buildMetricChip(
                icon: Icons.vpn_key_rounded,
                iconColor: AppColors.liquidGold,
                label: 'Zindan Anahtarı',
                value: '$bossKeys / 3',
                badgeText: 'Boss Hak',
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 1,
                height: 24,
                color: Colors.white.withValues(alpha: 0.1),
              ),

              // Energy Gauge Counter
              Expanded(
                child: _buildEnergyMetric(
                  current: energy,
                  max: maxEnergy,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 1,
                height: 24,
                color: Colors.white.withValues(alpha: 0.1),
              ),

              // Refill Countdown Timer
              _buildMetricChip(
                icon: Icons.hourglass_top_rounded,
                iconColor: const Color(0xFF22C55E),
                label: 'Yenilenme',
                value: refillTimeLabel,
                badgeText: '+1E / 3dk',
              ),

              // Info & Rules Dialog button
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onInfoTap,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    size: 13,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String badgeText,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            Text(
              badgeText,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnergyMetric({
    required int current,
    required int max,
  }) {
    final double ratio = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF38BDF8)),
            const SizedBox(width: 4),
            Text(
              '$current / $max E',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 3.5,
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Chapter Hero Showcase & Tier Unlock progression card.
class _DungeonChapterHubCard extends StatelessWidget {
  const _DungeonChapterHubCard({
    required this.zone,
    required this.playerLevel,
    required this.dungeonsInZone,
    required this.portalAnimation,
    this.onOpenDetails,
  });

  final DungeonZone? zone;
  final int playerLevel;
  final List<DungeonData> dungeonsInZone;
  final Animation<double> portalAnimation;
  final VoidCallback? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    if (zone == null) {
      // "All Zones" Overview card
      final int totalDungeons = dungeonsInZone.length;
      final int clearedCount = dungeonsInZone
          .where((DungeonData d) => d.playerStats?.hasFirstClear ?? false)
          .length;
      final double progress =
          totalDungeons > 0 ? clearedCount / totalDungeons : 0.0;

      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xE00C1322),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.3),
                width: 1.1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.08),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                _AnimatedPortalDisc(
                  animation: portalAnimation,
                  color: AppColors.liquidGold,
                  size: 48,
                  isLocked: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.liquidGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.liquidGold.withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Text(
                              'KADİM DİYAR • TÜM BÖLÜMLER',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.liquidGold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$clearedCount / $totalDungeons Temizlendi',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Zindan Diyarları Genel Bakış',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.liquidGold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Single Zone Chapter Showcase Card
    final bool isUnlocked = isZoneUnlockedForLevel(zone!, playerLevel);
    final int totalInZone = dungeonsInZone.length;
    final int clearedInZone = dungeonsInZone
        .where((DungeonData d) => d.playerStats?.hasFirstClear ?? false)
        .length;
    final double zoneProgress =
        totalInZone > 0 ? clearedInZone / totalInZone : 0.0;

    int minReqPower = 0;
    int maxReqPower = 0;
    for (final DungeonData d in dungeonsInZone) {
      final int req = d.powerRequirement ?? (d.requiredLevel * 500);
      if (minReqPower == 0 || req < minReqPower) minReqPower = req;
      if (req > maxReqPower) maxReqPower = req;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xE00C1322),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnlocked
                  ? zone!.color.withValues(alpha: 0.45)
                  : const Color(0xFFEF4444).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: isUnlocked
                    ? zone!.color.withValues(alpha: 0.1)
                    : const Color(0xFFEF4444).withValues(alpha: 0.08),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // Animated portal eye
                  _AnimatedPortalDisc(
                    animation: portalAnimation,
                    color: zone!.color,
                    size: 48,
                    isLocked: !isUnlocked,
                  ),
                  const SizedBox(width: 12),

                  // Chapter title & tier lock status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: zone!.color.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: zone!.color.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                tierNameForZone(zone!.number),
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: zone!.color,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Status pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isUnlocked
                                    ? const Color(0x2A22C55E)
                                    : const Color(0x2AEF4444),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: isUnlocked
                                      ? const Color(0x6622C55E)
                                      : const Color(0x66EF4444),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    isUnlocked ? Icons.check_circle_outline : Icons.lock_outline,
                                    size: 10,
                                    color: isUnlocked ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isUnlocked ? 'KADEME AÇIK' : 'Lv.${zone!.requiredLevel} GEREKLİ',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: isUnlocked ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Icon(zone!.icon, size: 15, color: zone!.color),
                            const SizedBox(width: 5),
                            Text(
                              zone!.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '#${zone!.min}–#${zone!.max}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress bar & Milestone rewards link
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Kademe İlerlemesi ($clearedInZone / $totalInZone)',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (minReqPower > 0)
                              Text(
                                'Önerilen: ${formatCompactGold(minReqPower)} - ${formatCompactGold(maxReqPower)} Güç',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: zone!.color.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: zoneProgress,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(zone!.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onOpenDetails != null) ...<Widget>[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onOpenDetails,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: zone!.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: zone!.color.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Detaylar',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: zone!.color,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.chevron_right, size: 12, color: zone!.color),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal Difficulty Selector with glowing neon borders.
class _DungeonDifficultyBar extends StatelessWidget {
  const _DungeonDifficultyBar({
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  final DungeonDifficultyFilter selected;
  final Map<DungeonDifficultyFilter, int> counts;
  final ValueChanged<DungeonDifficultyFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: DungeonDifficultyFilter.values.map((DungeonDifficultyFilter filter) {
          final bool isSelected = filter == selected;
          final int count = counts[filter] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSelect(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected
                      ? filter.color.withValues(alpha: 0.22)
                      : const Color(0xD90D1525),
                  border: Border.all(
                    color: isSelected
                        ? filter.color
                        : Colors.white.withValues(alpha: 0.12),
                    width: isSelected ? 1.3 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: filter.color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      filter.icon,
                      size: 13,
                      color: isSelected ? filter.color : Colors.white60,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      filter.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? filter.color.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : Colors.white60,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

/// Fallback empty state when a difficulty filter matches zero dungeons.
class _DungeonEmptyDifficultyState extends StatelessWidget {
  const _DungeonEmptyDifficultyState({
    required this.difficulty,
    required this.onReset,
  });

  final DungeonDifficultyFilter difficulty;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: difficulty.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: difficulty.color.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(difficulty.icon, size: 36, color: difficulty.color),
            ),
            const SizedBox(height: 14),
            Text(
              '${difficulty.label} Zorluğunda Zindan Yok',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bu bölgede seçili zorluk derecesinde zindan bulunmuyor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tüm Zorlukları Göster'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.liquidGold,
                side: BorderSide(color: AppColors.liquidGold.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cinematic battle entry warp overlay with vortex expansion and glowing runes.
class _DungeonWarpOverlay extends StatelessWidget {
  const _DungeonWarpOverlay({
    required this.animation,
    required this.dungeon,
    required this.zone,
  });

  final Animation<double> animation;
  final DungeonData dungeon;
  final DungeonZone? zone;

  @override
  Widget build(BuildContext context) {
    final Color portalColor = zone?.color ?? AppColors.liquidGold;
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? _) {
        final double t = animation.value;
        final double curvedT = Curves.easeInOutCubic.transform(t);
        final double scale = 0.8 + 1.6 * curvedT;
        final double rotateAngle = curvedT * 4 * math.pi;

        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12 * t, sigmaY: 12 * t),
          child: ColoredBox(
            color: Color.fromRGBO(6, 9, 18, (0.92 * t).clamp(0.0, 0.95)),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Concentric Expanding Portal Vortex
                  Transform.scale(
                    scale: scale,
                    child: Transform.rotate(
                      angle: rotateAngle,
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: CustomPaint(
                          painter: _DungeonRunicPortalPainter(
                            rotation: rotateAngle,
                            color: portalColor,
                            isLocked: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Portal activation banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: portalColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: portalColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.auto_awesome, size: 13, color: portalColor),
                        const SizedBox(width: 6),
                        Text(
                          'BOYUT GEÇİDİ AÇILIYOR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: portalColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dungeon Name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      dungeon.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Zone & Energy Cost info
                  Text(
                    '${zone?.name ?? 'Kadim Zindan'}  •  ${dungeon.energyCost} Enerji',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pulsing transition status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: portalColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Savaş Alanına Işınlanılıyor...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dark fantasy rules & mechanics bottom sheet.
class _DungeonRulesSheet extends StatelessWidget {
  const _DungeonRulesSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF00D1525),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: AppColors.liquidGold, width: 1.2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: <Widget>[
              Icon(Icons.menu_book_rounded, color: AppColors.liquidGold, size: 20),
              SizedBox(width: 8),
              Text(
                'KADİM ZİNDAN KURALLARI',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ruleItem(
            icon: Icons.vpn_key_rounded,
            color: AppColors.liquidGold,
            title: 'Zindan & Boss Anahtarları',
            desc:
                'Her gün 3 Boss Zindanı hakkın bulunur. Bu haklar gece 04:00\'te yenilenir. Normal zindanlar yalnızca Enerji tüketir.',
          ),
          const SizedBox(height: 10),
          _ruleItem(
            icon: Icons.bolt_rounded,
            color: const Color(0xFF38BDF8),
            title: 'Kadim Enerji & Yenilenme',
            desc:
                'Her zindan girişinde 5-25 Enerji tüketilir. Enerji her 3 dakikada +1 puan kendiliğinden yenilenir.',
          ),
          const SizedBox(height: 10),
          _ruleItem(
            icon: Icons.local_hospital_rounded,
            color: const Color(0xFFEF4444),
            title: 'Hastane Riski & Başarı Oranı',
            desc:
                'Savaş gücün zindan gereksiniminin altındaysa hastaneye düşme riski doğar. Şans statüsü bu riski azaltır.',
          ),
          const SizedBox(height: 10),
          _ruleItem(
            icon: Icons.shield_rounded,
            color: const Color(0xFFA855F7),
            title: 'Kuşatma Prime Saatleri',
            desc:
                'Prime saatlerinde kuşatma zindanlarında slot alan oyuncular ve kaleyi tutan loncalar %50\'ye varan bonus altın ve XP kazanır.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.liquidGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Anladım',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleItem({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.3,
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

/// Tier details modal dialog showing zone milestones and level requirements.
class _DungeonTierDetailsDialog extends StatelessWidget {
  const _DungeonTierDetailsDialog({
    required this.zone,
    required this.playerLevel,
    required this.dungeons,
  });

  final DungeonZone zone;
  final int playerLevel;
  final List<DungeonData> dungeons;

  @override
  Widget build(BuildContext context) {
    final bool isUnlocked = isZoneUnlockedForLevel(zone, playerLevel);
    final int clearedCount = dungeons
        .where((DungeonData d) => d.playerStats?.hasFirstClear ?? false)
        .length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xF20D1525),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: zone.color, width: 1.2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: zone.color.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(zone.icon, color: zone.color, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${zone.name} • ${tierNameForZone(zone.number)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20),
                _statRow('Giriş Seviyesi', 'Lv.${zone.requiredLevel}', isUnlocked ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
                const SizedBox(height: 6),
                _statRow('Mevcut Seviyeniz', 'Lv.$playerLevel', Colors.white),
                const SizedBox(height: 6),
                _statRow('Zindan Aralığı', '#${zone.min} – #${zone.max} (${dungeons.length} Zindan)', zone.color),
                const SizedBox(height: 6),
                _statRow('Temizleme Durumu', '$clearedCount / ${dungeons.length} Tamamlandı', AppColors.liquidGold),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.stars_rounded, color: AppColors.liquidGold, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isUnlocked
                              ? 'Bu kademedeki tüm zindanlara giriş yetkisine sahipsin.'
                              : 'Bu kademeye erişmek için seviyeni ${zone.requiredLevel}\'e yükseltmelisin.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: zone.color,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Kapat',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
