import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'package:gkk_flutter/components/common/item_icon_view.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../l10n/l10n.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/trade_invite_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import 'widgets/trade_theme.dart';

class TradeScreen extends ConsumerStatefulWidget {
  const TradeScreen({super.key});

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen> {
  int _tabIndex = 0;
  String _tradeStatus = 'idle';
  String _partnerName = '';
  String? _sessionId;
  List<Map<String, dynamic>> _blockedTradeUsers = <Map<String, dynamic>>[];
  bool _blockedTradeLoaded = false;
  bool _blockedPanelExpanded = false;
  List<Map<String, dynamic>> _myOffer = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _partnerOffer = <Map<String, dynamic>>[];
  int _myGold = 0;
  int _partnerGold = 0;
  bool _myConfirmed = false;
  bool _partnerConfirmed = false;
  bool _processing = false;
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];
  bool _historyLoading = false;
  String? _historyError;
  Timer? _sessionPollTimer;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _goldController = TextEditingController();

  static const Map<String, String> _statusLabels = <String, String>{
    'idle': '',
    'searching': '⏳ Oyuncu aranıyor...',
    'pending': '⏳ Ticaret başlatıldı, karşı taraf bekleniyor...',
    'active': '',
    'confirming': '✅ Onayınız alındı, karşı taraf bekleniyor',
    'done': '🎉 Ticaret tamamlandı',
  };

  int get _playerGoldBalance => ref.read(playerProvider).profile?.gold ?? 0;

  bool get _hasTradeOffer => _myOffer.isNotEmpty || _myGold > 0;

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  bool _canDirectTradeItem(InventoryItem item) =>
      item.isTradeable && (item.isDirectTradeable ?? true);

  @override
  void initState() {
    super.initState();
    ref.listenManual<TradeInviteState>(
      tradeInviteProvider,
      (TradeInviteState? previous, TradeInviteState next) {
        if (previous?.blockListRevision != next.blockListRevision) {
          unawaited(_loadBlockedTradeUsers(silent: true));
          if (mounted && next.blockListRevision > (previous?.blockListRevision ?? 0)) {
            setState(() => _blockedPanelExpanded = true);
          }
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadInventory();
      unawaited(_loadHistory());
      unawaited(_loadBlockedTradeUsers());
      unawaited(_restoreActiveSession());
    });
  }

  @override
  void dispose() {
    _stopSessionPolling();
    _searchController.dispose();
    _goldController.dispose();
    super.dispose();
  }

  void _startSessionPolling() {
    _sessionPollTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refreshTradeSession());
    });
  }

  void _stopSessionPolling() {
    _sessionPollTimer?.cancel();
    _sessionPollTimer = null;
  }

  List<Map<String, dynamic>> _parseTradeItems(dynamic raw) {
    if (raw == null) return <Map<String, dynamic>>[];
    dynamic decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _parseHistoryEntries(dynamic raw) {
    if (raw == null) return <Map<String, dynamic>>[];
    dynamic decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> _restoreActiveSession() async {
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_my_active_trade_session');
      if (raw is! Map || raw['success'] != true || !mounted) return;

      final String sessionId = raw['session_id'].toString();
      final String status = (raw['status'] as String?) ?? 'pending';
      final bool isInitiator = raw['is_initiator'] == true;

      if (status == 'pending' && !isInitiator) {
        return;
      }

      setState(() {
        _sessionId = sessionId;
        _tradeStatus = status;
      });
      _startSessionPolling();
    } catch (_) {
      // No active session — stay idle.
    }
  }

  Future<void> _loadBlockedTradeUsers({bool silent = false}) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_blocked_trade_users');
      if (!mounted) return;
      final List<Map<String, dynamic>> loaded = <Map<String, dynamic>>[];
      dynamic decoded = raw;
      if (raw is String) {
        try {
          decoded = jsonDecode(raw);
        } catch (_) {
          decoded = null;
        }
      }
      if (decoded is List) {
        for (final dynamic row in decoded) {
          if (row is Map) loaded.add(Map<String, dynamic>.from(row));
        }
      }
      if (_blockedListsEqual(_blockedTradeUsers, loaded)) {
        if (!_blockedTradeLoaded && mounted) {
          setState(() => _blockedTradeLoaded = true);
        }
        return;
      }
      setState(() {
        _blockedTradeUsers = loaded;
        _blockedTradeLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _blockedTradeLoaded = true);
    }
  }

  bool _blockedListsEqual(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> next,
  ) {
    if (current.length != next.length) return false;
    final Set<String> currentIds = current
        .map((Map<String, dynamic> row) => row['blocked_id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();
    final Set<String> nextIds = next
        .map((Map<String, dynamic> row) => row['blocked_id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();
    return currentIds.length == nextIds.length && currentIds.containsAll(nextIds);
  }

  Future<void> _unblockTradeUser(String blockedId, String username) async {
    if (blockedId.isEmpty) return;
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'unblock_trade_user',
        params: <String, dynamic>{'p_blocked_id': blockedId},
      );
      if (!mounted) return;
      if (raw is Map && raw['success'] == true) {
        setState(() {
          _blockedTradeUsers = _blockedTradeUsers
              .where((Map<String, dynamic> row) => row['blocked_id']?.toString() != blockedId)
              .toList();
        });
        AppMessenger.showSuccess(context, '@$username engeli kaldırıldı');
      } else {
        AppMessenger.showError(
          context,
          (raw is Map ? raw['error'] as String? : null) ?? 'Engel kaldırılamadı',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showError(
        context,
        userFacingErrorMessage(e, fallback: 'Engel kaldırılamadı.'),
      );
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_trade_history');
      if (!mounted) return;
      setState(() {
        _history = _parseHistoryEntries(raw);
        _historyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyLoading = false;
        _historyError = 'Geçmiş yüklenemedi';
      });
    }
  }

  Future<void> _refreshTradeSession() async {
    final String? sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'get_trade_session_details',
        params: <String, dynamic>{'p_session_id': sessionId},
      );
      if (!mounted || raw is! Map) return;
      final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
      if (data['success'] != true) return;

      final String status = (data['status'] as String?) ?? 'active';
      final List<Map<String, dynamic>> myItems = _parseTradeItems(data['my_items']);
      final List<Map<String, dynamic>> partnerItems = _parseTradeItems(data['partner_items']);
      final int myGold = (data['my_gold'] as num?)?.toInt() ?? 0;
      final int partnerGold = (data['partner_gold'] as num?)?.toInt() ?? 0;
      final bool myConfirmed = data['my_confirmed'] == true;
      final bool partnerConfirmed = data['partner_confirmed'] == true;
      final String? partnerName = data['partner_name'] as String?;

      setState(() {
        _myOffer = myItems;
        _partnerOffer = partnerItems;
        _myGold = myGold;
        _partnerGold = partnerGold;
        _myConfirmed = myConfirmed;
        _partnerConfirmed = partnerConfirmed;
        if (partnerName != null && partnerName.isNotEmpty) {
          _partnerName = partnerName;
        }

        if (status == 'completed') {
          _tradeStatus = 'done';
          _stopSessionPolling();
          ref.read(inventoryProvider.notifier).loadInventory();
          ref.read(playerProvider.notifier).loadProfile();
        } else if (status == 'cancelled') {
          _resetTrade();
        } else if (status == 'pending') {
          _tradeStatus = 'pending';
        } else if (myConfirmed && !partnerConfirmed) {
          _tradeStatus = 'confirming';
        } else {
          _tradeStatus = 'active';
        }

        if (myGold > 0 && _goldController.text.isEmpty) {
          _goldController.text = myGold.toString();
        }
      });
    } catch (_) {
      // Polling retries.
    }
  }

  Future<void> _handleSearch() async {
    final String target = _searchController.text.trim();
    if (target.isEmpty) {
      AppMessenger.showWarning(context, 'Oyuncu adı girin!');
      return;
    }
    setState(() {
      _processing = true;
      _tradeStatus = 'searching';
    });
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'initiate_trade',
        params: <String, dynamic>{'target_username': target},
      );
      if (!mounted) return;
      String sessionId = '';
      String partnerName = target;
      String status = 'pending';
      if (raw is Map) {
        if (raw['success'] == false) {
          throw Exception((raw['error'] as String?) ?? 'Ticaret başlatılamadı');
        }
        sessionId = raw['session_id']?.toString() ?? '';
        partnerName = (raw['partner_name'] as String?) ?? target;
        status = (raw['status'] as String?) ?? 'pending';
      }
      setState(() {
        _sessionId = sessionId.isNotEmpty ? sessionId : null;
        _partnerName = partnerName;
        _tradeStatus = sessionId.isNotEmpty ? status : 'idle';
        _processing = false;
      });
      if (sessionId.isNotEmpty) {
        _startSessionPolling();
        await _refreshTradeSession();
      }
      if (mounted) {
        AppMessenger.show(context, '$target ile ticaret başlatıldı');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tradeStatus = 'idle';
        _processing = false;
      });
      AppMessenger.showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _addItemToOffer(InventoryItem item) async {
    if (!_canDirectTradeItem(item)) {
      AppMessenger.showWarning(context, 'Bu eşya takas edilemez');
      return;
    }
    if (_myOffer.any((Map<String, dynamic> o) => o['row_id'] == item.rowId)) {
      AppMessenger.showWarning(context, 'Bu eşya zaten teklifte');
      return;
    }
    if (_sessionId != null) {
      try {
        await SupabaseService.client.rpc(
          'add_trade_item',
          params: <String, dynamic>{
            'p_session_id': _sessionId,
            'p_item_row_id': item.rowId,
          },
        );
      } catch (e) {
        if (mounted) {
          AppMessenger.show(context, 'Eşya sunucuya eklenemedi');
        }
        return;
      }
    }
    await _refreshTradeSession();
    if (mounted) {
      AppMessenger.show(context, '${item.name} teklife eklendi');
    }
  }

  Future<void> _removeFromOffer(String rowId) async {
    if (_sessionId != null) {
      try {
        await SupabaseService.client.rpc(
          'remove_trade_item',
          params: <String, dynamic>{
            'p_session_id': _sessionId,
            'p_item_row_id': rowId,
          },
        );
      } catch (_) {
        if (mounted) {
          AppMessenger.show(context, 'Eşya kaldırılamadı');
        }
        return;
      }
    }
    await _refreshTradeSession();
  }

  Future<void> _applyGold() async {
    if (_sessionId == null) return;
    final int amount = int.tryParse(_goldController.text.trim()) ?? 0;
    if (amount < 0) {
      AppMessenger.showWarning(context, 'Geçersiz altın miktarı');
      return;
    }
    setState(() => _processing = true);
    try {
      await SupabaseService.client.rpc(
        'set_trade_gold',
        params: <String, dynamic>{
          'p_session_id': _sessionId,
          'p_amount': amount,
        },
      );
      await _refreshTradeSession();
    } catch (_) {
      if (mounted) {
        AppMessenger.show(context, 'Altın eklenemedi');
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _confirmTrade() async {
    if (_myOffer.isEmpty && _myGold <= 0) {
      AppMessenger.showWarning(context, 'En az 1 eşya veya altın ekleyin!');
      return;
    }
    setState(() {
      _processing = true;
      _tradeStatus = 'confirming';
    });
    try {
      if (_sessionId != null) {
        await SupabaseService.client.rpc(
          'confirm_trade',
          params: <String, dynamic>{'p_session_id': _sessionId},
        );
      }
      if (!mounted) return;
      await _refreshTradeSession();
      if (_tradeStatus == 'done') {
        AppMessenger.showSuccess(context, '🎉 Ticaret tamamlandı!');
        await _loadHistory();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _tradeStatus = 'active');
      AppMessenger.show(context, 'Ticaret onaylanamadı');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _cancelTrade() async {
    setState(() => _processing = true);
    if (_sessionId != null) {
      try {
        await SupabaseService.client.rpc(
          'cancel_trade',
          params: <String, dynamic>{'p_session_id': _sessionId},
        );
      } catch (_) {
        if (mounted) {
          AppMessenger.show(context, 'İptal sunucuya iletilemedi');
        }
      }
    }
    if (!mounted) return;
    _resetTrade();
    setState(() => _processing = false);
    AppMessenger.showInfo(context, 'Ticaret iptal edildi');
    await _loadHistory();
  }

  void _resetTrade() {
    _stopSessionPolling();
    setState(() {
      _tradeStatus = 'idle';
      _searchController.clear();
      _goldController.clear();
      _partnerName = '';
      _sessionId = null;
      _myOffer = <Map<String, dynamic>>[];
      _partnerOffer = <Map<String, dynamic>>[];
      _myGold = 0;
      _partnerGold = 0;
      _myConfirmed = false;
      _partnerConfirmed = false;
    });
    unawaited(_loadBlockedTradeUsers(silent: true));
  }

  void _showItemPicker(BuildContext context) {
    final InventoryState invState = ref.read(inventoryProvider);
    final Set<String> equippedRowIds = invState.equippedItems.values
        .whereType<InventoryItem>()
        .map((InventoryItem i) => i.rowId)
        .toSet();
    final Set<String> offeredRowIds = _myOffer
        .map((Map<String, dynamic> o) => o['row_id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    final List<InventoryItem> inventoryItems = invState.items
        .where((InventoryItem i) =>
            !i.isEquipped &&
            i.isTradeable &&
            !equippedRowIds.contains(i.rowId) &&
            !offeredRowIds.contains(i.rowId))
        .toList()
      ..sort((InventoryItem a, InventoryItem b) {
        final int aOk = _canDirectTradeItem(a) ? 0 : 1;
        final int bOk = _canDirectTradeItem(b) ? 0 : 1;
        if (aOk != bOk) return aOk - bOk;
        return a.name.compareTo(b.name);
      });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return GestureDetector(
          onTap: _dismissKeyboard,
          child: Container(
            height: MediaQuery.of(sheetContext).size.height * 0.55,
            decoration: BoxDecoration(
              color: AppColors.spaceNavy,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(color: AppColors.darkObsidian),
            ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          '📤 Eşya Seç',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close, color: AppColors.mutedTitanium, size: 20),
                      ),
                    ],
                  ),
                ),
                Divider(color: AppColors.darkObsidian, height: 1),
                Expanded(
                  child: inventoryItems.isEmpty
                      ? const Center(
                          child: Text(
                            'Taşınabilir eşya yok',
                            style: TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(10),
                          itemCount: inventoryItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (BuildContext ctx, int i) {
                            final InventoryItem item = inventoryItems[i];
                            final bool tradable = _canDirectTradeItem(item);
                            final Color accent = _rarityColor(item.rarity.name);
                            return Opacity(
                              opacity: tradable ? 1 : 0.38,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: tradable
                                      ? () {
                                          Navigator.pop(sheetContext);
                                          unawaited(_addItemToOffer(item));
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.carbonVoid.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border(left: BorderSide(color: accent, width: 2)),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        _buildInventoryItemIcon(item, size: 34),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                item.name,
                                                style: TextStyle(
                                                  color: accent,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                tradable ? 'x${item.quantity}' : 'Takas edilemez',
                                                style: const TextStyle(
                                                  color: AppColors.mutedTitanium,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (tradable)
                                          const Icon(
                                            Icons.add_circle_outline,
                                            size: 16,
                                            color: AppColors.liquidGold,
                                          ),
                                      ],
                                    ),
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

  Color _rarityColor(String rarity) => AppColors.forRarity(rarity);

  ItemType? _parseItemType(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final ItemType type in ItemType.values) {
      if (type.name == raw.toLowerCase()) return type;
    }
    return null;
  }

  Widget _buildTradeItemIcon({
    required String icon,
    String? itemId,
    required String rarity,
    double size = 32,
    ItemType? itemType,
  }) {
    final Color accent = _rarityColor(rarity);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
        color: AppColors.darkObsidian.withValues(alpha: 0.55),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: ItemIconView(
          iconValue: icon,
          itemId: itemId,
          itemType: itemType,
          size: size - 4,
          expand: true,
          fallback: '📦',
        ),
      ),
    );
  }

  Widget _buildTradeItemIconFromMap(Map<String, dynamic> item, {double size = 32}) {
    return _buildTradeItemIcon(
      icon: (item['icon'] as String?) ?? '',
      itemId: item['item_id']?.toString(),
      itemType: _parseItemType(item['item_type']?.toString()),
      rarity: (item['rarity'] as String?) ?? 'common',
      size: size,
    );
  }

  Widget _buildInventoryItemIcon(InventoryItem item, {double size = 36}) {
    return _buildTradeItemIcon(
      icon: item.icon,
      itemId: item.itemId,
      itemType: item.itemType,
      rarity: item.rarity.name,
      size: size,
    );
  }

  Widget _buildGoldChip(int amount, {bool compact = false}) {
    if (amount <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 4 : 6,
      ),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AppColors.liquidGold.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.monetization_on, size: compact ? 14 : 16, color: AppColors.liquidGold),
          const SizedBox(width: 4),
          Text(
            '$amount Altın',
            style: TextStyle(
              color: AppColors.liquidGold,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferItemChip(
    Map<String, dynamic> offer, {
    required bool isMine,
    bool allowRemove = true,
  }) {
    final String rarity = (offer['rarity'] as String?) ?? 'common';
    final Color accent = _rarityColor(rarity);
    final int qty = (offer['quantity'] as num?)?.toInt() ?? 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: AppColors.carbonVoid.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: accent, width: 2)),
      ),
      child: Row(
        children: <Widget>[
          _buildTradeItemIconFromMap(offer, size: 28),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              (offer['name'] as String?) ?? '',
              style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'x$qty',
            style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 9),
          ),
          if (isMine && allowRemove) ...<Widget>[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => unawaited(_removeFromOffer(offer['row_id'].toString())),
              child: const Icon(Icons.close, size: 12, color: AppColors.mysticRuby),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryOfferColumn({
    required String title,
    required List<Map<String, dynamic>> items,
    required int gold,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 10)),
        const SizedBox(height: 4),
        if (gold > 0) _buildGoldChip(gold, compact: true),
        if (items.isEmpty && gold == 0)
          const Text('—', style: TextStyle(color: AppColors.mutedTitanium, fontSize: 11))
        else
          ...items.map(
            (Map<String, dynamic> item) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: <Widget>[
                  _buildTradeItemIconFromMap(item, size: 26),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${item['name']} x${(item['quantity'] as num?)?.toInt() ?? 1}',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTradeSummaryRow({bool allowRemove = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _buildOfferPanel(
            title: '📤 Teklifim',
            offers: _myOffer,
            goldAmount: _myGold,
            accent: AppColors.liquidGold,
            isMine: true,
            allowRemove: allowRemove,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildOfferPanel(
            title: '📥 Karşı Teklif',
            offers: _partnerOffer,
            goldAmount: _partnerGold,
            accent: AppColors.toxicNeon,
            isMine: false,
            allowRemove: false,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.screenTitleTrade,
        onLogout: () => performLogout(ref),
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.trade,
        onLogout: () => performLogout(ref),
      ),
      body: TradeBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: <Widget>[
                    _buildTab(0, '🤝 Ticaret'),
                    const SizedBox(width: 8),
                    _buildTab(1, '📜 Geçmiş'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: GameScrollLayout.pagePadding(context),
                  child: _tabIndex == 0 ? _buildTradeTab() : _buildHistoryTab(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final bool active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_tabIndex == index) return;
          setState(() => _tabIndex = index);
          if (index == 0) {
            unawaited(_loadBlockedTradeUsers(silent: true));
          }
        },
        child: TradeNeonPanel(
          accent: active ? AppColors.liquidGold : AppColors.mutedTitanium,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AppColors.liquidGold : AppColors.mutedTitanium,
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTradeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_tradeStatus != 'idle' && (_statusLabels[_tradeStatus] ?? '').isNotEmpty)
          TradeNeonPanel(
            accent: AppColors.cyberFuchsia,
            padding: const EdgeInsets.all(12),
            child: Text(
              _statusLabels[_tradeStatus] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
            ),
          ),
        if (_tradeStatus != 'idle' && (_statusLabels[_tradeStatus] ?? '').isNotEmpty)
          const SizedBox(height: 8),
        if (_tradeStatus == 'idle') _buildIdleState(),
        if (_tradeStatus == 'searching') _buildSearchingState(),
        if (_tradeStatus == 'pending') _buildPendingState(),
        if (_tradeStatus == 'active') _buildActiveState(),
        if (_tradeStatus == 'confirming') _buildConfirmingState(),
        if (_tradeStatus == 'done') _buildDoneState(),
      ],
    );
  }

  Widget _buildIdleState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildPlayerSearchPanel(),
        const SizedBox(height: 12),
        _buildBlockedUsersPanel(),
      ],
    );
  }

  Widget _buildPlayerSearchPanel() {
    return TradeNeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Ticaret yapmak istediğiniz oyuncuyu arayın.',
            style: TextStyle(color: AppColors.mutedTitanium, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Oyuncu adı...',
                    hintStyle: TextStyle(color: AppColors.mutedTitanium.withValues(alpha: 0.7)),
                    filled: true,
                    fillColor: AppColors.carbonVoid.withValues(alpha: 0.65),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.darkObsidian),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.darkObsidian),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.liquidGold),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 88,
                child: TradePrimaryButton(
                  label: '🔍 Ara',
                  onPressed: _processing ? null : _handleSearch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUsersPanel() {
    return TradeNeonPanel(
      accent: AppColors.mysticRuby,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _blockedPanelExpanded = !_blockedPanelExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '🚫 Engellenenler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '(${_blockedTradeUsers.length})',
                    style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _blockedPanelExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.mutedTitanium,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _blockedPanelExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildBlockedUsersList(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUsersList() {
    if (_blockedTradeUsers.isEmpty) {
      return Text(
        _blockedTradeLoaded ? 'Engellenen oyuncu yok.' : 'Yükleniyor...',
        style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
      );
    }

    return Column(
      children: _blockedTradeUsers.map((Map<String, dynamic> row) {
        final String blockedId = row['blocked_id']?.toString() ?? '';
        final String username = (row['username'] as String?) ?? 'oyuncu';
        final DateTime? until = DateTime.tryParse(row['blocked_until']?.toString() ?? '');
        final String untilLabel = until == null
            ? ''
            : '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.carbonVoid.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.darkObsidian),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '@$username',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (untilLabel.isNotEmpty)
                        Text(
                          'Engel bitiş: $untilLabel',
                          style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 10),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 78,
                  child: TradePrimaryButton(
                    label: 'Kaldır',
                    height: 34,
                    fontSize: 11,
                    onPressed:
                        blockedId.isEmpty ? null : () => _unblockTradeUser(blockedId, username),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchingState() {
    return TradeNeonPanel(
      accent: AppColors.cyberFuchsia,
      padding: const EdgeInsets.all(32),
      child: const Column(
        children: <Widget>[
          Text('🔍', style: TextStyle(fontSize: 32)),
          SizedBox(height: 8),
          Text('Oyuncu aranıyor...', style: TextStyle(color: AppColors.mutedTitanium)),
          SizedBox(height: 12),
          CircularProgressIndicator(color: AppColors.liquidGold),
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    return TradeNeonPanel(
      accent: AppColors.warningSolar,
      child: Column(
        children: <Widget>[
          const Text('⏳', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            '$_partnerName bekleniyor...',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Ticaret isteği gönderildi. Karşı taraf kabul edene kadar bekleyin.',
            style: TextStyle(color: AppColors.mutedTitanium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TradeSecondaryButton(
            label: 'İptal Et',
            onPressed: _processing ? null : _cancelTrade,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveState() {
    final int balance = _playerGoldBalance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TradeNeonPanel(
          accent: AppColors.toxicNeon,
          child: Row(
            children: <Widget>[
              const Text('🤝', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$_partnerName ile Ticaret',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Bakiyeniz: $balance altın',
                      style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 10),
                    ),
                    if (_partnerConfirmed)
                      const Text(
                        'Karşı taraf onayladı',
                        style: TextStyle(color: AppColors.toxicNeon, fontSize: 10),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 72,
                child: TradeSecondaryButton(
                  label: 'İptal',
                  height: 34,
                  fontSize: 11,
                  onPressed: _cancelTrade,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildTradeSummaryRow(allowRemove: true),
        const SizedBox(height: 8),
        TradeNeonPanel(
          accent: AppColors.liquidGold,
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _goldController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Altın miktarı',
                    hintStyle: TextStyle(color: AppColors.mutedTitanium.withValues(alpha: 0.7)),
                    prefixIcon: const Icon(Icons.monetization_on, color: AppColors.liquidGold, size: 18),
                    filled: true,
                    fillColor: AppColors.carbonVoid.withValues(alpha: 0.55),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.darkObsidian),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.darkObsidian),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.liquidGold),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TradePrimaryButton(
                  label: '💰 Altın',
                  color: AppColors.liquidGold,
                  onPressed: _processing ? null : _applyGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TradePrimaryButton(
          label: '➕ Eşya Ekle',
          color: AppColors.cyberFuchsia,
          textColor: AppColors.textPrimary,
          onPressed: () => _showItemPicker(context),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TradeSecondaryButton(
                label: '❌ İptal',
                onPressed: _processing ? null : _cancelTrade,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TradePrimaryButton(
                label: _myConfirmed ? '⏳ Bekleniyor' : '✅ Onayla',
                color: AppColors.toxicNeon,
                textColor: AppColors.carbonVoid,
                onPressed: (_processing || _myConfirmed || !_hasTradeOffer) ? null : _confirmTrade,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TradeNeonPanel(
          accent: AppColors.warningSolar,
          padding: const EdgeInsets.all(16),
          child: const Column(
            children: <Widget>[
              Text('⏳', style: TextStyle(fontSize: 28)),
              SizedBox(height: 8),
              Text(
                'Onayınız alındı',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Karşı tarafın onayı bekleniyor...',
                style: TextStyle(color: AppColors.mutedTitanium),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildTradeSummaryRow(allowRemove: false),
        const SizedBox(height: 12),
        TradeSecondaryButton(
          label: 'İptal Et',
          onPressed: _processing ? null : _cancelTrade,
        ),
      ],
    );
  }

  Widget _buildOfferPanel({
    required String title,
    required List<Map<String, dynamic>> offers,
    required int goldAmount,
    required Color accent,
    required bool isMine,
    bool allowRemove = true,
  }) {
    return TradeNeonPanel(
      accent: accent,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (goldAmount > 0) _buildGoldChip(goldAmount),
          if (offers.isEmpty && goldAmount == 0)
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.darkObsidian.withValues(alpha: 0.8)),
                color: AppColors.carbonVoid.withValues(alpha: 0.4),
              ),
              child: Center(
                child: Text(
                  isMine ? 'Boş teklif' : 'Henüz teklif yok',
                  style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 10),
                ),
              ),
            )
          else if (offers.isNotEmpty)
            ...offers.map(
              (Map<String, dynamic> offer) =>
                  _buildOfferItemChip(offer, isMine: isMine, allowRemove: allowRemove),
            ),
        ],
      ),
    );
  }

  Widget _buildDoneState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TradeNeonPanel(
          accent: AppColors.toxicNeon,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text(
                'Ticaret Tamamlandı!',
                style: TextStyle(
                  color: AppColors.toxicNeon,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_partnerName ile ticaret başarıyla gerçekleşti.',
                style: const TextStyle(color: AppColors.mutedTitanium),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildTradeSummaryRow(allowRemove: false),
        const SizedBox(height: 12),
        TradePrimaryButton(label: 'Yeni Ticaret', onPressed: _resetTrade),
      ],
    );
  }

  List<Map<String, dynamic>> _historyItems(dynamic raw) {
    if (raw is List) {
      return raw.map((dynamic entry) {
        if (entry is Map) return Map<String, dynamic>.from(entry);
        return <String, dynamic>{'name': entry.toString()};
      }).toList();
    }
    return <Map<String, dynamic>>[];
  }

  Widget _buildHistoryTab() {
    if (_historyLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: AppColors.liquidGold)),
      );
    }
    if (_historyError != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _historyError!,
                style: const TextStyle(color: AppColors.mysticRuby, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TradePrimaryButton(label: 'Tekrar Dene', onPressed: _loadHistory),
            ],
          ),
        ),
      );
    }
    if (_history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('Henüz ticaret geçmişi yok.', style: TextStyle(color: AppColors.mutedTitanium)),
        ),
      );
    }

    return Column(
      children: _history.map((Map<String, dynamic> entry) {
        final bool completed = entry['status'] == 'completed';
        final List<Map<String, dynamic>> myItems = _historyItems(entry['my_items']);
        final List<Map<String, dynamic>> theirItems = _historyItems(entry['their_items']);
        final int myGold = (entry['my_gold'] as num?)?.toInt() ?? 0;
        final int theirGold = (entry['their_gold'] as num?)?.toInt() ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TradeNeonPanel(
            accent: completed ? AppColors.toxicNeon : AppColors.mysticRuby,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('🤝', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            (entry['partner'] as String?) ?? '',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            (entry['date'] as String?) ?? '',
                            style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: (completed ? AppColors.toxicNeon : AppColors.mysticRuby).withValues(alpha: 0.2),
                      ),
                      child: Text(
                        completed ? '✓ Tamamlandı' : '✕ İptal',
                        style: TextStyle(
                          color: completed ? AppColors.toxicNeon : AppColors.mysticRuby,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _buildHistoryOfferColumn(
                        title: '📤 Ben verdim',
                        items: myItems,
                        gold: myGold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHistoryOfferColumn(
                        title: '📥 Ben aldım',
                        items: theirItems,
                        gold: theirGold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
