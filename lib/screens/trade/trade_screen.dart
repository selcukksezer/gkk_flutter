import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/logout_helper.dart';
import '../market/widgets/gold_coin_particle_burst.dart';
import '../market/widgets/market_item_pedestal.dart';
import 'widgets/trade_theme.dart';

/// 2027 Aion 2 Mobile — Player-to-Player Trade Interface.
/// Modernized with metallic filigree offer slots, pulsing lock-in auras,
/// duel-column trade deck, countdown confirmation seal, and rich trade ledger.
class TradeScreen extends ConsumerStatefulWidget {
  const TradeScreen({super.key});

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen> with WidgetsBindingObserver {
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

  bool get _hasTradeOffer => _myOffer.isNotEmpty || _myGold > 0;

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  bool _canDirectTradeItem(InventoryItem item) =>
      item.isTradeable && (item.isDirectTradeable ?? true);

  static const Duration _sessionPollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _stopSessionPolling();
    _searchController.dispose();
    _goldController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _sessionId != null) {
      unawaited(_refreshTradeSession());
    }
  }

  void _startSessionPolling() {
    _sessionPollTimer ??= Timer.periodic(_sessionPollInterval, (_) {
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
          final bool wasDone = _tradeStatus == 'done';
          _tradeStatus = 'done';
          _stopSessionPolling();
          ref.read(inventoryProvider.notifier).loadInventory();
          ref.read(playerProvider.notifier).loadProfile();
          if (!wasDone && mounted) {
            HapticFeedback.selectionClick();
            GoldCoinParticleBurst.trigger(context);
          }
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
    HapticFeedback.selectionClick();
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
    HapticFeedback.selectionClick();
    if (_myConfirmed) {
      AppMessenger.showWarning(context, 'Teklifiniz kilitli, önce kilidi açın');
      return;
    }
    if (_myOffer.length >= 6) {
      AppMessenger.showWarning(context, 'Teklif masası dolu (en fazla 6 eşya)');
      return;
    }
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
    HapticFeedback.selectionClick();
    if (_myConfirmed) {
      AppMessenger.showWarning(context, 'Teklifiniz kilitli, eşya kaldıramazsınız');
      return;
    }
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
    HapticFeedback.selectionClick();
    if (_sessionId == null) return;
    if (_myConfirmed) {
      AppMessenger.showWarning(context, 'Teklifiniz kilitli, altın değiştiremezsiniz');
      return;
    }
    final int amount = int.tryParse(_goldController.text.trim()) ?? 0;
    if (amount < 0) {
      AppMessenger.showWarning(context, 'Geçersiz altın miktarı');
      return;
    }
    final int myBalance = ref.read(playerProvider).profile?.gold ?? 0;
    if (amount > myBalance) {
      AppMessenger.showWarning(context, 'Yeterli altının yok ($myBalance altın)');
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
    HapticFeedback.selectionClick();
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
      if (!mounted) return;
      if (_tradeStatus == 'done') {
        HapticFeedback.selectionClick();
        GoldCoinParticleBurst.trigger(context);
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
    HapticFeedback.selectionClick();
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

    final List<InventoryItem> allInventoryItems = invState.items
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

    String searchFilter = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final List<InventoryItem> filteredItems = searchFilter.trim().isEmpty
                ? allInventoryItems
                : allInventoryItems
                    .where((InventoryItem item) =>
                        item.name.toLowerCase().contains(searchFilter.trim().toLowerCase()))
                    .toList();

            final double screenHeight = MediaQuery.sizeOf(sheetContext).height;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: GestureDetector(
                  onTap: _dismissKeyboard,
                  child: Container(
                    height: screenHeight * 0.70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          AppColors.spaceNavy.withValues(alpha: 0.98),
                          AppColors.carbonVoid.withValues(alpha: 0.98),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.38), width: 1.2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.liquidGold.withValues(alpha: 0.16),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: <Widget>[
                          // Drag Handle
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.liquidGold.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.inventory_2, color: AppColors.liquidGold, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'TEKLİFE EŞYA EKLE',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.carbonVoid,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${filteredItems.length} Eşya',
                                    style: const TextStyle(
                                      color: AppColors.liquidGold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => Navigator.pop(sheetContext),
                                  icon: const Icon(Icons.close, color: AppColors.mutedTitanium, size: 20),
                                ),
                              ],
                            ),
                          ),

                          // Inventory Search Filter
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: TextField(
                              onChanged: (String val) {
                                setModalState(() {
                                  searchFilter = val;
                                });
                              },
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Envanterde ara...',
                                hintStyle: TextStyle(
                                  color: AppColors.mutedTitanium.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                                prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.liquidGold),
                                filled: true,
                                fillColor: AppColors.carbonVoid.withValues(alpha: 0.75),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.darkObsidian),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.darkObsidian.withValues(alpha: 0.9)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.liquidGold, width: 1.2),
                                ),
                              ),
                            ),
                          ),

                          Divider(color: AppColors.darkObsidian.withValues(alpha: 0.8), height: 1),
                          Expanded(
                            child: filteredItems.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Icon(
                                          searchFilter.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
                                          color: AppColors.mutedTitanium.withValues(alpha: 0.5),
                                          size: 36,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          searchFilter.isEmpty
                                              ? 'Takas edilebilir eşya bulunamadı'
                                              : '"$searchFilter" ile eşleşen eşya yok',
                                          style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: filteredItems.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                                    itemBuilder: (BuildContext ctx, int i) {
                                      final InventoryItem item = filteredItems[i];
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
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: AppColors.carbonVoid.withValues(alpha: 0.7),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: accent.withValues(alpha: 0.35),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                children: <Widget>[
                                                  MarketItemPedestal(
                                                    rarity: item.rarity.name,
                                                    iconValue: item.icon,
                                                    itemId: item.itemId,
                                                    itemType: item.itemType,
                                                    itemName: item.name,
                                                    size: 38,
                                                    interactive: false,
                                                    autoRotate: true,
                                                    showLightBeam: false,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: <Widget>[
                                                        Text(
                                                          item.name,
                                                          style: TextStyle(
                                                            color: accent,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          tradable ? 'x${item.quantity} Adet' : 'Takas edilemez',
                                                          style: const TextStyle(
                                                            color: AppColors.mutedTitanium,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (tradable)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.liquidGold.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(
                                                          color: AppColors.liquidGold.withValues(alpha: 0.5),
                                                        ),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: <Widget>[
                                                          Icon(Icons.add, size: 13, color: AppColors.liquidGold),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            'Ekle',
                                                            style: TextStyle(
                                                              color: AppColors.liquidGold,
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w800,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
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
                  ),
                ),
              ),
            );
          },
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

  String _formatGold(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Widget _buildGoldChip(int amount, {bool compact = false}) {
    if (amount <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.liquidGold.withValues(alpha: 0.22),
            AppColors.carbonVoid.withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.55), width: 1.0),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.monetization_on, size: compact ? 13 : 16, color: AppColors.liquidGold),
          const SizedBox(width: 5),
          Text(
            '${_formatGold(amount)} Altın',
            style: TextStyle(
              color: AppColors.liquidGold,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeSummaryRow({bool allowRemove = false}) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompactMobile = screenWidth < 460;
    final String partnerDisplay = _partnerName.isNotEmpty ? _partnerName : 'Karşı Taraf';

    final Widget myDeck = TradeLockInAura(
      isLockedIn: _myConfirmed,
      auraColor: AppColors.toxicNeon,
      secondaryColor: AppColors.liquidGold,
      lockLabel: 'SENİN TEKLİFİN (KİLİTLENDİ)',
      unlockedLabel: 'SENİN TEKLİFİN',
      child: _buildOfferPanel(
        title: '📤 Senin Teklifin',
        offers: _myOffer,
        goldAmount: _myGold,
        accent: AppColors.liquidGold,
        isMine: true,
        allowRemove: allowRemove,
      ),
    );

    final Widget partnerDeck = TradeLockInAura(
      isLockedIn: _partnerConfirmed,
      auraColor: AppColors.toxicNeon,
      secondaryColor: AppColors.cyberFuchsia,
      lockLabel: '$partnerDisplay (KİLİTLENDİ)',
      unlockedLabel: '$partnerDisplay TEKLİFİ',
      child: _buildOfferPanel(
        title: '📥 $partnerDisplay',
        offers: _partnerOffer,
        goldAmount: _partnerGold,
        accent: AppColors.toxicNeon,
        isMine: false,
        allowRemove: false,
      ),
    );

    if (isCompactMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          myDeck,
          const SizedBox(height: 8),
          TradeDualLockIndicator(
            myConfirmed: _myConfirmed,
            partnerConfirmed: _partnerConfirmed,
            myName: 'Sen',
            partnerName: partnerDisplay,
          ),
          const SizedBox(height: 8),
          partnerDeck,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TradeDualLockIndicator(
          myConfirmed: _myConfirmed,
          partnerConfirmed: _partnerConfirmed,
          myName: 'Sen',
          partnerName: partnerDisplay,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: myDeck),
            const SizedBox(width: 8),
            Expanded(child: partnerDeck),
          ],
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
      body: GoldCoinParticleBurst(
        child: TradeBackdrop(
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
                  child: RefreshIndicator(
                    color: AppColors.liquidGold,
                    onRefresh: () async {
                      if (_tabIndex == 0) {
                        await Future.wait(<Future<void>>[
                          _loadBlockedTradeUsers(silent: true),
                          ref.read(inventoryProvider.notifier).loadInventory(silent: true),
                          if (_sessionId != null) _refreshTradeSession(),
                        ]);
                      } else {
                        await _loadHistory();
                      }
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: GameScrollLayout.pagePadding(context),
                      child: _tabIndex == 0 ? _buildTradeTab() : _buildHistoryTab(),
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

  Widget _buildTab(int index, String label) {
    final bool active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_tabIndex == index) return;
          HapticFeedback.selectionClick();
          setState(() => _tabIndex = index);
          if (index == 0) {
            unawaited(_loadBlockedTradeUsers(silent: true));
          }
        },
        child: TradeFiligreePanel(
          accent: active ? AppColors.liquidGold : AppColors.mutedTitanium.withValues(alpha: 0.35),
          secondaryAccent: active ? AppColors.warningSolar : AppColors.darkObsidian,
          glowOpacity: active ? 0.22 : 0.0,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AppColors.liquidGold : AppColors.mutedTitanium,
              fontSize: 13,
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              letterSpacing: 0.5,
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
          TradeFiligreePanel(
            accent: AppColors.cyberFuchsia,
            padding: const EdgeInsets.all(12),
            child: Text(
              _statusLabels[_tradeStatus] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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
        if (_recentPartners.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _buildRecentPartnersPanel(),
        ],
        const SizedBox(height: 12),
        _buildBlockedUsersPanel(),
      ],
    );
  }

  /// Tamamlanan işlemlerden benzersiz son partnerler (en fazla 5).
  List<String> get _recentPartners {
    final Set<String> blocked = _blockedTradeUsers
        .map((Map<String, dynamic> row) => (row['username'] as String?) ?? '')
        .where((String u) => u.isNotEmpty)
        .toSet();
    final List<String> out = <String>[];
    for (final Map<String, dynamic> entry in _history) {
      if (entry['status'] != 'completed') continue;
      final String partner = (entry['partner'] as String?) ?? '';
      if (partner.isEmpty || blocked.contains(partner) || out.contains(partner)) {
        continue;
      }
      out.add(partner);
      if (out.length >= 5) break;
    }
    return out;
  }

  Widget _buildRecentPartnersPanel() {
    return TradeFiligreePanel(
      accent: AppColors.toxicNeon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.history, color: AppColors.toxicNeon, size: 16),
              SizedBox(width: 6),
              Text(
                'SON TİCARET YAPTIKLARIN',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentPartners.map((String partner) {
              return GestureDetector(
                onTap: _processing
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        _searchController.text = partner;
                        unawaited(_handleSearch());
                      },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.carbonVoid.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.toxicNeon.withValues(alpha: 0.45),
                      width: 1.0,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.toxicNeon.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.handshake_outlined, size: 13, color: AppColors.toxicNeon),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          partner,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSearchPanel() {
    return TutorialAnchorScope(
      id: TutorialAnchorId.tradeSearchField,
      child: TradeFiligreePanel(
        accent: AppColors.liquidGold,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.person_search, color: AppColors.liquidGold, size: 18),
                SizedBox(width: 8),
                Text(
                  'OYUNCU TİCARET ODASI',
                  style: TextStyle(
                    color: AppColors.liquidGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Doğrudan eşya ve altın takası yapmak istediğiniz oyuncunun adını yazın.',
              style: TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _processing ? null : (_) => _handleSearch(),
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Oyuncu adı girin...',
                      hintStyle: TextStyle(color: AppColors.mutedTitanium.withValues(alpha: 0.6)),
                      prefixIcon: const Icon(Icons.search, color: AppColors.liquidGold, size: 18),
                      filled: true,
                      fillColor: AppColors.carbonVoid.withValues(alpha: 0.75),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.darkObsidian),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.darkObsidian.withValues(alpha: 0.9)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.liquidGold, width: 1.4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: TradePrimaryButton(
                    label: 'Ara',
                    icon: Icons.flash_on,
                    onPressed: _processing
                        ? null
                        : () async {
                            await TutorialTriggers.onAnchorTap(
                              ref,
                              TutorialAnchorId.tradeSearchField,
                            );
                            await _handleSearch();
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedUsersPanel() {
    return TradeFiligreePanel(
      accent: AppColors.mysticRuby,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _blockedPanelExpanded = !_blockedPanelExpanded);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.block, color: AppColors.mysticRuby, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ENGELLENEN OYUNCULAR',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          _blockedTradeLoaded ? 'Engellenen oyuncu yok.' : 'Yükleniyor...',
          style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
        ),
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
              color: AppColors.carbonVoid.withValues(alpha: 0.65),
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
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  width: 84,
                  child: TradePrimaryButton(
                    label: 'Kaldır',
                    height: 32,
                    fontSize: 11,
                    color: AppColors.liquidGold,
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
    return TradeFiligreePanel(
      accent: AppColors.cyberFuchsia,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: <Widget>[
          const Icon(Icons.radar, size: 44, color: AppColors.cyberFuchsia),
          const SizedBox(height: 12),
          const Text(
            'Oyuncu aranıyor...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ağdaki oyuncu durumu doğrulanıyor',
            style: TextStyle(color: AppColors.mutedTitanium, fontSize: 11),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(color: AppColors.liquidGold),
          const SizedBox(height: 18),
          SizedBox(
            width: 160,
            child: TradeSecondaryButton(
              label: 'Aramayı İptal Et',
              icon: Icons.close,
              height: 36,
              fontSize: 11,
              onPressed: () {
                setState(() {
                  _tradeStatus = 'idle';
                  _processing = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    return TradeFiligreePanel(
      accent: AppColors.warningSolar,
      child: Column(
        children: <Widget>[
          const Icon(Icons.hourglass_top, size: 44, color: AppColors.warningSolar),
          const SizedBox(height: 10),
          Text(
            '${_partnerName.isNotEmpty ? _partnerName : "Oyuncu"} bekleniyor...',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          const Text(
            'Ticaret daveti gönderildi. Karşı taraf kabul ettiğinde takas masası açılacak.',
            style: TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          TradeSecondaryButton(
            label: 'İstekten Vazgeç',
            icon: Icons.close,
            onPressed: _processing ? null : _cancelTrade,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Top Active Bar
        TradeFiligreePanel(
          accent: AppColors.toxicNeon,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.toxicNeon.withValues(alpha: 0.2),
                  border: Border.all(color: AppColors.toxicNeon.withValues(alpha: 0.6)),
                ),
                child: const Center(
                  child: Icon(Icons.handshake, size: 16, color: AppColors.toxicNeon),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$_partnerName ile Takas Masası',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _partnerConfirmed ? '✓ Karşı taraf kilitledi' : 'Teklifler hazırlanıyor',
                      style: TextStyle(
                        color: _partnerConfirmed ? AppColors.toxicNeon : AppColors.mutedTitanium,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                child: TradeSecondaryButton(
                  label: 'İptal',
                  height: 32,
                  fontSize: 11,
                  onPressed: _processing ? null : _cancelTrade,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Duel Summary Row with Metallic Filigree Slots & Lock Auras
        _buildTradeSummaryRow(allowRemove: true),
        const SizedBox(height: 10),

        // Gold Injection Panel
        TradeFiligreePanel(
          accent: AppColors.liquidGold,
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'ALTIN TEKLİFİ',
                      style: TextStyle(
                        color: AppColors.liquidGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'Kasadaki Altın: ${_formatGold(ref.watch(playerProvider).profile?.gold ?? 0)}',
                        style: const TextStyle(
                          color: AppColors.mutedTitanium,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _goldController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Altın tutarı',
                        hintStyle: TextStyle(color: AppColors.mutedTitanium.withValues(alpha: 0.6)),
                        prefixIcon: const Icon(Icons.monetization_on, color: AppColors.liquidGold, size: 18),
                        filled: true,
                        fillColor: AppColors.carbonVoid.withValues(alpha: 0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.darkObsidian),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.darkObsidian.withValues(alpha: 0.8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.liquidGold, width: 1.2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    child: TradePrimaryButton(
                      label: 'Ekle',
                      icon: Icons.add,
                      color: AppColors.liquidGold,
                      height: 38,
                      onPressed: (_processing || _myConfirmed) ? null : _applyGold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Mobile Quick Gold Presets
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  ...<int>[100, 500, 1000, 5000].map((int delta) {
                    return GestureDetector(
                      onTap: _myConfirmed
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              final int cur = int.tryParse(_goldController.text.trim()) ?? 0;
                              final int myBal = ref.read(playerProvider).profile?.gold ?? 0;
                              final int next = (cur + delta).clamp(0, myBal);
                              _goldController.text = next.toString();
                              _goldController.selection = TextSelection.fromPosition(
                                TextPosition(offset: _goldController.text.length),
                              );
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.liquidGold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '+${_formatGold(delta)}',
                          style: const TextStyle(
                            color: AppColors.liquidGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: _myConfirmed
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            final int myBal = ref.read(playerProvider).profile?.gold ?? 0;
                            _goldController.text = myBal.toString();
                            _goldController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _goldController.text.length),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.warningSolar.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.warningSolar.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'TÜMÜ (MAX)',
                        style: TextStyle(
                          color: AppColors.warningSolar,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _myConfirmed
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            _goldController.text = '0';
                            _goldController.selection = const TextSelection.collapsed(offset: 1);
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.carbonVoid.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.mutedTitanium.withValues(alpha: 0.35)),
                      ),
                      child: const Text(
                        'SIFIRLA',
                        style: TextStyle(
                          color: AppColors.mutedTitanium,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Action Deck
        SafeArea(
          top: false,
          bottom: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TradePrimaryButton(
                label: _myOffer.length >= 6
                    ? 'Masa Dolu (6/6 Eşya)'
                    : (_myConfirmed ? 'Teklif Kilitli' : 'Eşya Ekle'),
                icon: Icons.add_circle,
                color: AppColors.cyberFuchsia,
                textColor: AppColors.textPrimary,
                onPressed: (_processing || _myConfirmed || _myOffer.length >= 6)
                    ? null
                    : () => _showItemPicker(context),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TradeSecondaryButton(
                      label: 'İptal',
                      icon: Icons.close,
                      onPressed: _processing ? null : _cancelTrade,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TradePrimaryButton(
                      label: _myConfirmed ? 'Kilitlendi' : 'Teklifi Kilitle',
                      icon: _myConfirmed ? Icons.check_circle : Icons.lock,
                      color: AppColors.toxicNeon,
                      textColor: AppColors.carbonVoid,
                      onPressed: (_processing || _myConfirmed || !_hasTradeOffer) ? null : _confirmTrade,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmingState() {
    final bool bothConfirmed = _myConfirmed && _partnerConfirmed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (bothConfirmed)
          TradeCountdownSeal(
            durationSeconds: 3,
            title: 'TİCARET TAMAMLANIYOR',
            subtitle: 'Her iki taraf teklifini mühürledi. Oturum onaylanıyor.',
            onComplete: () async {
              await _refreshTradeSession();
            },
            onCancel: _cancelTrade,
          )
        else
          TradeFiligreePanel(
            accent: AppColors.warningSolar,
            padding: const EdgeInsets.all(16),
            child: const Column(
              children: <Widget>[
                Icon(Icons.lock_clock, size: 36, color: AppColors.warningSolar),
                SizedBox(height: 8),
                Text(
                  'Onayınız Alındı — Teklif Kilitlendi',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Karşı tarafın teklifini onaylaması bekleniyor...',
                  style: TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        _buildTradeSummaryRow(allowRemove: false),
        if (!bothConfirmed) ...<Widget>[
          const SizedBox(height: 12),
          TradeSecondaryButton(
            label: 'Mührü İptal Et',
            icon: Icons.close,
            onPressed: _processing ? null : _cancelTrade,
          ),
        ],
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
    // 6 metallic filigree offer slots per player
    const int slotCount = 6;

    return TradeFiligreePanel(
      accent: accent,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.carbonVoid.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: accent.withValues(alpha: 0.3), width: 0.8),
                ),
                child: Text(
                  '${offers.length}/$slotCount Eşya',
                  style: const TextStyle(
                    color: AppColors.mutedTitanium,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (goldAmount > 0) _buildGoldChip(goldAmount),

          // Responsive Metallic Filigree Grid Slots
          LayoutBuilder(
            builder: (BuildContext ctx, BoxConstraints constraints) {
              final double availableWidth = constraints.maxWidth;
              final int columns = availableWidth >= 320 ? 6 : 3;
              const double spacing = 6.0;
              final double computedSize =
                  ((availableWidth - ((columns - 1) * spacing)) / columns).floorToDouble();
              final double slotSize = computedSize.clamp(42.0, 56.0);

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.start,
                children: List<Widget>.generate(slotCount, (int index) {
                  final Map<String, dynamic>? offer = index < offers.length ? offers[index] : null;
                  return TradeFiligreeSlot(
                    offer: offer,
                    isMine: isMine,
                    allowRemove: allowRemove && !_myConfirmed,
                    size: slotSize,
                    onRemove: (offer != null && !_myConfirmed)
                        ? () => _removeFromOffer(offer['row_id'].toString())
                        : null,
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDoneState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TradeFiligreePanel(
          accent: AppColors.toxicNeon,
          secondaryAccent: AppColors.liquidGold,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.toxicNeon.withValues(alpha: 0.2),
                  border: Border.all(color: AppColors.toxicNeon, width: 2),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: AppColors.toxicNeon, blurRadius: 20),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.celebration, color: AppColors.toxicNeon, size: 36),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'TİCARET MÜHÜRLENDİ!',
                style: TextStyle(
                  color: AppColors.toxicNeon,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_partnerName.isNotEmpty ? _partnerName : "Karşı taraf"} ile takas başarıyla gerçekleşti. Eşyalar ve altınlar envanterinize aktarıldı.',
                style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildTradeSummaryRow(allowRemove: false),
        const SizedBox(height: 12),
        TradePrimaryButton(
          label: 'Yeni Ticaret Başlat',
          icon: Icons.refresh,
          color: AppColors.toxicNeon,
          textColor: AppColors.carbonVoid,
          onPressed: _resetTrade,
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_historyLoading) {
      return const Padding(
        padding: EdgeInsets.all(36),
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
              TradePrimaryButton(label: 'Tekrar Dene', icon: Icons.refresh, onPressed: _loadHistory),
            ],
          ),
        ),
      );
    }
    if (_history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(36),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.history_toggle_off, color: AppColors.mutedTitanium, size: 40),
              SizedBox(height: 8),
              Text(
                'Henüz ticaret geçmişi kaydı bulunmuyor.',
                style: TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _history.map((Map<String, dynamic> entry) {
        return TradeLogCard(entry: entry);
      }).toList(),
    );
  }
}
