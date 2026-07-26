import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/common/app_messenger.dart';
import '../../models/staff_model.dart';
import '../../repositories/staff_repository.dart';
import '../../screens/staff/widgets/staff_design.dart';
import '../../screens/support/widgets/support_design.dart';
import '../../theme/app_text_styles.dart';

Future<bool> showStaffInventoryEditor({
  required BuildContext context,
  required String authId,
  required String username,
  required String reason,
}) async {
  final bool? changed = await showStaffBottomSheet<bool>(
    context: context,
    accent: SettingsPalette.neon,
    child: StaffInventoryEditorPanel(
      authId: authId,
      username: username,
      reason: reason,
    ),
  );
  return changed == true;
}

class StaffInventoryEditorPanel extends StatefulWidget {
  const StaffInventoryEditorPanel({
    super.key,
    required this.authId,
    required this.username,
    required this.reason,
  });

  final String authId;
  final String username;
  final String reason;

  @override
  State<StaffInventoryEditorPanel> createState() => _StaffInventoryEditorPanelState();
}

class _StaffInventoryEditorPanelState extends State<StaffInventoryEditorPanel>
    with SingleTickerProviderStateMixin {
  final StaffRepository _repo = StaffRepository();
  final TextEditingController _itemSearch = TextEditingController();
  late TabController _tabs;
  bool _loading = true;
  bool _catalogLoading = false;
  bool _busy = false;
  bool _changed = false;
  String? _error;
  String? _catalogError;
  List<StaffInventoryRow> _inventory = <StaffInventoryRow>[];
  List<StaffItemCatalogEntry> _catalog = <StaffItemCatalogEntry>[];
  int _catalogTotal = 0;
  int _slotCount = 0;
  int _capacity = 20;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
    _loadInventory();
    unawaited(_searchCatalog(''));
    _itemSearch.addListener(_onSearchChanged);
  }

  void _onTabChanged() {
    if (!mounted || _tabs.indexIsChanging) return;
    if (_tabs.index == 1 && _catalog.isEmpty && !_catalogLoading) {
      unawaited(_searchCatalog(_itemSearch.text.trim()));
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _itemSearch.removeListener(_onSearchChanged);
    _tabs.removeListener(_onTabChanged);
    _itemSearch.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_searchCatalog(_itemSearch.text.trim()));
    });
  }

  Future<void> _loadInventory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repo.getPlayerInventory(widget.authId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.error;
      _inventory = result.items;
      _slotCount = result.slotCount;
      _capacity = result.capacity;
    });
  }

  Future<void> _searchCatalog(String query) async {
    setState(() {
      _catalogLoading = true;
      _catalogError = null;
    });
    final result = await _repo.searchItems(query);
    if (!mounted) return;
    setState(() {
      _catalogLoading = false;
      _catalogError = result.error;
      _catalog = result.items;
      _catalogTotal = result.total;
    });
  }

  bool get _inventoryFull => _slotCount >= _capacity;

  String get _reason {
    final String trimmed = widget.reason.trim();
    return trimmed.length >= 3 ? trimmed : 'Staff envanter düzenleme';
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    bool danger = false,
  }) async {
    return await showStaffConfirmDialog(
          context: context,
          title: title,
          message: message,
          confirmLabel: danger ? 'Onayla' : 'Uygula',
          danger: danger,
        ) ==
        true;
  }

  Future<void> _applyDelta(StaffInventoryRow row, int delta) async {
    if (_busy) return;
    if (delta == 0) return;
    if (row.isEquipped && delta < 0) {
      AppMessenger.showError(context, 'Kuşanılmış eşyada azaltma yok — Sil kullanın.');
      return;
    }
    if (delta.abs() >= 50 || (delta < 0 && delta.abs() >= row.quantity)) {
      final bool ok = await _confirmAction(
        title: delta > 0 ? 'Toplu ekleme' : 'Toplu silme',
        message: '${row.name}\nDeğişim: ${delta > 0 ? '+' : ''}$delta',
        danger: delta < 0,
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    final String? err = await _repo.adjustInventory(widget.authId, row.itemId, delta, _reason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
      return;
    }
    _changed = true;
    AppMessenger.showSuccess(context, '${row.name}: ${delta > 0 ? '+' : ''}$delta');
    await _loadInventory();
  }

  Future<void> _removeRow(StaffInventoryRow row, {bool force = false}) async {
    if (_busy) return;
    if (row.isEquipped && !force) {
      final bool ok = await _confirmAction(
        title: 'Kuşanılmış eşyayı sil',
        message: '${row.name} kuşanılmış.\nZorla silinsin mi?',
        danger: true,
      );
      if (!ok) return;
      force = true;
    } else {
      final bool ok = await _confirmAction(
        title: 'Eşyayı sil',
        message: '${row.name} x${row.quantity} tamamen silinecek.',
        danger: true,
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    final String? err = await _repo.removeInventoryRow(
      widget.authId,
      row.rowId,
      _reason,
      forceEquipped: force,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
      return;
    }
    _changed = true;
    AppMessenger.showSuccess(context, '${row.name} silindi');
    await _loadInventory();
  }

  Future<void> _setQuantity(StaffInventoryRow row) async {
    if (_busy || !row.isStackable) return;
    final Map<String, String>? values = await showStaffFormDialog(
      context: context,
      title: 'Miktar ayarla',
      confirmLabel: 'Kaydet',
      fields: <StaffFormFieldSpec>[
        StaffFormFieldSpec(
          key: 'qty',
          label: 'Hedef miktar',
          initial: '${row.quantity}',
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null) return;
    final int qty = int.tryParse(values['qty'] ?? '') ?? -1;
    if (qty < 0) {
      AppMessenger.showError(context, 'Geçersiz miktar.');
      return;
    }
    setState(() => _busy = true);
    final String? err = await _repo.setInventoryQuantity(widget.authId, row.itemId, qty, _reason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
      return;
    }
    _changed = true;
    AppMessenger.showSuccess(context, '${row.name} → $qty');
    await _loadInventory();
  }

  Future<void> _addCatalogItem(StaffItemCatalogEntry item) async {
    if (_busy) return;
    final Map<String, String>? values = await showStaffFormDialog(
      context: context,
      title: 'Eşya ekle',
      confirmLabel: 'Ekle',
      fields: <StaffFormFieldSpec>[
        StaffFormFieldSpec(
          key: 'qty',
          label: item.isStackable ? 'Miktar' : 'Adet (1)',
          initial: '1',
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null) return;
    int qty = int.tryParse(values['qty'] ?? '') ?? 0;
    if (!item.isStackable) qty = 1;
    if (qty < 1) {
      AppMessenger.showError(context, 'Geçersiz miktar.');
      return;
    }
    if (qty >= 20) {
      final bool ok = await _confirmAction(
        title: 'Toplu ekleme',
        message: '${item.name}\n+$qty adet eklenecek.',
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    final String? err = await _repo.adjustInventory(widget.authId, item.id, qty, _reason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
      return;
    }
    _changed = true;
    AppMessenger.showSuccess(context, '${item.name} +$qty');
    await _loadInventory();
  }

  Color _rarityColor(String? rarity) {
    switch (rarity) {
      case 'legendary':
        return SettingsPalette.gold;
      case 'epic':
        return SettingsPalette.fuchsia;
      case 'rare':
        return SettingsPalette.neon;
      case 'uncommon':
        return SettingsPalette.coral;
      default:
        return SettingsPalette.titanium;
    }
  }

  Widget _inventoryRow(StaffInventoryRow row) {
    final Color accent = row.isEquipped ? SettingsPalette.ruby : _rarityColor(row.rarity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SettingsGlassCard(
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(row.name, style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi, fontSize: 13)),
                      Text(
                        '${row.itemType ?? 'item'} · x${row.quantity}'
                        '${row.enhancementLevel > 0 ? ' · +${row.enhancementLevel}' : ''}'
                        '${row.isEquipped ? ' · kuşanılmış' : ''}',
                        style: supportCaptionStyle,
                      ),
                    ],
                  ),
                ),
                if (row.isStackable)
                  IconButton(
                    tooltip: 'Miktar ayarla',
                    onPressed: _busy ? null : () => _setQuantity(row),
                    icon: const Icon(Icons.tune_rounded, color: SettingsPalette.gold, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                if (row.isStackable && !row.isEquipped) ...<Widget>[
                  StaffActionButton(
                    label: '−1',
                    outlined: true,
                    onPressed: _busy ? null : () => _applyDelta(row, -1),
                  ),
                  StaffActionButton(
                    label: '−5',
                    outlined: true,
                    danger: true,
                    onPressed: _busy ? null : () => _applyDelta(row, -5),
                  ),
                ],
                if (row.isStackable && !row.isEquipped)
                  StaffActionButton(
                    label: '+1',
                    outlined: true,
                    accent: SettingsPalette.neon,
                    onPressed: _busy || row.isEquipped ? null : () => _applyDelta(row, 1),
                  ),
                if (row.isStackable && !row.isEquipped)
                  StaffActionButton(
                    label: '+5',
                    outlined: true,
                    accent: SettingsPalette.neon,
                    onPressed: _busy || row.isEquipped ? null : () => _applyDelta(row, 5),
                  ),
                StaffActionButton(
                  label: 'Sil',
                  danger: true,
                  outlined: true,
                  onPressed: _busy ? null : () => _removeRow(row),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _catalogRow(StaffItemCatalogEntry item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SettingsGlassCard(
        accent: _rarityColor(item.rarity),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.name, style: supportBodyStyle.copyWith(fontSize: 13)),
                  Text(
                    '${item.itemType ?? 'item'} · ${item.isStackable ? 'stack' : 'tek'} · max ${item.maxStack}',
                    style: supportCaptionStyle.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            StaffActionButton(
              label: 'Ekle',
              outlined: true,
              accent: SettingsPalette.neon,
              onPressed: _busy ? null : () => _addCatalogItem(item),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double panelWidth = MediaQuery.sizeOf(context).width - 56;
    return SizedBox(
      width: panelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: <Color>[
                      SettingsPalette.neon.withValues(alpha: 0.35),
                      SettingsPalette.obsidian,
                    ],
                  ),
                  border: Border.all(color: SettingsPalette.neon.withValues(alpha: 0.45)),
                ),
                child: const Icon(Icons.inventory_2_rounded, size: 18, color: SettingsPalette.neon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'ENVANTER DÜZENLE',
                      style: AppTextStyles.captionBold.copyWith(
                        color: SettingsPalette.textHi,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '@${widget.username} · $_slotCount/$_capacity slot',
                      style: supportCaptionStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_inventoryFull) ...<Widget>[
            const SizedBox(height: 8),
            SettingsGlassCard(
              accent: SettingsPalette.ruby,
              child: Text(
                'Envanter dolu ($_slotCount/$_capacity). Yeni slot gerektiren eşya eklenemez.',
                style: supportBodyStyle.copyWith(color: SettingsPalette.textHi, fontSize: 12),
              ),
            ),
          ] else if (_slotCount >= _capacity - 2) ...<Widget>[
            const SizedBox(height: 8),
            SettingsGlassCard(
              accent: SettingsPalette.gold,
              child: Text(
                'Envanter neredeyse dolu ($_slotCount/$_capacity).',
                style: supportCaptionStyle.copyWith(color: SettingsPalette.textHi),
              ),
            ),
          ],
        const SizedBox(height: 8),
        TabBar(
          controller: _tabs,
          labelColor: SettingsPalette.neon,
          unselectedLabelColor: SettingsPalette.textMid,
          indicatorColor: SettingsPalette.neon,
          tabs: const <Widget>[
            Tab(text: 'Oyuncu envanteri'),
            Tab(text: 'Eşya ekle'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.52,
          child: TabBarView(
            controller: _tabs,
            children: <Widget>[
              _loading
                  ? const Center(child: CircularProgressIndicator(color: SettingsPalette.neon, strokeWidth: 2))
                  : _error != null && _inventory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(_error!, style: supportBodyStyle.copyWith(color: SettingsPalette.ruby)),
                              const SizedBox(height: 10),
                              StaffActionButton(label: 'Yenile', outlined: true, onPressed: _loadInventory),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: SettingsPalette.neon,
                          onRefresh: _loadInventory,
                          child: _inventory.isEmpty
                              ? ListView(
                                  children: const <Widget>[
                                    StaffEmptyState(icon: Icons.inbox_outlined, message: 'Envanter boş.'),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(top: 4),
                                  itemCount: _inventory.length,
                                  itemBuilder: (BuildContext context, int i) => _inventoryRow(_inventory[i]),
                                ),
                        ),
              Column(
                children: <Widget>[
                  TextField(
                    controller: _itemSearch,
                    style: supportBodyStyle,
                    decoration: supportInputDecoration(
                      label: 'Eşya ara',
                      hint: 'isim veya id (boş = tüm eşyalar)',
                    ),
                    onSubmitted: (_) => _searchCatalog(_itemSearch.text.trim()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _catalog.isEmpty
                              ? ''
                              : _catalogTotal > _catalog.length
                                  ? '${_catalog.length}/$_catalogTotal eşya (limit)'
                                  : '${_catalog.length} eşya',
                          style: supportCaptionStyle,
                        ),
                      ),
                      StaffActionButton(
                        label: 'Yenile',
                        outlined: true,
                        onPressed: _catalogLoading ? null : () => _searchCatalog(_itemSearch.text.trim()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _catalogLoading
                        ? const Center(child: CircularProgressIndicator(color: SettingsPalette.neon, strokeWidth: 2))
                        : _catalogError != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(_catalogError!, style: supportBodyStyle.copyWith(color: SettingsPalette.ruby)),
                                    const SizedBox(height: 10),
                                    StaffActionButton(
                                      label: 'Tekrar dene',
                                      outlined: true,
                                      onPressed: () => _searchCatalog(_itemSearch.text.trim()),
                                    ),
                                  ],
                                ),
                              )
                            : _catalog.isEmpty
                                ? Center(
                                    child: Text(
                                      _itemSearch.text.trim().isEmpty
                                          ? 'Katalog yüklenemedi veya yetki yok'
                                          : 'Eşya bulunamadı',
                                      style: supportBodyStyle.copyWith(color: SettingsPalette.textMid),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _catalog.length,
                                    itemBuilder: (BuildContext context, int i) => _catalogRow(_catalog[i]),
                                  ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(color: SettingsPalette.neon, minHeight: 2),
          ),
        const SizedBox(height: 10),
        StaffActionButton(
          label: 'Kapat',
          outlined: true,
          onPressed: () => Navigator.pop(context, _changed),
        ),
        ],
      ),
    );
  }
}
