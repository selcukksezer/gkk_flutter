import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'widgets/merchant_vendor_header.dart';
import 'widgets/night_market_tab.dart';
import 'widgets/shop_quantity_dialog.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';

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
    final String currency = item['currency']?.toString() ?? 'gold';
    final int baseUnitPrice = ((item['price'] as num?) ?? 0).toInt();
    final KingdomMarketBlessingStatus blessing = ref.read(kingdomMarketBlessingProvider);
    final int unitPrice = blessing.applyDiscount(baseUnitPrice, currency);
    final profile = ref.read(playerProvider).profile;
    final int wallet = currency == 'gems'
        ? (profile?.gems ?? 0).toInt()
        : (profile?.gold ?? 0).toInt();
    final bool isStackable = (item['is_stackable'] as bool?) ?? false;
    final int maxStack = (item['max_stack'] as num?)?.toInt() ?? 99;

    ShopQuantityDialog.show(
      context,
      mode: ShopDialogMode.buy,
      item: item,
      unitPrice: unitPrice,
      baseUnitPrice: baseUnitPrice,
      currency: currency,
      walletBalance: wallet,
      hasBlessingDiscount: blessing.hasDiscountForCurrency(currency) && unitPrice < baseUnitPrice,
      blessingDiscountPct: blessing.discountPctForCurrency(currency),
      maxQuantityAvailable: isStackable ? maxStack : 1,
      onConfirm: (int quantity) async {
        await _buyShopItem(item, quantity);
      },
    );
  }

  Future<void> _sellShopItem(InventoryItem item, int qty) async {
    if (_purchaseLoading) return;
    setState(() => _purchaseLoading = true);
    try {
      final result = await ref.read(inventoryProvider.notifier).sellItemByRow(
        rowId: item.rowId,
        quantity: qty,
      );
      if (!mounted) return;
      if (result.success) {
        AppMessenger.show(
          context,
          '+${_fmtGoldFull(result.goldEarned)} altın kazanıldı!',
          type: AppMessageType.success,
        );
      } else {
        AppMessenger.showError(
          context,
          result.error ?? 'Satış işlemi başarısız.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Satış işlemi başarısız.');
      }
    } finally {
      if (mounted) setState(() => _purchaseLoading = false);
    }
  }

  void _handleSellClick(InventoryItem item) {
    final int unitPrice = item.vendorSellPrice > 0
        ? item.vendorSellPrice
        : (item.basePrice * 0.5).round();
    final profile = ref.read(playerProvider).profile;
    final int wallet = (profile?.gold ?? 0).toInt();

    ShopQuantityDialog.show(
      context,
      mode: ShopDialogMode.sell,
      item: <String, dynamic>{
        'id': item.itemId,
        'item_id': item.itemId,
        'name': item.name,
        'description': item.description,
        'icon': item.icon,
        'rarity': item.rarity.name,
        'is_stackable': item.isStackable,
        'max_stack': item.maxStack,
      },
      unitPrice: unitPrice,
      currency: 'gold',
      walletBalance: wallet,
      maxQuantityAvailable: item.quantity,
      isFavorite: item.isFavorite,
      onConfirm: (int quantity) async {
        await _sellShopItem(item, quantity);
      },
    );
  }

  Future<void> _buyGemPackage(_GemPackage pkg) async {
    if (_purchaseLoading) return;
    // IAP / StoreKit not wired — never mint gems from client.
    // Release: stub catalog hidden; this path is debug/profile only.
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

    return Scaffold(
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
              tabAnchorIds: const <String?>[
                null,
                null,
                TutorialAnchorId.shopNightTabBar,
                null,
                null,
              ],
              onTabTutorialTap: (_, String anchorId) {
                unawaited(TutorialTriggers.onAnchorTap(ref, anchorId));
              },
              tabs: GkkTabBar.textTabs(const <String>[
                '💎 Gem',
                '🪙 Altın',
                '🌙 Gece Pazarı',
                '⚔️ Pass',
                '🛍️ Tüccar',
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
                    child: NightMarketTab(
                      onPurchased: () async {
                        await TutorialTriggers.onAnchorTap(
                          ref,
                          TutorialAnchorId.shopNightOffer,
                        );
                        await ref.read(playerProvider.notifier).loadProfile();
                        await ref
                            .read(inventoryProvider.notifier)
                            .loadInventory(silent: true);
                      },
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
                    sectionTitle: 'Tüccar Pazarı',
                    child: _MerchantGoodsTab(
                      items: _shopItems,
                      loading: _shopDataLoading,
                      searchQuery: _itemSearchQuery,
                      buyingId: _buyingId,
                      playerTolerance:
                          ref.watch(playerProvider).profile?.tolerance ?? 0,
                      onSearchChanged: (q) => setState(() => _itemSearchQuery = q),
                      onBuyTap: _handleBuyClick,
                      onSellTap: _handleSellClick,
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
    // Release: hide stub IAP prices / buy CTAs (no StoreKit / Play Billing).
    if (kReleaseMode) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: _shopScrollPadding(context),
        children: <Widget>[
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xFF141D2E).withValues(alpha: 0.88),
                    const Color(0xFF0B101C).withValues(alpha: 0.94),
                  ],
                ),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.25),
                  width: 1.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.diamond_outlined,
                    size: 44,
                    color: AppColors.accentCyan.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Elmas Satın Alma Yakında',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mağaza IAP bağlantısı hazırlanıyor. Şimdilik elmas paketleri kullanılamıyor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.mutedTitanium,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            isBest
                ? const Color(0xFF18243C).withValues(alpha: 0.92)
                : const Color(0xFF131C2D).withValues(alpha: 0.88),
            isBest
                ? const Color(0xFF0E1626).withValues(alpha: 0.96)
                : const Color(0xFF0B101C).withValues(alpha: 0.94),
          ],
        ),
        border: Border.all(
          color: isBest
              ? AppColors.liquidGold.withValues(alpha: 0.65)
              : AppColors.accentCyan.withValues(alpha: 0.28),
          width: isBest ? 1.4 : 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isBest
                ? AppColors.liquidGold.withValues(alpha: 0.18)
                : AppColors.accentCyan.withValues(alpha: 0.08),
            blurRadius: isBest ? 16 : 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
                      color: AppColors.liquidGold.withValues(alpha: 0.75),
                      width: 1.1,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.liquidGold.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
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
                  color: AppColors.accentCyan.withValues(alpha: 0.22),
                  border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.55),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.accentCyan.withValues(alpha: 0.20),
                      blurRadius: 6,
                    ),
                  ],
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        AppColors.accentCyan.withValues(alpha: 0.32),
                        AppColors.accentCyan.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.accentCyan.withValues(alpha: 0.25),
                        blurRadius: 10,
                      ),
                    ],
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _ShopScaleButton(
                      label: 'Satın Al',
                      accent: AppColors.accentCyan,
                      loading: isBuying,
                      enabled: !purchaseLoading && !isBuying,
                      onTap: onBuy,
                    ),
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
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF131C2D).withValues(alpha: 0.65),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.20),
                width: 0.8,
              ),
            ),
            child: Text(
              'Kur: ${EconomyConstants.shopGoldPerGem} altın = 1 💎',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedTitanium.withValues(alpha: 0.85),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    final bool isBest = pkg.isBestValue;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            isBest
                ? const Color(0xFF1B253D).withValues(alpha: 0.92)
                : const Color(0xFF131C2D).withValues(alpha: 0.88),
            isBest
                ? const Color(0xFF0F1727).withValues(alpha: 0.96)
                : const Color(0xFF0B101C).withValues(alpha: 0.94),
          ],
        ),
        border: Border.all(
          color: isBest
              ? AppColors.liquidGold.withValues(alpha: 0.70)
              : AppColors.liquidGold.withValues(alpha: 0.24),
          width: isBest ? 1.4 : 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: isBest ? 0.20 : 0.08),
            blurRadius: isBest ? 16 : 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
                      color: AppColors.liquidGold.withValues(alpha: 0.75),
                      width: 1.1,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.liquidGold.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
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
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (isBest) const SizedBox(height: 6),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        AppColors.liquidGold.withValues(alpha: 0.32),
                        AppColors.liquidGold.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.liquidGold.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.liquidGold.withValues(alpha: 0.25),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.paid_rounded, color: AppColors.liquidGold, size: 28),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    fmtGold(pkg.gold),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Text(
                  '🪙 Altın',
                  style: TextStyle(color: AppColors.mutedTitanium, fontSize: 10),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Row(
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
                ),
                const SizedBox(height: 10),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _ShopScaleButton(
                      label: 'Satın Al',
                      loading: isBuying,
                      enabled: !disabled,
                      onTap: onBuy,
                    ),
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
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6.5,
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
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
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
      ),
    );
  }
}

// ── Merchant Goods tab (Buy & Sell) ──────────────────────────────────────────

class _MerchantGoodsTab extends ConsumerStatefulWidget {
  const _MerchantGoodsTab({
    required this.items,
    required this.loading,
    required this.searchQuery,
    required this.buyingId,
    required this.playerTolerance,
    required this.onSearchChanged,
    required this.onBuyTap,
    required this.onSellTap,
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
  final void Function(InventoryItem) onSellTap;
  final Color Function(String?) rarityColor;
  final Widget Function(Map<String, dynamic>) buildItemIcon;

  @override
  ConsumerState<_MerchantGoodsTab> createState() => _MerchantGoodsTabState();
}

class _MerchantGoodsTabState extends ConsumerState<_MerchantGoodsTab> {
  int _merchantMode = 0; // 0 = Buy from Vendor, 1 = Sell to Vendor
  String _selectedBuyCategory = 'all';
  String _selectedBuyCurrency = 'all';
  String _selectedSellCategory = 'all';

  bool _matchesBuyCategory(Map<String, dynamic> item, String cat) {
    if (cat == 'all') return true;
    final String type = (item['item_type'] ?? '').toString().toLowerCase();
    final String potionType = (item['potion_type'] ?? '').toString().toLowerCase();
    final String name = (item['name'] ?? '').toString().toLowerCase();

    if (cat == 'potion') {
      return type == 'potion' || potionType.isNotEmpty || name.contains('iksir') || name.contains('potion');
    }
    if (cat == 'consumable') {
      return type == 'consumable' || type == 'scroll' || name.contains('parşömen') || name.contains('kutu');
    }
    if (cat == 'equipment') {
      return type == 'weapon' || type == 'armor' || type == 'accessory';
    }
    if (cat == 'material') {
      return type == 'material' || type == 'recipe' || type == 'rune';
    }
    return true;
  }

  bool _matchesSellCategory(InventoryItem item, String cat) {
    if (cat == 'all') return true;
    if (cat == 'equipment') {
      return item.itemType == ItemType.weapon || item.itemType == ItemType.armor;
    }
    if (cat == 'potion') {
      return item.itemType == ItemType.potion;
    }
    if (cat == 'consumable') {
      return item.itemType == ItemType.consumable || item.itemType == ItemType.scroll;
    }
    if (cat == 'material') {
      return item.itemType == ItemType.material || item.itemType == ItemType.rune || item.itemType == ItemType.recipe;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const Center(child: CircularProgressIndicator());

    final KingdomMarketBlessingStatus blessing = ref.watch(kingdomMarketBlessingProvider);
    final String q = widget.searchQuery.trim().toLowerCase();

    // Buy list filtering
    final List<Map<String, dynamic>> buyList = widget.items.where((it) {
      if (q.isNotEmpty) {
        final String name = (it['name']?.toString() ?? '').toLowerCase();
        if (!name.contains(q)) return false;
      }
      if (_selectedBuyCurrency != 'all') {
        final String cur = it['currency']?.toString() ?? 'gold';
        if (cur != _selectedBuyCurrency) return false;
      }
      return _matchesBuyCategory(it, _selectedBuyCategory);
    }).toList(growable: false);

    final int energyPotionIndex = buyList.indexWhere(
      (Map<String, dynamic> it) =>
          shopEnergyPotionSubtitle(it, widget.playerTolerance) != null,
    );

    // Sell list filtering
    final List<InventoryItem> allInventory = ref.watch(inventoryProvider).items;
    final List<InventoryItem> sellableList = allInventory.where((it) {
      if (it.isEquipped) return false;
      if (q.isNotEmpty && !it.name.toLowerCase().contains(q)) return false;
      return _matchesSellCategory(it, _selectedSellCategory);
    }).toList(growable: false);

    // Category count helpers
    final int buyPotionCount = widget.items.where((it) => _matchesBuyCategory(it, 'potion')).length;
    final int buyConsumableCount = widget.items.where((it) => _matchesBuyCategory(it, 'consumable')).length;
    final int buyEquipCount = widget.items.where((it) => _matchesBuyCategory(it, 'equipment')).length;
    final int buyMaterialCount = widget.items.where((it) => _matchesBuyCategory(it, 'material')).length;

    final int sellEquipCount = allInventory.where((it) => !it.isEquipped && _matchesSellCategory(it, 'equipment')).length;
    final int sellPotionCount = allInventory.where((it) => !it.isEquipped && _matchesSellCategory(it, 'potion')).length;
    final int sellConsumableCount = allInventory.where((it) => !it.isEquipped && _matchesSellCategory(it, 'consumable')).length;
    final int sellMaterialCount = allInventory.where((it) => !it.isEquipped && _matchesSellCategory(it, 'material')).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // NPC Vendor Atmosphere Header
        MerchantVendorHeader(
          hasKingdomBlessing: blessing.active,
          blessingDiscountPct: blessing.discountPercent,
        ),

        // Mode Switcher: Buy vs Sell
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _MerchantModeToggle(
                  label: '🛍️ Satın Al',
                  subtitle: '${widget.items.length} Tüccar Eşyası',
                  isSelected: _merchantMode == 0,
                  accent: AppColors.liquidGold,
                  onTap: () => setState(() => _merchantMode = 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MerchantModeToggle(
                  label: '💰 Eşya Sat',
                  subtitle: '${allInventory.where((it) => !it.isEquipped).length} Çanta Eşyası',
                  isSelected: _merchantMode == 1,
                  accent: AppColors.accentCyan,
                  onTap: () => setState(() => _merchantMode = 1),
                ),
              ),
            ],
          ),
        ),

        // Category Navigation Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(
            children: _merchantMode == 0
                ? <Widget>[
                    _CategoryChip(
                      label: 'Tümü (${widget.items.length})',
                      isSelected: _selectedBuyCategory == 'all',
                      onTap: () => setState(() => _selectedBuyCategory = 'all'),
                    ),
                    const SizedBox(width: 6),
                    _CategoryChip(
                      label: '🧪 İksirler ($buyPotionCount)',
                      isSelected: _selectedBuyCategory == 'potion',
                      onTap: () => setState(() => _selectedBuyCategory = 'potion'),
                    ),
                    const SizedBox(width: 6),
                    _CategoryChip(
                      label: '📦 Tüketilebilir ($buyConsumableCount)',
                      isSelected: _selectedBuyCategory == 'consumable',
                      onTap: () => setState(() => _selectedBuyCategory = 'consumable'),
                    ),
                    const SizedBox(width: 6),
                    _CategoryChip(
                      label: '⚔️ Ekipman ($buyEquipCount)',
                      isSelected: _selectedBuyCategory == 'equipment',
                      onTap: () => setState(() => _selectedBuyCategory = 'equipment'),
                    ),
                    const SizedBox(width: 6),
                    _CategoryChip(
                      label: '💎 Malzeme ($buyMaterialCount)',
                      isSelected: _selectedBuyCategory == 'material',
                      onTap: () => setState(() => _selectedBuyCategory = 'material'),
                    ),
                    const SizedBox(width: 12),
                    // Currency quick filter
                    _CurrencyFilterChip(
                      label: 'Hepsi',
                      isSelected: _selectedBuyCurrency == 'all',
                      onTap: () => setState(() => _selectedBuyCurrency = 'all'),
                    ),
                    const SizedBox(width: 4),
                    _CurrencyFilterChip(
                      label: '🪙 Altın',
                      isSelected: _selectedBuyCurrency == 'gold',
                      onTap: () => setState(() => _selectedBuyCurrency = 'gold'),
                    ),
                    const SizedBox(width: 4),
                    _CurrencyFilterChip(
                      label: '💎 Elmas',
                      isSelected: _selectedBuyCurrency == 'gems',
                      onTap: () => setState(() => _selectedBuyCurrency = 'gems'),
                    ),
                  ]
                : <Widget>[
                    _CategoryChip(
                      label: 'Tümü (${allInventory.where((it) => !it.isEquipped).length})',
                      isSelected: _selectedSellCategory == 'all',
                      accent: AppColors.accentCyan,
                      onTap: () => setState(() => _selectedSellCategory = 'all'),
                    ),
                    const SizedBox(width: 6),
                    _CategoryChip(
                      label: '⚔️ Ekipman ($sellEquipCount)',
                      isSelected: _selectedSellCategory == 'equipment',
                      accent: AppColors.accentCyan,
                      onTap: () => setState(() => _selectedSellCategory = 'equipment'),
                    ),
                    const SizedBox(width: 6),
                    _CategoryChip(
                      label: '🧪 İksirler ($sellPotionCount)',
                      isSelected: _selectedSellCategory == 'potion',
                      accent: AppColors.accentCyan,
                      onTap: () => setState(() => _selectedSellCategory = 'potion'),
                    ),
                    const SizedBox(width: 6),
                    _CategoryChip(
                      label: '📦 Tüketilebilir ($sellConsumableCount)',
                      isSelected: _selectedSellCategory == 'consumable',
                      accent: AppColors.accentCyan,
                      onTap: () => setState(() => _selectedSellCategory = 'consumable'),
                    ),
                    const SizedBox(width: 6),
                    _CategoryChip(
                      label: '💎 Malzemeler ($sellMaterialCount)',
                      isSelected: _selectedSellCategory == 'material',
                      accent: AppColors.accentCyan,
                      onTap: () => setState(() => _selectedSellCategory = 'material'),
                    ),
                  ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(0xFF141C2E).withValues(alpha: 0.88),
                  const Color(0xFF0B101C).withValues(alpha: 0.92),
                ],
              ),
              border: Border.all(
                color: (_merchantMode == 0 ? AppColors.liquidGold : AppColors.accentCyan).withValues(alpha: 0.25),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.search_rounded,
                  color: (_merchantMode == 0 ? AppColors.liquidGold : AppColors.accentCyan).withValues(alpha: 0.80),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: widget.onSearchChanged,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _merchantMode == 0 ? 'Tüccar eşyalarında ara...' : 'Çantada satılacak eşya ara...',
                      hintStyle: TextStyle(
                        color: AppColors.mutedTitanium.withValues(alpha: 0.65),
                        fontSize: 12.5,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (widget.searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => widget.onSearchChanged(''),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        color: AppColors.mutedTitanium.withValues(alpha: 0.85),
                        size: 15,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Grid Content (Buy vs Sell)
        Expanded(
          child: _merchantMode == 0
              ? _buildBuyGrid(context, buyList, blessing, energyPotionIndex, q)
              : _buildSellGrid(context, sellableList, q),
        ),
      ],
    );
  }

  Widget _buildBuyGrid(
    BuildContext context,
    List<Map<String, dynamic>> filtered,
    KingdomMarketBlessingStatus blessing,
    int energyPotionIndex,
    String q,
  ) {
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: _shopScrollPadding(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(0xFF151E30).withValues(alpha: 0.90),
                  const Color(0xFF0C1220).withValues(alpha: 0.94),
                ],
              ),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.25),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 46,
                  color: AppColors.mutedTitanium.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 10),
                Text(
                  q.isNotEmpty
                      ? '"${widget.searchQuery}" için eşya bulunamadı'
                      : 'Bu kategoride mağazada eşya yok',
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
      );
    }

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final int crossCount = screenWidth < 360 ? 3 : (screenWidth > 680 ? 5 : 4);
    final double aspect = screenWidth < 360 ? 0.75 : 0.71;

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: _shopScrollPadding(context),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: aspect,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final item = filtered[i];
        final id = item['id']?.toString() ?? '';
        final isBuying = widget.buyingId == id;
        final rarity = item['rarity']?.toString();
        final rc = widget.rarityColor(rarity);
        final currency = item['currency']?.toString() ?? 'gold';
        final int basePrice = ((item['price'] as num?) ?? 0).toInt();
        final int price = blessing.applyDiscount(basePrice, currency);
        final bool hasKingDiscount = blessing.hasDiscountForCurrency(currency) && price < basePrice;
        final isGem = currency == 'gems';
        final String? energySubtitle =
            shopEnergyPotionSubtitle(item, widget.playerTolerance);

        Widget cell = GestureDetector(
          onTap: isBuying ? null : () => widget.onBuyTap(item),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(0xFF162035).withValues(alpha: 0.90),
                  const Color(0xFF0C1322).withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: rc.withValues(alpha: 0.65),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: rc.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 20, 6, 32),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.2),
                          radius: 0.9,
                          colors: <Color>[
                            rc.withValues(alpha: 0.14),
                            Colors.black.withValues(alpha: 0.35),
                          ],
                        ),
                        border: Border.all(
                          color: rc.withValues(alpha: 0.20),
                          width: 0.8,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: widget.buildItemIcon(item),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
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
                        const SizedBox(width: 3),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: rc,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: rc.withValues(alpha: 0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (energySubtitle != null)
                  Positioned(
                    top: 24,
                    left: 6,
                    right: 6,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.amber.shade400.withValues(alpha: 0.35),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          energySubtitle,
                          style: TextStyle(
                            color: Colors.amber.shade200,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isGem
                            ? <Color>[
                                AppColors.accentCyan.withValues(alpha: 0.24),
                                AppColors.accentCyan.withValues(alpha: 0.08),
                              ]
                            : <Color>[
                                AppColors.liquidGold.withValues(alpha: 0.24),
                                AppColors.liquidGold.withValues(alpha: 0.08),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isGem
                            ? AppColors.accentCyan.withValues(alpha: 0.45)
                            : AppColors.liquidGold.withValues(alpha: 0.48),
                        width: 1.0,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: (isGem ? AppColors.accentCyan : AppColors.liquidGold).withValues(alpha: 0.15),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(isGem ? '💎' : '🪙', style: const TextStyle(fontSize: 9.5)),
                          const SizedBox(width: 2.5),
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
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: hasKingDiscount
                                  ? AppColors.liquidGold
                                  : (isGem ? const Color(0xFF7DD3FC) : const Color(0xFFFDE68A)),
                            ),
                          ),
                        ],
                      ),
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
    );
  }

  Widget _buildSellGrid(
    BuildContext context,
    List<InventoryItem> sellable,
    String q,
  ) {
    if (sellable.isEmpty) {
      return Center(
        child: Padding(
          padding: _shopScrollPadding(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(0xFF151E30).withValues(alpha: 0.90),
                  const Color(0xFF0C1220).withValues(alpha: 0.94),
                ],
              ),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.25),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.inventory_2_outlined,
                  size: 46,
                  color: AppColors.mutedTitanium.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 10),
                Text(
                  q.isNotEmpty
                      ? '"${widget.searchQuery}" ile eşleşen çanta eşyası yok'
                      : 'Çantanızda satılabilecek eşya bulunmuyor',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.mutedTitanium,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ganimet ve craft eşyalarını bu ekranda doğrudan tüccara satabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedTitanium.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final int crossCount = screenWidth < 360 ? 3 : (screenWidth > 680 ? 5 : 4);
    final double aspect = screenWidth < 360 ? 0.75 : 0.71;

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: _shopScrollPadding(context),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: aspect,
      ),
      itemCount: sellable.length,
      itemBuilder: (context, i) {
        final item = sellable[i];
        final rc = widget.rarityColor(item.rarity.name);
        final int sellPrice = item.vendorSellPrice > 0
            ? item.vendorSellPrice
            : (item.basePrice * 0.5).round();

        return GkkTabStaggerItem(
          index: i,
          child: GestureDetector(
            onTap: () => widget.onSellTap(item),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xFF162035).withValues(alpha: 0.90),
                    const Color(0xFF0C1322).withValues(alpha: 0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: rc.withValues(alpha: 0.65),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: rc.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  // Item Icon
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 20, 6, 32),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.2),
                            radius: 0.9,
                            colors: <Color>[
                              rc.withValues(alpha: 0.14),
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                          border: Border.all(
                            color: rc.withValues(alpha: 0.20),
                            width: 0.8,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ItemIconView(
                            iconValue: item.icon.trim(),
                            itemId: item.itemId,
                            size: 64,
                            expand: true,
                            fallback: '📦',
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Name header with integrated lock
                  Positioned(
                    top: 6,
                    left: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (item.isFavorite) ...<Widget>[
                            const Icon(
                              Icons.lock_rounded,
                              size: 10,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 2.5),
                          ],
                          Flexible(
                            child: Text(
                              item.name,
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
                        ],
                      ),
                    ),
                  ),
                  // Quantity badge
                  Positioned(
                    top: 22,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1424).withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.liquidGold.withValues(alpha: 0.45),
                          width: 0.7,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        'x${item.quantity}',
                        style: const TextStyle(
                          color: AppColors.liquidGold,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  // Sell price footer
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            AppColors.liquidGold.withValues(alpha: 0.22),
                            AppColors.liquidGold.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.liquidGold.withValues(alpha: 0.45),
                          width: 1.0,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.liquidGold.withValues(alpha: 0.14),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('🪙', style: TextStyle(fontSize: 9.5)),
                            const SizedBox(width: 2.5),
                            Text(
                              '+$sellPrice',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.liquidGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MerchantModeToggle extends StatelessWidget {
  const _MerchantModeToggle({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? <Color>[
                    accent.withValues(alpha: 0.28),
                    accent.withValues(alpha: 0.08),
                  ]
                : <Color>[
                    const Color(0xFF131C2D).withValues(alpha: 0.75),
                    const Color(0xFF090E18).withValues(alpha: 0.85),
                  ],
          ),
          border: Border.all(
            color: isSelected ? accent : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.4 : 0.8,
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.textPrimary : AppColors.mutedTitanium,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? accent : AppColors.mutedTitanium.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accent = AppColors.liquidGold,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? <Color>[
                    accent.withValues(alpha: 0.26),
                    accent.withValues(alpha: 0.10),
                  ]
                : <Color>[
                    const Color(0xFF141C2D).withValues(alpha: 0.85),
                    const Color(0xFF0C1220).withValues(alpha: 0.90),
                  ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.2 : 0.8,
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CurrencyFilterChip extends StatelessWidget {
  const _CurrencyFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? <Color>[
                    AppColors.liquidGold.withValues(alpha: 0.26),
                    AppColors.liquidGold.withValues(alpha: 0.10),
                  ]
                : <Color>[
                    const Color(0xFF111726).withValues(alpha: 0.70),
                    const Color(0xFF090E18).withValues(alpha: 0.80),
                  ],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.liquidGold : Colors.white.withValues(alpha: 0.10),
            width: isSelected ? 1.2 : 0.7,
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.22),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? AppColors.liquidGold : AppColors.mutedTitanium,
          ),
        ),
      ),
    );
  }
}
