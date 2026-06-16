import '../models/item_model.dart';

class ItemIconResolver {
  ItemIconResolver._();

  static const Map<String, String> _legacyWeaponAliasByStem = <String, String>{
    'axe_basic': 'wpn_axe_common',
    'axe_divine': 'wpn_axe_epic',
    'dagger_basic': 'wpn_dagger_common',
    'staff_magic': 'wpn_staff_uncommon',
    'sword_steel': 'wpn_sword_uncommon',
    'sword_mithril': 'wpn_sword_rare',
    'sword_basic': 'wpn_sword_common',
    'iron_sword': 'wpn_sword_common',
    'steel_sword': 'wpn_sword_uncommon',
    'legendary_sword': 'wpn_sword_legendary',
    'bow_basic': 'wpn_staff_common',
    'spear_basic': 'wpn_axe_common',
    'spear_dragon': 'wpn_axe_rare',
  };

  static final RegExp _emojiRegex = RegExp(
    r'^[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]+$',
    unicode: true,
  );

  static bool isLikelyAssetPath(String value) {
    final String v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    return (v.contains('/') || v.contains('\\')) &&
        (v.endsWith('.png') ||
            v.endsWith('.jpg') ||
            v.endsWith('.jpeg') ||
            v.endsWith('.webp'));
  }

  static bool isLikelyEmoji(String value) {
    final String v = value.trim();
    if (v.isEmpty) return false;
    return _emojiRegex.hasMatch(v);
  }

  static String normalizeAssetPath(String iconValue) {
    String icon = iconValue.trim();
    if (icon.startsWith('res://')) {
      icon = icon.substring('res://'.length);
    }
    if (icon.startsWith('/')) {
      icon = icon.substring(1);
    }
    if (icon.startsWith('assets/icons/')) {
      return icon.replaceFirst('assets/icons/', 'assets/items/');
    }
    return icon;
  }

  static String _basenameWithoutExtension(String path) {
    final String normalized = path.replaceAll('\\', '/');
    final int slash = normalized.lastIndexOf('/');
    final String filename = slash >= 0
        ? normalized.substring(slash + 1)
        : normalized;
    final int dot = filename.lastIndexOf('.');
    if (dot > 0) return filename.substring(0, dot);
    return filename;
  }

  static String _folderByItemType(ItemType? itemType, String key) {
    switch (itemType) {
      case ItemType.weapon:
        return 'weapons';
      case ItemType.armor:
        return 'armor';
      case ItemType.potion:
      case ItemType.consumable:
      case ItemType.scroll:
        return 'potions';
      case ItemType.material:
      case ItemType.rune:
      case ItemType.recipe:
      case ItemType.cosmetic:
        return 'materials';
      case null:
        if (key.startsWith('wpn_')) return 'weapons';
        if (key.startsWith('arm_') ||
            key.startsWith('chest_') ||
            key.startsWith('head_') ||
            key.startsWith('legs_') ||
            key.startsWith('boots_') ||
            key.startsWith('gloves_') ||
            key.startsWith('ring_') ||
            key.startsWith('neck_')) {
          return 'armor';
        }
        if (key.startsWith('potion_') ||
            key.startsWith('scroll_') ||
            key.startsWith('catalyst_')) {
          return 'potions';
        }
        return 'materials';
    }
  }

  static List<String> _legacyWeaponKeys({
    required String stem,
    required String itemId,
    required ItemType? itemType,
  }) {
    if (itemType != ItemType.weapon &&
        !stem.contains('sword') &&
        !stem.contains('axe') &&
        !stem.contains('dagger') &&
        !stem.contains('staff') &&
        !stem.contains('bow') &&
        !stem.contains('spear') &&
        !itemId.startsWith('weapon_')) {
      return const <String>[];
    }

    final Set<String> keys = <String>{};
    final String lowerStem = stem.toLowerCase();
    final String lowerId = itemId.toLowerCase();

    final String? exact = _legacyWeaponAliasByStem[lowerStem];
    if (exact != null && exact.isNotEmpty) keys.add(exact);

    if (lowerStem.contains('sword') || lowerId.contains('_sword')) {
      keys.add('wpn_sword_common');
      keys.add('wpn_sword_uncommon');
      keys.add('wpn_sword_rare');
    }
    if (lowerStem.contains('axe') || lowerId.contains('_axe')) {
      keys.add('wpn_axe_common');
      keys.add('wpn_axe_uncommon');
      keys.add('wpn_axe_rare');
    }
    if (lowerStem.contains('dagger') || lowerId.contains('_dagger')) {
      keys.add('wpn_dagger_common');
      keys.add('wpn_dagger_uncommon');
      keys.add('wpn_dagger_rare');
    }
    if (lowerStem.contains('staff') ||
        lowerStem.contains('bow') ||
        lowerStem.contains('spear') ||
        lowerId.contains('_staff') ||
        lowerId.contains('_bow') ||
        lowerId.contains('_spear')) {
      keys.add('wpn_staff_common');
      keys.add('wpn_staff_uncommon');
      keys.add('wpn_staff_rare');
    }

    return keys.toList(growable: false);
  }

  static List<String> resolveCandidates({
    required String iconValue,
    String? itemId,
    ItemType? itemType,
  }) {
    final String icon = iconValue.trim();
    final String id = itemId?.trim() ?? '';

    if (icon.isNotEmpty && isLikelyAssetPath(icon)) {
      final String normalized = normalizeAssetPath(icon);
      final String stem = _basenameWithoutExtension(normalized);
      final String key = stem.isNotEmpty ? stem : id;
      final String folder = _folderByItemType(itemType, key);
      final Set<String> candidates = <String>{
        normalized,
        'assets/items/$folder/$key.png',
        'assets/items/$folder/$key.webp',
        'assets/items/$folder/$key.jpg',
        'assets/items/$folder/$key.jpeg',
        'assets/items/$key.png',
        'assets/items/$key.webp',
        'assets/items/$key.jpg',
        'assets/items/$key.jpeg',
      };

      for (final legacyKey in _legacyWeaponKeys(
        stem: stem,
        itemId: id,
        itemType: itemType,
      )) {
        candidates.add('assets/items/weapons/$legacyKey.png');
        candidates.add('assets/items/weapons/$legacyKey.webp');
        candidates.add('assets/items/weapons/$legacyKey.jpg');
        candidates.add('assets/items/weapons/$legacyKey.jpeg');
      }

      return candidates.toList(growable: false);
    }

    String key = '';
    if (icon.isNotEmpty && !isLikelyEmoji(icon)) {
      key = icon;
    } else if (id.isNotEmpty) {
      key = id;
    }

    if (key.isEmpty) return const <String>[];

    final String folder = _folderByItemType(itemType, key);
    return <String>[
      'assets/items/$folder/$key.png',
      'assets/items/$folder/$key.webp',
      'assets/items/$folder/$key.jpg',
      'assets/items/$folder/$key.jpeg',
      'assets/items/$key.png',
      'assets/items/$key.webp',
      'assets/items/$key.jpg',
      'assets/items/$key.jpeg',
    ];
  }
}
