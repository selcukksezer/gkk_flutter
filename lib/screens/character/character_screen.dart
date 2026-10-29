import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/item_icon_view.dart';
import '../../components/common/profile_avatar.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../core/tutorial/tutorial_anchor_registry.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../l10n/l10n.dart';
import '../../models/inventory_model.dart';
import '../../models/player_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_badges_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/logout_helper.dart';
import 'widgets/character_glass_overlay.dart';
import 'widgets/character_turntable_viewport.dart';
import 'widgets/equipment_socket_dock.dart';

export 'widgets/character_glass_overlay.dart';
export 'widgets/character_turntable_viewport.dart';
export 'widgets/equipment_socket_dock.dart';

/// Overhauled Mobile Character Profile & Equipment Screen
/// Standardized for 2027 Aion 2 mobile visuals:
/// - 3D Character Turntable Viewport (azimuth rotation, pitch tilt, reset)
/// - Ethereal Wings with motes, Runic Pedestal & Iridescent Armor Sheen
/// - Glowing Gear Sockets with Mobile Haptic Feedback on tap / equip / unequip
/// - Non-blocking Glassmorphic Stat Overlay (minimizes for full 3D view)
/// - Fluid mobile tab transitions between Stats, Equipment, Titles, and Codex
/// - Mobile SafeArea ergonomics optimized for 390x844 viewports
class CharacterScreen extends ConsumerStatefulWidget {
  const CharacterScreen({super.key});

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen> {
  bool _claimingDetox = false;
  bool _statsExpanded = false;
  CharacterTab _currentTab = CharacterTab.stats;
  final GlobalKey _classAbilitiesSectionKey = GlobalKey();
  int _classAbilitiesScrollGeneration = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual<TutorialState>(tutorialProvider, (
      TutorialState? prev,
      TutorialState next,
    ) {
      if (next.activeStep?.id == 'character_class_abilities') {
        _queueClassAbilitiesAutoScroll();
      }
    });
    ref.listenManual<PlayerState>(playerProvider, (
      PlayerState? prev,
      PlayerState next,
    ) {
      if (next.status != PlayerStatus.ready) return;
      if (ref.read(tutorialProvider).activeStep?.id !=
          'character_class_abilities') {
        return;
      }
      _queueClassAbilitiesAutoScroll();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(playerProvider.notifier).loadProfile();
      ref.read(inventoryProvider.notifier).loadInventory();
      ref.read(playerBadgesProvider.notifier).load();
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.character);
      if (!mounted) return;
      if (ref.read(tutorialProvider).activeStep?.id ==
          'character_class_abilities') {
        _queueClassAbilitiesAutoScroll();
      }
    });
  }

  void _queueClassAbilitiesAutoScroll() {
    final int generation = ++_classAbilitiesScrollGeneration;
    unawaited(_scrollToClassAbilitiesSection(generation));
  }

  Future<void> _scrollToClassAbilitiesSection(int generation) async {
    for (int attempt = 0; attempt < 36; attempt++) {
      await Future<void>.delayed(
        Duration(milliseconds: attempt == 0 ? 120 : 48),
      );
      if (!mounted || generation != _classAbilitiesScrollGeneration) return;
      if (ref.read(playerProvider).status != PlayerStatus.ready) continue;

      // Expand stats if collapsed so abilities section is mounted
      if (!_statsExpanded) {
        setState(() {
          _statsExpanded = true;
          _currentTab = CharacterTab.stats;
        });
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
      }

      final BuildContext? target = _classAbilitiesSectionKey.currentContext;
      if (target == null || !target.mounted) continue;
      if (!mounted) return;

      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
      if (!mounted) return;
      TutorialAnchorRegistry.instance.scheduleRefresh();
      return;
    }
  }

  Future<void> _claimAlchemistDetox() async {
    setState(() => _claimingDetox = true);
    try {
      final dynamic res =
          await SupabaseService.client.rpc('claim_alchemist_detox');
      if (res is! Map) {
        if (mounted) {
          AppMessenger.showError(context, 'Beklenmeyen yanıt');
        }
        return;
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(res);
      if (data['success'] == true) {
        if (mounted) {
          AppMessenger.showSuccess(context, '✅ Minor Detox başarıyla alındı!');
        }
      } else {
        if (mounted) {
          AppMessenger.showError(
            context,
            '❌ ${data['message'] ?? 'Bir hata oluştu.'}',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, '❌ İşlem başarısız');
      }
    } finally {
      if (mounted) setState(() => _claimingDetox = false);
    }
  }

  Future<void> _handleSlotTap(EquipmentSlotDef def, InventoryItem? item) async {
    HapticFeedback.selectionClick();
    if (item != null) {
      // Equipped slot: open detail modal with unequip option
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext ctx) => EquipmentDetailModal(
          slotDef: def,
          item: item,
          onUnequip: () async {
            await _handleUnequip(def.slotKey);
          },
        ),
      );
    } else {
      // Empty slot: open quick equip selector
      await _showEquipPickerForSlot(def);
    }
  }

  Future<void> _handleUnequip(String slotKey) async {
    if (!ref.read(inventoryProvider.notifier).canDirectUnequip()) {
      AppMessenger.show(context, 'Envanter dolu — eşyayı çıkaramazsın.');
      return;
    }
    HapticFeedback.mediumImpact();
    final bool ok =
        await ref.read(inventoryProvider.notifier).unequipItem(slot: slotKey);
    if (ok && mounted) {
      AppMessenger.showSuccess(context, 'Kuşan çıkarıldı.');
    }
  }

  Future<void> _showEquipPickerForSlot(EquipmentSlotDef def) async {
    final InventoryState invState = ref.read(inventoryProvider);
    final List<InventoryItem> available = invState.items.where((InventoryItem it) {
      return it.equipSlot == def.equipSlot && !it.isEquipped;
    }).toList();

    if (available.isEmpty) {
      AppMessenger.show(
        context,
        '${def.name} yuvası için çantanda uygun eşya bulunmuyor.',
      );
      return;
    }

    final int playerLevel = ref.read(playerProvider).profile?.level ?? 1;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkObsidian,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXxl)),
        side: BorderSide(
          color: AppColors.liquidGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.base,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.borderBright.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                    ),
                  ),
                ),
                Text(
                  '${def.name} Kuşan',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: available.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int index) {
                      final InventoryItem it = available[index];
                      final Color rarityColor =
                          AppColors.forRarity(it.rarity.name);
                      final bool canEquip = playerLevel >= it.requiredLevel;

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          side: BorderSide(
                            color: rarityColor.withValues(alpha: 0.35),
                          ),
                        ),
                        tileColor: AppColors.bgSurface.withValues(alpha: 0.6),
                        leading: ItemIconView(
                          iconValue: it.icon,
                          itemId: it.itemId,
                          itemType: it.itemType,
                          size: 32,
                        ),
                        title: Text(
                          it.name,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: rarityColor,
                          ),
                        ),
                        subtitle: Text(
                          'Güç: ${it.power} · Lvl ${it.requiredLevel}',
                          style: AppTextStyles.caption.copyWith(
                            color: canEquip ? AppColors.textSecondary : AppColors.danger,
                          ),
                        ),
                        trailing: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: canEquip
                                ? AppColors.liquidGold.withValues(alpha: 0.2)
                                : AppColors.bgCard,
                            foregroundColor:
                                canEquip ? AppColors.liquidGold : AppColors.textDisabled,
                          ),
                          onPressed: canEquip
                              ? () async {
                                  Navigator.pop(ctx);
                                  HapticFeedback.mediumImpact();
                                  final bool ok = await ref
                                      .read(inventoryProvider.notifier)
                                      .equipItem(
                                        rowId: it.rowId,
                                        slot: def.slotKey,
                                      );
                                  if (ok && mounted) {
                                    AppMessenger.showSuccess(
                                      this.context,
                                      '${it.name} kuşandı!',
                                    );
                                  }
                                }
                              : null,
                          child: Text(
                            'Kuşan',
                            style: AppTextStyles.label.copyWith(
                              color: canEquip ? AppColors.liquidGold : AppColors.textDisabled,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAvatarPicker() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkObsidian,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXxl)),
        side: BorderSide(
          color: AppColors.liquidGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Profil Fotoğrafı Seç',
                  style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.base),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: ProfilePhotoCatalog.selectablePhotos.map((path) {
                    return Semantics(
                      button: true,
                      label: 'Profil fotoğrafı seç',
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          try {
                            await SupabaseService.client
                                .from('users')
                                .update(<String, Object?>{'avatar_url': path})
                                .eq(
                                  'auth_id',
                                  SupabaseService.client.auth.currentUser!.id,
                                );
                            if (mounted) {
                              ref.read(playerProvider.notifier).loadProfile();
                            }
                          } catch (e) {
                            if (mounted) {
                              AppMessenger.show(
                                context,
                                userFacingErrorMessage(
                                  e,
                                  fallback: 'Profil fotoğrafı güncellenemedi.',
                                ),
                              );
                            }
                          }
                        },
                        child: ProfileAvatar(
                          size: 64,
                          avatarUrl: path,
                          border: Border.all(color: AppColors.borderBright, width: 2),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFramePicker() async {
    if (!mounted) return;
    bool codexFrameUnlocked = false;
    try {
      final dynamic dashRaw =
          await SupabaseService.client.rpc('get_codex_dashboard');
      if (dashRaw is Map && dashRaw['success'] == true) {
        final List<dynamic> milestones = dashRaw['milestones'] is List
            ? dashRaw['milestones'] as List
            : const <dynamic>[];
        codexFrameUnlocked = milestones.any(
          (dynamic row) =>
              row is Map &&
              (row['threshold'] as num?)?.toInt() == 50 &&
              row['claimed'] == true,
        );
      }
    } catch (_) {
      // Frame picker still works with default frames.
    }

    final List<Map<String, Object?>> frames = <Map<String, Object?>>[
      <String, Object?>{'id': null, 'name': 'Çerçevesiz (Normal)'},
      <String, Object?>{'id': 'glow', 'name': '✨ Parlayan Mavi Çerçeve'},
      if (codexFrameUnlocked)
        <String, Object?>{'id': 'codex', 'name': '📖 Kodex Kaşifi Çerçevesi'},
    ];

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkObsidian,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXxl)),
        side: BorderSide(
          color: AppColors.liquidGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Çerçeve Seç',
                  style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.base),
                Column(
                  children: frames.map((frameData) {
                    return ListTile(
                      title: Text(
                        frameData['name'] as String,
                        style: AppTextStyles.bodyBold.copyWith(color: AppColors.textPrimary),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        try {
                          await SupabaseService.client
                                .from('users')
                                .update(<String, Object?>{
                                  'avatar_frame': frameData['id'],
                                })
                                .eq(
                                  'auth_id',
                                  SupabaseService.client.auth.currentUser!.id,
                                );
                          if (mounted) {
                            ref.read(playerProvider.notifier).loadProfile();
                          }
                        } catch (e) {
                          if (mounted) {
                            AppMessenger.show(
                              context,
                              userFacingErrorMessage(
                                e,
                                fallback: 'Çerçeve güncellenemedi.',
                              ),
                            );
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCustomizationPicker() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkObsidian,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXxl)),
        side: BorderSide(
          color: AppColors.liquidGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Profili Düzenle',
                  style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.base),
                ListTile(
                  leading: const Icon(Icons.person, color: AppColors.liquidGold),
                  title: Text(
                    'Profil Fotoğrafını Değiştir',
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showAvatarPicker();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.stars, color: AppColors.gold),
                  title: Text(
                    'Çerçeveyi Değiştir',
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showFramePicker();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlayerState playerState = ref.watch(playerProvider);
    final InventoryState inventoryState = ref.watch(inventoryProvider);
    final PlayerProfile? profile = playerState.profile;

    Future<void> logout() async {
      await performLogout(ref);
    }

    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.screenTitleCharacter,
        onLogout: logout,
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.character,
        onLogout: logout,
      ),
      body: switch (playerState.status) {
        PlayerStatus.initial || PlayerStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        PlayerStatus.error => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                playerState.errorMessage ?? 'Hata',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.liquidGold.withValues(alpha: 0.22),
                  foregroundColor: AppColors.liquidGold,
                  side: BorderSide(
                    color: AppColors.liquidGold.withValues(alpha: 0.55),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                onPressed: () =>
                    ref.read(playerProvider.notifier).loadProfile(),
                child: Text(
                  'Tekrar Dene',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.liquidGold,
                  ),
                ),
              ),
            ],
          ),
        ),
        PlayerStatus.ready => _buildMobileCharacterStage(
          profile,
          inventoryState.equippedItems,
        ),
      },
    );
  }

  Widget _buildEtherealAuraStage(
    CharacterClass? characterClass,
    Widget child,
  ) {
    final (Color primaryGlow, Color secondaryGlow) = switch (characterClass) {
      CharacterClass.warrior => (
          AppColors.liquidGold.withValues(alpha: 0.16),
          AppColors.coralFlare.withValues(alpha: 0.06),
        ),
      CharacterClass.alchemist => (
          AppColors.accentCyan.withValues(alpha: 0.18),
          AppColors.accentTeal.withValues(alpha: 0.07),
        ),
      CharacterClass.shadow => (
          AppColors.accentPurple.withValues(alpha: 0.20),
          AppColors.cyberFuchsia.withValues(alpha: 0.07),
        ),
      null => (
          AppColors.liquidGold.withValues(alpha: 0.14),
          AppColors.accentBlue.withValues(alpha: 0.06),
        ),
    };

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.05),
          radius: 0.85,
          colors: <Color>[
            primaryGlow,
            secondaryGlow,
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.48, 1.0],
        ),
      ),
      child: child,
    );
  }

  Widget _buildMobileCharacterStage(
    PlayerProfile? profile,
    Map<String, InventoryItem?> equippedItems,
  ) {
    final bool highlightPowerTutorial =
        ref.watch(tutorialProvider).activeStep?.id == 'character_check_power';
    final bool statTutorialStep =
        ref.watch(tutorialProvider).activeStep?.id == 'character_stat_panel';

    return GameScreenBackground(
      child: SafeArea(
        // Ensure layout respects notches and Dynamic Island
        top: false,
        bottom: true,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1. Scrollable 3D Hero Viewport & Floating Gear Sockets
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 96),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  // Turntable and Equipment Sockets Stack with Ethereal Aura Lighting
                  _buildEtherealAuraStage(
                    profile?.characterClass,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          // Interactive 3D Turntable Viewport (Aion 2 aesthetic)
                          CharacterTurntableViewport(
                            characterClass: profile?.characterClass,
                            equippedCount: equippedItems.length,
                            height: 380,
                            onTap: () {
                              if (_statsExpanded) {
                                setState(() => _statsExpanded = false);
                              }
                            },
                          ),

                          // Glowing Gear Sockets (Thumb Reachable)
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                child: EquipmentSocketDock(
                                  equippedItems: equippedItems,
                                  onSlotTap: _handleSlotTap,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Hero Attributes Summary Ribbon (HP, MP, Attack, Defense, Crit, CP)
                  _HeroAttributesRibbon(
                    profile: profile,
                    isExpanded: _statsExpanded,
                    onTap: () {
                      setState(() => _statsExpanded = !_statsExpanded);
                    },
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // If stats are expanded, show full glassmorphic content inline
                  if (_statsExpanded)
                    CharacterGlassOverlay(
                      profile: profile,
                      isExpanded: true,
                      initialTab: _currentTab,
                      equippedItems: equippedItems,
                      onSlotTap: _handleSlotTap,
                      onTabChanged: (CharacterTab tab) {
                        setState(() => _currentTab = tab);
                      },
                      onToggleExpanded: () {
                        setState(() => _statsExpanded = false);
                      },
                      onOpenCodex: () {
                        unawaited(
                          TutorialTriggers.onAnchorTap(
                            ref,
                            TutorialAnchorId.characterCodexTile,
                          ),
                        );
                        context.push(AppRoutes.codex);
                      },
                      onOpenReputation: () => context.push(AppRoutes.reputation),
                      onCustomizeProfile: _showCustomizationPicker,
                      highlightPowerTutorial: highlightPowerTutorial,
                      statTutorialStep: statTutorialStep,
                      claimingDetox: _claimingDetox,
                      onClaimDetox: _claimAlchemistDetox,
                      classAbilitiesKey: _classAbilitiesSectionKey,
                    ),
                ],
              ),
            ),

            // 2. Floating Bottom Glassmorphic HUD (Visible when stats collapsed)
            if (!_statsExpanded)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CharacterGlassOverlay(
                  profile: profile,
                  isExpanded: false,
                  initialTab: _currentTab,
                  equippedItems: equippedItems,
                  onSlotTap: _handleSlotTap,
                  onTabChanged: (CharacterTab tab) {
                    setState(() {
                      _currentTab = tab;
                      _statsExpanded = true;
                    });
                  },
                  onToggleExpanded: () {
                    setState(() => _statsExpanded = true);
                  },
                  onOpenCodex: () {
                    unawaited(
                      TutorialTriggers.onAnchorTap(
                        ref,
                        TutorialAnchorId.characterCodexTile,
                      ),
                    );
                    context.push(AppRoutes.codex);
                  },
                  onOpenReputation: () => context.push(AppRoutes.reputation),
                  onCustomizeProfile: _showCustomizationPicker,
                  highlightPowerTutorial: highlightPowerTutorial,
                  statTutorialStep: statTutorialStep,
                  claimingDetox: _claimingDetox,
                  onClaimDetox: _claimAlchemistDetox,
                  classAbilitiesKey: _classAbilitiesSectionKey,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Glassmorphic Hero Attributes Quick Ribbon showing vital combat attributes:
/// HP, MP/Energy, Attack, Defense, Crit Strike, and Combat Power (CP).
class _HeroAttributesRibbon extends StatelessWidget {
  const _HeroAttributesRibbon({
    required this.profile,
    required this.isExpanded,
    required this.onTap,
  });

  final PlayerProfile? profile;
  final bool isExpanded;
  final VoidCallback onTap;

  String _fmt(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final int hp = profile?.health ?? 0;
    final int maxHp = (profile?.maxHealth ?? 100).clamp(1, 9999999);
    final double hpRatio = (hp / maxHp).clamp(0.0, 1.0);

    final int energy = profile?.energy ?? 0;
    final int maxEnergy = (profile?.maxEnergy ?? 100).clamp(1, 9999999);
    final double energyRatio = (energy / maxEnergy).clamp(0.0, 1.0);

    final int attack = profile?.attack ?? 0;
    final int defense = profile?.defense ?? 0;
    final int luck = profile?.luck ?? 0;
    final int crit = (luck * 2.2).round();

    return Semantics(
      button: true,
      label: 'Kahraman Nitelikleri: HP $hp, MP $energy, Saldırı $attack, Savunma $defense, Kritik $crit',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.spaceNavy.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: AppColors.liquidGold.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.bgDeep.withValues(alpha: 0.55),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.liquidGold.withValues(alpha: 0.08),
                blurRadius: 10,
                spreadRadius: -1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Top Vitals: HP and MP/Energy Bars
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildBarIndicator(
                      label: 'HP',
                      value: '$hp / $maxHp',
                      ratio: hpRatio,
                      barColor: hpRatio > 0.35 ? AppColors.success : AppColors.danger,
                      icon: Icons.favorite_rounded,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _buildBarIndicator(
                      label: 'MP',
                      value: '$energy / $maxEnergy',
                      ratio: energyRatio,
                      barColor: AppColors.accentCyan,
                      icon: Icons.bolt_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Bottom Attributes Grid: Attack, Defense, Crit, Power
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _buildAttributeItem(
                    label: 'Saldırı',
                    value: _fmt(attack),
                    icon: Icons.flash_on_rounded,
                    color: AppColors.coralFlare,
                  ),
                  _buildVerticalDivider(),
                  _buildAttributeItem(
                    label: 'Savunma',
                    value: _fmt(defense),
                    icon: Icons.shield_rounded,
                    color: AppColors.accentCyan,
                  ),
                  _buildVerticalDivider(),
                  _buildAttributeItem(
                    label: 'Kritik',
                    value: _fmt(crit),
                    icon: Icons.crisis_alert_rounded,
                    color: AppColors.warningSolar,
                  ),
                  _buildVerticalDivider(),
                  _buildAttributeItem(
                    label: 'Savaş Gücü',
                    value: _fmt(profile?.power ?? 0),
                    icon: Icons.workspace_premium_rounded,
                    color: AppColors.liquidGold,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Hint row to toggle detailed stats
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    isExpanded ? 'Modeli İncele (Statları Gizle)' : 'Tüm Statları & Ayrıntıları Göster',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 14,
                    color: AppColors.liquidGold,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarIndicator({
    required String label,
    required String value,
    required double ratio,
    required Color barColor,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 12, color: barColor),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTextStyles.micro.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: AppTextStyles.micro.copyWith(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          child: SizedBox(
            height: 5,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          barColor,
                          barColor.withValues(alpha: 0.8),
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: barColor.withValues(alpha: 0.4),
                          blurRadius: 4,
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
    );
  }

  Widget _buildAttributeItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.micro.copyWith(
                color: AppColors.textTertiary,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 20,
      color: AppColors.borderBright.withValues(alpha: 0.35),
    );
  }
}
