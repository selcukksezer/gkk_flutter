import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/gkk_card.dart';
import '../../components/common/item_icon_view.dart';
import '../../components/common/universal_game_dialog.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/services/supabase_service.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/crafting_queue_slots.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../l10n/l10n.dart';
import '../../models/crafting_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crafting_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/logout_helper.dart';
import '../inventory/widgets/aion_rarity_glow.dart';
import 'crafting_utils.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'widgets/crafting_forge_effects.dart';
import 'widgets/crafting_main_ui.dart';
import 'widgets/crafting_queue_slots_panel.dart';
import 'widgets/crafting_recipe_carousel.dart';
import 'widgets/crafting_recipe_preview_dialog.dart';
import 'widgets/crafting_result_modal.dart';

// ---------------------------------------------------------------------------
// Tab configuration
// ---------------------------------------------------------------------------
const List<(String, String)> _kTabs = <(String, String)>[
  ('tumu', 'Tümü'),
  ('weapon', '🗡️ Silahlar'),
  ('armor', '🛡️ Zırhlar'),
  ('potion', '⚗️ İksirler'),
  ('accessory', '💍 Mücevherler'),
  ('rune', '✨ Runlar'),
  ('scroll', '📜 Yazıtlar'),
  ('other', 'Diğer'),
];

String _formatDuration(int totalSeconds) => formatCraftingDuration(totalSeconds);

String _craftTabCategory(CraftRecipe recipe) {
  final String tabType = recipe.recipeType.toLowerCase();
  if (<String>{
    'weapon',
    'armor',
    'potion',
    'accessory',
    'rune',
    'scroll',
    'other',
  }.contains(tabType)) {
    return tabType;
  }

  final String itemType = recipe.itemType.toLowerCase();
  final String itemId = recipe.outputItemId.toLowerCase();

  if (itemType == 'weapon' || itemId.startsWith('wpn_')) return 'weapon';
  if (itemId.startsWith('ring_') || itemId.startsWith('neck_')) return 'accessory';
  if (itemType == 'armor' ||
      itemId.startsWith('chest_') ||
      itemId.startsWith('head_') ||
      itemId.startsWith('legs_') ||
      itemId.startsWith('boots_') ||
      itemId.startsWith('gloves_')) {
    return 'armor';
  }
  if (itemType == 'rune' || itemId.startsWith('rune_')) return 'rune';
  if (itemType == 'scroll' || itemId.startsWith('scroll_')) return 'scroll';
  if (itemType == 'potion' ||
      itemType == 'catalyst' ||
      itemId.startsWith('potion_') ||
      itemId.startsWith('detox_') ||
      itemId.startsWith('han_')) {
    return 'potion';
  }
  if (itemId.startsWith('box_') ||
      tabType == 'consumable_box' ||
      tabType == 'other') {
    return 'other';
  }
  return tabType;
}

bool _recipeMatchesTab(CraftRecipe recipe, String tab) {
  if (tab == 'tumu') return true;
  return _craftTabCategory(recipe) == tab;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class CraftingScreen extends ConsumerStatefulWidget {
  const CraftingScreen({super.key});

  @override
  ConsumerState<CraftingScreen> createState() => _CraftingScreenState();
}

class _CraftingScreenState extends ConsumerState<CraftingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _queueTimer;
  final ValueNotifier<int> _queueTick = ValueNotifier<int>(0);
  final Set<String> _pendingFinalizations = <String>{};
  bool _isCarouselMode = false;
  late final TextEditingController _searchController;
  String _searchQuery = '';
  bool _onlyCraftable = false;
  bool _isQueueExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: _kTabs.length, vsync: this);
    final String selectedTab = ref.read(craftingProvider).selectedTab;
    _tabController.index = _kTabs.indexWhere((t) => t.$1 == selectedTab).clamp(0, _kTabs.length - 1);
    _tabController.addListener(_onTabChanged);

    deferProviderUpdate(() async {
      await ref.read(playerProvider.notifier).loadProfile();
      await ref.read(inventoryProvider.notifier).loadInventory();
      final int level = ref.read(playerProvider).profile?.level ?? 1;
      await ref.read(craftingProvider.notifier).loadRecipes(level);
      await ref.read(craftingProvider.notifier).loadQueue();
      _startQueueTimer();
      if (mounted) {
        await TutorialTriggers.onRouteEnter(ref, AppRoutes.crafting);
      }
    });
  }

  void _startQueueTimer() {
    _queueTimer?.cancel();
    _queueTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _autoFinalizeCompletedItems();
      _queueTick.value++;
    });
  }

  void _autoFinalizeCompletedItems() {
    final queue = ref.read(craftingProvider).queue;
    for (final item in queue) {
      if (item.isCompleted || item.claimed || (item.failed == true)) continue;
      if (_pendingFinalizations.contains(item.id)) continue;

      final DateTime? completesAt = DateTime.tryParse(item.completesAt);
      if (completesAt == null) continue;
      if (completesAt.isAfter(DateTime.now())) continue;

      // Timer has passed – finalize on the server
      _pendingFinalizations.add(item.id);
      ref.read(craftingProvider.notifier).finalizeCraftedItem(item.id).then((
        _,
      ) {
        _pendingFinalizations.remove(item.id);
      });
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final String tab = _kTabs[_tabController.index].$1;
    AionHaptics.tabSwitch();
    deferProviderUpdate(() {
      ref.read(craftingProvider.notifier).setSelectedTab(tab);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _queueTimer?.cancel();
    _queueTick.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    AppMessenger.show(context, msg);
  }

  Future<bool> _craft() async {
    final craftState = ref.read(craftingProvider);
    final authState = ref.read(authProvider);
    final authId =
        authState.user?.id ?? SupabaseService.client.auth.currentUser?.id ?? '';
    if (authId.isEmpty || craftState.selectedRecipeId == null) return false;

    // Refresh inventory before crafting to validate materials are still available
    await ref.read(inventoryProvider.notifier).loadInventory();

    final bool ok = await ref
        .read(craftingProvider.notifier)
        .craftItem(
          authId: authId,
          recipeId: craftState.selectedRecipeId!,
          batchCount: craftState.selectedBatchCount,
          inventoryItems: ref.read(inventoryProvider).items,
          maxQueueSlots: playerCraftingQueueSlots(ref.read(playerProvider).profile),
        );

    if (ok) {
      await AionHaptics.craftSuccess();
      _showSnack('Demir ocağı ateşlendi — üretim başladı!');
      ref.read(craftingProvider.notifier).selectRecipe(null);
      ref.read(craftingProvider.notifier).setBatchCount(1);
      await ref.read(inventoryProvider.notifier).loadInventory();
      return true;
    } else {
      final err = ref.read(craftingProvider).error;
      if (err != null) _showSnack(err);
      return false;
    }
  }

  Future<bool> _expandCraftQueue() async {
    final int currentSlots =
        playerCraftingQueueSlots(ref.read(playerProvider).profile);
    final int? gemCost = nextCraftQueueSlotUnlockCost(currentSlots);
    if (gemCost == null) return false;

    if (!mounted) return false;
    final bool confirmed = await showCraftQueueSlotUnlockDialog(
      context,
      nextSlot: currentSlots + 1,
      gemCost: gemCost,
      currentSlots: currentSlots,
    );
    if (!confirmed) return false;

    final bool ok =
        await ref.read(craftingProvider.notifier).expandCraftQueueSlot();
    if (ok) {
      await AionHaptics.equipSuccess();
      await ref.read(playerProvider.notifier).loadProfile();
      if (mounted) {
        final int slots =
            playerCraftingQueueSlots(ref.read(playerProvider).profile);
        AppMessenger.showSuccess(
          context,
          'Üretim kuyruğu genişletildi · $slots/$craftingQueueMaxSlots slot',
          title: 'Slot Açıldı',
        );
      }
    } else {
      final String? err = ref.read(craftingProvider).error;
      if (err != null) _showSnack(err);
    }
    return ok;
  }

  Future<void> _openRecipePreview(CraftRecipe recipe) async {
    await AionHaptics.slotSelect();
    if (!mounted) return;
    await showCraftingRecipePreviewDialog(
      context: context,
      ref: ref,
      recipe: recipe,
      onCraft: () async {
        await TutorialTriggers.onAnchorTap(ref, TutorialAnchorId.craftStartBtn);
        return _craft();
      },
      onExpandQueue: _expandCraftQueue,
    );
  }

  Future<void> _claim(String id) async {
    final queue = ref.read(craftingProvider).queue;
    final CraftQueueItem? item = queue.cast<CraftQueueItem?>().firstWhere(
          (it) => it?.id == id,
          orElse: () => null,
        );

    final ok = await ref.read(craftingProvider.notifier).claimItem(id);
    if (ok) {
      await AionHaptics.equipSuccess();
      await ref.read(inventoryProvider.notifier).loadInventory();

      if (mounted && item != null) {
        await showCraftingResultModal(
          context: context,
          itemName: item.outputName?.isNotEmpty == true
              ? item.outputName!
              : item.recipeName,
          itemId: item.outputItemId ?? item.recipeIcon ?? '',
          rarity: 'epic',
          quantity: (item.outputQuantity ?? 1) * item.batchCount,
          xpReward: (item.xpReward ?? 0) * item.batchCount,
        );
      } else {
        _showSnack('Ürün alındı!');
      }
    } else {
      final err = ref.read(craftingProvider).error;
      if (err != null && err != 'Üretim başarısız') _showSnack(err);
    }
  }

  Future<void> _acknowledge(String id) async {
    final queue = ref.read(craftingProvider).queue;
    final CraftQueueItem? item = queue.cast<CraftQueueItem?>().firstWhere(
          (it) => it?.id == id,
          orElse: () => null,
        );

    await ref.read(craftingProvider.notifier).acknowledgeItem(id);

    if (mounted && item != null && item.failed == true) {
      await showCraftingResultModal(
        context: context,
        itemName: item.outputName?.isNotEmpty == true
            ? item.outputName!
            : item.recipeName,
        itemId: item.outputItemId ?? item.recipeIcon ?? '',
        rarity: 'common',
        quantity: item.batchCount,
        isFailed: true,
      );
    }
  }

  Future<void> _cancel(String id) async {
    await AionHaptics.slotSelect();
    final ok = await ref.read(craftingProvider.notifier).cancelItem(id);
    if (!ok) {
      final err = ref.read(craftingProvider).error;
      if (err != null) _showSnack(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final craftState = ref.watch(craftingProvider);
    final hasMaterials = ref.watch(hasMaterialsProvider);
    final int queueMax =
        playerCraftingQueueSlots(ref.watch(playerProvider).profile);
    final double playerGems = ref.watch(playerProvider).profile?.gems ?? 0;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double childAspectRatio =
        screenWidth < 360 ? 0.70 : (screenWidth < 420 ? 0.73 : 0.76);

    Future<void> onLogout() async {
      await performLogout(ref);
    }

    // Craftable count in currently selected tab
    final int craftableInTabCount = craftState.recipes
        .where((CraftRecipe r) =>
            _recipeMatchesTab(r, craftState.selectedTab) &&
            hasMaterials(r, batchCount: 1))
        .length;

    // Filtered recipes
    final List<CraftRecipe> filtered = craftState.recipes
        .where((CraftRecipe r) {
          if (!_recipeMatchesTab(r, craftState.selectedTab)) return false;
          if (_onlyCraftable && !hasMaterials(r, batchCount: 1)) return false;
          if (_searchQuery.trim().isNotEmpty) {
            final String query = _searchQuery.trim().toLowerCase();
            final String name = r.name.toLowerCase();
            final String output = (r.outputName ?? '').toLowerCase();
            final String desc = r.description.toLowerCase();
            if (!name.contains(query) &&
                !output.contains(query) &&
                !desc.contains(query)) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);

    final bool craftPickCoach =
        ref.watch(tutorialProvider).activeStep?.id == 'craft_browse_recipes';

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.routeCrafting, onLogout: onLogout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.crafting,
        onLogout: onLogout,
      ),
      body: GameScreenBackground(
        child: ForgeEmbersOverlay(
          particleCount: 22,
          child: craftState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.liquidGold),
                )
              : Stack(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        // Atmospheric Forge Header with Mode Toggle
                        ForgeAnvilHeader(
                          recipeCount: filtered.length,
                          queueCount: craftState.queue.length,
                          queueMax: queueMax,
                          isCarouselMode: _isCarouselMode,
                          onToggleViewMode: () {
                            AionHaptics.tabSwitch();
                            setState(() => _isCarouselMode = !_isCarouselMode);
                          },
                        ),
                        // Category Tabs
                        CraftingCategoryTabBar(
                          controller: _tabController,
                          tabs: _kTabs,
                          recipeCount: filtered.length,
                        ),
                        // Search & Craftable Filter Bar
                        _CraftingFilterBar(
                          searchController: _searchController,
                          searchQuery: _searchQuery,
                          onSearchChanged: (String val) {
                            setState(() => _searchQuery = val);
                          },
                          onClearSearch: () {
                            AionHaptics.tabSwitch();
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          onlyCraftable: _onlyCraftable,
                          onToggleOnlyCraftable: () {
                            AionHaptics.tabSwitch();
                            setState(() => _onlyCraftable = !_onlyCraftable);
                          },
                          craftableCount: craftableInTabCount,
                        ),
                        // Content: Carousel Mode or Grid Mode or Empty Altar
                        Expanded(
                          child: filtered.isEmpty
                              ? _CraftingEmptyAltar(
                                  isCraftableFilterActive: _onlyCraftable,
                                  searchQuery: _searchQuery,
                                  onResetFilters: () {
                                    AionHaptics.tabSwitch();
                                    _searchController.clear();
                                    setState(() {
                                      _onlyCraftable = false;
                                      _searchQuery = '';
                                    });
                                  },
                                  onShowAllTabs: () {
                                    AionHaptics.tabSwitch();
                                    _tabController.animateTo(0);
                                    ref
                                        .read(craftingProvider.notifier)
                                        .setSelectedTab('tumu');
                                  },
                                )
                              : _isCarouselMode
                                  ? SingleChildScrollView(
                                      padding: GameScrollLayout.withClearance(
                                        context,
                                        const EdgeInsets.fromLTRB(12, 6, 12, 116),
                                      ),
                                      child: CraftingRecipeCarousel(
                                        recipes: filtered,
                                        selectedRecipeId: craftState.selectedRecipeId,
                                        hasMaterials: (r) => hasMaterials(
                                          r,
                                          batchCount: craftState.selectedBatchCount,
                                        ),
                                        onSelectRecipe: (r) => ref
                                            .read(craftingProvider.notifier)
                                            .selectRecipe(r.id),
                                        onOpenPreview: (r) => _openRecipePreview(r),
                                      ),
                                    )
                                  : GridView.builder(
                                      padding: GameScrollLayout.withClearance(
                                        context,
                                        const EdgeInsets.fromLTRB(12, 0, 12, 116),
                                      ),
                                      gridDelegate:
                                          SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: screenWidth < 360 ? 150 : 170,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                        childAspectRatio: childAspectRatio,
                                      ),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, index) {
                                        final CraftRecipe recipe = filtered[index];
                                        final bool isSelected =
                                            craftState.selectedRecipeId == recipe.id;
                                        Widget tile = CraftingRecipeGridTile(
                                          index: index,
                                          recipe: recipe,
                                          isSelected: isSelected,
                                          hasMaterials: hasMaterials(
                                            recipe,
                                            batchCount:
                                                craftState.selectedBatchCount,
                                          ),
                                          onTap: () {
                                            if (craftPickCoach && index != 0) {
                                              ref
                                                  .read(tutorialProvider.notifier)
                                                  .registerWrongTap();
                                              return;
                                            }
                                            if (index == 0) {
                                              unawaited(
                                                TutorialTriggers.onAnchorTap(
                                                  ref,
                                                  TutorialAnchorId
                                                      .craftRecipeFirst,
                                                ),
                                              );
                                            }
                                            if (isSelected) {
                                              ref
                                                  .read(craftingProvider.notifier)
                                                  .selectRecipe(null);
                                              return;
                                            }
                                            _openRecipePreview(recipe);
                                          },
                                        );
                                        if (index == 0) {
                                          tile = TutorialAnchorScope(
                                            id: TutorialAnchorId.craftRecipeFirst,
                                            child: tile,
                                          );
                                        }
                                        return tile;
                                      },
                                    ),
                        ),
                      ],
                    ),
                    // Background scrim when queue drawer is expanded
                    if (_isQueueExpanded)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            AionHaptics.tabSwitch();
                            setState(() => _isQueueExpanded = false);
                          },
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                    // Floating Queue Section at bottom right
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: GameScrollLayout.bottomInset(context) -
                          MediaQuery.paddingOf(context).bottom +
                          4,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _QueueSection(
                            queue: craftState.queue,
                            queueMax: queueMax,
                            playerGems: playerGems,
                            isCancelling: craftState.isCancelling,
                            isExpandingQueue: craftState.isExpandingQueue,
                            queueTick: _queueTick,
                            isExpanded: _isQueueExpanded,
                            onToggleExpanded: () {
                              AionHaptics.slotSelect();
                              setState(() => _isQueueExpanded = !_isQueueExpanded);
                            },
                            onClaim: _claim,
                            onAcknowledge: _acknowledge,
                            onCancel: _cancel,
                            onExpandQueue: _expandCraftQueue,
                          ),
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
// Search & Filter Bar
// ---------------------------------------------------------------------------
class _CraftingFilterBar extends StatelessWidget {
  const _CraftingFilterBar({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onlyCraftable,
    required this.onToggleOnlyCraftable,
    required this.craftableCount,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final bool onlyCraftable;
  final VoidCallback onToggleOnlyCraftable;
  final int craftableCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isNarrow = constraints.maxWidth < 350;

          return Row(
            children: <Widget>[
              // Search Input Field
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D18).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: searchQuery.isNotEmpty
                          ? AppColors.liquidGold.withValues(alpha: 0.55)
                          : AppColors.borderDefault.withValues(alpha: 0.45),
                      width: 0.9,
                    ),
                    boxShadow: <BoxShadow>[
                      if (searchQuery.isNotEmpty)
                        BoxShadow(
                          color: AppColors.liquidGold.withValues(alpha: 0.12),
                          blurRadius: 8,
                        ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                    cursorColor: AppColors.liquidGold,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      hintText: isNarrow ? 'Ara...' : 'Tarif veya eşya ara...',
                      hintStyle: AppTextStyles.caption.copyWith(
                        color: AppColors.mutedTitanium.withValues(alpha: 0.65),
                        fontSize: 11.5,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 6),
                        child: Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: searchQuery.isNotEmpty
                              ? AppColors.liquidGold
                              : AppColors.mutedTitanium.withValues(alpha: 0.65),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 20,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 15),
                              color: AppColors.mutedTitanium,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: onClearSearch,
                              tooltip: 'Temizle',
                            )
                          : null,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Craftable Filter Toggle Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggleOnlyCraftable,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: 38,
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      gradient: onlyCraftable
                          ? LinearGradient(
                              colors: <Color>[
                                AppColors.liquidGold.withValues(alpha: 0.28),
                                const Color(0xFFE65100).withValues(alpha: 0.22),
                              ],
                            )
                          : null,
                      color: onlyCraftable
                          ? null
                          : const Color(0xFF090D18).withValues(alpha: 0.88),
                      border: Border.all(
                        color: onlyCraftable
                            ? AppColors.liquidGold.withValues(alpha: 0.75)
                            : AppColors.borderDefault.withValues(alpha: 0.45),
                        width: onlyCraftable ? 1.2 : 0.9,
                      ),
                      boxShadow: <BoxShadow>[
                        if (onlyCraftable)
                          BoxShadow(
                            color: AppColors.liquidGold.withValues(alpha: 0.20),
                            blurRadius: 10,
                          ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          onlyCraftable
                              ? Icons.local_fire_department_rounded
                              : Icons.hardware_rounded,
                          size: 14,
                          color: onlyCraftable
                              ? AppColors.liquidGold
                              : AppColors.mutedTitanium,
                        ),
                        if (!isNarrow) ...<Widget>[
                          const SizedBox(width: 5),
                          Text(
                            'Üretilebilir',
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 10.5,
                              fontWeight: onlyCraftable
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: onlyCraftable
                                  ? AppColors.liquidGold
                                  : AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: onlyCraftable
                                ? AppColors.liquidGold.withValues(alpha: 0.25)
                                : AppColors.darkObsidian.withValues(alpha: 0.8),
                            border: Border.all(
                              color: onlyCraftable
                                  ? AppColors.liquidGold.withValues(alpha: 0.5)
                                  : Colors.white12,
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            '$craftableCount',
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: onlyCraftable
                                  ? AppColors.liquidGold
                                  : AppColors.mutedTitanium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty State Altar
// ---------------------------------------------------------------------------
class _CraftingEmptyAltar extends StatelessWidget {
  const _CraftingEmptyAltar({
    required this.isCraftableFilterActive,
    required this.searchQuery,
    required this.onResetFilters,
    required this.onShowAllTabs,
  });

  final bool isCraftableFilterActive;
  final String searchQuery;
  final VoidCallback onResetFilters;
  final VoidCallback onShowAllTabs;

  @override
  Widget build(BuildContext context) {
    final bool hasFilter = isCraftableFilterActive || searchQuery.trim().isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Glowing Altar Emblem Pedestal
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    AppColors.liquidGold.withValues(alpha: 0.22),
                    const Color(0xFF0D1424).withValues(alpha: 0.9),
                  ],
                ),
                border: Border.all(
                  color: AppColors.liquidGold.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.15),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.fireplace_rounded,
                size: 34,
                color: AppColors.liquidGold,
              ),
            ),
            const SizedBox(height: 16),

            // Mystic Title
            Text(
              hasFilter ? 'TARİF BULUNAMADI' : 'BU KATEGORİ SESSİZ',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                searchQuery.trim().isNotEmpty
                    ? '"${searchQuery.trim()}" ile eşleşen demircilik tarifi bulunamadı.'
                    : (isCraftableFilterActive
                        ? 'Şu anda envanterindeki malzemelerle dövebileceğin bir tarif yok.'
                        : 'Bu kategoriye ait açık bir demircilik tarifi bulunmuyor.'),
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.mutedTitanium,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: <Widget>[
                if (hasFilter)
                  OutlinedButton.icon(
                    onPressed: onResetFilters,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Filtreleri Temizle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.liquidGold,
                      side: BorderSide(
                        color: AppColors.liquidGold.withValues(alpha: 0.55),
                      ),
                      backgroundColor:
                          AppColors.liquidGold.withValues(alpha: 0.10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      textStyle: AppTextStyles.captionBold.copyWith(
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: onShowAllTabs,
                  icon: const Icon(Icons.apps_rounded, size: 14),
                  label: const Text('Tüm Tarifler'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentCyan,
                    side: BorderSide(
                      color: AppColors.accentCyan.withValues(alpha: 0.45),
                    ),
                    backgroundColor:
                        AppColors.accentCyan.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: AppTextStyles.captionBold.copyWith(
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Queue section
// ---------------------------------------------------------------------------
class _QueueSection extends StatefulWidget {
  const _QueueSection({
    required this.queue,
    required this.queueMax,
    required this.playerGems,
    required this.isCancelling,
    required this.isExpandingQueue,
    required this.queueTick,
    this.isExpanded = false,
    this.onToggleExpanded,
    required this.onClaim,
    required this.onAcknowledge,
    required this.onCancel,
    required this.onExpandQueue,
  });

  final List<CraftQueueItem> queue;
  final int queueMax;
  final double playerGems;
  final bool isCancelling;
  final bool isExpandingQueue;
  final ValueNotifier<int> queueTick;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  final Future<void> Function(String) onClaim;
  final Future<void> Function(String) onAcknowledge;
  final Future<void> Function(String) onCancel;
  final Future<bool> Function() onExpandQueue;

  @override
  State<_QueueSection> createState() => _QueueSectionState();
}

class _QueueSectionState extends State<_QueueSection> {
  bool _internalExpanded = false;
  final Set<String> _pendingClaims = <String>{};
  final Set<String> _pendingAcks = <String>{};

  bool get _effectiveExpanded =>
      widget.onToggleExpanded != null ? widget.isExpanded : _internalExpanded;

  void _toggleExpanded() {
    AionHaptics.slotSelect();
    if (widget.onToggleExpanded != null) {
      widget.onToggleExpanded!();
    } else {
      setState(() => _internalExpanded = !_internalExpanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFF131A2A).withValues(alpha: 0.96),
                const Color(0xFF090D18).withValues(alpha: 0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: AppColors.liquidGold.withValues(alpha: 0.38),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.liquidGold.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleExpanded,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.liquidGold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.precision_manufacturing_rounded,
                            size: 16,
                            color: AppColors.liquidGold.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Ocak Dövme Kuyruğu',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.liquidGold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${widget.queue.length} / ${widget.queueMax} slot dolu',
                                style: AppTextStyles.micro.copyWith(
                                  color: AppColors.mutedTitanium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: AppColors.darkObsidian.withValues(alpha: 0.75),
                            border: Border.all(
                              color: AppColors.liquidGold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '${widget.queueMax}/$craftingQueueMaxSlots',
                            style: AppTextStyles.micro.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _effectiveExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.liquidGold.withValues(alpha: 0.9),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: ValueListenableBuilder<int>(
                    valueListenable: widget.queueTick,
                    builder: (BuildContext context, int _, Widget? __) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          CraftingQueueSlotsPanel(
                            unlockedSlots: widget.queueMax,
                            queueLength: widget.queue.length,
                            playerGems: widget.playerGems,
                            isExpanding: widget.isExpandingQueue,
                            onRequestUnlock: () => widget.onExpandQueue(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (widget.queue.isEmpty)
                            GkkCard(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                              accentColor: AppColors.mutedTitanium,
                              borderRadius: AppSpacing.radiusMd,
                              child: Text(
                                'Ocak hazır — açık slotlara üretim ekleyebilirsiniz.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            )
                          else
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: (MediaQuery.sizeOf(context).height * 0.42).clamp(180.0, 320.0),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const ClampingScrollPhysics(),
                                itemCount: widget.queue.length,
                                separatorBuilder: (_, int separatorIndex) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (BuildContext context, int index) {
                                  final CraftQueueItem item = widget.queue[index];
                                  final bool claimPending =
                                      _pendingClaims.contains(item.id);
                                  final bool ackPending =
                                      _pendingAcks.contains(item.id);
                                  return _QueueItemTile(
                                    item: item,
                                    isCancelling: widget.isCancelling,
                                    claimPending: claimPending,
                                    ackPending: ackPending,
                                    onClaim: () async {
                                      if (claimPending) return;
                                      setState(() => _pendingClaims.add(item.id));
                                      try {
                                        await widget.onClaim(item.id);
                                      } finally {
                                        if (mounted) {
                                          setState(() =>
                                              _pendingClaims.remove(item.id));
                                        }
                                      }
                                    },
                                    onAcknowledge: () async {
                                      if (ackPending) return;
                                      setState(() => _pendingAcks.add(item.id));
                                      try {
                                        await widget.onAcknowledge(item.id);
                                      } finally {
                                        if (mounted) {
                                          setState(() =>
                                              _pendingAcks.remove(item.id));
                                        }
                                      }
                                    },
                                    onCancel: () async {
                                      final bool? ok =
                                          await UniversalGameDialog.show(
                                        context,
                                        title: 'Üretimi İptal Et?',
                                        message:
                                            'Bu işlem geri alınamaz. Harcanan malzemeler iade edilmez.',
                                        confirmLabel: 'İptal Et',
                                        cancelLabel: 'Vazgeç',
                                        accent: AppColors.mysticRuby,
                                      );
                                      if (ok == true) {
                                        await widget.onCancel(item.id);
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                crossFadeState: _effectiveExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  const _QueueItemTile({
    required this.item,
    required this.isCancelling,
    required this.claimPending,
    required this.ackPending,
    required this.onClaim,
    required this.onAcknowledge,
    required this.onCancel,
  });

  final CraftQueueItem item;
  final bool isCancelling;
  final bool claimPending;
  final bool ackPending;
  final VoidCallback onClaim;
  final VoidCallback onAcknowledge;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bool isFailed = item.failed == true;
    final bool isClaimed = item.claimed;
    final bool isReady = item.isCompleted && !isClaimed && !isFailed;

    // Remaining seconds
    int remainSec = 0;
    if (!item.isCompleted && !isFailed) {
      final DateTime? completesAt = DateTime.tryParse(item.completesAt);
      if (completesAt != null) {
        remainSec = completesAt.difference(DateTime.now()).inSeconds;
        if (remainSec < 0) remainSec = 0;
      }
    }

    final DateTime? startsAt = DateTime.tryParse(item.startedAt);
    final DateTime? completesAt = DateTime.tryParse(item.completesAt);
    final DateTime now = DateTime.now();
    double progress = 0;
    if (startsAt != null && completesAt != null) {
      final int totalMs = completesAt.difference(startsAt).inMilliseconds;
      final int doneMs = now.difference(startsAt).inMilliseconds;
      if (totalMs <= 0) {
        progress = 1;
      } else {
        progress = (doneMs / totalMs).clamp(0, 1);
      }
    }

    final bool awaitingFinalize =
        !item.isCompleted && remainSec == 0 && !isFailed;

    final Color accent = isFailed
        ? AppColors.mysticRuby
        : isReady
            ? AppColors.toxicNeon
            : AppColors.liquidGold;

    return GkkCard(
      padding: const EdgeInsets.all(10),
      accentColor: accent,
      borderGlow: isReady || isFailed,
      borderRadius: AppSpacing.radiusMd,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accent.withValues(alpha: isReady || isFailed ? 0.16 : 0.08),
          AppColors.darkObsidian.withValues(alpha: 0.94),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.spaceNavy.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: ItemIconView(
                  iconValue: item.recipeIcon?.trim().isNotEmpty == true
                      ? item.recipeIcon!
                      : (item.outputItemId ?? ''),
                  itemId: item.outputItemId,
                  size: 36,
                  expand: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.outputName?.isNotEmpty == true
                          ? item.outputName!
                          : item.recipeName,
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: <Widget>[
                        Text(
                          'x${item.batchCount} adet',
                          style: AppTextStyles.micro.copyWith(
                            color: AppColors.mutedTitanium,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (item.isCompleted &&
                            !isFailed &&
                            (item.xpReward ?? 0) > 0)
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: AppColors.liquidGold.withValues(alpha: 0.16),
                                border: Border.all(
                                  color: AppColors.liquidGold.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                '+${(item.xpReward ?? 0) * item.batchCount} XP',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.micro.copyWith(
                                  color: AppColors.liquidGold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isFailed && !isClaimed)
                Text(
                  item.isCompleted ? 'Hazır' : _formatDuration(remainSec),
                  style: AppTextStyles.captionBold.copyWith(
                    fontSize: 11,
                    color: item.isCompleted
                        ? AppColors.toxicNeon
                        : AppColors.liquidGold,
                  ),
                ),
            ],
          ),
          if (!item.isCompleted && !isFailed) ...<Widget>[
            const SizedBox(height: 8),
            MoltenProgressBar(
              progress: progress,
              height: 6,
            ),
          ],
          const SizedBox(height: 8),
          if (isReady)
            _QueueActionButton(
              label: claimPending ? 'Talep ediliyor...' : '🎁 Teslim Al',
              onPressed: claimPending ? null : onClaim,
              accent: AppColors.toxicNeon,
            )
          else if (isFailed)
            _QueueActionButton(
              label: ackPending ? 'İşleniyor...' : 'Kaldır',
              onPressed: ackPending ? null : onAcknowledge,
              accent: AppColors.accentCyan,
            )
          else if (isClaimed)
            _QueueStatusChip(label: 'Teslim Alındı', color: AppColors.mutedTitanium)
          else if (awaitingFinalize)
            _QueueStatusChip(label: 'Tamamlanıyor...', color: AppColors.mutedTitanium)
          else if (!isClaimed)
            Row(
              children: <Widget>[
                Expanded(
                  child: _QueueStatusChip(
                    label: 'Ocakta Dövülüyor...',
                    color: AppColors.liquidGold,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  height: 36,
                  child: IconButton(
                    onPressed: isCancelling ? null : onCancel,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          AppColors.mysticRuby.withValues(alpha: 0.18),
                      foregroundColor: AppColors.mysticRuby,
                    ),
                    icon: isCancelling
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: AppColors.mysticRuby,
                            ),
                          )
                        : const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'İptal',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QueueActionButton extends StatelessWidget {
  const _QueueActionButton({
    required this.label,
    required this.onPressed,
    required this.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            gradient: onPressed == null
                ? null
                : LinearGradient(
                    colors: <Color>[accent, accent.withValues(alpha: 0.75)],
                  ),
            color: onPressed == null ? AppColors.darkObsidian : null,
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.captionBold.copyWith(
                color: onPressed == null
                    ? AppColors.mutedTitanium
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueStatusChip extends StatelessWidget {
  const _QueueStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        color: AppColors.darkObsidian.withValues(alpha: 0.75),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionBold.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}
