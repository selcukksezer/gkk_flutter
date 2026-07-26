import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/gkk_tab_bar.dart';
import '../../components/common/gkk_tab_page_shell.dart';
import '../../components/common/universal_game_dialog.dart';
import '../../components/common/item_icon_view.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/constants/economy_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/potion_energy.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../components/kingdom/kingdom_market_blessing_banner.dart';
import '../../models/kingdom_market_blessing_model.dart';
import '../../providers/kingdom_market_blessing_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import 'widgets/battle_pass_shop_tab.dart';
import 'widgets/night_market_tab.dart';

// ---------------------------------------------------------------------------
// Data helpers
// ---------------------------------------------------------------------------

class _GemPackage {
  const _GemPackage({
    required this.id,
    required this.gems,
    required this.priceTry,
    required this.priceUsd,
    this.label,
    this.bonusPercent,
    this.isBestValue = false,
  });
  final String id;
  final int gems;
  final String priceTry;
  final String priceUsd;
  final String? label;
  final int? bonusPercent;
  final bool isBestValue;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, this.initialTabIndex});

  final int? initialTabIndex;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 5;

  late TabController _tabController;

  List<Map<String, dynamic>> _shopItems = [];
  bool _shopDataLoading = true;
  bool _purchaseLoading = false;
  String _itemSearchQuery = '';
  Map<String, dynamic>? _quantityDialogItem;
  int _quantityInput = 1;
  String? _buyingId;
  String? _buyingGemId;
  String? _buyingGoldKey;

  static List<_GemPackage> get _gemPackages => EconomyConstants.gemIapPackages
      .map(
        (GemIapPackage pkg) => _GemPackage(
          id: pkg.id,
          gems: pkg.gems,
          priceTry: pkg.priceTry,
          priceUsd: pkg.priceUsd,
          label: pkg.label,
          bonusPercent: pkg.bonusPercent,
          isBestValue: pkg.isBestValue,
        ),
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final int initial = widget.initialTabIndex ?? 0;
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: initial.clamp(0, _tabCount - 1),
    );
    _loadShopData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kingdomMarketBlessingProvider.notifier).load();
    });
  }

  void _ensureTabControllerIntegrity() {
    if (_tabController.length == _tabCount) return;

    final int oldIndex = _tabController.index;
    final int safeIndex;
    if (_tabCount == 0) {
      safeIndex = 0;
    } else if (oldIndex < 0) {
      safeIndex = 0;
    } else if (oldIndex >= _tabCount) {
      safeIndex = _tabCount - 1;
    } else {
      safeIndex = oldIndex;
    }

    _tabController.dispose();
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: safeIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Widget _buildItemIcon(Map<String, dynamic> item) {
    final String icon = (item['icon']?.toString() ?? '').trim();
    return ItemIconView(
      iconValue: icon,
      itemId: item['item_id']?.toString(),
      size: 64,
      expand: true,
      fallback: '🎁',
    );
  }

  List<Map<String, dynamic>> _mapItemsForShop(
    List<dynamic> rows, {
    bool hasShopCurrency = true,
  }) {
    return rows.whereType<Map>().map((Map raw) {
      final Map<String, dynamic> row = Map<String, dynamic>.from(raw);
      final int unitPrice = _toInt(row['base_price'], fallback: _toInt(row['vendor_sell_price']));

      return <String, dynamic>{
        'id': row['id']?.toString() ?? '',
        'item_id': row['id']?.toString() ?? '',
        'name': row['name']?.toString() ?? 'İsimsiz',
        'description': row['description']?.toString() ?? '',
        'icon': row['icon']?.toString() ?? '📦',
        'rarity': row['rarity']?.toString() ?? 'common',
        'item_type': row['type']?.toString(),
        'potion_type': row['potion_type']?.toString(),
        'energy_restore': _toInt(row['energy_restore']),
        'is_stackable': row['is_stackable'] == true,
        'max_stack': _toInt(row['max_stack'], fallback: 1),
        'price': unitPrice,
        'currency': hasShopCurrency && row['shop_currency']?.toString() == 'gems' ? 'gems' : 'gold',
      };
    }).where((Map<String, dynamic> item) => (item['id'] as String).isNotEmpty).toList(growable: false);
  }

  Future<void> _loadShopData() async {
    setState(() => _shopDataLoading = true);
    List<Map<String, dynamic>> mappedShopItems = <Map<String, dynamic>>[];
    String? itemsLoadError;

    // `items` yüklemesini bağımsız tutuyoruz: diğer tablolar patlasa bile Eşya sekmesi dolmalı.
    try {
      final filteredItemsRes = await SupabaseService.client
          .from('items')
          .select(
            'id,name,description,icon,rarity,type,potion_type,energy_restore,is_stackable,max_stack,base_price,vendor_sell_price,shop_available,shop_currency',
          )
          .eq('shop_available', true)
          .order('id', ascending: true);

      mappedShopItems = _mapItemsForShop(filteredItemsRes, hasShopCurrency: true);
    } catch (e) {
      itemsLoadError = e.toString();
    }

    if (mappedShopItems.isEmpty) {
      try {
        final legacyItemsRes = await SupabaseService.client
            .from('items')
            .select(
              'id,name,description,icon,rarity,type,potion_type,energy_restore,is_stackable,max_stack,base_price,vendor_sell_price',
            )
            .order('id', ascending: true);

        mappedShopItems = _mapItemsForShop(legacyItemsRes, hasShopCurrency: false);
      } catch (e) {
        itemsLoadError = itemsLoadError == null ? e.toString() : '$itemsLoadError | $e';
      }
    }

    if (!mounted) return;

    setState(() {
      _shopItems = mappedShopItems;
      _shopDataLoading = false;
    });

    if (mappedShopItems.isEmpty && itemsLoadError != null) {
      AppMessenger.show(
        context,
        'Eşya listesi alınamadı.',
        type: AppMessageType.warning,
      );
    }
    await TutorialTriggers.onRouteEnter(ref, AppRoutes.shop);
  }

  Future<void> _buyShopItem(Map<String, dynamic> item, int qty) async {
    if (_buyingId != null || _purchaseLoading) return;

    final id = item['id']?.toString() ?? '';
    final itemId = item['item_id']?.toString() ?? id;
    final String currency = item['currency']?.toString() ?? 'gold';
    final int baseUnitPrice = ((item['price'] as num?) ?? 0).toInt();
    final KingdomMarketBlessingStatus blessing = ref.read(kingdomMarketBlessingProvider);
    final int unitPrice = blessing.applyDiscount(baseUnitPrice, currency);
    final int totalPrice = unitPrice * qty;

    setState(() => _buyingId = id);

    await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
    final addCheck = ref.read(inventoryProvider.notifier).canAddItem(itemId: itemId, quantity: qty);
    if (!addCheck.canAdd) {
      if (mounted) {
        AppMessenger.showError(
          context,
          addCheck.reason ?? 'Envanter dolu!',
        );
      }
      setState(() => _buyingId = null);
      return;
    }

    final profile = ref.read(playerProvider).profile;
    final num wallet =
        currency == 'gems' ? (profile?.gems ?? 0) : (profile?.gold ?? 0);
    if (wallet < totalPrice) {
      if (mounted) {
        AppMessenger.showError(
          context,
          'Yetersiz ${currency == 'gems' ? 'elmas' : 'altın'}!',
        );
        setState(() => _buyingId = null);
      }
      return;
    }

    try {
      final dynamic res = await SupabaseService.client.rpc(
        'buy_shop_item',
        params: <String, dynamic>{
          'p_item_id': itemId,
          'p_currency': currency,
          'p_price': unitPrice,
          // Overload çakışmasını engellemek için quantity her zaman gönderilir.
          'p_quantity': qty,
        },
      );

      final bool ok = res is Map && res['success'] == true;
      if (!ok) {
        final String serverError =
            res is Map ? (res['error']?.toString() ?? '') : '';
        if (mounted) {
          AppMessenger.showError(
            context,
            switch (serverError) {
              'Insufficient gold' => 'Yetersiz altın!',
              'Insufficient gems' => 'Yetersiz elmas!',
              'Inventory full' => 'Envanter dolu!',
              _ => 'Satın alma başarısız.',
            },
          );
        }
        return;
      }

      if (mounted) {
        await ref.read(playerProvider.notifier).loadProfile();
        await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(context, 'Satın alma başarısız.');
      }
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  void _handleBuyClick(Map<String, dynamic> item) {
    final isStackable = (item['is_stackable'] as bool?) ?? false;
    if (isStackable) {
      setState(() { _quantityDialogItem = item; _quantityInput = 1; });
    } else {
      _confirmAndBuyItem(item);
    }
  }

  Future<void> _confirmAndBuyItem(Map<String, dynamic> item) async {
    final name = item['name']?.toString() ?? 'Eşya';
    final currency = item['currency']?.toString() ?? 'gold';
    final price = item['price'] ?? 0;
    final isGem = currency == 'gems';
    final confirmed = await UniversalGameDialog.show(
      context,
      title: name,
      message:
          '$name satin almak istedigine emin misin?\nFiyat: $price ${isGem ? 'gem' : 'altin'}',
      confirmLabel: 'Satin Al',
      cancelLabel: 'Iptal',
    );
    if (confirmed != true) return;
    _buyShopItem(item, 1);
  }

  Future<void> _buyGemPackage(_GemPackage pkg) async {
    if (_purchaseLoading) return;
    // IAP / StoreKit not wired — never mint gems from client.
    AppMessenger.show(
      context,
      'Elmas satın alma yakında (IAP). Şimdilik kullanılamıyor.',
    );
  }

  static String _fmtGold(int gold) {
    if (gold >= 1000000) {
      final double m = gold / 1000000;
      return m == m.roundToDouble() ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    }
    if (gold >= 1000) return '${(gold / 1000).toStringAsFixed(0)}K';
    return '$gold';
  }

  static String _fmtGoldFull(int gold) {
    final String s = gold.toString();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<void> _buyGoldWithGems(int goldAmount, {required String purchaseKey}) async {
    if (_buyingGoldKey != null || _purchaseLoading) return;

    final int gemsNeeded = EconomyConstants.gemsRequiredForGold(goldAmount);
    final profile = ref.read(playerProvider).profile;
    if ((profile?.gems ?? 0) < gemsNeeded) {
      if (!mounted) return;
      AppMessenger.showError(context, 'Yetersiz elmas!');
      return;
    }

    if (!mounted) return;
    final bool? confirmed = await UniversalGameDialog.show(
      context,
      title: 'Altın Al',
      message:
          '${_fmtGoldFull(goldAmount)} altın almak istediğine emin misin?\n'
          'Maliyet: $gemsNeeded 💎',
      confirmLabel: 'Satın Al',
      cancelLabel: 'İptal',
    );
    if (confirmed != true) return;

    setState(() => _buyingGoldKey = purchaseKey);

    try {
      final dynamic res = await SupabaseService.client.rpc(
        'buy_gold_with_gems',
        params: <String, dynamic>{'p_gold_amount': goldAmount},
      );

      final bool ok = res is Map && res['success'] == true;
      if (!ok) {
        if (!mounted) return;
        final String serverError =
            res is Map ? (res['error']?.toString() ?? '') : '';
        AppMessenger.showError(
          context,
          switch (serverError) {
            'Insufficient gems' => 'Yetersiz elmas!',
            'Invalid amount' => 'Geçersiz altın miktarı.',
            _ => 'Altın satın alma başarısız.',
          },
        );
        return;
      }

      if (mounted) {
        await ref.read(playerProvider.notifier).loadProfile();
        if (!mounted) return;
        AppMessenger.show(
          context,
          '+${_fmtGoldFull(goldAmount)} altın eklendi!',
          type: AppMessageType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Altın satın alma başarısız.');
      }
    } finally {
      if (mounted) setState(() => _buyingGoldKey = null);
    }
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    _ensureTabControllerIntegrity();

    final profile = ref.watch(playerProvider).profile;
    final int gems = (profile?.gems ?? 0).toInt();

    return Stack(
      children: [
        Scaffold(
      appBar: GameTopBar(title: context.l10n.routeShop, onLogout: _doLogout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.shop, onLogout: _doLogout),
      body: GameScreenBackground(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: KingdomMarketBlessingBanner(locationLabel: 'Mağaza'),
            ),
            GkkTabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: GkkTabBar.textTabs(const <String>[
                '💎 Gem',
                '🪙 Altın',
                '🌙 Gece Pazarı',
                '⚔️ Pass',
                '🛍️ Eşya',
              ]),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  GkkTabPageShell(
                    tabIndex: 0,
                    sectionTitle: 'Elmas Paketleri',
                    child: _GemPackagesTab(
                      packages: _gemPackages,
                      purchaseLoading: _purchaseLoading,
                      buyingGemId: _buyingGemId,
                      onBuyGem: _buyGemPackage,
                    ),
                  ),
                  GkkTabPageShell(
                    tabIndex: 1,
                    sectionTitle: 'Altın Paketleri',
                    child: _GoldPurchaseTab(
                      buyingGoldKey: _buyingGoldKey,
                      onBuyGold: _buyGoldWithGems,
                      fmtGold: _fmtGold,
                    ),
                  ),
                  GkkTabPageShell(
                    tabIndex: 2,
                    sectionTitle: 'Gece Pazarı',
                    sectionAccent: AppColors.cyberFuchsia,
                    child: TutorialAnchorScope(
                      id: TutorialAnchorId.shopNightTab,
                      child: NightMarketTab(
                        onPurchased: () async {
                          await TutorialTriggers.onAnchorTap(
                            ref,
                            TutorialAnchorId.shopNightTab,
                          );
                          await ref.read(playerProvider.notifier).loadProfile();
                          await ref
                              .read(inventoryProvider.notifier)
                              .loadInventory(silent: true);
                        },
                      ),
                    ),
                  ),
                  GkkTabPageShell(
                    tabIndex: 3,
                    sectionTitle: 'Savaş Pass',
                    sectionAccent: AppColors.coralFlare,
                    child: BattlePassShopTab(playerGems: gems),
                  ),
                  GkkTabPageShell(
                    tabIndex: 4,
                    sectionTitle: 'Mağaza Eşyaları',
                    child: _ItemsTab(
                      items: _shopItems,
                      loading: _shopDataLoading,
                      searchQuery: _itemSearchQuery,
                      buyingId: _buyingId,
                      playerTolerance:
                          ref.watch(playerProvider).profile?.tolerance ?? 0,
                      onSearchChanged: (q) => setState(() => _itemSearchQuery = q),
                      onBuyTap: _handleBuyClick,
                      rarityColor: (String? rarity) =>
                          AppColors.forRarity(rarity ?? ''),
                      buildItemIcon: _buildItemIcon,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
        ),
        // Quantity dialog overlay
        if (_quantityDialogItem != null)
          GestureDetector(
            onTap: () => setState(() => _quantityDialogItem = null),
            child: Container(
              color: Colors.black87,
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2030),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFBBF24)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_quantityDialogItem!['name']?.toString() ?? 'Eşya', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24))),
                          const SizedBox(height: 4),
                          Text(
                            'Birim: ${_quantityDialogItem!['currency'] == 'gems' ? '💎' : '🪙'} ${_quantityDialogItem!['price'] ?? 0}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: () => setState(() => _quantityInput = (_quantityInput - 1).clamp(1, 99)),
                                icon: const Icon(Icons.remove, color: Color(0xFFFBBF24)),
                              ),
                              SizedBox(
                                width: 60,
                                child: TextField(
                                  controller: TextEditingController(text: '$_quantityInput')..selection = TextSelection.collapsed(offset: '$_quantityInput'.length),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFFBBF24)),
                                  decoration: const InputDecoration(border: InputBorder.none),
                                  onChanged: (v) => setState(() => _quantityInput = (int.tryParse(v) ?? 1).clamp(1, 99)),
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(() => _quantityInput = (_quantityInput + 1).clamp(1, 99)),
                                icon: const Icon(Icons.add, color: Color(0xFFFBBF24)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final item = _quantityDialogItem!;
                                    final qty = _quantityInput;
                                    setState(() => _quantityDialogItem = null);
                                    _buyShopItem(item, qty);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: Colors.black),
                                  child: const Text('✓ Satın Al', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => setState(() => _quantityDialogItem = null),
                                  child: Text(context.l10n.commonCancel),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab content widgets
// ---------------------------------------------------------------------------

EdgeInsets _shopScrollPadding(BuildContext context) =>
    GameScrollLayout.fromLTRB(
      context,
      left: 14,
      top: 4,
      right: 14,
      bottomExtra: 48,
    );

class _GemPackagesTab extends StatelessWidget {
  const _GemPackagesTab({
    required this.packages,
    required this.purchaseLoading,
    required this.buyingGemId,
    required this.onBuyGem,
  });
  final List<_GemPackage> packages;
  final bool purchaseLoading;
  final String? buyingGemId;
  final void Function(_GemPackage pkg) onBuyGem;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: _shopScrollPadding(context),
      children: <Widget>[
        GameFixedGrid(
          crossAxisCount: 2,
          spacing: 12,
          itemCount: packages.length,
          itemBuilder: (BuildContext context, int index) {
            return GkkTabStaggerItem(
              index: index,
              child: _GemPackageCard(
                pkg: packages[index],
                purchaseLoading: purchaseLoading,
                buyingGemId: buyingGemId,
                onBuy: () => onBuyGem(packages[index]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _GemPackageCard extends StatelessWidget {
  const _GemPackageCard({
    required this.pkg,
    required this.purchaseLoading,
    required this.buyingGemId,
    required this.onBuy,
  });

  final _GemPackage pkg;
  final bool purchaseLoading;
  final String? buyingGemId;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final bool isBest = pkg.isBestValue;
    final bool isBuying = buyingGemId == pkg.id;
    final int? bonus = pkg.bonusPercent;
    final String tierLabel = pkg.label ?? '💎 Elmas';

    return DottedPanel(
      borderColor: isBest
          ? AppColors.liquidGold.withValues(alpha: 0.5)
          : AppColors.liquidGold.withValues(alpha: 0.16),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          if (isBest)
            Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: AppColors.liquidGoldGradient,
                    border: Border.all(
                      color: AppColors.liquidGold.withValues(alpha: 0.65),
                    ),
                  ),
                  child: const Text(
                    'En İyi Değer',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.carbonVoid,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          if (!isBest && bonus != null && bonus > 0)
            Positioned(
              top: -8,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.accentCyan.withValues(alpha: 0.18),
                  border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  '+$bonus% Bonus',
                  style: const TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentCyan,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (isBest) const SizedBox(height: 4),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        AppColors.accentCyan.withValues(alpha: 0.28),
                        AppColors.accentCyan.withValues(alpha: 0.04),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Icon(
                    Icons.diamond_rounded,
                    color: AppColors.accentCyan,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    '${pkg.gems}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  tierLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.mutedTitanium,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isBest && bonus != null && bonus > 0) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '+$bonus% Bonus',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.accentCyan.withValues(alpha: 0.85),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    pkg.priceTry,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.liquidGold,
                    ),
                  ),
                ),
                Text(
                  pkg.priceUsd,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedTitanium.withValues(alpha: 0.75),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: _ShopScaleButton(
                    label: 'Satın Al',
                    accent: AppColors.accentCyan,
                    loading: isBuying,
                    enabled: !purchaseLoading && !isBuying,
                    onTap: onBuy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldPurchaseTab extends StatelessWidget {
  const _GoldPurchaseTab({
    required this.buyingGoldKey,
    required this.onBuyGold,
    required this.fmtGold,
  });

  final String? buyingGoldKey;
  final Future<void> Function(int goldAmount, {required String purchaseKey}) onBuyGold;
  final String Function(int gold) fmtGold;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: _shopScrollPadding(context),
      children: <Widget>[
        GameFixedGrid(
          crossAxisCount: 2,
          spacing: 12,
          itemCount: EconomyConstants.goldShopPackages.length,
          itemBuilder: (BuildContext context, int index) {
            final GoldShopPackage pkg = EconomyConstants.goldShopPackages[index];
            final bool isBuying = buyingGoldKey == pkg.id;
            final bool disabled = isBuying || buyingGoldKey != null;

            return GkkTabStaggerItem(
              index: index,
              child: _GoldPackageCard(
                pkg: pkg,
                fmtGold: fmtGold,
                isBuying: isBuying,
                disabled: disabled,
                onBuy: () => onBuyGold(pkg.gold, purchaseKey: pkg.id),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Kur: ${EconomyConstants.shopGoldPerGem} altın = 1 💎',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.mutedTitanium.withValues(alpha: 0.65),
            fontSize: 10,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _GoldPackageCard extends StatelessWidget {
  const _GoldPackageCard({
    required this.pkg,
    required this.fmtGold,
    required this.isBuying,
    required this.disabled,
    required this.onBuy,
  });

  final GoldShopPackage pkg;
  final String Function(int gold) fmtGold;
  final bool isBuying;
  final bool disabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      borderColor: pkg.isBestValue
          ? AppColors.liquidGold.withValues(alpha: 0.5)
          : AppColors.liquidGold.withValues(alpha: 0.16),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          if (pkg.isBestValue)
            Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: AppColors.liquidGoldGradient,
                    border: Border.all(
                      color: AppColors.liquidGold.withValues(alpha: 0.65),
                    ),
                  ),
                  child: const Text(
                    'En İyi Değer',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.carbonVoid,
                    ),
                  ),
                ),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (pkg.isBestValue) const SizedBox(height: 8),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.liquidGold.withValues(alpha: 0.28),
                      AppColors.liquidGold.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(Icons.paid_rounded, color: AppColors.liquidGold, size: 28),
              ),
              const SizedBox(height: 6),
              Text(
                fmtGold(pkg.gold),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                '🪙 Altın',
                style: TextStyle(color: AppColors.mutedTitanium, fontSize: 10),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.diamond_rounded, size: 13, color: AppColors.accentCyan),
                  const SizedBox(width: 4),
                  Text(
                    '${pkg.gems}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ShopScaleButton(
                label: 'Satın Al',
                loading: isBuying,
                enabled: !disabled,
                onTap: onBuy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopScaleButton extends StatefulWidget {
  const _ShopScaleButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
    this.accent,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;
  final Color? accent;

  @override
  State<_ShopScaleButton> createState() => _ShopScaleButtonState();
}

class _ShopScaleButtonState extends State<_ShopScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && !widget.loading;
    final Color accent = widget.accent ?? AppColors.liquidGold;
    final bool useGoldGradient = widget.accent == null;

    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed && active ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: active && useGoldGradient ? AppColors.liquidGoldGradient : null,
            color: active
                ? (useGoldGradient ? null : accent.withValues(alpha: 0.88))
                : AppColors.darkObsidian.withValues(alpha: 0.55),
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: widget.loading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: useGoldGradient ? AppColors.carbonVoid : Colors.white,
                  ),
                )
              : Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? (useGoldGradient ? AppColors.carbonVoid : Colors.white)
                        : AppColors.mutedTitanium,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Items tab ──────────────────────────────────────────────────────────────

class _ItemsTab extends ConsumerWidget {
  const _ItemsTab({
    required this.items,
    required this.loading,
    required this.searchQuery,
    required this.buyingId,
    required this.playerTolerance,
    required this.onSearchChanged,
    required this.onBuyTap,
    required this.rarityColor,
    required this.buildItemIcon,
  });

  final List<Map<String, dynamic>> items;
  final bool loading;
  final String searchQuery;
  final String? buyingId;
  final int playerTolerance;
  final ValueChanged<String> onSearchChanged;
  final void Function(Map<String, dynamic>) onBuyTap;
  final Color Function(String?) rarityColor;
  final Widget Function(Map<String, dynamic>) buildItemIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final KingdomMarketBlessingStatus blessing = ref.watch(kingdomMarketBlessingProvider);

    final q = searchQuery.trim().toLowerCase();
    final filtered = q.isEmpty ? items : items.where((it) => (it['name']?.toString() ?? '').toLowerCase().contains(q)).toList();
    final int energyPotionIndex = filtered.indexWhere(
      (Map<String, dynamic> it) =>
          shopEnergyPotionSubtitle(it, playerTolerance) != null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: DottedPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderColor: AppColors.liquidGold.withValues(alpha: 0.16),
            child: Row(
              children: <Widget>[
                const Icon(Icons.search, color: AppColors.mutedTitanium, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: onSearchChanged,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: context.l10n.e_ya_ara,
                      hintStyle: TextStyle(
                        color: AppColors.mutedTitanium.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => onSearchChanged(''),
                    child: Icon(
                      Icons.close,
                      color: AppColors.mutedTitanium.withValues(alpha: 0.75),
                      size: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Text(
            '${filtered.length} eşya${q.isNotEmpty ? ' · "$searchQuery"' : ''}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedTitanium.withValues(alpha: 0.75),
              fontSize: 10,
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: _shopScrollPadding(context),
                    child: DottedPanel(
                      borderColor: AppColors.liquidGold.withValues(alpha: 0.2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 48,
                            color: AppColors.mutedTitanium.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            q.isNotEmpty
                                ? '"$searchQuery" için eşya bulunamadı'
                                : 'Mağazada henüz eşya yok',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.mutedTitanium,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: _shopScrollPadding(context),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    final id = item['id']?.toString() ?? '';
                    final isBuying = buyingId == id;
                    final rarity = item['rarity']?.toString();
                    final rc = rarityColor(rarity);
                    final currency = item['currency']?.toString() ?? 'gold';
                    final int basePrice = ((item['price'] as num?) ?? 0).toInt();
                    final int price = blessing.applyDiscount(basePrice, currency);
                    final bool hasKingDiscount = blessing.hasDiscountForCurrency(currency) && price < basePrice;
                    final isGem = currency == 'gems';
                    final String? energySubtitle =
                        shopEnergyPotionSubtitle(item, playerTolerance);

                    Widget cell = GestureDetector(
                      onTap: isBuying ? null : () => onBuyTap(item),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF121A2A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: rc.withValues(alpha: 0.65), width: 1.2),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: rc.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 18, 8, 34),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.black.withValues(alpha: 0.16),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: buildItemIcon(item),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              left: 8,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.36),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item['name']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: rc,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 22,
                              left: 6,
                              right: 6,
                              child: energySubtitle == null
                                  ? const SizedBox.shrink()
                                  : Text(
                                      energySubtitle,
                                      style: TextStyle(
                                        color: Colors.amber.shade200
                                            .withValues(alpha: 0.9),
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.1,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                            Positioned(
                              left: 8,
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isGem ? Colors.blue : Colors.amber).withValues(alpha: 0.17),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: (isGem ? Colors.blue : Colors.amber).withValues(alpha: 0.28)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(isGem ? '💎' : '🪙', style: const TextStyle(fontSize: 9)),
                                    const SizedBox(width: 2),
                                    if (hasKingDiscount) ...<Widget>[
                                      Text(
                                        '$basePrice',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          decoration: TextDecoration.lineThrough,
                                          color: AppColors.mutedTitanium.withValues(alpha: 0.75),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(
                                      isBuying ? '...' : '$price',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: hasKingDiscount
                                            ? AppColors.liquidGold
                                            : (isGem ? const Color(0xFF7DD3FC) : const Color(0xFFFDE68A)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (i == energyPotionIndex) {
                      cell = TutorialAnchorScope(
                        id: TutorialAnchorId.shopPotionRow,
                        child: cell,
                      );
                    }
                    return GkkTabStaggerItem(index: i, child: cell);
                  },
                ),
        ),
      ],
    );
  }
}
