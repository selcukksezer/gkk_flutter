import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/market_provider.dart';
import '../../../theme/app_colors.dart';
import 'gold_coin_particle_burst.dart';
import 'market_design.dart';
import 'market_helpers.dart';
import 'market_listing_card.dart';
import 'market_quantity_sheet.dart';

class MarketSellTab extends ConsumerStatefulWidget {
  const MarketSellTab({super.key});

  @override
  ConsumerState<MarketSellTab> createState() => _MarketSellTabState();
}

class _MarketSellTabState extends ConsumerState<MarketSellTab> {
  String _search = '';
  String _selectedCategory = '';
  String _selectedRarity = '';
  int _filterResetIndex = 0;

  void _clearFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _search = '';
      _selectedCategory = '';
      _selectedRarity = '';
      _filterResetIndex++;
    });
  }

  int _rarityRank(String rarityName) {
    return switch (rarityName.toLowerCase()) {
      'mythic' => 6,
      'legendary' => 5,
      'epic' => 4,
      'rare' => 3,
      'uncommon' => 2,
      _ => 1,
    };
  }

  bool _matchesCategory(InventoryItem item, String category) {
    if (category.isEmpty) return true;
    final String typeName = item.itemType.name.toLowerCase();
    if (category == 'consumable') {
      return typeName == 'consumable' || typeName == 'potion';
    }
    if (category == 'accessory') {
      return item.equipSlot == EquipSlot.ring ||
          item.equipSlot == EquipSlot.necklace ||
          typeName == 'rune';
    }
    return typeName == category;
  }

  bool _matchesRarity(InventoryItem item, String rarity) {
    if (rarity.isEmpty) return true;
    return item.rarity.name.toLowerCase() == rarity.toLowerCase();
  }

  bool _matchesSearch(InventoryItem item, String query) {
    if (query.trim().isEmpty) return true;
    final String q = query.trim().toLowerCase();
    return item.name.toLowerCase().contains(q) ||
        marketRarityLabel(item.rarity.name).toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final List<InventoryItem> allItems = ref.watch(inventoryProvider).items;
    final List<InventoryItem> tradeableItems = allItems
        .where((InventoryItem item) => item.isTradeable && !item.isEquipped && item.quantity > 0)
        .toList();

    if (tradeableItems.isEmpty) {
      return _buildNoTradeableEmptyState();
    }

    tradeableItems.sort((InventoryItem a, InventoryItem b) {
      final bool lockedA = a.isMarketTradeable == false || a.isHanOnly == true;
      final bool lockedB = b.isMarketTradeable == false || b.isHanOnly == true;
      if (lockedA != lockedB) {
        return lockedA ? 1 : -1;
      }
      final int rankA = _rarityRank(a.rarity.name);
      final int rankB = _rarityRank(b.rarity.name);
      if (rankA != rankB) {
        return rankB.compareTo(rankA);
      }
      if (a.enhancementLevel != b.enhancementLevel) {
        return b.enhancementLevel.compareTo(a.enhancementLevel);
      }
      if (a.basePrice != b.basePrice) {
        return b.basePrice.compareTo(a.basePrice);
      }
      return a.name.compareTo(b.name);
    });

    final int sellableCount = tradeableItems
        .where((InventoryItem i) => i.isMarketTradeable != false && i.isHanOnly != true)
        .length;

    final List<InventoryItem> filteredItems = tradeableItems.where((InventoryItem item) {
      if (!_matchesSearch(item, _search)) return false;
      if (!_matchesCategory(item, _selectedCategory)) return false;
      if (!_matchesRarity(item, _selectedRarity)) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSellMarquee(sellableCount: sellableCount),
        const SizedBox(height: 10),
        _buildFilterPanel(),
        const SizedBox(height: 10),
        _buildSectionHeader(totalCount: filteredItems.length),
        const SizedBox(height: 6),
        if (filteredItems.isEmpty)
          _buildFilteredEmptyState()
        else
          ...List<Widget>.generate(filteredItems.length, (int index) {
            final InventoryItem item = filteredItems[index];
            final bool locked = item.isMarketTradeable == false || item.isHanOnly == true;
            final int initialPrice = item.basePrice > 0 ? item.basePrice : 100;
            final String? badge = item.enhancementLevel > 0 ? '+${item.enhancementLevel}' : null;
            final String metaLine = locked
                ? (item.isHanOnly == true ? 'Sadece Han Ticareti' : 'Pazarda Satilamaz')
                : '${marketRarityLabel(item.rarity.name)} • ${item.isStackable ? '${item.quantity} Adet' : 'Tekil'}';
            final String priceText = locked ? '—' : 'Taban: ${formatMarketGold(initialPrice)} Altin';

            return MarketListingCard(
              index: index,
              itemName: item.name,
              rarity: item.rarity.name,
              itemId: item.itemId,
              iconValue: item.icon,
              itemType: item.itemType,
              quantity: item.quantity,
              showQuantity: item.isStackable && item.quantity > 1,
              badge: badge,
              metaLine: metaLine,
              priceText: priceText,
              onTap: locked ? null : () => _openSellSheet(context, item),
              trailing: locked
                  ? const MarketSecondaryButton(
                      label: 'Kilitli',
                      accent: AppColors.mutedTitanium,
                      compact: true,
                      onPressed: null,
                    )
                  : MarketPrimaryButton(
                      label: 'Sat',
                      icon: Icons.sell_rounded,
                      compact: true,
                      onPressed: () => _openSellSheet(context, item),
                    ),
            );
          }),
      ],
    );
  }

  Widget _buildSellMarquee({required int sellableCount}) {
    return MarketGlassCard(
      borderColor: AppColors.liquidGold.withValues(alpha: 0.35),
      glowColor: AppColors.liquidGold.withValues(alpha: 0.16),
      borderRadius: 16,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: MarketDesign.goldGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sell_rounded,
                  size: 15,
                  color: AppColors.carbonVoid,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'ENVANTER MEZAT LISTELEME',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kendi fiyatini belirle, dogrudan diger oyunculara arz et.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _statPill(
                icon: Icons.inventory_2_rounded,
                label: '$sellableCount satilabilir',
                accent: AppColors.accentCyan,
              ),
              _statPill(
                icon: Icons.percent_rounded,
                label: '%5 pazar vergisi',
                accent: AppColors.liquidGold,
              ),
              _statPill(
                icon: Icons.security_rounded,
                label: 'Emanet korumali',
                accent: AppColors.toxicNeon,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return MarketFilterPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MarketSearchField(
            key: ValueKey<int>(_filterResetIndex),
            hint: 'Satilacak esya ara...',
            onChanged: (String value) {
              setState(() => _search = value);
            },
          ),
          const SizedBox(height: 8),
          MarketPillStrip(
            options: marketStaticCategoryPillOptions(),
            selectedKey: _selectedCategory,
            onSelected: (String key) {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = key);
            },
            accent: AppColors.accentCyan,
          ),
          const SizedBox(height: 6),
          MarketPillStrip(
            options: marketStaticRarityPillOptions(),
            selectedKey: _selectedRarity,
            onSelected: (String key) {
              HapticFeedback.selectionClick();
              setState(() => _selectedRarity = key);
            },
            accent: AppColors.liquidGold,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required int totalCount}) {
    final bool isFiltered =
        _search.isNotEmpty || _selectedCategory.isNotEmpty || _selectedRarity.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: MarketSectionHeader(
            title: 'SATILACAK ESYALAR ($totalCount)',
            subtitle: isFiltered
                ? 'Filtrelenmis esyalar listeleniyor'
                : 'Envanterinden ilana koymak icin esyayi sec',
          ),
        ),
        if (isFiltered) ...<Widget>[
          const SizedBox(width: 8),
          MarketPressable(
            onTap: _clearFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.darkObsidian.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.45)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.close_rounded, size: 12, color: AppColors.accentCyan),
                  SizedBox(width: 3),
                  Text(
                    'Sifirla',
                    style: TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilteredEmptyState() {
    return MarketGlassCard(
      borderColor: AppColors.darkObsidian.withValues(alpha: 0.7),
      glowColor: AppColors.carbonVoid,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.search_off_rounded,
              size: 34,
              color: AppColors.mutedTitanium.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aramaya Uygun Esya Bulunamadi',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Secili filtreleri temizleyerek tum satilabilir esyalarini gorebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedTitanium,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 12),
            MarketSecondaryButton(
              label: 'Filtreleri Temizle',
              accent: AppColors.accentCyan,
              compact: true,
              onPressed: _clearFilters,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTradeableEmptyState() {
    return MarketGlassCard(
      borderColor: AppColors.darkObsidian.withValues(alpha: 0.8),
      glowColor: AppColors.carbonVoid,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.spaceNavy.withValues(alpha: 0.6),
                border: Border.all(
                  color: AppColors.liquidGold.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 26,
                color: AppColors.mutedTitanium,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Satilabilir Esya Yok',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Envanterindeki tum esyalar kusanilmis veya takaslanamaz durumda. Canavar ganimetleri ve zindan odulleri toplayarak pazarda satis yapabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedTitanium,
                fontSize: 11,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            const Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: <Widget>[
                _HelpBadge(icon: Icons.shield_outlined, text: 'Kusanilanlar satilamaz'),
                _HelpBadge(icon: Icons.lock_outline_rounded, text: 'Ruh bagi olanlar satilamaz'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.carbonVoid.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.0),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSellSheet(
    BuildContext context,
    InventoryItem item,
  ) async {
    HapticFeedback.selectionClick();
    final int initialPrice = item.basePrice > 0 ? item.basePrice : 100;

    final MarketQuantityResult? result = await MarketQuantitySheet.show(
      context,
      title: item.name,
      subtitle: item.isStackable ? '${item.quantity} adet mevcut' : 'Tekil esya',
      unitPrice: initialPrice,
      maxQuantity: item.quantity,
      isStackable: item.isStackable,
      mode: MarketQuantityMode.sell,
      confirmLabel: 'Ilana Koy',
      allowPriceEdit: true,
    );

    if (result == null || !context.mounted) return;

    final bool ok = await ref.read(marketProvider.notifier).createOrder(
          itemRowId: item.rowId,
          quantity: result.quantity,
          price: result.unitPrice,
        );

    if (!context.mounted) return;
    if (ok) {
      HapticFeedback.selectionClick();
      GoldCoinParticleBurst.trigger(context);
    }
    showMarketSnackBar(
      context,
      ok ? 'Ilan olusturuldu' : (ref.read(marketProvider).errorMessage ?? 'Basarisiz'),
      isError: !ok,
    );
  }
}

class _HelpBadge extends StatelessWidget {
  const _HelpBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.carbonVoid.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.darkObsidian),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: AppColors.mutedTitanium),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.mutedTitanium,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

