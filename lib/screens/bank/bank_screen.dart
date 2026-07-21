import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/inline_error_retry.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/utils/bank_tutorial.dart';
import '../../l10n/l10n.dart';
import '../../core/services/supabase_service.dart';
import '../../models/inventory_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'widgets/bank_design.dart';
import 'widgets/bank_quantity_dialog.dart';
import 'widgets/bank_drag_hint.dart';
import 'widgets/bank_drag_scroll.dart';
import 'widgets/bank_section_header.dart';
import 'widgets/bank_slot_grid.dart';
import 'widgets/bank_stats_card.dart';

class BankScreen extends ConsumerStatefulWidget {
  const BankScreen({super.key});

  @override
  ConsumerState<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends ConsumerState<BankScreen> {
  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _bankItems = <Map<String, dynamic>>[];
  int _totalSlots = bankBaseSlots;
  int _usedSlots = 0;

  int _bankPage = 1;
  int _inventoryPage = 1;

  final Set<String> _selectedBankIds = <String>{};
  final Set<String> _selectedInventoryRowIds = <String>{};

  bool _depositing = false;
  bool _withdrawing = false;
  bool _expanding = false;
  bool get _actionInProgress => _depositing || _withdrawing || _expanding;

  final ScrollController _scrollController = ScrollController();
  late final BankDragScrollCoordinator _dragScrollCoordinator;

  @override
  void initState() {
    super.initState();
    _dragScrollCoordinator = BankDragScrollCoordinator(
      scrollController: _scrollController,
      contextProvider: () => context,
    );
    ref.listenManual<InventoryState>(inventoryProvider, (
      InventoryState? previous,
      InventoryState next,
    ) {
      if (!mounted || next.status != InventoryStatus.ready) return;
      final int itemCount = next.items
          .where((InventoryItem item) => !item.isEquipped)
          .where((InventoryItem item) => item.quantity > 0)
          .length;
      final int totalPages =
          (itemCount / bankInventoryPerPage).ceil().clamp(1, 9999);
      if (_inventoryPage > totalPages) {
        setState(() => _inventoryPage = totalPages);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadData();
      await ref.read(inventoryProvider.notifier).loadInventory();
      if (!mounted) return;
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.bank);
    });
  }

  @override
  void dispose() {
    _dragScrollCoordinator.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _clampBankPage() {
    final int bankTotalPages = (bankMaxSlots / bankSlotsPerPage).ceil();
    if (_bankPage > bankTotalPages) {
      _bankPage = bankTotalPages;
    }
  }

  Map<String, dynamic>? _readBankRpcResult(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is List && raw.isNotEmpty) {
      final dynamic first = raw.first;
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final dynamic accountRaw = await SupabaseService.client.rpc(
        'get_bank_account',
      );

      int totalSlots = bankBaseSlots;
      int usedSlots = 0;

      if (accountRaw is Map) {
        totalSlots = bankAsInt(
          accountRaw['total_slots'],
          fallback: bankBaseSlots,
        );
        usedSlots = bankAsInt(accountRaw['used_slots']);
      } else if (accountRaw is List && accountRaw.isNotEmpty) {
        final dynamic first = accountRaw[0];
        if (first is Map) {
          totalSlots = bankAsInt(first['total_slots'], fallback: bankBaseSlots);
          usedSlots = bankAsInt(first['used_slots']);
        }
      }

      final dynamic itemsRaw = await SupabaseService.client.rpc(
        'get_bank_items',
        params: <String, dynamic>{'p_category': null},
      );

      List<dynamic> rawList = <dynamic>[];
      if (itemsRaw is Map && itemsRaw['items'] is List) {
        rawList = itemsRaw['items'] as List<dynamic>;
      } else if (itemsRaw is List && itemsRaw.isNotEmpty) {
        final dynamic first = itemsRaw[0];
        if (first is Map && first['items'] is List) {
          rawList = first['items'] as List<dynamic>;
        } else {
          rawList = itemsRaw;
        }
      }

      final List<Map<String, dynamic>> bankItems = rawList
          .whereType<Map>()
          .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
          .where((Map<String, dynamic> row) => bankAsInt(row['quantity']) > 0)
          .toList();

      if (!mounted) return;
      setState(() {
        _totalSlots = totalSlots.clamp(bankBaseSlots, bankMaxSlots);
        _usedSlots = usedSlots;
        _bankItems = bankItems;
        _loading = false;
        _clampBankPage();
      });
    } catch (e) {
      if (!mounted) return;
      final String message =
          userFacingErrorMessage(e, fallback: 'Banka yüklenemedi.');
      if (silent) {
        AppMessenger.showError(context, message);
        return;
      }
      setState(() {
        _loading = false;
        _loadError = message;
      });
    }
  }

  Future<void> _refreshAll({bool silentInventory = true}) async {
    await Future.wait(<Future<void>>[
      _loadData(silent: true),
      ref
          .read(inventoryProvider.notifier)
          .loadInventory(silent: silentInventory),
    ]);
  }

  Map<String, dynamic>? _findBankItemAtSlot(int slotIndex) {
    for (final Map<String, dynamic> item in _bankItems) {
      final int pos = bankAsInt(
        item['slot_position'],
        fallback: bankAsInt(item['position'], fallback: -1),
      );
      if (pos == slotIndex) return item;
    }
    return null;
  }

  List<InventoryItem?> _buildInventorySlots(
    List<InventoryItem> items,
    int page,
  ) {
    final List<InventoryItem> sorted = List<InventoryItem>.from(items)
      ..sort((InventoryItem a, InventoryItem b) {
        final int ap = a.slotPosition < 0 ? 1 << 30 : a.slotPosition;
        final int bp = b.slotPosition < 0 ? 1 << 30 : b.slotPosition;
        return ap.compareTo(bp);
      });

    final List<InventoryItem?> slots = List<InventoryItem?>.filled(
      bankInventoryPerPage,
      null,
    );
    final int pageStart = (page - 1) * bankInventoryPerPage;

    for (final InventoryItem item in sorted) {
      final int localIndex = item.slotPosition - pageStart;
      if (localIndex >= 0 && localIndex < bankInventoryPerPage) {
        slots[localIndex] = item;
      }
    }

    int fillCursor = 0;
    for (final InventoryItem item in sorted) {
      if (item.slotPosition >= 0) continue;
      while (fillCursor < bankInventoryPerPage && slots[fillCursor] != null) {
        fillCursor++;
      }
      if (fillCursor >= bankInventoryPerPage) break;
      slots[fillCursor] = item;
      fillCursor++;
    }

    return slots;
  }

  Future<int?> _askQuantity({
    required String title,
    required String subtitle,
    required int maxQuantity,
    required Color accent,
  }) {
    if (maxQuantity <= 0) return Future<int?>.value(null);
    return BankQuantityDialog.show(
      context,
      title: title,
      subtitle: subtitle,
      maxQuantity: maxQuantity,
      accent: accent,
    );
  }

  Future<void> _performSwap({
    required BankDragPayload payload,
    required BankDragSourceType targetType,
    required int targetSlot,
    required String? targetId,
    required int quantity,
  }) async {
    if (_actionInProgress) return;
    if (quantity <= 0) return;

    if (payload.sourceType == BankDragSourceType.bank &&
        targetType == BankDragSourceType.inventory) {
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      final InventoryAddCheck addCheck = ref
          .read(inventoryProvider.notifier)
          .canAddItem(itemId: payload.itemId, quantity: quantity);
      if (!addCheck.canAdd) {
        if (mounted) {
          AppMessenger.show(context, addCheck.reason ?? 'Envanter dolu!');
        }
        return;
      }
    }

    setState(() {
      if (payload.sourceType == BankDragSourceType.inventory) {
        _depositing = true;
      } else {
        _withdrawing = true;
      }
    });

    try {
      await SupabaseService.client.rpc(
        'swap_inventory_bank',
        params: <String, dynamic>{
          'p_source_type': payload.sourceType == BankDragSourceType.inventory
              ? 'inventory'
              : 'bank',
          'p_source_id': payload.sourceId,
          'p_target_type': targetType == BankDragSourceType.inventory
              ? 'inventory'
              : 'bank',
          'p_target_id': targetId,
          'p_quantity': quantity,
          'p_target_slot': targetSlot,
        },
      );

      _selectedBankIds.clear();
      _selectedInventoryRowIds.clear();
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showError(
        context,
        userFacingErrorMessage(e, fallback: 'Taşıma başarısız.'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _depositing = false;
          _withdrawing = false;
        });
      }
    }
  }

  Future<void> _handleDrop({
    required BankDragPayload payload,
    required BankDragSourceType targetType,
    required int targetSlot,
    required String? targetId,
    required bool targetLocked,
  }) async {
    if (targetLocked || _actionInProgress) return;

    if (payload.sourceType == targetType) {
      if (targetType == BankDragSourceType.bank && targetSlot >= _totalSlots) {
        return;
      }
    }

    if (payload.sourceType == BankDragSourceType.inventory &&
        payload.sourceId.isEmpty) {
      return;
    }
    if (payload.sourceType == BankDragSourceType.bank &&
        payload.sourceId.isEmpty) {
      return;
    }

    final bool isStackable = payload.isStackable;

    int transferQty = payload.quantity;
    if (isStackable && payload.quantity > 1) {
      final int? picked = await _askQuantity(
        title: payload.sourceType == BankDragSourceType.inventory
            ? 'Envanterden Taşıma'
            : 'Bankadan Taşıma',
        subtitle: 'Maksimum: ${payload.quantity} adet',
        maxQuantity: payload.quantity,
        accent: const Color(0xFFFBBF24),
      );
      if (picked == null) return;
      transferQty = picked;
    }

    await _performSwap(
      payload: payload,
      targetType: targetType,
      targetSlot: targetSlot,
      targetId: targetId,
      quantity: transferQty,
    );
  }

  Future<void> _depositSingle(InventoryItem item) async {
    if (_actionInProgress) return;
    if (item.quantity <= 0) {
      if (mounted) {
        AppMessenger.show(context, 'Yatırılacak geçerli miktar yok.');
      }
      return;
    }

    int qty = item.quantity;
    if (item.isStackable && item.quantity > 1) {
      final int? picked = await _askQuantity(
        title: 'Bankaya Aktar',
        subtitle: 'Envanterde: ${item.quantity} adet',
        maxQuantity: item.quantity,
        accent: const Color(0xFFFBBF24),
      );
      if (picked == null) return;
      qty = picked;
    }

    final BankDragPayload payload = BankDragPayload(
      sourceType: BankDragSourceType.inventory,
      sourceId: item.rowId,
      itemId: item.itemId,
      name: item.name,
      quantity: item.quantity,
      isStackable: item.isStackable,
    );

    await _performSwap(
      payload: payload,
      targetType: BankDragSourceType.bank,
      targetSlot: -1,
      targetId: null,
      quantity: qty,
    );
  }

  Future<void> _depositBatch() async {
    if (_selectedInventoryRowIds.isEmpty || _actionInProgress) return;

    final InventoryState inventoryState = ref.read(inventoryProvider);
    final List<InventoryItem> selectedRows = inventoryState.items
        .where((InventoryItem item) => !item.isEquipped)
        .where(
          (InventoryItem item) => _selectedInventoryRowIds.contains(item.rowId),
        )
        .where((InventoryItem item) => item.quantity > 0)
        .toList();

    if (selectedRows.isEmpty) {
      if (mounted) {
        AppMessenger.show(context, 'Yatırılacak geçerli eşya seçilmedi.');
      }
      return;
    }

    final List<String> rowIds = selectedRows
        .map((InventoryItem e) => e.rowId)
        .toList();
    final List<int> quantities = selectedRows
        .map((InventoryItem e) => e.quantity)
        .toList();

    setState(() => _depositing = true);
    try {
      await SupabaseService.client.rpc(
        'deposit_to_bank',
        params: <String, dynamic>{
          'p_item_row_ids': rowIds,
          'p_quantities': quantities,
        },
      );

      if (!mounted) return;
      AppMessenger.show(context, '${rowIds.length} eşya bankaya yatırıldı');
      _selectedInventoryRowIds.clear();
      await BankTutorial.markDepositCoachShown();
      await _refreshAll();
      await TutorialTriggers.onBankDeposit(ref);
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showError(
        context,
        userFacingErrorMessage(e, fallback: 'Yatırma başarısız.'),
      );
    } finally {
      if (mounted) setState(() => _depositing = false);
    }
  }

  Future<void> _withdrawSingle(Map<String, dynamic> bankItem) async {
    if (_actionInProgress) return;

    final String id = bankItem['id']?.toString() ?? '';
    final String name = bankItem['name']?.toString() ?? 'Eşya';
    final String itemId = bankItem['item_id']?.toString() ?? '';
    final int maxQty = bankAsInt(bankItem['quantity']);

    if (id.isEmpty || maxQty <= 0) {
      if (mounted) {
        AppMessenger.show(context, 'Bankada çekilecek geçerli miktar yok.');
      }
      return;
    }

    int qty = maxQty;
    final bool stackable = bankRowIsStackable(bankItem);
    if (stackable && maxQty > 1) {
      final int? picked = await _askQuantity(
        title: 'Bankadan Çek',
        subtitle: 'Bankada: $maxQty adet',
        maxQuantity: maxQty,
        accent: Colors.greenAccent,
      );
      if (picked == null) return;
      qty = picked;
    }

    setState(() => _withdrawing = true);
    try {
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      final InventoryAddCheck addCheck = ref
          .read(inventoryProvider.notifier)
          .canAddItem(itemId: itemId, quantity: qty);
      if (!addCheck.canAdd) {
        if (mounted) {
          AppMessenger.show(context, addCheck.reason ?? 'Envanter dolu!');
        }
        return;
      }

      final dynamic raw = await SupabaseService.client.rpc(
        'withdraw_from_bank',
        params: <String, dynamic>{
          'p_bank_item_ids': <String>[id],
          'p_quantities': <int>[qty],
        },
      );

      final Map<String, dynamic>? result = _readBankRpcResult(raw);
      final bool success = result?['success'] != false;
      final int withdrawnCount = bankAsInt(
        result?['items_withdrawn'],
        fallback: 0,
      );
      if (!mounted) return;
      if (!success || withdrawnCount <= 0) {
        AppMessenger.showError(
          context,
          result?['message']?.toString() ?? 'Çekme başarısız.',
        );
        return;
      }

      AppMessenger.show(context, '$name envanterinize taşındı');
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showError(
        context,
        userFacingErrorMessage(e, fallback: 'Çekme başarısız.'),
      );
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  Future<void> _withdrawBatch() async {
    if (_selectedBankIds.isEmpty || _actionInProgress) return;

    final List<Map<String, dynamic>> selectedRows = _bankItems.where((
      Map<String, dynamic> row,
    ) {
      final String rid = row['id']?.toString() ?? '';
      return rid.isNotEmpty && _selectedBankIds.contains(rid);
    }).toList();

    final List<String> validIds = <String>[];
    final List<int> quantities = <int>[];
    final Map<String, int> demandByItem = <String, int>{};

    for (final Map<String, dynamic> row in selectedRows) {
      final String rid = row['id']?.toString() ?? '';
      final String itemId = row['item_id']?.toString() ?? '';
      final int qty = bankAsInt(row['quantity']);
      if (rid.isEmpty || qty <= 0) continue;
      validIds.add(rid);
      quantities.add(qty);
      if (itemId.isNotEmpty) {
        demandByItem[itemId] = (demandByItem[itemId] ?? 0) + qty;
      }
    }

    if (validIds.isEmpty) {
      if (mounted) {
        AppMessenger.show(context, 'Çekilecek geçerli banka eşyası yok.');
      }
      return;
    }

    setState(() => _withdrawing = true);
    try {
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      final InventoryAddCheck batchCheck = ref
          .read(inventoryProvider.notifier)
          .canAddBatch(demandByItem);
      if (!batchCheck.canAdd) {
        if (mounted) {
          AppMessenger.show(context, batchCheck.reason ?? 'Envanter dolu!');
        }
        return;
      }

      final dynamic raw = await SupabaseService.client.rpc(
        'withdraw_from_bank',
        params: <String, dynamic>{
          'p_bank_item_ids': validIds,
          'p_quantities': quantities,
        },
      );

      final Map<String, dynamic>? result = _readBankRpcResult(raw);
      final bool success = result?['success'] != false;
      final int withdrawnCount = bankAsInt(
        result?['items_withdrawn'],
        fallback: 0,
      );
      final String? message = result?['message']?.toString();

      if (!mounted) return;
      if (!success || withdrawnCount <= 0) {
        AppMessenger.showError(
          context,
          message ?? 'Toplu çekme başarısız.',
        );
        return;
      }

      if (withdrawnCount < validIds.length) {
        AppMessenger.show(
          context,
          '$withdrawnCount / ${validIds.length} eşya envanterinize taşındı',
        );
      } else {
        AppMessenger.show(
          context,
          '$withdrawnCount eşya envanterinize taşındı',
        );
      }
      _selectedBankIds.clear();
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showError(
        context,
        userFacingErrorMessage(e, fallback: 'Toplu çekme başarısız.'),
      );
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  Future<void> _unlockNextBankSlot() async {
    if (_totalSlots >= bankMaxSlots) {
      AppMessenger.show(context, 'Maksimum slot sayısına ulaşıldı');
      return;
    }
    if (_actionInProgress) return;

    final int nextSlot = bankNextSlotIndex(_totalSlots);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2030),
        title: const Text(
          'Banka Slotu Aç',
          style: TextStyle(color: Color(0xFFFBBF24)),
        ),
        content: Text(
          'Slot $nextSlot açılacak.\n\n'
          '$bankSlotUnlockCost 💎 harcanır '
          '($_totalSlots → $nextSlot).\n\n'
          'Kilitli slota dokunarak da açabilirsin.',
          style: const TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBBF24),
              foregroundColor: Colors.black,
            ),
            child: Text(
              '$bankSlotUnlockCost 💎 · Slot $nextSlot',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _expanding = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc('expand_bank_slots');

      final Map<String, dynamic>? result = _readBankRpcResult(raw);
      final bool success = result?['success'] != false;
      final String? message = result?['message']?.toString();

      if (!success) {
        if (!mounted) return;
        AppMessenger.showError(
          context,
          message ?? 'Slot açılamadı.',
        );
        return;
      }

      await Future.wait(<Future<void>>[
        _loadData(silent: true),
        ref.read(playerProvider.notifier).loadProfile(),
      ]);

      if (!mounted) return;
      final int newTotal = bankAsInt(
        result?['new_total_slots'],
        fallback: nextSlot,
      );
      AppMessenger.show(
        context,
        'Slot açıldı: $newTotal / $bankMaxSlots',
      );
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showError(
        context,
        userFacingErrorMessage(e, fallback: 'Slot açılamadı.'),
      );
    } finally {
      if (mounted) setState(() => _expanding = false);
    }
  }

  Widget _buildInventoryArea() {
    final InventoryState inventoryState = ref.watch(inventoryProvider);
    final List<InventoryItem> items = inventoryState.items
        .where((InventoryItem item) => !item.isEquipped)
        .where((InventoryItem item) => item.quantity > 0)
        .toList();

    final int totalPages = (items.length / bankInventoryPerPage).ceil().clamp(
      1,
      9999,
    );
    final int currentPage = _inventoryPage.clamp(1, totalPages);

    final List<InventoryItem?> pageSlots = _buildInventorySlots(
      items,
      currentPage,
    );
    final int pageStart = (currentPage - 1) * bankInventoryPerPage;

    return DottedPanel(
      padding: EdgeInsets.zero,
      borderColor: BankDesign.deposit.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TutorialAnchorScope(
            id: TutorialAnchorId.bankDepositBtn,
            child: BankSectionHeader(
              title: 'Envanter',
              actionText: 'Yatır (${_selectedInventoryRowIds.length})',
              actionColor: BankDesign.deposit,
              enabled: _selectedInventoryRowIds.isNotEmpty,
              loading: _depositing,
              onAction: () async {
                await TutorialTriggers.onAnchorTap(
                  ref,
                  TutorialAnchorId.bankDepositBtn,
                );
                await _depositBatch();
              },
              selectedCount: _selectedInventoryRowIds.length,
              onClear: () => setState(_selectedInventoryRowIds.clear),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: BankFixedSlotGrid(
              itemCount: bankInventoryPerPage,
              itemBuilder: (BuildContext context, int index) {
                final int globalSlotIndex = pageStart + index;
                final InventoryItem? item = pageSlots[index];
                final String? targetId = item?.rowId;
                final bool selected =
                    item != null && _selectedInventoryRowIds.contains(item.rowId);

                return DragTarget<BankDragPayload>(
                  onWillAcceptWithDetails:
                      (DragTargetDetails<BankDragPayload> details) {
                        if (_actionInProgress) return false;
                        if (details.data.sourceType ==
                                BankDragSourceType.inventory &&
                            details.data.sourceId == targetId) {
                          return false;
                        }
                        return true;
                      },
                  onAcceptWithDetails:
                      (DragTargetDetails<BankDragPayload> details) {
                        unawaited(
                          _handleDrop(
                            payload: details.data,
                            targetType: BankDragSourceType.inventory,
                            targetSlot: globalSlotIndex,
                            targetId: targetId,
                            targetLocked: false,
                          ),
                        );
                      },
                  builder:
                      (
                        BuildContext context,
                        List<BankDragPayload?> candidateData,
                        List<dynamic> rejectedData,
                      ) {
                        return BankInventorySlot(
                          item: item,
                          globalSlotIndex: globalSlotIndex,
                          isDragTargetActive: candidateData.isNotEmpty,
                          isSelected: selected,
                          onDragStarted: _dragScrollCoordinator.handleDragStarted,
                          onDragUpdate: _dragScrollCoordinator.handleDragUpdate,
                          onDragEnd: _dragScrollCoordinator.handleDragEnd,
                          onTap: item == null
                              ? null
                              : () {
                                  setState(() {
                                    if (selected) {
                                      _selectedInventoryRowIds.remove(item.rowId);
                                    } else {
                                      _selectedInventoryRowIds.add(item.rowId);
                                    }
                                  });
                                },
                          onLongPress:
                              item == null ? null : () => _depositSingle(item),
                        );
                      },
                );
              },
            ),
          ),
          BankPageControls(
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: (int page) => setState(() => _inventoryPage = page),
          ),
        ],
      ),
    );
  }

  Widget _buildBankArea() {
    final int bankTotalPages = (bankMaxSlots / bankSlotsPerPage).ceil();
    final int currentPage = _bankPage.clamp(1, bankTotalPages);
    final int bankStartIndex = (currentPage - 1) * bankSlotsPerPage;

    return DottedPanel(
      padding: EdgeInsets.zero,
      borderColor: BankDesign.withdraw.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BankSectionHeader(
            title: 'Banka Kasası',
            actionText: 'Çek (${_selectedBankIds.length})',
            actionColor: BankDesign.withdraw,
            enabled: _selectedBankIds.isNotEmpty,
            loading: _withdrawing,
            onAction: _withdrawBatch,
            selectedCount: _selectedBankIds.length,
            onClear: () => setState(_selectedBankIds.clear),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: BankFixedSlotGrid(
              itemCount: bankSlotsPerPage,
              itemBuilder: (BuildContext context, int index) {
                final int globalSlotIndex = bankStartIndex + index;
                final bool isLocked = globalSlotIndex >= _totalSlots;
                final Map<String, dynamic>? item = _findBankItemAtSlot(
                  globalSlotIndex,
                );
                final String? targetId = item?['id']?.toString();
                final bool selected = item != null &&
                    _selectedBankIds.contains(item['id']?.toString() ?? '');
                final int unlockCost = bankSlotUnlockCost;

                return DragTarget<BankDragPayload>(
                  onWillAcceptWithDetails:
                      (DragTargetDetails<BankDragPayload> details) {
                        if (_actionInProgress || isLocked) return false;
                        if (details.data.sourceType == BankDragSourceType.bank &&
                            details.data.sourceId == targetId) {
                          return false;
                        }
                        return true;
                      },
                  onAcceptWithDetails:
                      (DragTargetDetails<BankDragPayload> details) {
                        unawaited(
                          _handleDrop(
                            payload: details.data,
                            targetType: BankDragSourceType.bank,
                            targetSlot: globalSlotIndex,
                            targetId: targetId,
                            targetLocked: isLocked,
                          ),
                        );
                      },
                  builder:
                      (
                        BuildContext context,
                        List<BankDragPayload?> candidateData,
                        List<dynamic> rejectedData,
                      ) {
                        return BankStorageSlot(
                          item: item,
                          globalSlotIndex: globalSlotIndex,
                          isLocked: isLocked,
                          isDragTargetActive: candidateData.isNotEmpty,
                          isSelected: selected,
                          unlockGemCost: isLocked ? unlockCost : null,
                          onDragStarted: _dragScrollCoordinator.handleDragStarted,
                          onDragUpdate: _dragScrollCoordinator.handleDragUpdate,
                          onDragEnd: _dragScrollCoordinator.handleDragEnd,
                          onTap: isLocked
                              ? (_expanding || _actionInProgress
                                    ? null
                                    : _unlockNextBankSlot)
                              : item == null
                              ? null
                              : () {
                                  final String id = item['id']?.toString() ?? '';
                                  setState(() {
                                    if (selected) {
                                      _selectedBankIds.remove(id);
                                    } else {
                                      _selectedBankIds.add(id);
                                    }
                                  });
                                },
                          onLongPress: (item == null || isLocked)
                              ? null
                              : () => _withdrawSingle(item),
                        );
                      },
                );
              },
            ),
          ),
          BankPageControls(
            currentPage: currentPage,
            totalPages: bankTotalPages,
            onPageChanged: (int page) => setState(() => _bankPage = page),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    logoutHandler() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.screenTitleBank, onLogout: logoutHandler),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.bank, onLogout: logoutHandler),
      body: GameScreenBackground(
        child: SafeArea(
          bottom: false,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: BankDesign.gold),
                )
              : _loadError != null
              ? InlineErrorRetry(message: _loadError!, onRetry: _loadData)
              : SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    bottom: gameBottomBarClearance(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      BankStatsCard(
                        totalSlots: _totalSlots,
                        usedSlots: _usedSlots,
                        maxSlots: bankMaxSlots,
                        expanding: _expanding,
                        actionInProgress: _actionInProgress,
                        onExpand: _unlockNextBankSlot,
                      ),
                      const BankDragHint(),
                      const SizedBox(height: 10),
                      _buildInventoryArea(),
                      const SizedBox(height: 12),
                      _buildBankArea(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
