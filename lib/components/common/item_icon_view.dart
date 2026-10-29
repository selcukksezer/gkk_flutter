import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/item_model.dart';
import '../../utils/item_icon_resolver.dart';

import '../../screens/loot/loot_chest_theme.dart';
import 'aion_asset_illustrations.dart';

class ItemIconView extends StatelessWidget {
  const ItemIconView({
    super.key,
    required this.iconValue,
    this.itemId,
    this.itemType,
    this.size = 24,
    this.fallback = '📦',
    this.fit = BoxFit.contain,
    this.expand = false,
  });

  final String iconValue;
  final String? itemId;
  final ItemType? itemType;
  final double size;
  final String fallback;
  final BoxFit fit;
  final bool expand;

  static Future<Set<String>>? _manifestFuture;

  static Future<Set<String>> _loadManifestPaths() async {
    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        rootBundle,
      );
      return manifest.listAssets().toSet();
    } catch (_) {
      // Fallback for older runtimes where JSON manifest is still present.
      final String raw = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> jsonMap =
          json.decode(raw) as Map<String, dynamic>;
      return jsonMap.keys.toSet();
    }
  }

  static Future<Set<String>> _manifestPaths() {
    _manifestFuture ??= _loadManifestPaths();
    return _manifestFuture!;
  }

  Widget _fallbackWidget(String raw) {
    final double displaySize = expand ? double.infinity : size;
    final String target = '${raw.toLowerCase()} ${(itemId ?? '').toLowerCase()}';

    // 1. Potion Detection
    if (itemType == ItemType.potion ||
        target.contains('potion') ||
        target.contains('iksir') ||
        target.contains('elixir') ||
        target.contains('brew') ||
        target.contains('flask') ||
        target.contains('phial') ||
        target.contains('vigor') ||
        target.contains('clarity') ||
        target.contains('berserk') ||
        target.contains('detox')) {
      final AionPotionTheme theme = () {
        if (target.contains('mana') || target.contains('mp') || target.contains('clarity')) {
          return AionPotionTheme.mana;
        }
        if (target.contains('energy') || target.contains('stamina')) {
          return AionPotionTheme.energy;
        }
        if (target.contains('buff') ||
            target.contains('berserk') ||
            target.contains('attack') ||
            target.contains('defense') ||
            target.contains('luck') ||
            target.contains('xp')) {
          return AionPotionTheme.buff;
        }
        if (target.contains('detox') ||
            target.contains('cleanse') ||
            target.contains('cure') ||
            target.contains('purge')) {
          return AionPotionTheme.detox;
        }
        if (target.contains('shadow') || target.contains('void') || target.contains('dark')) {
          return AionPotionTheme.shadow;
        }
        return AionPotionTheme.health;
      }();
      return SizedBox(
        width: displaySize,
        height: displaySize,
        child: Center(
          child: AionPotionIllustration(theme: theme, size: size, showGlow: true),
        ),
      );
    }

    // 2. Crafting Material Detection
    if (itemType == ItemType.material ||
        itemType == ItemType.rune ||
        target.contains('material') ||
        target.contains('res_') ||
        target.contains('herb') ||
        target.contains('bitki') ||
        target.contains('maden') ||
        target.contains('mining') ||
        target.contains('ore') ||
        target.contains('ingot') ||
        target.contains('wood') ||
        target.contains('lumber') ||
        target.contains('odun') ||
        target.contains('stone') ||
        target.contains('quarry') ||
        target.contains('tas') ||
        target.contains('clay') ||
        target.contains('kil') ||
        target.contains('shard') ||
        target.contains('crystal') ||
        target.contains('kristal') ||
        target.contains('rune') ||
        target.contains('catalyst') ||
        target.contains('kataliz') ||
        target.contains('silk') ||
        target.contains('ipek') ||
        target.contains('leather') ||
        target.contains('deri')) {
      final AionCraftingMaterialType matType = () {
        if (target.contains('herb') ||
            target.contains('bitki') ||
            target.contains('flower') ||
            target.contains('cicek') ||
            target.contains('farming')) {
          return AionCraftingMaterialType.herbFlora;
        }
        if (target.contains('wood') ||
            target.contains('lumber') ||
            target.contains('odun') ||
            target.contains('agac')) {
          return AionCraftingMaterialType.lumberWood;
        }
        if (target.contains('mining') ||
            target.contains('ore') ||
            target.contains('ingot') ||
            target.contains('demir') ||
            target.contains('maden') ||
            target.contains('metal') ||
            target.contains('quarry') ||
            target.contains('stone') ||
            target.contains('tas')) {
          return AionCraftingMaterialType.oreIngot;
        }
        if (target.contains('silk') ||
            target.contains('ipek') ||
            target.contains('leather') ||
            target.contains('deri') ||
            target.contains('cloth') ||
            target.contains('kumas')) {
          return AionCraftingMaterialType.silkLeather;
        }
        if (target.contains('catalyst') ||
            target.contains('kataliz') ||
            target.contains('essence') ||
            target.contains('oz')) {
          return AionCraftingMaterialType.alchemicalCatalyst;
        }
        return AionCraftingMaterialType.runeCrystal;
      }();
      return SizedBox(
        width: displaySize,
        height: displaySize,
        child: Center(
          child: AionCraftingMaterialIllustration(materialType: matType, size: size, showGlow: true),
        ),
      );
    }

    // 3. Chest / Box Detection
    if (target.contains('chest') ||
        target.contains('box') ||
        target.contains('crate') ||
        target.contains('kasa') ||
        target.contains('sandik') ||
        target.contains('coffer') ||
        target.contains('vault')) {
      final LootChestTier tier = () {
        if (target.contains('eternal') || target.contains('witch') || target.contains('ebedi') || target.contains('void')) {
          return LootChestTier.eternal;
        }
        if (target.contains('fabled') || target.contains('crystal') || target.contains('efsanevi') || target.contains('buz')) {
          return LootChestTier.fabled;
        }
        if (target.contains('heroic') || target.contains('gold') || target.contains('altin') || target.contains('lav')) {
          return LootChestTier.heroic;
        }
        if (target.contains('rare') || target.contains('nadir') || target.contains('cobalt') || target.contains('deniz')) {
          return LootChestTier.rare;
        }
        return LootChestTier.common;
      }();
      return SizedBox(
        width: displaySize,
        height: displaySize,
        child: Center(
          child: AionChestIllustration(tier: tier, size: size, showGlow: true),
        ),
      );
    }

    // 4. Currency Detection
    if (target.contains('gold') || target.contains('altin') || target.contains('coin')) {
      return SizedBox(
        width: displaySize,
        height: displaySize,
        child: Center(
          child: AionCurrencyIllustration.gold(size: size, showGlow: true),
        ),
      );
    }
    if (target.contains('gem') || target.contains('elmas') || target.contains('diamond')) {
      return SizedBox(
        width: displaySize,
        height: displaySize,
        child: Center(
          child: AionCurrencyIllustration.gem(size: size, showGlow: true),
        ),
      );
    }

    // 5. Clean emoji or runic fallback
    final bool showRaw = ItemIconResolver.isLikelyEmoji(raw);
    if (showRaw && raw.isNotEmpty) {
      return SizedBox(
        width: displaySize,
        height: displaySize,
        child: Center(
          child: Text(
            raw,
            style: TextStyle(fontSize: size * 0.72),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SizedBox(
      width: displaySize,
      height: displaySize,
      child: Center(
        child: AionCraftingMaterialIllustration(
          materialType: AionCraftingMaterialType.runeCrystal,
          size: size,
          showGlow: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String raw = iconValue.trim();
    final List<String> candidates = ItemIconResolver.resolveCandidates(
      iconValue: iconValue,
      itemId: itemId,
      itemType: itemType,
    );

    if (candidates.isEmpty) return _fallbackWidget(raw);

    return FutureBuilder<Set<String>>(
      future: _manifestPaths(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: expand ? double.infinity : size,
            height: expand ? double.infinity : size,
          );
        }

        final Set<String> manifest = snapshot.data ?? <String>{};
        String? selected;
        for (final candidate in candidates) {
          if (manifest.contains(candidate)) {
            selected = candidate;
            break;
          }
        }

        if (selected == null) return _fallbackWidget(raw);

        return Image.asset(
          selected,
          width: expand ? double.infinity : size,
          height: expand ? double.infinity : size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return _fallbackWidget(raw);
          },
        );
      },
    );
  }
}
