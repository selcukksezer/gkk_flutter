import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/item_icon_view.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../components/layout/game_chrome.dart';
import '../../l10n/l10n.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/services/supabase_service.dart';
import '../../models/crafting_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crafting_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import '../../utils/logout_helper.dart';
import 'crafting_utils.dart';
import 'widgets/crafting_main_ui.dart';
import 'widgets/crafting_recipe_preview_dialog.dart';

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

  @override
  void initState() {
    super.initState();
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
        );

    if (ok) {
      _showSnack('Üretim başlatıldı!');
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

  Future<void> _openRecipePreview(CraftRecipe recipe) async {
    await showCraftingRecipePreviewDialog(
      context: context,
      ref: ref,
      recipe: recipe,
      onCraft: _craft,
    );
  }

  Future<void> _claim(String id) async {
    final ok = await ref.read(craftingProvider.notifier).claimItem(id);
    if (ok) {
      _showSnack('Ürün alındı!');
      await ref.read(inventoryProvider.notifier).loadInventory();
    } else {
      final err = ref.read(craftingProvider).error;
      if (err != null && err != 'Üretim başarısız') _showSnack(err);
    }
  }

  Future<void> _acknowledge(String id) async {
    await ref.read(craftingProvider.notifier).acknowledgeItem(id);
  }

  Future<void> _cancel(String id) async {
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

    Future<void> onLogout() async {
      await performLogout(ref);
}

    // Filtered recipes
    final List<CraftRecipe> filtered = craftState.recipes
        .where((CraftRecipe r) => _recipeMatchesTab(r, craftState.selectedTab))
        .toList();

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.routeCrafting, onLogout: onLogout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.crafting,
        onLogout: onLogout,
      ),
      body: GameScreenBackground(
        child: craftState.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.liquidGold))
            : Stack(
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      CraftingCategoryTabBar(
                        controller: _tabController,
                        tabs: _kTabs,
                        recipeCount: filtered.length,
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'Bu kategoride tarif bulunamadı.',
                                  style: TextStyle(color: AppColors.mutedTitanium.withValues(alpha: 0.7)),
                                ),
                              )
                            : TutorialAnchorScope(
                                id: TutorialAnchorId.craftRecipeList,
                                child: GridView.builder(
                                padding: GameScrollLayout.withClearance(
                                  context,
                                  EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    12 + (craftState.queue.isNotEmpty ? 88 : 0),
                                  ),
                                ),
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 168,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.78,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final CraftRecipe recipe = filtered[index];
                                  final bool isSelected = craftState.selectedRecipeId == recipe.id;
                                  return CraftingRecipeGridTile(
                                    index: index,
                                    recipe: recipe,
                                    isSelected: isSelected,
                                    hasMaterials: hasMaterials(
                                      recipe,
                                      batchCount: craftState.selectedBatchCount,
                                    ),
                                    onTap: () {
                                      unawaited(
                                        TutorialTriggers.onAnchorTap(
                                          ref,
                                          TutorialAnchorId.craftRecipeList,
                                        ),
                                      );
                                      if (isSelected) {
                                        ref.read(craftingProvider.notifier).selectRecipe(null);
                                        return;
                                      }
                                      _openRecipePreview(recipe);
                                    },
                                  );
                                },
                              ),
                              ),
                      ),
                    ],
                  ),
                  if (craftState.queue.isNotEmpty)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: GameScrollLayout.bottomInset(context) - MediaQuery.paddingOf(context).bottom + 4,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _QueueSection(
                            queue: craftState.queue,
                            isCancelling: craftState.isCancelling,
                            queueTick: _queueTick,
                            onClaim: _claim,
                            onAcknowledge: _acknowledge,
                            onCancel: _cancel,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}


// Queue section
// ---------------------------------------------------------------------------
class _QueueSection extends StatefulWidget {
  const _QueueSection({
    required this.queue,
    required this.isCancelling,
    required this.queueTick,
    required this.onClaim,
    required this.onAcknowledge,
    required this.onCancel,
  });

  final List<CraftQueueItem> queue;
  final bool isCancelling;
  final ValueNotifier<int> queueTick;
  final Future<void> Function(String) onClaim;
  final Future<void> Function(String) onAcknowledge;
  final Future<void> Function(String) onCancel;

  @override
  State<_QueueSection> createState() => _QueueSectionState();
}

class _QueueSectionState extends State<_QueueSection> {
  bool _expanded = false;
  final Set<String> _pendingClaims = <String>{};
  final Set<String> _pendingAcks = <String>{};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.18)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            GameScreenBackground.spaceNavy.withValues(alpha: 0.95),
            AppColors.carbonVoid.withValues(alpha: 0.92),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.carbonVoid.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: <Widget>[
                  Text(
                    '📦 Üretim Kuyruğu (${widget.queue.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.liquidGold,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Text(
                      '▼',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              constraints: const BoxConstraints(maxHeight: 390),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: ValueListenableBuilder<int>(
                valueListenable: widget.queueTick,
                builder: (BuildContext context, int _, Widget? __) {
                  return ListView.separated(
                shrinkWrap: true,
                itemCount: widget.queue.length,
                separatorBuilder: (_, separatorIndex) =>
                    const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  final CraftQueueItem item = widget.queue[index];
                  final bool claimPending = _pendingClaims.contains(item.id);
                  final bool ackPending = _pendingAcks.contains(item.id);
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
                          setState(() => _pendingClaims.remove(item.id));
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
                          setState(() => _pendingAcks.remove(item.id));
                        }
                      }
                    },
                    onCancel: () async {
                      final bool? ok = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext c) => AlertDialog(
                          backgroundColor: const Color(0xFF111827),
                          title: const Text('⚠️ Üretim İptal Et?'),
                          content: const Text(
                            'Bu işlem geri alınamaz. Ödül geri verilmeyecektir!',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Vazgeç'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Evet, İptal Et'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await widget.onCancel(item.id);
                      }
                    },
                  );
                },
              );
                },
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isFailed
            ? Colors.red.withValues(alpha: 0.12)
            : isReady
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFailed
              ? Colors.red.withValues(alpha: 0.4)
              : isReady
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: <Widget>[
                        Text(
                          'x${item.batchCount} adet',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white60,
                          ),
                        ),
                        if (item.isCompleted &&
                            !isFailed &&
                            (item.xpReward ?? 0) > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0x33D97706),
                            ),
                            child: Text(
                              '+${(item.xpReward ?? 0) * item.batchCount} XP',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFFFDE68A),
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
                  item.isCompleted ? 'Hazır!' : _formatDuration(remainSec),
                  style: TextStyle(
                    fontSize: 10,
                    color: item.isCompleted
                        ? Colors.greenAccent
                        : Colors.yellowAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (!item.isCompleted && !isFailed) ...<Widget>[
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.cyberFuchsia,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (isReady)
            FilledButton(
              onPressed: claimPending ? null : onClaim,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                minimumSize: const Size.fromHeight(32),
              ),
              child: Text(claimPending ? 'Talep Ediliyor...' : '✓ Talep Et'),
            )
          else if (isFailed)
            FilledButton(
              onPressed: ackPending ? null : onAcknowledge,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                minimumSize: const Size.fromHeight(32),
              ),
              child: Text(ackPending ? 'İşleniyor...' : 'Tamam'),
            )
          else if (isClaimed)
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.10),
              ),
              child: const Text(
                '✓ Talep Edildi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          else if (awaitingFinalize)
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.10),
              ),
              child: const Text(
                'Tamamlanıyor...',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          else if (!isClaimed)
            Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    child: const Text(
                      'Üretiliyor...',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 32,
                  child: FilledButton(
                    onPressed: isCancelling ? null : onCancel,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0x7FD32F2F),
                    ),
                    child: const Text('✕'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
