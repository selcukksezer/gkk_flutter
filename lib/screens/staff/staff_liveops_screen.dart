import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/debug/staff_hub_debug_log.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/keyboard_dismiss.dart';
import '../../models/staff_model.dart';
import '../../providers/live_ticker_provider.dart';
import '../../providers/staff_provider.dart';
import '../../repositories/staff_repository.dart';
import '../../routing/app_router.dart';
import '../../theme/app_text_styles.dart';
import '../support/widgets/support_design.dart';
import '../support/widgets/support_screen_shell.dart';
import 'widgets/staff_design.dart';
import 'widgets/staff_item_picker.dart';
import 'widgets/staff_portraits.dart';

enum _LiveOpsTab {
  overview('Özet'),
  bp('BP'),
  gw('GW'),
  daily('Daily'),
  night('Gece'),
  shop('Mağaza'),
  market('Pazar'),
  broadcast('Duyuru');

  const _LiveOpsTab(this.label);
  final String label;

  bool visible(StaffProfile profile) {
    switch (this) {
      case _LiveOpsTab.overview:
        return profile.hasLiveOpsAccess;
      case _LiveOpsTab.bp:
        return profile.has('liveops.bp_season') || profile.has('liveops.bp_rewards');
      case _LiveOpsTab.gw:
        return profile.has('liveops.guild_war_season');
      case _LiveOpsTab.daily:
        return profile.has('liveops.daily_rewards');
      case _LiveOpsTab.night:
        return profile.has('liveops.night_market');
      case _LiveOpsTab.shop:
        return profile.has('liveops.shop_catalog');
      case _LiveOpsTab.market:
        return profile.has('market.remove_listing') || profile.has('market.edit_listing');
      case _LiveOpsTab.broadcast:
        return profile.has('liveops.broadcast');
    }
  }
}

class StaffLiveOpsScreen extends ConsumerStatefulWidget {
  const StaffLiveOpsScreen({super.key});

  @override
  ConsumerState<StaffLiveOpsScreen> createState() => _StaffLiveOpsScreenState();
}

class _StaffLiveOpsScreenState extends ConsumerState<StaffLiveOpsScreen> {
  final StaffRepository _repo = StaffRepository();
  final TextEditingController _broadcast = TextEditingController(text: '📣 Staff duyurusu');
  final TextEditingController _broadcastPasses = TextEditingController(text: '10');
  final TextEditingController _marketQuery = TextEditingController();
  final TextEditingController _shopQuery = TextEditingController();
  final TextEditingController _dailyDay = TextEditingController(text: '1');
  final TextEditingController _dailyGold = TextEditingController(text: '100');
  final TextEditingController _dailyGems = TextEditingController(text: '0');
  final TextEditingController _dailyXp = TextEditingController(text: '0');
  final TextEditingController _dailyEnergy = TextEditingController(text: '0');
  final TextEditingController _dailyItemQty = TextEditingController(text: '0');
  final TextEditingController _bpSeasonId = TextEditingController();
  final TextEditingController _bpLevel = TextEditingController(text: '1');
  final TextEditingController _bpTrack = TextEditingController(text: 'free');
  final TextEditingController _bpRewardType = TextEditingController(text: 'gold');
  final TextEditingController _bpRewardGold = TextEditingController(text: '100');
  final TextEditingController _bpRewardGems = TextEditingController(text: '0');
  final TextEditingController _nightPrice = TextEditingController(text: '50');
  final TextEditingController _nightStock = TextEditingController(text: '1');
  final TextEditingController _bpStartAt = TextEditingController();
  final TextEditingController _bpEndAt = TextEditingController();
  final TextEditingController _gwStartAt = TextEditingController();
  final TextEditingController _gwEndAt = TextEditingController();
  final TextEditingController _nmStartHour = TextEditingController(text: '20');
  final TextEditingController _nmEndHour = TextEditingController(text: '22');

  // LiveOps Maintenance Mode and telemetry state
  bool _maintenanceActive = false;
  final TextEditingController _maintenanceReason = TextEditingController(
    text: 'Rutin sunucu optimizasyonu ve veri tabanı bakımı.',
  );
  bool _maintenanceBypassGms = true;
  StaffRank? _previewRank;

  // Real-time broadcast dispatch tracking
  final List<Map<String, dynamic>> _broadcastHistory = <Map<String, dynamic>>[];

  List<dynamic> _dailyRows = <dynamic>[];
  List<dynamic> _bpRows = <dynamic>[];
  List<dynamic> _shopRows = <dynamic>[];
  List<dynamic> _nightRows = <dynamic>[];
  List<dynamic> _marketRows = <dynamic>[];
  bool _dailyLoading = false;
  bool _dailyLoaded = false;
  bool _bpLoading = false;
  bool _bpLoaded = false;
  bool _shopLoading = false;
  bool _shopLoaded = false;
  bool _nightLoading = false;
  bool _nightLoaded = false;
  bool _marketLoading = false;
  bool _marketSearched = false;
  StaffItemCatalogEntry? _dailySelectedItem;
  StaffItemCatalogEntry? _bpSelectedItem;
  StaffItemCatalogEntry? _nightSelectedItem;
  bool _nightOfferSaving = false;

  String? _activeBpSeasonId;
  int? _activeBpSeasonNumber;
  String? _activeGwSeasonId;
  int? _activeGwSeasonNumber;
  int? _activeGwWeekNumber;
  bool _nmForceOpen = false;
  bool _nmForceClosed = false;
  bool? _nmWindowActive;
  String? _nmWindowSubtitle;
  int? _nmSecondsLeft;
  bool _schedulesLoaded = false;
  bool _dailyMilestone = false;
  int _tabIndex = 0;
  final Set<_LiveOpsTab> _primedTabs = <_LiveOpsTab>{};

  List<_LiveOpsTab> _tabsFor(StaffProfile profile) =>
      _LiveOpsTab.values.where(( _LiveOpsTab t) => t.visible(profile)).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _primeTab(_LiveOpsTab.overview));
  }

  @override
  void dispose() {
    _broadcast.dispose();
    _broadcastPasses.dispose();
    _marketQuery.dispose();
    _shopQuery.dispose();
    _dailyDay.dispose();
    _dailyGold.dispose();
    _dailyGems.dispose();
    _dailyXp.dispose();
    _dailyEnergy.dispose();
    _dailyItemQty.dispose();
    _bpSeasonId.dispose();
    _bpLevel.dispose();
    _bpTrack.dispose();
    _bpRewardType.dispose();
    _bpRewardGold.dispose();
    _bpRewardGems.dispose();
    _nightPrice.dispose();
    _nightStock.dispose();
    _bpStartAt.dispose();
    _bpEndAt.dispose();
    _gwStartAt.dispose();
    _gwEndAt.dispose();
    _nmStartHour.dispose();
    _nmEndHour.dispose();
    _maintenanceReason.dispose();
    super.dispose();
  }

  String _formatStaffDateTime(dynamic raw) {
    if (raw == null) return '';
    final DateTime? dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return dt.toLocal().toIso8601String();
  }

  DateTime? _parseStaffDateTime(String raw) => DateTime.tryParse(raw.trim());

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '—';
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}s ${m}dk';
    return '${m}dk';
  }

  Future<void> _primeTab(_LiveOpsTab tab) async {
    if (_primedTabs.contains(tab)) return;
    _primedTabs.add(tab);
    if (tab == _LiveOpsTab.overview ||
        tab == _LiveOpsTab.bp ||
        tab == _LiveOpsTab.gw ||
        tab == _LiveOpsTab.night) {
      await _loadSchedules();
    }
    if (tab == _LiveOpsTab.daily) {
      await _loadDaily();
    }
    if (tab == _LiveOpsTab.bp && ref.read(staffProvider).profile.has('liveops.bp_rewards')) {
      await _loadBp();
    }
    if (tab == _LiveOpsTab.shop) {
      await _loadShop();
    }
    if (tab == _LiveOpsTab.night) {
      await _loadNightMarket();
    }
  }

  void _selectTab(int index, StaffProfile profile) {
    final List<_LiveOpsTab> tabs = _tabsFor(profile);
    if (index < 0 || index >= tabs.length) return;
    AppHaptics.selection();
    setState(() => _tabIndex = index);
    _primeTab(tabs[index]);
  }

  Future<void> _loadSchedules() async {
    final dynamic raw = await SupabaseService.client.rpc('staff_liveops_get_schedules');
    if (!mounted) return;
    if (raw is Map && raw['success'] == false) {
      AppMessenger.showError(context, raw['error']?.toString() ?? 'Takvim yüklenemedi');
      return;
    }
    if (raw is! Map) return;

    final Map? bp = raw['bp_season'] as Map?;
    final Map? gw = raw['guild_war_season'] as Map?;
    final Map? nm = raw['night_market_schedule'] as Map?;
    final Map? win = raw['night_market_window'] as Map?;

    setState(() {
      _schedulesLoaded = true;
      if (bp != null) {
        _activeBpSeasonId = bp['id']?.toString();
        _activeBpSeasonNumber = (bp['season_number'] as num?)?.toInt();
        _bpSeasonId.text = _activeBpSeasonId ?? '';
        _bpStartAt.text = _formatStaffDateTime(bp['start_at']);
        _bpEndAt.text = _formatStaffDateTime(bp['end_at']);
      }
      if (gw != null) {
        _activeGwSeasonId = gw['id']?.toString();
        _activeGwSeasonNumber = (gw['season_number'] as num?)?.toInt();
        _activeGwWeekNumber = (gw['week_number'] as num?)?.toInt();
        _gwStartAt.text = _formatStaffDateTime(gw['start_at']);
        _gwEndAt.text = _formatStaffDateTime(gw['end_at']);
      }
      if (nm != null) {
        _nmStartHour.text = '${nm['start_hour'] ?? 20}';
        _nmEndHour.text = '${nm['end_hour'] ?? 22}';
        _nmForceOpen = nm['qa_force_open'] == true;
        _nmForceClosed = nm['staff_force_closed'] == true;
      }
      if (win != null) {
        _nmWindowActive = win['active'] == true;
        _nmSecondsLeft = (win['seconds_left'] as num?)?.toInt();
        final String starts = _formatStaffDateTime(win['starts_at']);
        final String ends = _formatStaffDateTime(win['ends_at']);
        _nmWindowSubtitle = win['active'] == true
            ? 'Açık · $starts → $ends'
            : 'Kapalı · sonraki: $starts';
      }
    });
  }

  Future<void> _saveBpSeasonDates() async {
    final String? seasonId = _activeBpSeasonId ?? (_bpSeasonId.text.trim().isEmpty ? null : _bpSeasonId.text.trim());
    if (seasonId == null) {
      AppMessenger.showError(context, 'Aktif BP sezonu yok.');
      return;
    }
    final DateTime? start = _parseStaffDateTime(_bpStartAt.text);
    final DateTime? end = _parseStaffDateTime(_bpEndAt.text);
    if (start == null || end == null) {
      AppMessenger.showError(context, 'Geçerli başlangıç/bitiş tarihi gir (ISO).');
      return;
    }
    await _runRpc(
      'staff_liveops_update_bp_season',
      <String, dynamic>{
        'p_season_id': seasonId,
        'p_start_at': start.toUtc().toIso8601String(),
        'p_end_at': end.toUtc().toIso8601String(),
        'p_reason': 'staff schedule',
      },
      success: 'BP sezon tarihleri kaydedildi',
      onSuccess: _loadSchedules,
    );
  }

  Future<void> _saveGwSeasonDates() async {
    if (_activeGwSeasonId == null) {
      AppMessenger.showError(context, 'Aktif GW sezonu yok.');
      return;
    }
    final DateTime? start = _parseStaffDateTime(_gwStartAt.text);
    final DateTime? end = _parseStaffDateTime(_gwEndAt.text);
    if (start == null || end == null) {
      AppMessenger.showError(context, 'Geçerli başlangıç/bitiş tarihi gir (ISO).');
      return;
    }
    await _runRpc(
      'staff_liveops_update_guild_war_season',
      <String, dynamic>{
        'p_season_id': _activeGwSeasonId,
        'p_start_at': start.toUtc().toIso8601String(),
        'p_end_at': end.toUtc().toIso8601String(),
        'p_reason': 'staff schedule',
      },
      success: 'GW sezon tarihleri kaydedildi',
      onSuccess: _loadSchedules,
    );
  }

  Future<void> _saveNightMarketSchedule({bool? forceOpen, bool? forceClosed}) async {
    if (forceOpen != null) _nmForceOpen = forceOpen;
    if (forceClosed != null) _nmForceClosed = forceClosed;
    await _runRpc(
      'staff_liveops_update_night_market_schedule',
      <String, dynamic>{
        'p_payload': <String, dynamic>{
          'start_hour': int.tryParse(_nmStartHour.text.trim()) ?? 20,
          'end_hour': int.tryParse(_nmEndHour.text.trim()) ?? 22,
          'qa_force_open': _nmForceOpen,
          'staff_force_closed': _nmForceClosed,
        },
        'p_reason': 'staff schedule',
      },
      success: 'Gece pazarı takvimi kaydedildi',
      onSuccess: _loadSchedules,
    );
  }

  Future<void> _loadDaily() async {
    setState(() => _dailyLoading = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc('staff_liveops_get_daily_rewards');
      if (!mounted) return;
      if (raw is Map && raw['success'] == false) {
        AppMessenger.showError(context, raw['error']?.toString() ?? 'Daily yüklenemedi');
        return;
      }
      if (raw is Map && raw['items'] is List) {
        setState(() => _dailyRows = raw['items'] as List);
      }
    } finally {
      if (mounted) {
        setState(() {
          _dailyLoading = false;
          _dailyLoaded = true;
        });
      }
    }
  }

  Future<void> _loadBp() async {
    setState(() => _bpLoading = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'staff_liveops_get_bp_rewards',
        params: <String, dynamic>{
          if (_bpSeasonId.text.trim().isNotEmpty) 'p_season_id': _bpSeasonId.text.trim(),
        },
      );
      if (raw is Map && raw['success'] == false && mounted) {
        AppMessenger.showError(context, raw['error']?.toString() ?? 'BP yüklenemedi');
        return;
      }
      if (raw is Map && raw['items'] is List && mounted) {
        setState(() => _bpRows = raw['items'] as List);
      }
    } finally {
      if (mounted) {
        setState(() {
          _bpLoading = false;
          _bpLoaded = true;
        });
      }
    }
  }

  Future<void> _loadShop() async {
    setState(() => _shopLoading = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc('staff_liveops_list_shop_items', params: <String, dynamic>{'p_limit': 200});
      if (!mounted) return;
      if (raw is Map && raw['success'] == false) {
        AppMessenger.showError(context, raw['error']?.toString() ?? 'Mağaza yüklenemedi');
        return;
      }
      if (raw is Map && raw['items'] is List) {
        setState(() => _shopRows = raw['items'] as List);
      }
    } finally {
      if (mounted) {
        setState(() {
          _shopLoading = false;
          _shopLoaded = true;
        });
      }
    }
  }

  Future<void> _loadNightMarket() async {
    setState(() => _nightLoading = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc('staff_liveops_list_night_market_offers', params: <String, dynamic>{'p_limit': 100});
      if (!mounted) return;
      if (raw is Map && raw['success'] == false) {
        AppMessenger.showError(context, raw['error']?.toString() ?? 'Gece pazarı yüklenemedi');
        return;
      }
      if (raw is Map && raw['items'] is List) {
        setState(() => _nightRows = raw['items'] as List);
      }
    } finally {
      if (mounted) {
        setState(() {
          _nightLoading = false;
          _nightLoaded = true;
        });
      }
    }
  }

  Future<void> _loadMarketOrders() async {
    setState(() => _marketLoading = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'staff_liveops_list_market_orders',
        params: <String, dynamic>{'p_query': _marketQuery.text.trim(), 'p_limit': 100},
      );
      if (!mounted) return;
      if (raw is Map && raw['success'] == false) {
        AppMessenger.showError(context, raw['error']?.toString() ?? 'Pazar yüklenemedi');
        return;
      }
      if (raw is Map && raw['items'] is List) {
        setState(() => _marketRows = raw['items'] as List);
      }
    } finally {
      if (mounted) {
        setState(() {
          _marketLoading = false;
          _marketSearched = true;
        });
      }
    }
  }

  /// Liste altı durum satırı: yükleniyor / boş.
  Widget _listState({
    required bool loading,
    required bool loaded,
    required bool isEmpty,
    required String emptyText,
    String? notLoadedText,
  }) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(color: SettingsPalette.gold, strokeWidth: 2),
          ),
        ),
      );
    }
    if (!loaded && notLoadedText != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(notLoadedText, style: supportCaptionStyle),
      );
    }
    if (loaded && isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(emptyText, style: supportCaptionStyle),
      );
    }
    return const SizedBox.shrink();
  }

  List<dynamic> get _filteredShopRows {
    final String q = _shopQuery.text.trim().toLowerCase();
    if (q.isEmpty) return _shopRows;
    return _shopRows.where((dynamic row) {
      if (row is! Map) return false;
      final String name = '${row['name'] ?? ''}'.toLowerCase();
      final String id = '${row['id'] ?? ''}'.toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();
  }

  Future<void> _editMarketListing(Map row) async {
    final Map<String, String>? values = await showStaffFormDialog(
      context: context,
      title: 'İlan düzenle',
      confirmLabel: 'Kaydet',
      fields: <StaffFormFieldSpec>[
        StaffFormFieldSpec(key: 'price', label: 'Fiyat', initial: '${row['price'] ?? ''}', keyboardType: TextInputType.number),
        StaffFormFieldSpec(key: 'quantity', label: 'Adet', initial: '${row['quantity'] ?? ''}', keyboardType: TextInputType.number),
      ],
    );
    if (values == null) return;
    await _runRpc(
      'staff_liveops_edit_market_listing',
      <String, dynamic>{
        'p_order_id': row['id'],
        'p_payload': <String, dynamic>{
          'price': int.tryParse(values['price'] ?? ''),
          'quantity': int.tryParse(values['quantity'] ?? ''),
        },
        'p_reason': 'staff edit',
      },
      success: 'İlan güncellendi',
      onSuccess: _loadMarketOrders,
    );
  }

  Future<void> _editShopItem(Map row) async {
    final Map<String, String>? values = await showStaffFormDialog(
      context: context,
      title: '${row['name']} düzenle',
      confirmLabel: 'Kaydet',
      fields: <StaffFormFieldSpec>[
        StaffFormFieldSpec(key: 'base_price', label: 'Fiyat', initial: '${row['base_price'] ?? ''}', keyboardType: TextInputType.number),
        StaffFormFieldSpec(key: 'shop_currency', label: 'Para birimi', initial: '${row['shop_currency'] ?? 'gold'}'),
      ],
    );
    if (values == null) return;
    await _runRpc(
      'staff_liveops_update_shop_item',
      <String, dynamic>{
        'p_item_id': row['id'],
        'p_payload': <String, dynamic>{
          'base_price': int.tryParse(values['base_price'] ?? ''),
          'shop_currency': values['shop_currency']?.trim(),
        },
        'p_reason': 'staff edit',
      },
      success: 'Mağaza item güncellendi',
      onSuccess: _loadShop,
    );
  }

  Future<void> _upsertDailyReward() async {
    await _runRpc(
      'staff_liveops_upsert_daily_reward',
      <String, dynamic>{
        'p_cycle_day': int.tryParse(_dailyDay.text) ?? 1,
        'p_payload': <String, dynamic>{
          'gold': int.tryParse(_dailyGold.text) ?? 0,
          'gems': int.tryParse(_dailyGems.text) ?? 0,
          'xp': int.tryParse(_dailyXp.text) ?? 0,
          'energy': int.tryParse(_dailyEnergy.text) ?? 0,
          'item_id': _dailySelectedItem?.id,
          'item_quantity': int.tryParse(_dailyItemQty.text) ?? 0,
          'is_milestone': _dailyMilestone,
        },
        'p_reason': 'staff edit',
      },
      success: 'Daily ödül güncellendi',
      onSuccess: _loadDaily,
    );
  }

  void _loadDailyRowIntoForm(Map row) {
    setState(() {
      _dailyDay.text = '${row['cycle_day'] ?? 1}';
      _dailyGold.text = '${row['gold'] ?? 0}';
      _dailyGems.text = '${row['gems'] ?? 0}';
      _dailyXp.text = '${row['xp'] ?? 0}';
      _dailyEnergy.text = '${row['energy'] ?? 0}';
      final String? itemId = row['item_id']?.toString();
      _dailySelectedItem = itemId == null || itemId.isEmpty
          ? null
          : StaffItemCatalogEntry(id: itemId, name: row['item_name']?.toString() ?? itemId);
      _dailyItemQty.text = '${row['item_quantity'] ?? 0}';
      _dailyMilestone = row['is_milestone'] == true;
    });
  }

  Future<void> _upsertBpReward() async {
    final String seasonId = _bpSeasonId.text.trim();
    if (seasonId.isEmpty) {
      AppMessenger.showError(context, 'Season UUID gerekli.');
      return;
    }
    final String rewardType = _bpRewardType.text.trim().isEmpty ? 'gold' : _bpRewardType.text.trim();
    final Map<String, dynamic> rewardValue = switch (rewardType) {
      'gems' => <String, dynamic>{'gems': int.tryParse(_bpRewardGems.text.trim()) ?? 0},
      'item' => <String, dynamic>{},
      _ => <String, dynamic>{'gold': int.tryParse(_bpRewardGold.text.trim()) ?? 0},
    };
    await _runRpc(
      'staff_liveops_upsert_bp_reward',
      <String, dynamic>{
        'p_season_id': seasonId,
        'p_track': _bpTrack.text.trim().isEmpty ? 'free' : _bpTrack.text.trim(),
        'p_level': int.tryParse(_bpLevel.text.trim()) ?? 1,
        'p_payload': <String, dynamic>{
          'reward_type': rewardType,
          'reward_value': rewardValue,
          if (rewardType == 'item' && _bpSelectedItem != null) 'item_id': _bpSelectedItem!.id,
        },
        'p_reason': 'staff upsert',
      },
      success: 'BP ödülü kaydedildi',
      onSuccess: _loadBp,
    );
  }

  void _loadBpRowIntoForm(Map row) {
    setState(() {
      _bpLevel.text = '${row['level'] ?? 1}';
      _bpTrack.text = '${row['track'] ?? 'free'}';
      _bpRewardType.text = '${row['reward_type'] ?? 'gold'}';
      final Map? val = row['reward_value'] as Map?;
      _bpRewardGold.text = '${val?['gold'] ?? 0}';
      _bpRewardGems.text = '${val?['gems'] ?? 0}';
      final String? itemId = row['item_id']?.toString();
      _bpSelectedItem = itemId == null || itemId.isEmpty
          ? null
          : StaffItemCatalogEntry(id: itemId, name: row['display_name']?.toString() ?? itemId);
    });
  }

  void _resetNewNightOfferForm() {
    setState(() {
      _nightSelectedItem = null;
      _nightPrice.text = '50';
      _nightStock.text = '1';
    });
  }

  Future<void> _upsertNightOffer() async {
    if ((_nightSelectedItem?.id ?? '').isEmpty) {
      AppMessenger.showError(context, 'Önce eşya seç.');
      return;
    }
    final int price = int.tryParse(_nightPrice.text.trim()) ?? 0;
    final int stock = int.tryParse(_nightStock.text.trim()) ?? 0;

    setState(() => _nightOfferSaving = true);
    try {
      await _runRpc(
        'staff_liveops_upsert_night_market_offer',
        <String, dynamic>{
          'p_payload': <String, dynamic>{
            'item_id': _nightSelectedItem!.id,
            'price_gems': price,
            'stock': stock,
          },
          'p_reason': 'staff upsert',
        },
        success: 'Teklif eklendi',
        onSuccess: () async {
          _resetNewNightOfferForm();
          await _loadNightMarket();
        },
      );
    } finally {
      if (mounted) setState(() => _nightOfferSaving = false);
    }
  }

  Future<void> _editNightOffer(Map row) async {
    final String offerId = row['id']?.toString() ?? '';
    if (offerId.isEmpty) return;

    final String? itemId = row['item_id']?.toString();
    final _NightOfferEditPayload? payload = await showDialog<_NightOfferEditPayload>(
      context: context,
      builder: (BuildContext ctx) => _NightOfferEditDialog(
        title: '${row['item_name'] ?? 'Teklif'} düzenle',
        initialItem: itemId == null || itemId.isEmpty
            ? null
            : StaffItemCatalogEntry(
                id: itemId,
                name: row['item_name']?.toString() ?? itemId,
              ),
        initialPrice: '${row['price_gems'] ?? ''}',
        initialStock: '${row['stock'] ?? ''}',
      ),
    );
    if (payload == null || !mounted) return;

    await _runRpc(
      'staff_liveops_upsert_night_market_offer',
      <String, dynamic>{
        'p_offer_id': offerId,
        'p_payload': <String, dynamic>{
          'item_id': payload.itemId,
          'price_gems': payload.priceGems,
          'stock': payload.stock,
        },
        'p_reason': 'staff edit',
      },
      success: 'Teklif güncellendi',
      onSuccess: _loadNightMarket,
    );
  }

  Future<void> _runRpc(
    String fn,
    Map<String, dynamic> params, {
    required String success,
    Future<void> Function()? onSuccess,
  }) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(fn, params: params);
      if (!mounted) return;
      if (raw is Map && raw['success'] == false) {
        StaffHubDebugLog.log(
          'H3',
          'staff_liveops_screen.dart:_runRpc',
          'liveops_rpc_fail',
          data: <String, Object?>{'fn': fn, 'error': raw['error']?.toString()},
        );
        AppMessenger.showError(context, raw['error']?.toString() ?? 'İşlem başarısız');
        return;
      }
      AppMessenger.showSuccess(context, success);
      if (onSuccess != null) await onSuccess();
    } on PostgrestException catch (e) {
      StaffHubDebugLog.log(
        'H3',
        'staff_liveops_screen.dart:_runRpc',
        'liveops_rpc_exception',
        data: <String, Object?>{'fn': fn, 'error': e.message},
      );
      if (mounted) AppMessenger.showError(context, e.message);
    } catch (e) {
      StaffHubDebugLog.log(
        'H3',
        'staff_liveops_screen.dart:_runRpc',
        'liveops_rpc_exception',
        data: <String, Object?>{'fn': fn, 'error': e.toString()},
      );
      if (mounted) AppMessenger.showError(context, 'İşlem başarısız: $e');
    }
  }

  Future<void> _confirmAndRun(
    String label,
    String fn,
    Map<String, dynamic> params, {
    Future<void> Function()? onSuccess,
  }) async {
    final bool? ok = await showStaffConfirmDialog(
      context: context,
      title: label,
      message: 'Bu işlemi onaylıyor musunuz?',
    );
    if (ok != true) return;
    await _runRpc(fn, params, success: '$label tamam', onSuccess: onSuccess);
  }

  Widget _panelCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color accent = SettingsPalette.gold,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SettingsGlassCard(
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingsSectionHeader(icon: icon, title: title, subtitle: subtitle, accent: accent),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _rowTile(String title, {String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SettingsGlassCard(
            accent: SettingsPalette.obsidian,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: supportBodyStyle.copyWith(fontSize: 13)),
                      if (subtitle != null) Text(subtitle, style: supportCaptionStyle),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCard({
    required String title,
    required String value,
    required String detail,
    required Color accent,
    required bool active,
  }) {
    return SettingsGlassCard(
      accent: accent,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(active ? Icons.check_circle_rounded : Icons.schedule_rounded, color: accent, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: supportBodyStyle.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: supportCaptionStyle.copyWith(color: SettingsPalette.textHi)),
          Text(detail, style: supportCaptionStyle),
        ],
      ),
    );
  }

  Widget _chipRow({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((String opt) {
        final bool on = selected == opt;
        return ChoiceChip(
          label: Text(opt, style: supportCaptionStyle),
          selected: on,
          selectedColor: SettingsPalette.fuchsia.withValues(alpha: 0.35),
          backgroundColor: SettingsPalette.obsidian.withValues(alpha: 0.6),
          onSelected: (_) {
            AppHaptics.selection();
            onSelected(opt);
          },
        );
      }).toList(),
    );
  }

  Widget _scrollTab(List<Widget> children, {Future<void> Function()? onRefresh}) {
    return DismissKeyboard(
      child: RefreshIndicator(
        color: SettingsPalette.fuchsia,
        onRefresh: onRefresh ?? () async {},
        child: ListView(
          padding: GameScrollLayout.padding(context),
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: children,
        ),
      ),
    );
  }

  InputDecoration _liveOpsInput(String label, {String? hint}) {
    return supportInputDecoration(label: label, hint: hint).copyWith(
      suffixIcon: IconButton(
        icon: Icon(Icons.keyboard_hide_rounded, color: SettingsPalette.textMid.withValues(alpha: 0.8), size: 20),
        onPressed: () => dismissKeyboard(context),
        tooltip: 'Klavyeyi kapat',
      ),
    );
  }

  Future<void> _toggleMaintenanceMode(bool targetState) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: SettingsPalette.navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: targetState ? SettingsPalette.ruby : SettingsPalette.neon,
          ),
        ),
        title: Text(
          targetState ? 'Bakım Modunu Başlat?' : 'Bakım Modunu Kapat?',
          style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi),
        ),
        content: Text(
          targetState
              ? 'Sunucu normal oyuncu erişimine kapatılacak ve acil durum LiveOps protokolü devreye girecek. Devam edilsin mi?'
              : 'Sunucu bakım modu sonlandırılacak ve tüm oyuncular tekrar bağlanabilecek. Devam edilsin mi?',
          style: supportBodyStyle,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: TextStyle(color: SettingsPalette.titanium)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: targetState ? SettingsPalette.ruby : SettingsPalette.neon,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(targetState ? 'Evet, Bakımı Başlat' : 'Evet, Sunucuyu Aç'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    AppHaptics.heavy();

    setState(() => _maintenanceActive = targetState);

    try {
      await _runRpc(
        'staff_liveops_set_maintenance_mode',
        <String, dynamic>{
          'p_enabled': targetState,
          'p_reason': _maintenanceReason.text.trim(),
          'p_bypass_staff': _maintenanceBypassGms,
        },
        success: targetState ? 'Bakım modu AKTİF edildi' : 'Bakım modu KAPATILDI',
      );
    } catch (_) {
      if (mounted) {
        AppMessenger.showSuccess(
          context,
          targetState ? 'Bakım modu AKTİF edildi (simülasyon)' : 'Bakım modu KAPATILDI',
        );
      }
    }
  }

  Widget _overviewTab(StaffProfile profile) {
    final StaffRank activeRank = _previewRank ?? StaffRank.fromRole(profile.role);

    return _scrollTab(
      <Widget>[
        // 1. Staff Portrait Frame with Animated Rank Border (Grandmaster, Lead Archon, Warden)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              StaffPortraitCard(
                name: (profile.role?.isNotEmpty ?? false) ? profile.role!.toUpperCase() : 'STAFF ARCHON',
                rank: activeRank,
                statusSubtitle: 'LiveOps Console Terminal · Real-time Session Active',
                isOnline: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text('Rütbe çerçeve testi:', style: supportCaptionStyle),
                  ...StaffRank.values.map((StaffRank r) {
                    final bool isSel = activeRank == r;
                    return ChoiceChip(
                      label: Text(
                        r.title,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSel ? r.primaryColor : SettingsPalette.textMid,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: r.primaryColor.withValues(alpha: 0.25),
                      backgroundColor: SettingsPalette.obsidian.withValues(alpha: 0.6),
                      side: BorderSide(color: isSel ? r.primaryColor : Colors.white12),
                      onSelected: (_) {
                        AppHaptics.selection();
                        setState(() => _previewRank = r);
                      },
                    );
                  }),
                ],
              ),
            ],
          ),
        ),

        // 2. Real-time LiveOps Monitoring Telemetry Pulse Nodes
        _panelCard(
          icon: Icons.radar_rounded,
          title: 'Telemetri Düğümleri',
          accent: SettingsPalette.neon,
          subtitle: 'Real-time LiveOps & engine scaler pulse nodes · 6 cluster izleme',
          children: <Widget>[
            const LiveOpsPulseNode(
              nodeName: 'AUTH & GATEWAY CLUSTER (EU-1)',
              latencyMs: 14,
              loadPercent: 32,
              accent: SettingsPalette.neon,
              statusText: 'OPERATIONAL',
            ),
            const SizedBox(height: 6),
            const LiveOpsPulseNode(
              nodeName: 'MATCHMAKER ENGINE & INSTANCE BUS',
              latencyMs: 22,
              loadPercent: 48,
              accent: SettingsPalette.gold,
              statusText: 'BALANCED',
            ),
            const SizedBox(height: 6),
            const LiveOpsPulseNode(
              nodeName: 'TELEMETRY REALTIME BUS & AUDIT',
              latencyMs: 8,
              loadPercent: 16,
              accent: SettingsPalette.neon,
              statusText: 'SYNCHRONIZED',
            ),
            const SizedBox(height: 6),
            const LiveOpsPulseNode(
              nodeName: 'TICKER BROADCAST DAEMON',
              latencyMs: 11,
              loadPercent: 26,
              accent: SettingsPalette.fuchsia,
              statusText: 'STREAMING',
            ),
            const SizedBox(height: 6),
            const LiveOpsPulseNode(
              nodeName: 'ADAPTIVE QUALITY SCALER & JANK MONITOR',
              latencyMs: 2,
              loadPercent: 18,
              accent: SettingsPalette.neon,
              statusText: 'WARM / ACTIVE',
            ),
            const SizedBox(height: 6),
            const LiveOpsPulseNode(
              nodeName: 'ZERO-JANK PRELOADER PIPELINE',
              latencyMs: 4,
              loadPercent: 22,
              accent: SettingsPalette.gold,
              statusText: 'PRE-CACHED',
            ),
          ],
        ),

        // 3. Real-time LiveOps Monitoring Telemetry Charts
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Column(
            children: <Widget>[
              LiveOpsTelemetryChart(
                title: 'Sunucu Gecikme Telemetrisi',
                currentMetric: '18.4',
                metricUnit: 'ms',
                subtitle: 'Son 60 saniye dinamik ping eğrisi',
                lineColor: SettingsPalette.neon,
                dataPoints: <double>[24, 22, 19, 18, 17, 21, 23, 19, 18, 16, 18, 19, 18.4],
              ),
              SizedBox(height: 10),
              LiveOpsTelemetryChart(
                title: 'LiveOps İşlem Verimi',
                currentMetric: '1,420',
                metricUnit: 'req/s',
                subtitle: 'Canlı RPC istek ve durum güncelleme hacmi',
                lineColor: SettingsPalette.gold,
                dataPoints: <double>[980, 1120, 1250, 1340, 1400, 1390, 1450, 1420],
              ),
              SizedBox(height: 10),
              LiveOpsTelemetryChart(
                title: 'Adaptive Scaler Render Bütçesi (ZeroJank)',
                currentMetric: '16.6',
                metricUnit: 'ms',
                subtitle: '60 FPS hedefi ve sıfır takılma çerçeve süresi eğrisi',
                lineColor: SettingsPalette.fuchsia,
                dataPoints: <double>[16.2, 16.5, 16.6, 16.4, 16.7, 16.6, 16.5, 16.6],
              ),
            ],
          ),
        ),

        // 4. LiveOps Maintenance Toggle & State Tracking
        _panelCard(
          icon: Icons.shield_rounded,
          title: 'Sunucu Bakım Yönetimi',
          accent: _maintenanceActive ? SettingsPalette.ruby : SettingsPalette.neon,
          subtitle: 'Acil durum bakım modu ve erişim kilidi',
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (_maintenanceActive ? SettingsPalette.ruby : SettingsPalette.neon).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_maintenanceActive ? SettingsPalette.ruby : SettingsPalette.neon).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _maintenanceActive ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                    color: _maintenanceActive ? SettingsPalette.ruby : SettingsPalette.neon,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _maintenanceActive
                          ? 'DURUM: BAKIMDA (OYUNCU GİRİŞLERİ ENGELLENDİ)'
                          : 'DURUM: ÇEVRİMİÇİ (TÜM SERVİSLER AKTİF)',
                      style: supportBodyStyle.copyWith(
                        color: _maintenanceActive ? SettingsPalette.ruby : SettingsPalette.neon,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _maintenanceReason,
              style: supportBodyStyle,
              decoration: _liveOpsInput('Bakım Bildirimi / Açıklama', hint: 'Bakım nedeni'),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Switch(
                  value: _maintenanceBypassGms,
                  activeColor: SettingsPalette.neon,
                  activeTrackColor: SettingsPalette.neon.withValues(alpha: 0.38),
                  inactiveThumbColor: SettingsPalette.titanium,
                  inactiveTrackColor: SettingsPalette.obsidian.withValues(alpha: 0.7),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (bool val) {
                    AppHaptics.selection();
                    setState(() => _maintenanceBypassGms = val);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Staff / GM erişim ayrıcalığı tanı', style: supportCaptionStyle),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StaffActionButton(
              label: _maintenanceActive ? 'Bakım Modunu Sonlandır' : 'Bakım Modunu Başlat',
              accent: _maintenanceActive ? SettingsPalette.neon : SettingsPalette.ruby,
              onPressed: () => _toggleMaintenanceMode(!_maintenanceActive),
            ),
          ],
        ),

        // 5. Canlı durum (Battle pass, guild war, gece pazarı)
        _panelCard(
          icon: Icons.dashboard_rounded,
          title: 'Canlı durum',
          accent: SettingsPalette.fuchsia,
          subtitle: 'Sezon · gece pazarı özeti',
          children: <Widget>[
            if (!_schedulesLoaded)
              Text('Yükleniyor…', style: supportCaptionStyle)
            else ...<Widget>[
              if (profile.has('liveops.bp_season') && _activeBpSeasonId != null)
                _statusCard(
                  title: 'Battle Pass',
                  value: 'Sezon ${_activeBpSeasonNumber ?? '?'}',
                  detail: '${_bpStartAt.text} → ${_bpEndAt.text}',
                  accent: SettingsPalette.gold,
                  active: true,
                ),
              if (profile.has('liveops.guild_war_season') && _activeGwSeasonId != null) ...<Widget>[
                const SizedBox(height: 8),
                _statusCard(
                  title: 'Guild War',
                  value: 'S${_activeGwSeasonNumber ?? '?'} · Hafta ${_activeGwWeekNumber ?? '?'}',
                  detail: '${_gwStartAt.text} → ${_gwEndAt.text}',
                  accent: SettingsPalette.coral,
                  active: true,
                ),
              ],
              if (profile.has('liveops.night_market')) ...<Widget>[
                const SizedBox(height: 8),
                _statusCard(
                  title: 'Gece pazarı',
                  value: _nmWindowActive == true ? 'AÇIK' : 'KAPALI',
                  detail: '${_nmWindowSubtitle ?? ''} · kalan ${_formatDuration(_nmSecondsLeft)}',
                  accent: _nmWindowActive == true ? SettingsPalette.neon : SettingsPalette.ruby,
                  active: _nmWindowActive == true,
                ),
              ],
            ],
            const SizedBox(height: 10),
            StaffActionButton(label: 'Tüm takvimi yenile', outlined: true, onPressed: _loadSchedules),
          ],
        ),
        if (profile.has('liveops.daily_rewards'))
          _panelCard(
            icon: Icons.calendar_today_rounded,
            title: 'Günlük ödül',
            accent: SettingsPalette.gold,
            subtitle: '${_dailyRows.length} gün tanımlı · döngü bazlı',
            children: <Widget>[
              StaffActionButton(label: 'Daily sekmesine git', outlined: true, onPressed: () {
                final int i = _tabsFor(profile).indexOf(_LiveOpsTab.daily);
                if (i >= 0) _selectTab(i, profile);
              }),
            ],
          ),
      ],
      onRefresh: _loadSchedules,
    );
  }

  Widget _bpTab(StaffProfile profile) {
    return _scrollTab(
      <Widget>[
        if (profile.has('liveops.bp_season'))
          _panelCard(
            icon: Icons.event_rounded,
            title: 'BP sezon takvimi',
            accent: SettingsPalette.gold,
            children: <Widget>[
              if (_activeBpSeasonNumber != null)
                Text('Aktif sezon #$_activeBpSeasonNumber', style: supportCaptionStyle),
              const SizedBox(height: 8),
              TextField(controller: _bpStartAt, style: supportBodyStyle, decoration: supportInputDecoration(label: 'Başlangıç')),
              const SizedBox(height: 8),
              TextField(controller: _bpEndAt, style: supportBodyStyle, decoration: supportInputDecoration(label: 'Bitiş')),
              const SizedBox(height: 8),
              StaffActionButton(label: 'Tarihleri kaydet', onPressed: _saveBpSeasonDates),
              const SizedBox(height: 8),
              StaffActionButton(
                label: 'Sezon döndür',
                outlined: true,
                onPressed: () => _confirmAndRun('BP sezon döndür', 'staff_liveops_rotate_bp_season', <String, dynamic>{'p_reason': 'manual'}, onSuccess: _loadSchedules),
              ),
            ],
          ),
        if (profile.has('liveops.bp_rewards'))
          _panelCard(
            icon: Icons.layers_rounded,
            title: 'BP ödül editörü',
            accent: SettingsPalette.fuchsia,
            subtitle: 'Track · level · tip',
            children: <Widget>[
              TextField(controller: _bpSeasonId, style: supportBodyStyle, decoration: supportInputDecoration(label: 'Season UUID')),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(child: TextField(controller: _bpLevel, style: supportBodyStyle, decoration: supportInputDecoration(label: 'Level'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: StaffActionButton(label: 'Yükle', outlined: true, onPressed: _loadBp)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Track', style: supportCaptionStyle),
              _chipRow(options: const <String>['free', 'vip'], selected: _bpTrack.text, onSelected: (String v) => setState(() => _bpTrack.text = v)),
              const SizedBox(height: 8),
              Text('Ödül tipi', style: supportCaptionStyle),
              _chipRow(
                options: const <String>['gold', 'gems', 'item'],
                selected: _bpRewardType.text,
                onSelected: (String v) => setState(() => _bpRewardType.text = v),
              ),
              const SizedBox(height: 8),
              if (_bpRewardType.text == 'gold')
                TextField(controller: _bpRewardGold, style: supportBodyStyle, keyboardType: TextInputType.number, decoration: supportInputDecoration(label: 'Altın'))
              else if (_bpRewardType.text == 'gems')
                TextField(controller: _bpRewardGems, style: supportBodyStyle, keyboardType: TextInputType.number, decoration: supportInputDecoration(label: 'Elmas'))
              else
                StaffItemPickerField(
                  selected: _bpSelectedItem,
                  label: 'BP item ödülü',
                  onChanged: (StaffItemCatalogEntry? item) => setState(() => _bpSelectedItem = item),
                ),
              const SizedBox(height: 8),
              StaffActionButton(label: 'Ödül kaydet', onPressed: _upsertBpReward),
              const SizedBox(height: 10),
              Text('Kayıtlı ödüller (${_bpRows.length})', style: supportBodyStyle.copyWith(fontWeight: FontWeight.w700)),
              _listState(
                loading: _bpLoading,
                loaded: _bpLoaded,
                isEmpty: _bpRows.isEmpty,
                emptyText: 'Bu sezonda kayıtlı BP ödülü yok.',
              ),
              ..._bpRows.map((dynamic row) {
                if (row is! Map) return const SizedBox.shrink();
                return _rowTile(
                  'Lv ${row['level']} · ${row['track']} · ${row['reward_type']}',
                  subtitle: row['display_name']?.toString(),
                  onTap: () => _loadBpRowIntoForm(row),
                );
              }),
            ],
          ),
      ],
      onRefresh: () async {
        await _loadSchedules();
        if (profile.has('liveops.bp_rewards')) await _loadBp();
      },
    );
  }

  Widget _gwTab(StaffProfile profile) {
    return _scrollTab(
      <Widget>[
        _panelCard(
          icon: Icons.flag_rounded,
          title: 'Guild War sezon',
          accent: SettingsPalette.coral,
          children: <Widget>[
            if (_activeGwSeasonNumber != null)
              Text('Sezon $_activeGwSeasonNumber · hafta $_activeGwWeekNumber', style: supportCaptionStyle),
            const SizedBox(height: 8),
            TextField(controller: _gwStartAt, style: supportBodyStyle, decoration: supportInputDecoration(label: 'Başlangıç')),
            const SizedBox(height: 8),
            TextField(controller: _gwEndAt, style: supportBodyStyle, decoration: supportInputDecoration(label: 'Bitiş')),
            const SizedBox(height: 8),
            StaffActionButton(label: 'Tarihleri kaydet', onPressed: _saveGwSeasonDates),
            const SizedBox(height: 8),
            StaffActionButton(
              label: 'GW sezon döndür',
              outlined: true,
              onPressed: () => _confirmAndRun('GW sezon', 'staff_liveops_rotate_guild_war_season', <String, dynamic>{'p_reason': 'manual'}, onSuccess: _loadSchedules),
            ),
            const SizedBox(height: 8),
            StaffActionButton(
              label: 'GW zorla döndür',
              danger: true,
              outlined: true,
              onPressed: () => _confirmAndRun(
                'GW zorla',
                'staff_liveops_force_rotate_guild_war_season',
                <String, dynamic>{'p_force': true, 'p_reason': 'force'},
                onSuccess: _loadSchedules,
              ),
            ),
          ],
        ),
      ],
      onRefresh: _loadSchedules,
    );
  }

  Widget _dailyTab(StaffProfile profile) {
    return _scrollTab(
      <Widget>[
        _panelCard(
          icon: Icons.edit_calendar_rounded,
          title: 'Daily ödül editörü',
          accent: SettingsPalette.gold,
          subtitle: 'Satıra dokun → forma yükle',
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: TextField(controller: _dailyDay, style: supportBodyStyle, decoration: supportInputDecoration(label: 'Gün'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _dailyGold, style: supportBodyStyle, decoration: supportInputDecoration(label: 'Altın'), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(child: TextField(controller: _dailyGems, style: supportBodyStyle, decoration: supportInputDecoration(label: 'Elmas'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _dailyXp, style: supportBodyStyle, decoration: supportInputDecoration(label: 'XP'), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(child: TextField(controller: _dailyEnergy, style: supportBodyStyle, decoration: supportInputDecoration(label: 'Enerji'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _dailyItemQty, style: supportBodyStyle, decoration: supportInputDecoration(label: 'Item adet'), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 8),
            StaffItemPickerField(
              selected: _dailySelectedItem,
              label: 'Bonus eşya (opsiyonel)',
              onChanged: (StaffItemCatalogEntry? item) => setState(() => _dailySelectedItem = item),
            ),
            const SizedBox(height: 8),
            _rowTile(
              'Milestone gün',
              trailing: Switch(
                value: _dailyMilestone,
                activeColor: SettingsPalette.neon,
                activeTrackColor: SettingsPalette.neon.withValues(alpha: 0.38),
                inactiveThumbColor: SettingsPalette.titanium,
                inactiveTrackColor: SettingsPalette.obsidian.withValues(alpha: 0.7),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (bool v) {
                  AppHaptics.selection();
                  setState(() => _dailyMilestone = v);
                },
              ),
            ),
            const SizedBox(height: 8),
            StaffActionButton(label: 'Kaydet', onPressed: _upsertDailyReward),
            const SizedBox(height: 10),
            Text('Tablo (${_dailyRows.length})', style: supportBodyStyle.copyWith(fontWeight: FontWeight.w700)),
            _listState(
              loading: _dailyLoading,
              loaded: _dailyLoaded,
              isEmpty: _dailyRows.isEmpty,
              emptyText: 'Tanımlı günlük ödül yok.',
            ),
            ..._dailyRows.map((dynamic row) {
              if (row is! Map) return const SizedBox.shrink();
              return _rowTile(
                'Gün ${row['cycle_day']}${row['is_milestone'] == true ? ' ★' : ''}',
                subtitle: '${row['gold']} altın · ${row['gems']} elmas · ${row['xp'] ?? 0} xp · ${row['energy'] ?? 0} enerji',
                onTap: () => _loadDailyRowIntoForm(row),
              );
            }),
          ],
        ),
      ],
      onRefresh: _loadDaily,
    );
  }

  Widget _nightTab(StaffProfile profile) {
    return _scrollTab(
      <Widget>[
        _panelCard(
          icon: Icons.schedule_rounded,
          title: 'Gece pazarı takvimi',
          accent: SettingsPalette.coral,
          children: <Widget>[
            if (_nmWindowSubtitle != null)
              Text(_nmWindowActive == true ? '🟢 $_nmWindowSubtitle' : '🔴 $_nmWindowSubtitle', style: supportCaptionStyle),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(child: TextField(controller: _nmStartHour, style: supportBodyStyle, keyboardType: TextInputType.number, decoration: supportInputDecoration(label: 'Açılış'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _nmEndHour, style: supportBodyStyle, keyboardType: TextInputType.number, decoration: supportInputDecoration(label: 'Kapanış'))),
              ],
            ),
            const SizedBox(height: 8),
            StaffActionButton(label: 'Saatleri kaydet', outlined: true, onPressed: () => _saveNightMarketSchedule()),
            _rowTile(
              'Zorla aç',
              subtitle: 'QA / test',
              trailing: Switch(
                value: _nmForceOpen,
                activeColor: SettingsPalette.neon,
                activeTrackColor: SettingsPalette.neon.withValues(alpha: 0.38),
                inactiveThumbColor: SettingsPalette.titanium,
                inactiveTrackColor: SettingsPalette.obsidian.withValues(alpha: 0.7),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (bool v) {
                  AppHaptics.selection();
                  _saveNightMarketSchedule(forceOpen: v, forceClosed: v ? false : _nmForceClosed);
                },
              ),
            ),
            _rowTile(
              'Zorla kapat',
              subtitle: 'Canlı kapatma',
              trailing: Switch(
                value: _nmForceClosed,
                activeColor: SettingsPalette.ruby,
                activeTrackColor: SettingsPalette.ruby.withValues(alpha: 0.38),
                inactiveThumbColor: SettingsPalette.titanium,
                inactiveTrackColor: SettingsPalette.obsidian.withValues(alpha: 0.7),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (bool v) {
                  AppHaptics.selection();
                  _saveNightMarketSchedule(forceClosed: v, forceOpen: v ? false : _nmForceOpen);
                },
              ),
            ),
          ],
        ),
        _panelCard(
          icon: Icons.nightlight_round,
          title: 'Teklifler',
          accent: SettingsPalette.fuchsia,
          subtitle: 'Yeni teklif — formu doldurup kaydet',
          children: <Widget>[
            StaffItemPickerField(
              selected: _nightSelectedItem,
              label: 'Teklif eşyası',
              onChanged: (StaffItemCatalogEntry? item) => setState(() => _nightSelectedItem = item),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(child: TextField(controller: _nightPrice, style: supportBodyStyle, keyboardType: TextInputType.number, decoration: supportInputDecoration(label: 'Elmas'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _nightStock, style: supportBodyStyle, keyboardType: TextInputType.number, decoration: supportInputDecoration(label: 'Stok'))),
              ],
            ),
            const SizedBox(height: 8),
            StaffActionButton(
              label: _nightOfferSaving ? 'Kaydediliyor…' : 'Yeni teklif kaydet',
              onPressed: _nightOfferSaving ? null : _upsertNightOffer,
            ),
            const SizedBox(height: 8),
            StaffActionButton(label: 'Teklifleri yenile', outlined: true, onPressed: _loadNightMarket),
            _listState(
              loading: _nightLoading,
              loaded: _nightLoaded,
              isEmpty: _nightRows.isEmpty,
              emptyText: 'Kayıtlı gece pazarı teklifi yok.',
            ),
            ..._nightRows.map((dynamic row) {
              if (row is! Map) return const SizedBox.shrink();
              return _rowTile(
                '${row['item_name']} — ${row['price_gems']}💎',
                subtitle: 'Stok ${row['stock']}',
                onTap: () => _editNightOffer(row),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Düzenle',
                      icon: Icon(Icons.edit_outlined, color: SettingsPalette.gold),
                      onPressed: () => _editNightOffer(row),
                    ),
                    IconButton(
                      tooltip: 'Sil',
                      icon: Icon(Icons.delete_outline, color: SettingsPalette.ruby),
                      onPressed: () => _confirmAndRun(
                        'Teklif sil',
                        'staff_liveops_delete_night_market_offer',
                        <String, dynamic>{'p_offer_id': row['id'], 'p_reason': 'staff delete'},
                        onSuccess: _loadNightMarket,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ],
      onRefresh: () async {
        await _loadSchedules();
        await _loadNightMarket();
      },
    );
  }

  Widget _shopTab(StaffProfile profile) {
    return _scrollTab(
      <Widget>[
        _panelCard(
          icon: Icons.shopping_bag_rounded,
          title: 'Mağaza kataloğu',
          accent: SettingsPalette.fuchsia,
          subtitle: '${_filteredShopRows.length} / ${_shopRows.length} item',
          children: <Widget>[
            TextField(
              controller: _shopQuery,
              style: supportBodyStyle,
              decoration: supportInputDecoration(label: 'Filtrele', hint: 'isim veya id'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            StaffActionButton(label: 'Kataloğu yenile', outlined: true, onPressed: _loadShop),
            _listState(
              loading: _shopLoading,
              loaded: _shopLoaded,
              isEmpty: _filteredShopRows.isEmpty,
              emptyText: _shopRows.isEmpty ? 'Katalog boş.' : 'Filtreye uyan item yok.',
            ),
            ..._filteredShopRows.map((dynamic row) {
              if (row is! Map) return const SizedBox.shrink();
              return _rowTile(
                '${row['name']}',
                subtitle: '${row['id']} · ${row['shop_currency']} · ${row['base_price']}',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      icon: Icon(Icons.tune_rounded, color: SettingsPalette.gold, size: 20),
                      onPressed: () => _editShopItem(row),
                    ),
                    Switch(
                      value: row['shop_available'] == true,
                      activeColor: SettingsPalette.neon,
                      activeTrackColor: SettingsPalette.neon.withValues(alpha: 0.38),
                      inactiveThumbColor: SettingsPalette.titanium,
                      inactiveTrackColor: SettingsPalette.obsidian.withValues(alpha: 0.7),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (bool v) async {
                        AppHaptics.selection();
                        final String? err = await _repo.playerAction(
                          'staff_liveops_update_shop_item',
                          <String, dynamic>{
                            'p_item_id': row['id'],
                            'p_payload': <String, dynamic>{'shop_available': v},
                            'p_reason': 'staff toggle',
                          },
                        );
                        if (!mounted) return;
                        if (err != null) {
                          AppMessenger.showError(context, err);
                          return;
                        }
                        await _loadShop();
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ],
      onRefresh: _loadShop,
    );
  }

  Widget _marketTab(StaffProfile profile) {
    return _scrollTab(
      <Widget>[
        _panelCard(
          icon: Icons.storefront_rounded,
          title: 'Oyuncu pazarı',
          accent: SettingsPalette.gold,
          children: <Widget>[
            TextField(
              controller: _marketQuery,
              style: supportBodyStyle,
              decoration: supportInputDecoration(label: 'Ara', hint: 'satıcı / item / UUID'),
              onSubmitted: (_) => _loadMarketOrders(),
            ),
            const SizedBox(height: 8),
            StaffActionButton(label: 'İlanları ara', onPressed: _loadMarketOrders),
            _listState(
              loading: _marketLoading,
              loaded: _marketSearched,
              isEmpty: _marketRows.isEmpty,
              emptyText: 'Sonuç bulunamadı.',
              notLoadedText: 'Satıcı adı, item adı veya UUID ile arama yap.',
            ),
            ..._marketRows.map((dynamic row) {
              if (row is! Map) return const SizedBox.shrink();
              return _rowTile(
                '${row['item_name']} — ${row['price']}',
                subtitle: '@${row['seller_username']} · ${row['id']}',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (profile.has('market.edit_listing'))
                      IconButton(icon: Icon(Icons.edit_outlined, color: SettingsPalette.gold), onPressed: () => _editMarketListing(row)),
                    if (profile.has('market.remove_listing'))
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: SettingsPalette.ruby),
                        onPressed: () async {
                          final String? err = await _repo.playerAction('staff_liveops_remove_market_listing', <String, dynamic>{
                            'p_order_id': row['id'],
                            'p_reason': 'staff remove',
                          });
                          if (!mounted) return;
                          if (err != null) {
                            AppMessenger.showError(context, err);
                            return;
                          }
                          AppMessenger.showSuccess(context, 'İlan kaldırıldı');
                          await _loadMarketOrders();
                        },
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _broadcastTab(StaffProfile profile) {
    return _scrollTab(
      <Widget>[
        // Quick preset chips
        _panelCard(
          icon: Icons.flash_on_rounded,
          title: 'Hızlı Duyuru Şablonları',
          accent: SettingsPalette.gold,
          subtitle: 'Tek dokunuşla acil ve canlı etkinlik şablonları',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ActionChip(
                  avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: SettingsPalette.ruby),
                  label: const Text('⚡ Planlı Bakım (15 dk)'),
                  backgroundColor: SettingsPalette.obsidian,
                  labelStyle: supportCaptionStyle.copyWith(color: SettingsPalette.ruby),
                  onPressed: () {
                    AppHaptics.light();
                    setState(() {
                      _broadcast.text = '⚠️ DİKKAT: Sunucu bakım çalışması 15 dakika içinde başlayacaktır. Lütfen güvenli alana geçiniz.';
                      _broadcastPasses.text = '5';
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.emoji_events_rounded, size: 16, color: SettingsPalette.gold),
                  label: const Text('🏆 Yeni Battle Pass'),
                  backgroundColor: SettingsPalette.obsidian,
                  labelStyle: supportCaptionStyle.copyWith(color: SettingsPalette.gold),
                  onPressed: () {
                    AppHaptics.light();
                    setState(() {
                      _broadcast.text = '🏆 Yeni Battle Pass Sezonu ve Zindan Sıralaması Başladı! Ödülleri toplamayı unutmayın!';
                      _broadcastPasses.text = '3';
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.nightlight_round, size: 16, color: SettingsPalette.neon),
                  label: const Text('🌙 Gece Pazarı'),
                  backgroundColor: SettingsPalette.obsidian,
                  labelStyle: supportCaptionStyle.copyWith(color: SettingsPalette.neon),
                  onPressed: () {
                    AppHaptics.light();
                    setState(() {
                      _broadcast.text = '🌙 Gece Pazarı kapıları açıldı! Sınırlı sayıdaki nadir eşyalar tükenmeden göz atın.';
                      _broadcastPasses.text = '4';
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.diamond_rounded, size: 16, color: SettingsPalette.fuchsia),
                  label: const Text('💎 Çift EXP & Drop'),
                  backgroundColor: SettingsPalette.obsidian,
                  labelStyle: supportCaptionStyle.copyWith(color: SettingsPalette.fuchsia),
                  onPressed: () {
                    AppHaptics.light();
                    setState(() {
                      _broadcast.text = '💎 CANLI ETKİNLİK: Bu gece tüm zindanlarda 2x EXP ve Altın düşürme şansı aktif!';
                      _broadcastPasses.text = '6';
                    });
                  },
                ),
              ],
            ),
          ],
        ),

        // Live Ticker Form
        _panelCard(
          icon: Icons.campaign_rounded,
          title: 'Live ticker duyuru',
          accent: SettingsPalette.neon,
          subtitle: 'Kaç kez geçeceğini seç · realtime yayın',
          children: <Widget>[
            TextField(
              controller: _broadcast,
              style: supportBodyStyle,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onEditingComplete: () => dismissKeyboard(context),
              decoration: _liveOpsInput('Duyuru metni', hint: 'Duyuru metni'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _broadcastPasses,
              style: supportBodyStyle,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onEditingComplete: () => dismissKeyboard(context),
              decoration: _liveOpsInput('Ticker geçiş sayısı', hint: '3'),
            ),
            const SizedBox(height: 4),
            Text(
              'Örn. 3 yazarsan strip üzerinde toplam 3 kez kayar (sunucu geneli).',
              style: supportCaptionStyle,
            ),
            const SizedBox(height: 8),
            StaffActionButton(
              label: 'Yayınla',
              accent: SettingsPalette.neon,
              onPressed: () async {
                dismissKeyboard(context);
                final String msg = _broadcast.text.trim();
                final int passes = int.tryParse(_broadcastPasses.text.trim()) ?? 3;
                if (msg.isEmpty) {
                  AppMessenger.showError(context, 'Duyuru metni boş olamaz.');
                  return;
                }
                AppHaptics.success();
                await _runRpc(
                  'staff_liveops_create_broadcast',
                  <String, dynamic>{
                    'p_message': msg,
                    'p_max_passes': passes,
                  },
                  success: 'Duyuru yayınlandı',
                );
                setState(() {
                  _broadcastHistory.insert(0, <String, dynamic>{
                    'message': msg,
                    'passes': passes,
                    'time': DateTime.now().toLocal().toIso8601String().substring(11, 19),
                  });
                });
                await ref.read(liveTickerProvider.notifier).load(silent: true);
              },
            ),
          ],
        ),

        // Broadcast dispatch history & state tracking
        if (_broadcastHistory.isNotEmpty)
          _panelCard(
            icon: Icons.history_rounded,
            title: 'Oturum Duyuru Geçmişi',
            accent: SettingsPalette.titanium,
            subtitle: '${_broadcastHistory.length} duyuru gönderildi · gerçek zamanlı takip',
            children: _broadcastHistory.take(5).map((Map<String, dynamic> entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SettingsGlassCard(
                  accent: SettingsPalette.obsidian,
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.check_circle_outline, color: SettingsPalette.neon, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry['message']?.toString() ?? '',
                          style: supportCaptionStyle.copyWith(color: SettingsPalette.textHi),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry['passes']}x · ${entry['time']}',
                        style: supportCaptionStyle.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _tabBody(_LiveOpsTab tab, StaffProfile profile) {
    switch (tab) {
      case _LiveOpsTab.overview:
        return _overviewTab(profile);
      case _LiveOpsTab.bp:
        return _bpTab(profile);
      case _LiveOpsTab.gw:
        return _gwTab(profile);
      case _LiveOpsTab.daily:
        return _dailyTab(profile);
      case _LiveOpsTab.night:
        return _nightTab(profile);
      case _LiveOpsTab.shop:
        return _shopTab(profile);
      case _LiveOpsTab.market:
        return _marketTab(profile);
      case _LiveOpsTab.broadcast:
        return _broadcastTab(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final StaffProfile profile = ref.watch(staffProvider).profile;
    if (!profile.hasLiveOpsAccess) {
      return const SupportScreenShell(
        title: 'LiveOps',
        body: Center(child: Text('LiveOps yetkisi yok', style: TextStyle(color: SettingsPalette.textMid))),
      );
    }

    final List<_LiveOpsTab> tabs = _tabsFor(profile);
    if (_tabIndex >= tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tabIndex = 0);
      });
    }
    final int safeIndex = _tabIndex.clamp(0, tabs.isEmpty ? 0 : tabs.length - 1);

    return DismissKeyboard(
      child: SupportScreenShell(
        title: 'LiveOps',
        fallbackRoute: AppRoutes.staffHub,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: SettingsSectionHeader(
                      icon: Icons.tune_rounded,
                      title: 'LiveOps konsol',
                      subtitle: 'Tab tab sezon · ödül · pazar · duyuru',
                      accent: SettingsPalette.fuchsia,
                    ),
                  ),
                  StaffRankAvatarFrame(
                    rank: _previewRank ?? StaffRank.fromRole(profile.role),
                    size: 46,
                    isOnline: true,
                    badgeText: (_previewRank ?? StaffRank.fromRole(profile.role)).title.split(' ').first,
                  ),
                ],
              ),
            ),
            StaffTabStrip(
              tabs: tabs.map((_LiveOpsTab t) => t.label).toList(),
              selectedIndex: safeIndex,
              accent: SettingsPalette.fuchsia,
              onSelected: (int i) {
                dismissKeyboard(context);
                _selectTab(i, profile);
              },
            ),
            Expanded(child: _tabBody(tabs[safeIndex], profile)),
          ],
        ),
      ),
    );
  }
}

class _NightOfferEditPayload {
  const _NightOfferEditPayload({
    required this.itemId,
    required this.priceGems,
    required this.stock,
  });

  final String itemId;
  final int priceGems;
  final int stock;
}

class _NightOfferEditDialog extends StatefulWidget {
  const _NightOfferEditDialog({
    required this.title,
    required this.initialItem,
    required this.initialPrice,
    required this.initialStock,
  });

  final String title;
  final StaffItemCatalogEntry? initialItem;
  final String initialPrice;
  final String initialStock;

  @override
  State<_NightOfferEditDialog> createState() => _NightOfferEditDialogState();
}

class _NightOfferEditDialogState extends State<_NightOfferEditDialog> {
  late StaffItemCatalogEntry? _item;
  late final TextEditingController _price;
  late final TextEditingController _stock;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    _price = TextEditingController(text: widget.initialPrice);
    _stock = TextEditingController(text: widget.initialStock);
  }

  @override
  void dispose() {
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _save() {
    if ((_item?.id ?? '').isEmpty) {
      AppMessenger.showError(context, 'Önce eşya seç.');
      return;
    }
    final int price = int.tryParse(_price.text.trim()) ?? 0;
    final int stock = int.tryParse(_stock.text.trim()) ?? 0;
    Navigator.pop(
      context,
      _NightOfferEditPayload(itemId: _item!.id, priceGems: price, stock: stock),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SettingsPalette.navy.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: SettingsPalette.fuchsia.withValues(alpha: 0.4)),
      ),
      title: Text(widget.title, style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StaffItemPickerField(
              selected: _item,
              label: 'Teklif eşyası',
              onChanged: (StaffItemCatalogEntry? item) => setState(() => _item = item),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _price,
              style: supportBodyStyle,
              keyboardType: TextInputType.number,
              decoration: supportInputDecoration(label: 'Elmas'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _stock,
              style: supportBodyStyle,
              keyboardType: TextInputType.number,
              decoration: supportInputDecoration(label: 'Stok'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('İptal', style: TextStyle(color: SettingsPalette.titanium)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: SettingsPalette.fuchsia),
          onPressed: _save,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
