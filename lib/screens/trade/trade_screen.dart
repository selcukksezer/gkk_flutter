import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'package:gkk_flutter/components/common/item_icon_view.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/services/supabase_service.dart';
import '../../l10n/l10n.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
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
    'active': '🤝 Ticaret aktif — eşyaları ekleyin',
    'confirming': '✅ Onayınız alındı, karşı taraf bekleniyor',
    'done': '🎉 Ticaret tamamlandı',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadInventory();
      unawaited(_loadHistory());
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
      if (raw is Map) {
        sessionId = raw['session_id']?.toString() ?? '';
        partnerName = (raw['partner_name'] as String?) ?? target;
      }
      setState(() {
        _sessionId = sessionId.isNotEmpty ? sessionId : null;
        _partnerName = partnerName;
        _tradeStatus = sessionId.isNotEmpty ? 'active' : 'pending';
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
      AppMessenger.show(context, 'Ticaret başlatılamadı');
    }
  }

  Future<void> _addItemToOffer(InventoryItem item) async {
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
  }

  void _showItemPicker(BuildContext context) {
    final List<InventoryItem> inventoryItems = ref
        .read(inventoryProvider)
        .items
        .where((InventoryItem i) => !i.isEquipped && i.isTradeable)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.spaceNavy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '📤 Eşya Seç',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: inventoryItems.isEmpty
                  ? const Center(child: Text('Taşınabilir eşya yok', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: inventoryItems.length,
                      itemBuilder: (BuildContext ctx, int i) {
                        final InventoryItem item = inventoryItems[i];
                        return ListTile(
                          leading: ItemIconView(
                            iconValue: item.icon,
                            itemId: item.itemId,
                            itemType: item.itemType,
                            size: 32,
                          ),
                          title: Text(item.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text('x${item.quantity}', style: const TextStyle(color: Colors.white54)),
                          onTap: () {
                            Navigator.pop(context);
                            unawaited(_addItemToOffer(item));
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
        onTap: () => setState(() => _tabIndex = index),
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
        if (_tradeStatus == 'active' || _tradeStatus == 'confirming') _buildActiveState(),
        if (_tradeStatus == 'done') _buildDoneState(),
      ],
    );
  }

  Widget _buildIdleState() {
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
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Oyuncu adı...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: AppColors.darkObsidian.withValues(alpha: 0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.mutedTitanium.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.mutedTitanium.withValues(alpha: 0.3)),
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
              TradePrimaryButton(
                label: '🔍 Ara',
                onPressed: _processing ? null : _handleSearch,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingState() {
    return TradeNeonPanel(
      child: const Column(
        children: <Widget>[
          Text('🔍', style: TextStyle(fontSize: 32)),
          SizedBox(height: 8),
          Text('Oyuncu aranıyor...', style: TextStyle(color: AppColors.mutedTitanium)),
          SizedBox(height: 8),
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
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Ticaret isteği gönderildi.',
            style: TextStyle(color: AppColors.mutedTitanium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TradeSecondaryButton(label: 'İptal Et', onPressed: _processing ? null : _cancelTrade),
        ],
      ),
    );
  }

  Widget _buildActiveState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TradeNeonPanel(
          accent: AppColors.liquidGold,
          padding: const EdgeInsets.all(12),
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
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (_partnerConfirmed)
                      const Text('Karşı taraf onayladı', style: TextStyle(color: AppColors.toxicNeon, fontSize: 10)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _cancelTrade,
                child: const Text('İptal', style: TextStyle(color: AppColors.mysticRuby)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _buildOfferPanel(
                title: '📤 Teklifim',
                offers: _myOffer,
                goldAmount: _myGold,
                accent: AppColors.liquidGold,
                isMine: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildOfferPanel(
                title: '📥 Karşı Teklif',
                offers: _partnerOffer,
                goldAmount: _partnerGold,
                accent: AppColors.cyberFuchsia,
                isMine: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TradeNeonPanel(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _goldController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Altın miktarı',
                    hintStyle: TextStyle(color: AppColors.mutedTitanium.withValues(alpha: 0.6)),
                    prefixIcon: const Icon(Icons.monetization_on, color: AppColors.liquidGold, size: 18),
                    filled: true,
                    fillColor: AppColors.darkObsidian.withValues(alpha: 0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TradePrimaryButton(
                label: 'Altın Koy',
                onPressed: _processing ? null : _applyGold,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TradePrimaryButton(
          label: '➕ Eşya Ekle',
          onPressed: () => _showItemPicker(context),
          color: AppColors.cyberFuchsia,
          textColor: Colors.white,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TradeSecondaryButton(label: '❌ İptal', onPressed: _processing ? null : _cancelTrade),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TradePrimaryButton(
                label: _myConfirmed ? '⏳ Bekleniyor' : '✅ Onayla',
                onPressed: (_processing || _myConfirmed) ? null : _confirmTrade,
              ),
            ),
          ],
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
  }) {
    return TradeNeonPanel(
      accent: accent,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (goldAmount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.liquidGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.monetization_on, color: AppColors.liquidGold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '$goldAmount altın',
                    style: const TextStyle(color: AppColors.liquidGold, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          if (offers.isEmpty)
            Container(
              constraints: const BoxConstraints(minHeight: 80),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.mutedTitanium.withValues(alpha: 0.2)),
              ),
              child: Text(
                isMine ? 'Eşya ekle' : 'Bekleniyor...',
                style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 11),
              ),
            )
          else
            ...offers.map((Map<String, dynamic> offer) {
              final String rowId = offer['row_id']?.toString() ?? '';
              final String name = offer['name']?.toString() ?? '';
              final int qty = (offer['quantity'] as num?)?.toInt() ?? 1;
              final String rarity = offer['rarity']?.toString() ?? 'common';
              return Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.darkObsidian.withValues(alpha: 0.5),
                ),
                child: Row(
                  children: <Widget>[
                    ItemIconView(
                      iconValue: offer['icon']?.toString() ?? '',
                      itemId: offer['item_id']?.toString(),
                      itemType: _parseItemType(offer['item_type']?.toString()),
                      size: 24,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        qty > 1 ? '$name x$qty' : name,
                        style: TextStyle(color: _rarityColor(rarity), fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMine && rowId.isNotEmpty)
                      GestureDetector(
                        onTap: () => unawaited(_removeFromOffer(rowId)),
                        child: const Icon(Icons.close, size: 14, color: AppColors.mysticRuby),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDoneState() {
    return TradeNeonPanel(
      accent: AppColors.toxicNeon,
      child: Column(
        children: <Widget>[
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          const Text(
            'Ticaret Tamamlandı!',
            style: TextStyle(color: AppColors.toxicNeon, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$_partnerName ile ticaret başarıyla gerçekleşti.',
            style: const TextStyle(color: AppColors.mutedTitanium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TradePrimaryButton(label: 'Yeni Ticaret', onPressed: _resetTrade),
        ],
      ),
    );
  }

  Widget _buildHistoryItemRow(Map<String, dynamic> item) {
    final String name = item['name']?.toString() ?? '';
    final int qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final bool hasIcon = item.containsKey('icon');
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          if (hasIcon)
            ItemIconView(
              iconValue: item['icon']?.toString() ?? '',
              itemId: item['item_id']?.toString(),
              itemType: _parseItemType(item['item_type']?.toString()),
              size: 20,
            ),
          if (hasIcon) const SizedBox(width: 6),
          Expanded(
            child: Text(
              qty > 1 ? '$name x$qty' : name,
              style: TextStyle(
                color: _rarityColor(item['rarity']?.toString() ?? 'common'),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
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
                              color: Colors.white,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('📤 Ben verdim:', style: TextStyle(color: AppColors.mutedTitanium, fontSize: 10)),
                          if (myGold > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('💰 $myGold altın', style: const TextStyle(color: AppColors.liquidGold, fontSize: 11)),
                            ),
                          if (myItems.isEmpty && myGold == 0)
                            const Text('—', style: TextStyle(color: AppColors.mutedTitanium, fontSize: 11))
                          else
                            ...myItems.map(_buildHistoryItemRow),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('📥 Ben aldım:', style: TextStyle(color: AppColors.mutedTitanium, fontSize: 10)),
                          if (theirGold > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('💰 $theirGold altın', style: const TextStyle(color: AppColors.liquidGold, fontSize: 11)),
                            ),
                          if (theirItems.isEmpty && theirGold == 0)
                            const Text('—', style: TextStyle(color: AppColors.mutedTitanium, fontSize: 11))
                          else
                            ...theirItems.map(_buildHistoryItemRow),
                        ],
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
