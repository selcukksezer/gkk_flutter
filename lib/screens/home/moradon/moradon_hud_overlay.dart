import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/common/adaptive_glass_blur.dart';
import '../../../components/common/profile_avatar.dart';
import '../../../components/notifications/notification_inbox_ui.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_controller.dart';
import '../../../core/tutorial/tutorial_hud_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/utils/xp_formula.dart';
import '../../../models/inventory_model.dart';
import '../../../models/moradon_models.dart';
import '../../../models/player_model.dart';
import '../../../models/retention_promos_model.dart';
import '../../../providers/dungeon_siege_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/moradon_hub_provider.dart';
import '../../../providers/retention_promos_provider.dart';
import '../../../routing/app_router.dart';
import '../widgets/character_inspect_sheet.dart';
import '../widgets/hero_showcase.dart';
import '../widgets/home_promo_carousel.dart';
import '../widgets/pantheon_board.dart';
import 'moradon_v5_layers.dart';

class MoradonHudOverlay extends ConsumerStatefulWidget {
  final PlayerProfile profile;
  final InventoryState inventoryState;
  final int totalPower;
  final int reputation;
  final void Function(String slotLabel, InventoryItem? item) onSlotTap;

  const MoradonHudOverlay({
    super.key,
    required this.profile,
    required this.inventoryState,
    required this.totalPower,
    required this.reputation,
    required this.onSlotTap,
  });

  @override
  ConsumerState<MoradonHudOverlay> createState() => _MoradonHudOverlayState();
}

class _MoradonHudOverlayState extends ConsumerState<MoradonHudOverlay> {
  final TextEditingController _chatCtrl = TextEditingController();
  Offset _joystickDelta = Offset.zero;
  bool _showNpcDirectory = false;
  bool _showMobileMinimap = false;

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

  void _openHeroEquipmentSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0F1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          builder: (BuildContext ctx, ScrollController scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                HeroShowcase(
                  profile: widget.profile,
                  inventoryState: widget.inventoryState,
                  totalPower: widget.totalPower,
                  reputation: widget.reputation,
                  onSlotTap: widget.onSlotTap,
                ),
                const SizedBox(height: 18),
                const PantheonBoard(),
              ],
            );
          },
        );
      },
    );
  }

  void _openPromoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A0F1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext ctx) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'GÖLGE KRALLIĞI DUYURULARI',
                  style: TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 12),
                HomePromoCarousel(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptMerchantMode(
    MoradonHubState hubState,
    MoradonHubNotifier notifier,
  ) async {
    if (hubState.isMerchant) {
      notifier.toggleMerchantMode();
      return;
    }
    final TextEditingController titleCtrl = TextEditingController(
      text: '${widget.profile.username} Pazar Tezgahı',
    );
    final String? chosen = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFFBBF24), width: 1.2),
          ),
          title: const Row(
            children: <Widget>[
              Text('🏪 '),
              Expanded(
                child: Text(
                  'Başkent Pazar Tezgahı Kur',
                  style: TextStyle(
                    color: Color(0xFFFEF08A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Karakterin başkent meydanında tezgah açar ve başının üstünde pazar başlığın görünür.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                maxLength: 36,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Örn: +8 Illusion Sabre & Kutsal Rune',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(titleCtrl.text),
              icon: const Icon(Icons.storefront, size: 18),
              label: const Text('Tezgahı Aç'),
            ),
          ],
        );
      },
    );
    titleCtrl.dispose();
    if (chosen != null) {
      notifier.toggleMerchantMode(title: chosen);
    }
  }

  void _openChannelAndDistrictSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF7080D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetCtx) {
        return Consumer(
          key: const Key('moradon_channel_sheet'),
          builder: (BuildContext ctx, WidgetRef sheetRef, Widget? _) {
            final MoradonHubState liveState = sheetRef.watch(moradonHubProvider);
            final MoradonHubNotifier liveNotifier =
                sheetRef.read(moradonHubProvider.notifier);
            final MoradonDistrictZone activeDistrict =
                liveState.currentDistrict;
            final int realmTotal = math.max(
              liveState.totalRealmOnline,
              liveState.channelOnlineCount,
            );

            return SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.78,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          const Text('🌐 ', style: TextStyle(fontSize: 16)),
                          const Expanded(
                            child: Text(
                              'MEGA BAŞKENT KANALLARI & MAHALLELER',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFFFEF08A),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(sheetCtx).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white60,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF11192C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                          ),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          alignment: WrapAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              '🟢 Toplam Online: $realmTotal',
                              style: const TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '📡 Kanal-${liveState.currentChannel}: ${liveState.channelOnlineCount} Oyuncu',
                              style: const TextStyle(
                                color: Color(0xFFBAE6FD),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${activeDistrict.emoji} ${activeDistrict.name}',
                              style: const TextStyle(
                                color: Color(0xFFFEF08A),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '🧭 8 BAŞKENT MAHALLESİ HIZLI IŞINLANMA (6400×3600)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final MoradonDistrictZone zone
                              in kMoradonDistricts)
                            GestureDetector(
                              key: Key('moradon_district_chip_${zone.id}'),
                              onTap: () {
                                liveNotifier.teleportToDistrict(zone);
                                Navigator.of(sheetCtx).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: zone.id == activeDistrict.id
                                      ? zone.accentColor.withValues(alpha: 0.25)
                                      : const Color(0xFF131C30),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: zone.id == activeDistrict.id
                                        ? zone.accentColor
                                        : zone.accentColor
                                            .withValues(alpha: 0.42),
                                    width: zone.id == activeDistrict.id
                                        ? 1.3
                                        : 0.9,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      zone.emoji,
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      zone.name,
                                      style: TextStyle(
                                        color: zone.id == activeDistrict.id
                                            ? const Color(0xFFFEF08A)
                                            : Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '🌐 SUNUCU KANALLARI (10.000+ ONLINE DİNAMİK SHARD)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: liveState.channels.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (BuildContext _, int idx) {
                            final MoradonChannelInfo ch =
                                liveState.channels[idx];
                            final bool selected =
                                ch.channelId == liveState.currentChannel;
                            final Color statusColor = ch.statusColor;
                            return InkWell(
                              key: Key('moradon_channel_tile_${ch.channelId}'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                liveNotifier.switchChannel(ch.channelId);
                                Navigator.of(sheetCtx).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF172542)
                                      : const Color(0xFF101829),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFFFBBF24)
                                        : Colors.white12,
                                    width: selected ? 1.3 : 0.9,
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: statusColor,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Text(
                                                ch.label,
                                                style: TextStyle(
                                                  color: selected
                                                      ? const Color(0xFFFEF08A)
                                                      : Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              if (selected) ...<Widget>[
                                                const SizedBox(width: 6),
                                                const Text(
                                                  '• AKTİF',
                                                  style: TextStyle(
                                                    color: Color(0xFF38BDF8),
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            child: LinearProgressIndicator(
                                              value: ch.loadRatio,
                                              minHeight: 4,
                                              backgroundColor: Colors.white10,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        Text(
                                          ch.statusLabelTr,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          '${ch.onlineCount}/${ch.capacity}',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool isDesktopWide = screenSize.width >= 760;
    final bool trackMinimapCoords = isDesktopWide || _showMobileMinimap;

    // Watch ONLY coarse HUD-relevant slice so 60Hz guard/crowd locomotion never rebuilds 3,300 lines of HUD!
    ref.watch(
      moradonHubProvider.select(
        (MoradonHubState s) => (
          s.currentChannel,
          s.channelOnlineCount,
          s.totalRealmOnline,
          s.remotePlayers.length,
          s.realtimeConnected,
          s.isMerchant,
          s.merchantTitle,
          s.selectedRemoteUserId,
          s.activeNpcDialog?.id,
          s.atmosphereChoice,
          s.activeCelebration?.id,
          s.mountedSteed,
          s.activeEmote?.id,
          s.worldBoss.isActive,
          s.worldBoss.isDefeated,
          (s.worldBoss.hpRatio * 100).round(),
          s.is3dPerspective,
          s.attackProgress > 0.01,
          s.comboStage,
          s.comboStreak,
          s.currentDistrict.id,
          trackMinimapCoords ? (s.playerX ~/ 24) : 0,
          trackMinimapCoords ? (s.playerY ~/ 24) : 0,
          trackMinimapCoords ? (s.zoom * 20).round() : 0,
        ),
      ),
    );
    final MoradonHubState hubState = ref.read(moradonHubProvider);
    final MoradonHubNotifier notifier = ref.read(moradonHubProvider.notifier);
    final MoradonPlayerPresence? selectedPlayer = hubState.selectedRemotePlayer;
    final MoradonNpcDefinition? activeNpc = hubState.activeNpcDialog;
    final RetentionPromos promos = ref.watch(retentionPromosProvider).promos;
    final bool siegeLive =
        ref.watch(dungeonSiegeProvider).status.siegeActive;
    final MoradonAtmospherePhase atmosphere = resolveLiveAtmospherePhase(
      choice: hubState.atmosphereChoice,
      nightMarketActive: promos.nightMarket.active,
      siegeLive: siegeLive,
    );
    final MoradonCelebrationEvent? celebration =
        (hubState.activeCelebration != null &&
                !hubState.activeCelebration!.isExpired)
            ? hubState.activeCelebration
            : null;

    final double topInset = MediaQuery.paddingOf(context).top + 8;
    final double bottomInset = MediaQuery.paddingOf(context).bottom + 84;

    if (!isDesktopWide) {
      return _buildMobileFirstHud(
        hubState: hubState,
        notifier: notifier,
        selectedPlayer: selectedPlayer,
        activeNpc: activeNpc,
        atmosphere: atmosphere,
        celebration: celebration,
        screenSize: screenSize,
        topInset: topInset,
        bottomInset: bottomInset,
      );
    }

    return Stack(
      children: <Widget>[
        // 1. Top-Left: Sovereign RPG Hero Crest Medallion & Equipped Weapon Readout
        Positioned(
          top: topInset + 6,
          left: 14,
          child: TutorialAnchorScope(
            id: TutorialAnchorId.homeHero,
            child: _buildPlayerHudCard(hubState),
          ),
        ),

        // 1b. Top-Center: Floating Gilded Royal Treasury & Realm Strip
        Positioned(
          top: topInset + 6,
          left: 252,
          right: 224,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _buildRoyalTreasuryRibbon(),
            ),
          ),
        ),

        // 2. Top-Right: Interactive Başkent Radar + Atmosphere & Controls
        Positioned(
          top: topInset + 6,
          right: 14,
          child: _buildMinimapCluster(
            hubState,
            notifier,
            screenSize,
            atmosphere,
          ),
        ),

        // 3. Optional Collapsible NPC Quick-Travel Directory Popover
        if (_showNpcDirectory)
          Positioned(
            top: topInset + 204,
            right: 14,
            width: 268,
            child: _buildNpcDirectoryCard(hubState, notifier),
          ),

        // 4. Top-Center: Live +9/+10 Forge or Legendary Crate Herald Banner
        if (celebration != null && selectedPlayer == null)
          Positioned(
            top: topInset + 54,
            left: 240,
            right: 240,
            child: IgnorePointer(
              child: Center(
                child: _buildCelebrationBanner(celebration),
              ),
            ),
          ),

        // 5. Top-Center: Selected Remote Player Target Bar
        if (selectedPlayer != null)
          Positioned(
            top: topInset + 54,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _buildTargetPlayerBar(selectedPlayer, notifier),
              ),
            ),
          ),

        // 6. Center/Bottom: Active NPC Dialogue & Route Actions Modal
        if (activeNpc != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: bottomInset + 56,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _buildNpcDialogCard(activeNpc, notifier),
              ),
            ),
          ),

        // 7. Bottom-Right Desktop Action Skill Button
        Positioned(
          right: 22,
          bottom: bottomInset + 2,
          child: _buildActionSkillCluster(hubState, notifier, compact: true),
        ),

        // 8. Bottom-Center: Sleek Constrained KO Chat & Merchant Bar
        Positioned(
          left: screenSize.width >= 1040 ? 206 : 14,
          right: 206,
          bottom: bottomInset,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: _buildBottomTownBar(hubState, notifier),
            ),
          ),
        ),
      ],
    );
  }

  /// Dedicated 95% Mobile-First Action-MMORPG HUD (< 760px width):
  /// Zero top card collisions on 320px-430px phones, quick horizontal activity
  /// strip, collapsible live radar, bottom-left 360° analog thumb joystick,
  /// center chat/merchant pill, and bottom-right 3-hit Combo Attack cluster!
  Widget _buildMobileFirstHud({
    required MoradonHubState hubState,
    required MoradonHubNotifier notifier,
    required MoradonPlayerPresence? selectedPlayer,
    required MoradonNpcDefinition? activeNpc,
    required MoradonAtmospherePhase atmosphere,
    required MoradonCelebrationEvent? celebration,
    required Size screenSize,
    required double topInset,
    required double bottomInset,
  }) {
    final PlayerProfile p = widget.profile;
    final double hpRatio =
        p.maxHealth > 0 ? (p.health / p.maxHealth).clamp(0.0, 1.0) : 1.0;
    final double enRatio =
        p.maxEnergy > 0 ? (p.energy / p.maxEnergy).clamp(0.0, 1.0) : 1.0;
    final xpProg = buildXpProgress(level: p.level, totalXp: p.xp);
    final int onlineCount = _resolvedShardOnlineCount(hubState);

    return Stack(
      children: <Widget>[
        // 0. Top System Status-Bar Obsidian Scrim (keeps clock/battery crisp over north entities)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topInset + 22,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xE0050811),
                    Color(0x88050811),
                    Colors.transparent,
                  ],
                  stops: <double>[0.0, 0.58, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 1. Unified Mobile Top Header + Quick Activity Strip
        Positioned(
          top: topInset,
          left: 10,
          right: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Row 1: Compact Hero Medallion (left) + Currencies & Radar Toggle (right)
              Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xEE090E1C), Color(0xE8050811)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD97706).withValues(alpha: 0.72),
                    width: 1.15,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    // Hero Avatar + Level + Bars
                    Expanded(
                      child: TutorialAnchorScope(
                        id: TutorialAnchorId.homeHero,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openHeroEquipmentSheet,
                          child: Row(
                            children: <Widget>[
                              Stack(
                                clipBehavior: Clip.none,
                                children: <Widget>[
                                  ProfileAvatar(
                                    size: 34,
                                    avatarUrl: p.avatarUrl,
                                    backgroundColor: const Color(0xFFB45309)
                                        .withValues(alpha: 0.28),
                                    glowFrame: p.avatarFrame == 'glow',
                                    codexFrame: p.avatarFrame == 'codex',
                                  ),
                                  Positioned(
                                    bottom: -3,
                                    right: -3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: const Color(0xFFFBBF24),
                                          width: 0.9,
                                        ),
                                      ),
                                      child: Text(
                                        '${xpProg.level}',
                                        style: const TextStyle(
                                          color: Color(0xFFFEF08A),
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TutorialAnchorScope(
                                  id: TutorialAnchorId.hudHealth,
                                  onTutorialTap: () async {
                                    await ref
                                        .read(tutorialProvider.notifier)
                                        .onAnchorTap(TutorialAnchorId.hudHealth);
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Flexible(
                                            child: Text(
                                              p.username,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          const _GothicCrossedBladesIcon(
                                            size: 11.5,
                                            color: Color(0xFFFDE047),
                                          ),
                                          const SizedBox(width: 2.5),
                                          Text(
                                            _compactNum(widget.totalPower),
                                            style: const TextStyle(
                                              color: Color(0xFFFDE047),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      _buildMiniBar(
                                        label: 'CAN ${p.health}/${p.maxHealth}',
                                        ratio: hpRatio,
                                        colors: const <Color>[
                                          Color(0xFF991B1B),
                                          Color(0xFFEF4444),
                                        ],
                                      ),
                                      const SizedBox(height: 2.5),
                                      TutorialHudAnchorChip(
                                        anchorId: TutorialAnchorId.hudEnergy,
                                        child: _buildMiniBar(
                                          label:
                                              'ENERJİ ${p.energy}/${p.maxEnergy}',
                                          ratio: enRatio,
                                          colors: const <Color>[
                                            Color(0xFF0369A1),
                                            Color(0xFF38BDF8),
                                          ],
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
                    ),
                    const SizedBox(width: 6),
                    // Compact Currency + Bell + Radar Toggle
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            TutorialHudAnchorChip(
                              anchorId: TutorialAnchorId.hudGold,
                              child: GestureDetector(
                                onTap: () => context.push(AppRoutes.bank),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.paid_rounded,
                                      size: 13,
                                      color: Color(0xFFFBBF24),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _compactNum(p.gold),
                                      style: const TextStyle(
                                        color: Color(0xFFFEF08A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            TutorialHudAnchorChip(
                              anchorId: TutorialAnchorId.hudGems,
                              child: GestureDetector(
                                onTap: () => context.push(AppRoutes.shop),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.diamond_rounded,
                                      size: 12,
                                      color: Color(0xFF38BDF8),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _compactNum(p.gems),
                                      style: const TextStyle(
                                        color: Color(0xFFBAE6FD),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const SizedBox(
                          height: 28,
                          width: 28,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: NotificationBellButton(),
                          ),
                        ),
                        const SizedBox(width: 3),
                        // Collapsible Live Başkent Radar Toggle (Long-press: Channel Sheet)
                        GestureDetector(
                          onTap: () => setState(
                            () => _showMobileMinimap = !_showMobileMinimap,
                          ),
                          onLongPress: _openChannelAndDistrictSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _showMobileMinimap
                                  ? const Color(0xFFD97706).withValues(alpha: 0.28)
                                  : const Color(0xFF151F32),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFBBF24)
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.radar_rounded,
                                  size: 13,
                                  color: Color(0xFF4ADE80),
                                ),
                                Text(
                                  'K${hubState.currentChannel}•$onlineCount',
                                  style: const TextStyle(
                                    color: Color(0xFFFEF08A),
                                    fontSize: 8.2,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Row 2: One-Thumb Horizontal Quick Activity Strip
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _buildMobileQuickChip(
                      emoji: '🏰',
                      icon: Icons.fort_rounded,
                      label: 'Zindan',
                      accent: const Color(0xFFF59E0B),
                      emphasized: true,
                      onTap: () => context.push(AppRoutes.dungeon),
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      chipKey: const Key('moradon_channel_switcher_chip'),
                      emoji: '🌐',
                      icon: Icons.public_rounded,
                      label:
                          'K${hubState.currentChannel} • ${hubState.currentDistrict.name}',
                      accent: const Color(0xFF38BDF8),
                      onTap: _openChannelAndDistrictSheet,
                    ),
                    const SizedBox(width: 5),
                    const GraphicsQuickPill(),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      chipKey: const Key('moradon_mount_chip'),
                      emoji: '🐎',
                      icon: Icons.pets_rounded,
                      label: hubState.mountedSteed.isMounted
                          ? hubState.mountedSteed.labelTr
                          : 'Binek',
                      accent: hubState.mountedSteed.isMounted
                          ? hubState.mountedSteed.accentColor
                          : const Color(0xFFF59E0B),
                      emphasized: hubState.mountedSteed.isMounted,
                      onTap: notifier.toggleMount,
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      chipKey: const Key('moradon_emote_chip'),
                      emoji: '🎭',
                      icon: Icons.celebration_rounded,
                      label: 'İfade',
                      accent: const Color(0xFFE879F9),
                      emphasized: hubState.activeEmote != null &&
                          !hubState.activeEmote!.isExpired,
                      onTap: notifier.cycleQuickEmote,
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      chipKey: const Key('moradon_world_boss_chip'),
                      emoji: '👹',
                      icon: Icons.whatshot_rounded,
                      label: hubState.worldBoss.isActive &&
                              !hubState.worldBoss.isDefeated
                          ? 'Boss %${(hubState.worldBoss.hpRatio * 100).round()}'
                          : 'Boss',
                      accent: const Color(0xFFEF4444),
                      emphasized: hubState.worldBoss.isActive &&
                          !hubState.worldBoss.isDefeated,
                      onTap: notifier.toggleWorldBossRaid,
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      emoji: '🎥',
                      icon: Icons.threed_rotation_rounded,
                      label: hubState.is3dPerspective ? '3D Açık' : '2D Düz',
                      accent: const Color(0xFF22D3EE),
                      emphasized: hubState.is3dPerspective,
                      onTap: notifier.toggle3dPerspective,
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      emoji: '⚔️',
                      icon: Icons.sports_kabaddi_rounded,
                      label: 'PvP Arena',
                      accent: const Color(0xFFF87171),
                      onTap: () => context.push(AppRoutes.pvp),
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      emoji: '🔥',
                      icon: Icons.local_fire_department_rounded,
                      label: '+Basma',
                      accent: const Color(0xFFFB923C),
                      onTap: () => context.push(AppRoutes.enhancement),
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      emoji: '⚖️',
                      icon: Icons.storefront_rounded,
                      label: 'Pazar',
                      accent: const Color(0xFF34D399),
                      onTap: () => context.push(AppRoutes.market),
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      emoji: '📍',
                      icon: Icons.explore_rounded,
                      label: 'NPC Rehber',
                      accent: const Color(0xFF38BDF8),
                      onTap: () => setState(
                        () => _showNpcDirectory = !_showNpcDirectory,
                      ),
                    ),
                    const SizedBox(width: 5),
                    TutorialAnchorScope(
                      id: TutorialAnchorId.homePromo,
                      child: _buildMobileQuickChip(
                        emoji: '📢',
                        icon: Icons.campaign_rounded,
                        label: 'Duyuru',
                        accent: const Color(0xFFFBBF24),
                        onTap: _openPromoSheet,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      emoji: '🏆',
                      icon: Icons.emoji_events_rounded,
                      label: 'Sıralama',
                      accent: const Color(0xFF60A5FA),
                      onTap: () => context.push(AppRoutes.leaderboard),
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      emoji: '🔍',
                      icon: Icons.zoom_out_rounded,
                      label: 'Uzaklaş',
                      accent: const Color(0xFF94A3B8),
                      onTap: () => notifier.adjustZoom(-0.10),
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      emoji: '🔎',
                      icon: Icons.zoom_in_rounded,
                      label: 'Yaklaş',
                      accent: const Color(0xFF94A3B8),
                      onTap: () => notifier.adjustZoom(0.10),
                    ),
                    const SizedBox(width: 5),
                    _buildMobileQuickChip(
                      emoji: '🎛️',
                      icon: Icons.dashboard_customize_rounded,
                      label: 'Klasik',
                      accent: const Color(0xFFC084FC),
                      onTap: notifier.toggleClassicViewMode,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Collapsible Mobile Live Radar Drawer (top-right when toggled)
        if (_showMobileMinimap)
          Positioned(
            top: topInset + 96,
            right: 10,
            child: _buildMinimapCluster(
              hubState,
              notifier,
              screenSize,
              atmosphere,
            ),
          ),

        // 3. Optional Collapsible NPC Quick-Travel Directory Popover
        if (_showNpcDirectory)
          Positioned(
            top: topInset + 96,
            left: 10,
            right: 10,
            child: Align(
              alignment: Alignment.topRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 276),
                child: _buildNpcDirectoryCard(hubState, notifier),
              ),
            ),
          ),

        // 4. Live Town Celebration Banner
        if (celebration != null && selectedPlayer == null && !_showMobileMinimap)
          Positioned(
            top: topInset + 96,
            left: 12,
            right: 12,
            child: IgnorePointer(
              child: Center(
                child: _buildCelebrationBanner(celebration),
              ),
            ),
          ),

        // 5. Selected Remote Player Target Bar
        if (selectedPlayer != null)
          Positioned(
            top: topInset + 96,
            left: 10,
            right: 10,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildTargetPlayerBar(selectedPlayer, notifier),
              ),
            ),
          ),

        // 6. Active NPC Dialogue Modal (above thumb controls)
        if (activeNpc != null)
          Positioned(
            left: 10,
            right: 10,
            bottom: bottomInset + 114,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildNpcDialogCard(activeNpc, notifier),
              ),
            ),
          ),

        // 7. Bottom-Left: Responsive 360° Analog Thumb Joystick
        Positioned(
          left: 12,
          bottom: bottomInset + 6,
          child: _buildVirtualJoystick(notifier),
        ),

        // 8. Bottom-Center: Compact Mobile Chat & Merchant Pill (opens keyboard-safe sheet)
        Positioned(
          left: 118,
          right: 118,
          bottom: bottomInset + 14,
          child: Center(
            child: _buildMobileCenterSocialPill(hubState, notifier),
          ),
        ),

        // 9. Bottom-Right: Tactile Action RPG Combat & Quick-Interact Cluster
        Positioned(
          right: 12,
          bottom: bottomInset + 4,
          child: _buildActionSkillCluster(hubState, notifier, compact: false),
        ),
      ],
    );
  }

  Widget _buildMobileQuickChip({
    Key? chipKey,
    required String emoji,
    IconData? icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
    bool emphasized = false,
  }) {
    return GestureDetector(
      key: chipKey,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          gradient: emphasized
              ? LinearGradient(
                  colors: <Color>[
                    accent.withValues(alpha: 0.34),
                    const Color(0xEB0B1120),
                  ],
                )
              : null,
          color: emphasized ? null : const Color(0xDE0B1120),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent.withValues(alpha: emphasized ? 0.85 : 0.48),
            width: emphasized ? 1.2 : 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null)
              Icon(
                icon,
                size: 13.5,
                color: Color.lerp(accent, Colors.white, emphasized ? 0.25 : 0.0)!,
              )
            else
              Text(emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: emphasized ? const Color(0xFFFEF08A) : Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMobileChatSheet(
    MoradonHubState hubState,
    MoradonHubNotifier notifier,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF60A0F1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            12,
            14,
            MediaQuery.viewInsetsOf(sheetCtx).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    '💬 BAŞKENT MEYDAN SOHBETİ',
                    style: TextStyle(
                      color: Color(0xFFFEF08A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      _promptMerchantMode(hubState, notifier);
                    },
                    icon: const Icon(
                      Icons.storefront_rounded,
                      size: 16,
                      color: Color(0xFFFBBF24),
                    ),
                    label: Text(
                      hubState.isMerchant ? 'Tezgahı Boz' : 'Pazar Kur',
                      style: const TextStyle(
                        color: Color(0xFFFEF08A),
                        fontSize: 11.5,
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
                    child: TextField(
                      controller: _chatCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (String val) {
                        notifier.sendChatBubble(val);
                        _chatCtrl.clear();
                        Navigator.of(sheetCtx).pop();
                      },
                      decoration: InputDecoration(
                        hintText: 'Başının üstünde konuşma balonu çıkar...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF141D2E),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                    ),
                    onPressed: () {
                      notifier.sendChatBubble(_chatCtrl.text);
                      _chatCtrl.clear();
                      Navigator.of(sheetCtx).pop();
                    },
                    child: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileCenterSocialPill(
    MoradonHubState hubState,
    MoradonHubNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xE0080C16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.55),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black87, blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: GestureDetector(
              onTap: () => _openMobileChatSheet(hubState, notifier),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 13,
                      color: Color(0xFF38BDF8),
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Sohbet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 14, color: Colors.white12),
          GestureDetector(
            onTap: () => _promptMerchantMode(hubState, notifier),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: Icon(
                hubState.isMerchant
                    ? Icons.store_mall_directory_outlined
                    : Icons.storefront_rounded,
                size: 15,
                color: hubState.isMerchant
                    ? const Color(0xFFF87171)
                    : const Color(0xFFFBBF24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _resolvedShardOnlineCount(MoradonHubState hubState) {
    final int localPlusRealPeers = hubState.remotePlayers.values
            .where((MoradonPlayerPresence rp) => !rp.isAmbientBot)
            .length +
        1;
    return math.max(hubState.channelOnlineCount, localPlusRealPeers);
  }

  Widget _buildActionSkillCluster(
    MoradonHubState hubState,
    MoradonHubNotifier notifier, {
    required bool compact,
  }) {
    final bool attacking = hubState.attackProgress > 0.01;
    final int comboNum = (hubState.comboStage % 3) + 1;
    final int streak = hubState.comboStreak;
    final String primaryAttackLabel = streak >= 2 ? 'x$streak' : 'SALDIR';

    if (compact) {
      return GestureDetector(
        key: const Key('moradon_attack_btn'),
        onTap: () {
          if (comboNum == 3) {
            HapticFeedback.mediumImpact();
          } else {
            HapticFeedback.lightImpact();
          }
          notifier.triggerHeroAttack();
        },
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: <Color>[Color(0xFFF97316), Color(0xFF991B1B)],
            ),
            border: Border.all(
              color: const Color(0xFFFEF08A),
              width: attacking ? 2.2 : 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFF97316).withValues(alpha: 0.55),
                blurRadius: attacking ? 18 : 10,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const _GothicCrossedBladesIcon(
                size: 20,
                color: Color(0xFFFEF9C3),
              ),
              const SizedBox(height: 1),
              Text(
                primaryAttackLabel,
                style: const TextStyle(
                  color: Color(0xFFFEF08A),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Upper satellite: Nearest NPC 1-Tap Interact
          Positioned(
            top: 0,
            right: 6,
            child: GestureDetector(
              key: const Key('moradon_nearest_npc_btn'),
              onTap: () {
                HapticFeedback.selectionClick();
                notifier.interactNearestNpc();
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xEB0F172A),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.82),
                    width: 1.2,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Colors.black87, blurRadius: 8),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.forum_rounded,
                      size: 13.5,
                      color: Color(0xFF38BDF8),
                    ),
                    Text(
                      'NPC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7.4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Lower-left satellite: Central Plaza Fast-Return
          Positioned(
            bottom: 6,
            left: 0,
            child: GestureDetector(
              key: const Key('moradon_center_return_btn'),
              onTap: () {
                HapticFeedback.selectionClick();
                notifier.teleportToTownCenter();
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xEB0F172A),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.78),
                    width: 1.2,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Colors.black87, blurRadius: 8),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.castle_rounded,
                      size: 13.5,
                      color: Color(0xFF34D399),
                    ),
                    Text(
                      'Merkez',
                      style: TextStyle(
                        color: Color(0xFFD1FAE5),
                        fontSize: 6.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Primary Thumb Attack Button (64x64)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              key: const Key('moradon_attack_btn'),
              onTap: () {
                HapticFeedback.lightImpact();
                notifier.triggerHeroAttack();
              },
              child: AnimatedScale(
                scale: attacking ? 0.93 : 1.0,
                duration: const Duration(milliseconds: 90),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: <Color>[
                        Color(0xFFFB923C),
                        Color(0xFFEA580C),
                        Color(0xFF7F1D1D),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFFEF08A),
                      width: attacking ? 2.4 : 1.6,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFFF97316)
                            .withValues(alpha: attacking ? 0.75 : 0.45),
                        blurRadius: attacking ? 20 : 12,
                      ),
                      const BoxShadow(color: Colors.black87, blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const _GothicCrossedBladesIcon(
                        size: 22,
                        color: Color(0xFFFEF9C3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        primaryAttackLabel,
                        style: const TextStyle(
                          color: Color(0xFFFEF9C3),
                          fontSize: 8.2,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _compactNum(num value) {
    final double v = value.toDouble();
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  Widget _buildRoyalTreasuryRibbon({bool compact = false}) {
    final PlayerProfile p = widget.profile;
    final int tolerance = p.tolerance.clamp(0, 100);
    final Color tolColor = tolerance >= 60
        ? const Color(0xFFEF4444)
        : (tolerance >= 40 ? const Color(0xFFF59E0B) : const Color(0xFF34D399));

    Widget buildCurrencyChip({
      required IconData icon,
      required Color iconColor,
      required String value,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 9,
            vertical: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xDE070B14),
            Color(0xEB0E1526),
            Color(0xDE070B14),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.72),
          width: 1.15,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black87, blurRadius: 14, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!compact) ...<Widget>[
            const Icon(
              Icons.castle_rounded,
              size: 13,
              color: Color(0xFFFBBF24),
            ),
            const SizedBox(width: 5),
            const Text(
              'GÖLGE BAŞKENTİ',
              style: TextStyle(
                color: Color(0xFFFEF08A),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
            Container(
              width: 1,
              height: 15,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.white12,
            ),
          ],
          TutorialHudAnchorChip(
            anchorId: TutorialAnchorId.hudGold,
            child: buildCurrencyChip(
              icon: Icons.paid_rounded,
              iconColor: const Color(0xFFFBBF24),
              value: _compactNum(p.gold),
              onTap: () => context.push(AppRoutes.bank),
            ),
          ),
          Container(width: 1, height: 14, color: Colors.white12),
          TutorialHudAnchorChip(
            anchorId: TutorialAnchorId.hudGems,
            child: buildCurrencyChip(
              icon: Icons.diamond_rounded,
              iconColor: const Color(0xFF38BDF8),
              value: _compactNum(p.gems),
              onTap: () => context.push(AppRoutes.shop),
            ),
          ),
          Container(width: 1, height: 14, color: Colors.white12),
          TutorialHudAnchorChip(
            anchorId: TutorialAnchorId.hudEnergy,
            child: buildCurrencyChip(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFFACC15),
              value: '${p.energy}/${p.maxEnergy}',
              onTap: () => context.push(AppRoutes.mekans),
            ),
          ),
          if (!compact) ...<Widget>[
            Container(width: 1, height: 14, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.balance_rounded, size: 13, color: tolColor),
                  const SizedBox(width: 3),
                  Text(
                    '$tolerance%',
                    style: TextStyle(
                      color: tolColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Container(width: 1, height: 14, color: Colors.white12),
          const SizedBox(width: 2),
          const SizedBox(
            height: 28,
            width: 30,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: NotificationBellButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerHudCard(MoradonHubState hubState) {
    final PlayerProfile p = widget.profile;
    final double hpRatio =
        p.maxHealth > 0 ? (p.health / p.maxHealth).clamp(0.0, 1.0) : 1.0;
    final double enRatio =
        p.maxEnergy > 0 ? (p.energy / p.maxEnergy).clamp(0.0, 1.0) : 1.0;
    final xpProg = buildXpProgress(level: p.level, totalXp: p.xp);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _openHeroEquipmentSheet,
        child: Container(
          width: 232,
          padding: const EdgeInsets.fromLTRB(10, 9, 11, 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xEC0B1120), Color(0xE0050811)],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFD97706).withValues(alpha: 0.78),
              width: 1.25,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      ProfileAvatar(
                        size: 38,
                        avatarUrl: p.avatarUrl,
                        backgroundColor:
                            const Color(0xFFB45309).withValues(alpha: 0.28),
                        glowFrame: p.avatarFrame == 'glow',
                        codexFrame: p.avatarFrame == 'codex',
                      ),
                      Positioned(
                        bottom: -3,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFBBF24),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            '${xpProg.level}',
                            style: const TextStyle(
                              color: Color(0xFFFEF08A),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          p.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: xpProg.percent.clamp(0.0, 1.0),
                            minHeight: 3.5,
                            backgroundColor: const Color(0xFF1E293B),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF34D399),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Image.asset(
                    'assets/ui/character_status_bar/gucicon.png',
                    width: 18,
                    height: 18,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.shield_moon_outlined,
                      color: Color(0xFFFBBF24),
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              TutorialAnchorScope(
                id: TutorialAnchorId.hudHealth,
                onTutorialTap: () async {
                  await ref
                      .read(tutorialProvider.notifier)
                      .onAnchorTap(TutorialAnchorId.hudHealth);
                },
                child: Column(
                  children: <Widget>[
                    _buildMiniBar(
                      label: 'CAN ${p.health}/${p.maxHealth}',
                      ratio: hpRatio,
                      colors: const <Color>[
                        Color(0xFF991B1B),
                        Color(0xFFEF4444),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildMiniBar(
                      label: 'ENERJİ ${p.energy}/${p.maxEnergy}',
                      ratio: enRatio,
                      colors: const <Color>[
                        Color(0xFF0369A1),
                        Color(0xFF38BDF8),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (BuildContext context) {
                  final String rawClass =
                      p.characterClass?.name.toLowerCase() ?? 'savasci';
                  final String classKey = rawClass.contains('golge')
                      ? 'golge'
                      : (rawClass.contains('simyaci') ? 'simyaci' : 'savasci');
                  int maxEnh = 0;
                  for (final InventoryItem? it
                      in widget.inventoryState.equippedItems.values) {
                    if (it != null && it.enhancementLevel > maxEnh) {
                      maxEnh = it.enhancementLevel;
                    }
                  }
                  final int glow = maxEnh >= 7
                      ? maxEnh.clamp(7, 10)
                      : (widget.totalPower >= 8000
                          ? 10
                          : (widget.totalPower >= 4000 ? 9 : 7));
                  final (MoradonWeaponVisual _, String weaponLabel) =
                      resolveEquippedWeaponSpec(
                    inventoryState: widget.inventoryState,
                    classKey: classKey,
                    glowLevel: glow,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '🗡️ $weaponLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 9.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      '⚔️ Güç: ${formatCharacterPower(widget.totalPower)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFDE047),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Zırh ▸',
                    style: TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBar({
    required String label,
    required double ratio,
    required List<Color> colors,
  }) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: <Widget>[
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        FractionallySizedBox(
          widthFactor: ratio,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMinimapCluster(
    MoradonHubState hubState,
    MoradonHubNotifier notifier,
    Size viewportSize,
    MoradonAtmospherePhase atmosphere,
  ) {
    final int onlineCount = _resolvedShardOnlineCount(hubState);
    final bool isDesktopWide = viewportSize.width >= 760;
    final int coordX = (hubState.playerX / 4).round();
    final int coordZ = (hubState.playerY / 4).round();
    const double mapW = 168.0;
    const double mapH = 98.0;

    void navigateFromMinimapOffset(Offset localPos) {
      final double nx = (localPos.dx / mapW).clamp(0.0, 1.0);
      final double ny = (localPos.dy / mapH).clamp(0.0, 1.0);
      notifier.moveToWorldPoint(
        nx * MoradonHubState.worldWidth,
        ny * MoradonHubState.worldHeight,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTapUp: (TapUpDetails d) =>
              navigateFromMinimapOffset(d.localPosition),
          onPanUpdate: (DragUpdateDetails d) =>
              navigateFromMinimapOffset(d.localPosition),
          child: Container(
            width: mapW,
            height: mapH,
            decoration: BoxDecoration(
              color: const Color(0xEB070B14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD97706).withValues(alpha: 0.78),
                width: 1.3,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Colors.black87, blurRadius: 12),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.5),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Image.asset(
                      'assets/moradon/citadel_dungeon_v9.jpg',
                      fit: BoxFit.cover,
                      cacheWidth: 320,
                      filterQuality: FilterQuality.low,
                      opacity: const AlwaysStoppedAnimation<double>(0.68),
                      errorBuilder: (_, _, _) => Image.network(
                        'assets/assets/moradon/citadel_dungeon_v9.jpg',
                        fit: BoxFit.cover,
                        cacheWidth: 320,
                        filterQuality: FilterQuality.low,
                        opacity: const AlwaysStoppedAnimation<double>(0.68),
                        errorBuilder: (_, _, _) => const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: <Color>[
                                Color(0xFF283246),
                                Color(0xFF0E131F),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MoradonMinimapPainter(
                        hubState: hubState,
                        viewportSize: viewportSize,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 6,
                    right: 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hubState.realtimeConnected
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFFFBBF24),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'K${hubState.currentChannel} ${hubState.currentDistrict.emoji} ($onlineCount)',
                              style: const TextStyle(
                                color: Color(0xFFFEF08A),
                                fontSize: 8.2,
                                fontWeight: FontWeight.w900,
                                shadows: <Shadow>[
                                  Shadow(color: Colors.black, blurRadius: 3),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$coordX,$coordZ',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            shadows: <Shadow>[
                              Shadow(color: Colors.black, blurRadius: 3),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 6,
                    child: Text(
                      hubState.currentDistrict.name,
                      style: const TextStyle(
                        color: Color(0xFFBAE6FD),
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        shadows: <Shadow>[
                          Shadow(color: Colors.black, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 5,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _buildZoomMicroBtn(
                          label: '−',
                          onTap: () => notifier.adjustZoom(-0.10),
                        ),
                        const SizedBox(width: 3),
                        _buildZoomMicroBtn(
                          label: '+',
                          onTap: () => notifier.adjustZoom(0.10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktopWide ? 268 : 244),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              _buildMiniActionPill(
                pillKey: isDesktopWide
                    ? const Key('moradon_channel_switcher_chip')
                    : null,
                icon: Icons.public_rounded,
                label: 'K${hubState.currentChannel}',
                color: const Color(0xFF38BDF8),
                onTap: _openChannelAndDistrictSheet,
              ),
              _buildMiniActionPill(
                icon: Icons.my_location,
                label: 'Meydan',
                color: const Color(0xFF60A5FA),
                onTap: notifier.teleportToTownCenter,
              ),
              _buildMiniActionPill(
                icon: Icons.place_outlined,
                label: 'NPC',
                color: const Color(0xFF34D399),
                onTap: () =>
                    setState(() => _showNpcDirectory = !_showNpcDirectory),
              ),
              TutorialAnchorScope(
                id: TutorialAnchorId.homePromo,
                child: _buildMiniActionPill(
                  icon: Icons.campaign_outlined,
                  label: 'Duyuru',
                  color: const Color(0xFFFBBF24),
                  onTap: _openPromoSheet,
                ),
              ),
              if (isDesktopWide) ...<Widget>[
                _buildMiniActionPill(
                  pillKey: const Key('moradon_mount_chip'),
                  icon: Icons.pets_rounded,
                  label: hubState.mountedSteed.isMounted
                      ? hubState.mountedSteed.labelTr
                      : 'Binek',
                  color: hubState.mountedSteed.isMounted
                      ? hubState.mountedSteed.accentColor
                      : const Color(0xFFF59E0B),
                  onTap: notifier.toggleMount,
                ),
                _buildMiniActionPill(
                  pillKey: const Key('moradon_emote_chip'),
                  icon: Icons.celebration_rounded,
                  label: 'İfade',
                  color: const Color(0xFFE879F9),
                  onTap: notifier.cycleQuickEmote,
                ),
                _buildMiniActionPill(
                  pillKey: const Key('moradon_world_boss_chip'),
                  icon: Icons.whatshot_rounded,
                  label: hubState.worldBoss.isActive &&
                          !hubState.worldBoss.isDefeated
                      ? 'Boss %${(hubState.worldBoss.hpRatio * 100).round()}'
                      : 'Boss',
                  color: const Color(0xFFEF4444),
                  onTap: notifier.toggleWorldBossRaid,
                ),
              ],
              _buildMiniActionPill(
                icon: atmospherePhaseIcon(atmosphere),
                label: atmosphereChoiceBadgeLabel(
                  hubState.atmosphereChoice,
                  atmosphere,
                ),
                color: atmospherePhaseAccent(atmosphere),
                onTap: notifier.cycleAtmosphereChoice,
              ),
              _buildMiniActionPill(
                icon: Icons.threed_rotation_rounded,
                label: hubState.is3dPerspective ? '3D' : '2D',
                color: const Color(0xFF22D3EE),
                onTap: notifier.toggle3dPerspective,
              ),
              if (isDesktopWide) const GraphicsQuickPill(),
              _buildMiniActionPill(
                icon: Icons.grid_view_rounded,
                label: 'Klasik',
                color: const Color(0xFFC084FC),
                onTap: notifier.toggleClassicViewMode,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCelebrationBanner(MoradonCelebrationEvent event) {
    final bool isCrate = event.isCrateDrop;
    final bool isPlus10 = event.enhancementLevel >= 10;
    final Color accent = isCrate
        ? const Color(0xFF34D399)
        : (isPlus10 ? const Color(0xFFF43F5E) : const Color(0xFFFBBF24));
    final String headline = isCrate
        ? '🎁 HAN KASASI MÜJDESİ'
        : '🔥 BAŞKENT OCAĞI KUTLAMASI';
    final String detail = isCrate
        ? '${event.username} kasadan efsanevi «${event.itemName}» çıkardı!'
        : '${event.username} ocağında «+${event.enhancementLevel} ${event.itemName}» bastı!';

    return Container(
      constraints: const BoxConstraints(maxWidth: 470),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            const Color(0xF2090D16),
            accent.withValues(alpha: 0.28),
            const Color(0xF2090D16),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent, width: 1.3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.45),
            blurRadius: 16,
          ),
          const BoxShadow(color: Colors.black87, blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            headline,
            style: TextStyle(
              color: accent,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFEF9C3),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomMicroBtn({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 17,
        height: 17,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xD8090D16),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.55),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFEF08A),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildNpcDirectoryCard(
    MoradonHubState hubState,
    MoradonHubNotifier notifier,
  ) {
    final double maxListHeight =
        (MediaQuery.sizeOf(context).height - 230).clamp(100.0, 320.0);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xF2090D16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.65),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black87, blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Flexible(
                child: Text(
                  'BAŞKENT HIZLI ULAŞIM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFFEF08A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _showNpcDirectory = false),
                child: const Icon(Icons.close, size: 15, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () {
              setState(() => _showNpcDirectory = false);
              _openChannelAndDistrictSheet();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF14213A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Text('🌐', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'K${hubState.currentChannel} Kanal & 8 Mahalle Işınlan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFBAE6FD),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new_rounded,
                    size: 13,
                    color: Color(0xFF38BDF8),
                  ),
                ],
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final MoradonNpcDefinition npc in kMoradonNpcs)
                    InkWell(
                      onTap: () {
                        setState(() => _showNpcDirectory = false);
                        notifier.interactWithNpc(npc);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: npc.accentColor,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                npc.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 15,
                              color: Colors.white38,
                            ),
                          ],
                        ),
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

  Widget _buildMiniActionPill({
    Key? pillKey,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: pillKey,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xEB0B1120),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 11.5, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetPlayerBar(
    MoradonPlayerPresence target,
    MoradonHubNotifier notifier,
  ) {
    final double maxPanelHeight =
        (MediaQuery.sizeOf(context).height * 0.56).clamp(180.0, 440.0);
    final List<CharacterInspectAction> actions = <CharacterInspectAction>[
      CharacterInspectAction(
        emoji: '⚔️',
        label: 'Düello (PvP)',
        color: const Color(0xFFF87171),
        onTap: () => context.push(AppRoutes.pvp),
      ),
      CharacterInspectAction(
        emoji: '🤝',
        label: 'Ticaret',
        color: const Color(0xFF4ADE80),
        onTap: () => context.push(AppRoutes.trade),
      ),
      if (target.isMerchant)
        CharacterInspectAction(
          emoji: '🛒',
          label: 'Tezgaha Bak',
          color: const Color(0xFFFBBF24),
          onTap: () => context.push(AppRoutes.market),
        ),
      CharacterInspectAction(
        emoji: '💬',
        label: 'Sohbet',
        color: const Color(0xFF38BDF8),
        onTap: () => context.push(AppRoutes.chat),
      ),
      CharacterInspectAction(
        emoji: '👥',
        label: 'Arkadaş',
        color: const Color(0xFFC084FC),
        onTap: () => context.push(AppRoutes.friends),
      ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxPanelHeight),
      child: SingleChildScrollView(
        child: CharacterInspectPanel(
          seed: InspectedCharacterData.seedFromMoradonPresence(target),
          onClose: notifier.clearSelection,
          actions: actions,
        ),
      ),
    );
  }

  Widget _buildNpcDialogCard(
    MoradonNpcDefinition npc,
    MoradonHubNotifier notifier,
  ) {
    final double maxCardHeight =
        (MediaQuery.sizeOf(context).height - 220).clamp(136.0, 380.0);
    return Container(
      constraints: BoxConstraints(maxHeight: maxCardHeight),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xF50B1120),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: npc.accentColor, width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: npc.accentColor.withValues(alpha: 0.25),
            blurRadius: 20,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
          Row(
            children: <Widget>[
              if (npc.assetPath.isEmpty || npc.isArchitecturalZone)
                Container(
                  key: Key('moradon_npc_emblem_${npc.id}'),
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        npc.accentColor.withValues(alpha: 0.34),
                        const Color(0xFF0B1120),
                      ],
                    ),
                    border: Border.all(
                      color: npc.accentColor.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: npc.accentColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Text(
                    npc.badgeEmoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                )
              else
                Image.asset(
                  npc.assetPath,
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Image.network(
                    'assets/${npc.assetPath}',
                    width: 64,
                    height: 64,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0F172A),
                        border: Border.all(color: npc.accentColor),
                      ),
                      child: Text(
                        npc.badgeEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      npc.title,
                      style: TextStyle(
                        color: npc.accentColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      npc.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '"${npc.quote}"',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: notifier.clearSelection,
                icon: const Icon(Icons.close, color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: npc.actions.map((MoradonNpcAction act) {
              return InkWell(
                onTap: () {
                  notifier.clearSelection();
                  context.push(act.route);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: npc.accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: npc.accentColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(act.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                act.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                act.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 9.5,
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
            }).toList(),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildVirtualJoystick(MoradonHubNotifier notifier) {
    const double outerSize = 92.0;
    const double knobSize = 36.0;
    const double maxRadius = (outerSize - knobSize) / 2;

    void updateStick(Offset localPos) {
      final Offset local =
          localPos - const Offset(outerSize / 2, outerSize / 2);
      final double dist = local.distance;
      final Offset clamped =
          dist > maxRadius ? (local / dist) * maxRadius : local;
      setState(() {
        _joystickDelta = Offset(
          clamped.dx / maxRadius,
          clamped.dy / maxRadius,
        );
      });
      notifier.nudgeByJoystick(_joystickDelta);
    }

    void resetStick() {
      setState(() {
        _joystickDelta = Offset.zero;
      });
      notifier.nudgeByJoystick(Offset.zero);
    }

    final bool active = _joystickDelta.distance > 0.08;

    return GestureDetector(
      onPanStart: (DragStartDetails d) => updateStick(d.localPosition),
      onPanUpdate: (DragUpdateDetails d) => updateStick(d.localPosition),
      onPanEnd: (_) => resetStick(),
      onPanCancel: resetStick,
      child: Container(
        width: outerSize,
        height: outerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x9C090D16),
          border: Border.all(
            color: const Color(0xFFFBBF24)
                .withValues(alpha: active ? 0.85 : 0.45),
            width: active ? 1.8 : 1.4,
          ),
          boxShadow: <BoxShadow>[
            if (active)
              BoxShadow(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.28),
                blurRadius: 14,
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Subtle directional chevrons
            const Positioned(
              top: 5,
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 13,
                color: Colors.white30,
              ),
            ),
            const Positioned(
              bottom: 5,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 13,
                color: Colors.white30,
              ),
            ),
            const Positioned(
              left: 5,
              child: Icon(
                Icons.keyboard_arrow_left_rounded,
                size: 13,
                color: Colors.white30,
              ),
            ),
            const Positioned(
              right: 5,
              child: Icon(
                Icons.keyboard_arrow_right_rounded,
                size: 13,
                color: Colors.white30,
              ),
            ),
            Transform.translate(
              offset: Offset(
                _joystickDelta.dx * maxRadius,
                _joystickDelta.dy * maxRadius,
              ),
              child: Container(
                width: knobSize,
                height: knobSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: active
                        ? const <Color>[Color(0xFFFDE047), Color(0xFFB45309)]
                        : const <Color>[Color(0xFF334155), Color(0xFF0F172A)],
                  ),
                  border: Border.all(
                    color: const Color(0xFFFBBF24)
                        .withValues(alpha: active ? 0.95 : 0.55),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: active
                          ? const Color(0xFFFBBF24).withValues(alpha: 0.60)
                          : Colors.black87,
                      blurRadius: active ? 12 : 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTownBar(
    MoradonHubState hubState,
    MoradonHubNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xEB080C16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.5),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black87, blurRadius: 12),
        ],
      ),
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: () => _promptMerchantMode(hubState, notifier),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: hubState.isMerchant
                    ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hubState.isMerchant
                      ? const Color(0xFFF87171)
                      : const Color(0xFFFBBF24),
                ),
              ),
              child: Text(
                hubState.isMerchant ? '🛑 Tezgahı Boz' : '🏪 Pazar Kur',
                style: TextStyle(
                  color: hubState.isMerchant
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFFEF08A),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 34,
              child: TextField(
                controller: _chatCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textInputAction: TextInputAction.send,
                onSubmitted: (String value) {
                  notifier.sendChatBubble(value);
                  _chatCtrl.clear();
                },
                decoration: InputDecoration(
                  hintText: 'Başkent meydanında yaz (Enter)...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  filled: true,
                  fillColor: const Color(0xFF141D2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              notifier.sendChatBubble(_chatCtrl.text);
              _chatCtrl.clear();
            },
            icon: const Icon(
              Icons.send_rounded,
              color: Color(0xFFFBBF24),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoradonMinimapPainter extends CustomPainter {
  final MoradonHubState hubState;
  final Size viewportSize;

  const _MoradonMinimapPainter({
    required this.hubState,
    required this.viewportSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double worldW = MoradonHubState.worldWidth;
    const double worldH = MoradonHubState.worldHeight;
    final double sx = size.width / worldW;
    final double sy = size.height / worldH;

    // 1. Live Camera Viewport Frame
    final double minZoom = math.max(
      MoradonHubState.minWorldZoom,
      math.max(viewportSize.width / worldW, viewportSize.height / worldH),
    );
    final double scale = math.max(hubState.zoom, minZoom);
    final double visW = viewportSize.width / scale;
    final double visH = viewportSize.height / scale;
    final double vFocus = viewportSize.width < 680 ? 0.61 : 0.52;
    final double camX =
        (hubState.playerX - visW / 2).clamp(0.0, math.max(0.0, worldW - visW));
    final double camY = (hubState.playerY - visH * vFocus)
        .clamp(0.0, math.max(0.0, worldH - visH));
    final RRect camRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(camX * sx, camY * sy, visW * sx, visH * sy),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(
      camRRect,
      Paint()
        ..color = const Color(0x1FFDE68A)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      camRRect,
      Paint()
        ..color = const Color(0xA8FDE68A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 2. NPC Landmarks + Sparring Dummies + Active World Boss Raid Beacon
    for (final MoradonNpcDefinition npc in kMoradonNpcs) {
      canvas.drawCircle(
        Offset(npc.x * sx, npc.y * sy),
        2.9,
        Paint()..color = npc.accentColor,
      );
    }
    for (final MoradonTrainingDummy d in kMoradonTrainingDummies) {
      canvas.drawCircle(
        Offset(d.x * sx, d.y * sy),
        1.7,
        Paint()..color = d.accentColor.withValues(alpha: 0.72),
      );
    }
    if (hubState.worldBoss.isActive && !hubState.worldBoss.isDefeated) {
      final Offset bossPos = Offset(
        hubState.worldBoss.x * sx,
        hubState.worldBoss.y * sy,
      );
      canvas.drawCircle(
        bossPos,
        5.2,
        Paint()..color = const Color(0x55EF4444),
      );
      canvas.drawCircle(
        bossPos,
        3.2,
        Paint()..color = const Color(0xFFEF4444),
      );
    }

    // 3. Patrol Guards (Sapphire dots) + Remote Players (Emerald / Amber-Orange)
    for (final MoradonPatrolGuard g in hubState.patrolGuards) {
      canvas.drawCircle(
        Offset(g.x * sx, g.y * sy),
        2.1,
        Paint()..color = const Color(0xFF60A5FA),
      );
    }
    for (final MoradonPlayerPresence rp in hubState.remotePlayers.values) {
      final Paint rpPaint = Paint()
        ..color = rp.isMerchant
            ? const Color(0xFFF97316)
            : (rp.isAmbientBot
                ? const Color(0xFF94A3B8)
                : const Color(0xFF4ADE80));
      canvas.drawCircle(Offset(rp.x * sx, rp.y * sy), 2.3, rpPaint);
    }

    // 4. Local Player + Active Destination Line
    final Offset mePos = Offset(hubState.playerX * sx, hubState.playerY * sy);
    if (hubState.isMoving && hubState.moveRingPosition != null) {
      final Offset dstPos = Offset(
        hubState.moveRingPosition!.dx * sx,
        hubState.moveRingPosition!.dy * sy,
      );
      canvas.drawLine(
        mePos,
        dstPos,
        Paint()
          ..color = const Color(0x9938BDF8)
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(
        dstPos,
        2.0,
        Paint()..color = const Color(0xFF7DD3FC),
      );
    }

    canvas.drawCircle(
      mePos,
      5.5,
      Paint()..color = const Color(0x5538BDF8),
    );
    canvas.drawCircle(
      mePos,
      3.2,
      Paint()..color = const Color(0xFF38BDF8),
    );
  }

  @override
  bool shouldRepaint(covariant _MoradonMinimapPainter oldDelegate) {
    final MoradonHubState a = oldDelegate.hubState;
    final MoradonHubState b = hubState;
    return oldDelegate.viewportSize != viewportSize ||
        a.zoom != b.zoom ||
        a.isMoving != b.isMoving ||
        a.moveRingPosition != b.moveRingPosition ||
        a.worldBoss.isActive != b.worldBoss.isActive ||
        a.worldBoss.isDefeated != b.worldBoss.isDefeated ||
        a.remotePlayers.length != b.remotePlayers.length ||
        (a.playerX - b.playerX).abs() > 14.0 ||
        (a.playerY - b.playerY).abs() > 14.0;
  }
}

class _GothicCrossedBladesIcon extends StatelessWidget {
  const _GothicCrossedBladesIcon({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GothicCrossedBladesPainter(color: color),
      ),
    );
  }
}

class _GothicCrossedBladesPainter extends CustomPainter {
  const _GothicCrossedBladesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..strokeWidth = w * 0.14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Paint bladePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.105
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Paint guardPaint = Paint()
      ..color = color
      ..strokeWidth = w * 0.115
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Paint pommelPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Blade 1 (bottom-left hilt -> top-right tip)
    final Offset hilt1 = Offset(w * 0.16, h * 0.84);
    final Offset tip1 = Offset(w * 0.86, h * 0.14);
    canvas.drawLine(hilt1, tip1, shadowPaint);
    canvas.drawLine(Offset(w * 0.28, h * 0.72), tip1, bladePaint);
    canvas.drawLine(hilt1, Offset(w * 0.28, h * 0.72), guardPaint);
    canvas.drawLine(
      Offset(w * 0.19, h * 0.63),
      Offset(w * 0.37, h * 0.81),
      guardPaint,
    );
    canvas.drawCircle(hilt1, w * 0.065, pommelPaint);

    // Blade 2 (bottom-right hilt -> top-left tip)
    final Offset hilt2 = Offset(w * 0.84, h * 0.84);
    final Offset tip2 = Offset(w * 0.14, h * 0.14);
    canvas.drawLine(hilt2, tip2, shadowPaint);
    canvas.drawLine(Offset(w * 0.72, h * 0.72), tip2, bladePaint);
    canvas.drawLine(hilt2, Offset(w * 0.72, h * 0.72), guardPaint);
    canvas.drawLine(
      Offset(w * 0.63, h * 0.81),
      Offset(w * 0.81, h * 0.63),
      guardPaint,
    );
    canvas.drawCircle(hilt2, w * 0.065, pommelPaint);
  }

  @override
  bool shouldRepaint(covariant _GothicCrossedBladesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
