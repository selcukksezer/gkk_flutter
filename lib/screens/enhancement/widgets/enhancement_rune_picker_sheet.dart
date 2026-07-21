import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';

typedef EnhancementRuneType = String;

class EnhancementRuneCatalogEntry {
  const EnhancementRuneCatalogEntry({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;
}

const Map<EnhancementRuneType, EnhancementRuneCatalogEntry> kEnhancementRuneCatalog =
    <EnhancementRuneType, EnhancementRuneCatalogEntry>{
  'basic': EnhancementRuneCatalogEntry(
    label: 'Temel Rune',
    description: '+5% başarı şansı',
  ),
  'advanced': EnhancementRuneCatalogEntry(
    label: 'Gelişmiş Rune',
    description: '+10% başarı şansı',
  ),
  'superior': EnhancementRuneCatalogEntry(
    label: 'Üstün Rune',
    description: '+15% başarı, yıkım riski yarıya',
  ),
  'legendary': EnhancementRuneCatalogEntry(
    label: 'Efsanevi Rune',
    description: '+25% başarı, yıkım riski %75 azalır',
  ),
  'protection': EnhancementRuneCatalogEntry(
    label: 'Koruma Rune',
    description: 'Başarısızlıkta eşya yok olmaz',
  ),
  'blessed': EnhancementRuneCatalogEntry(
    label: 'Kutsal Rune',
    description: '+20% başarı, seviye düşmez',
  ),
};

EnhancementRuneType enhancementRuneTypeFromItemId(String itemId) =>
    itemId.replaceFirst('rune_', '');

String enhancementRuneLabel(EnhancementRuneType type) {
  if (type == 'none') return 'Rune kullanma';
  return kEnhancementRuneCatalog[type]?.label ?? type;
}

String? enhancementRuneDescription(EnhancementRuneType type) =>
    kEnhancementRuneCatalog[type]?.description;

/// Envanterdeki rune item'larından seçim listesi açar. `none` veya rune type döner.
Future<EnhancementRuneType?> showEnhancementRunePickerSheet({
  required BuildContext context,
  required List<InventoryItem> ownedRunes,
  required EnhancementRuneType selectedRune,
}) {
  final List<InventoryItem> runes = ownedRunes
      .where((InventoryItem item) =>
          item.itemType == ItemType.rune || item.itemId.startsWith('rune_'))
      .where((InventoryItem item) => item.quantity > 0)
      .toList(growable: false)
    ..sort((InventoryItem a, InventoryItem b) => a.name.compareTo(b.name));

  return showModalBottomSheet<EnhancementRuneType>(
    context: context,
    backgroundColor: AppColors.carbonVoid,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (BuildContext context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Rune Seç',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                runes.isEmpty
                    ? 'Envanterinde rune yok. Rune kullanmadan devam edebilirsin.'
                    : 'Envanterindeki runelerden birini seç.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedTitanium.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 12),
              _RunePickerTile(
                selected: selectedRune == 'none',
                title: 'Rune kullanma',
                subtitle: 'Ek bonus olmadan güçlendir',
                leading: const Text('—', style: TextStyle(fontSize: 18, color: AppColors.mutedTitanium)),
                onTap: () => Navigator.of(context).pop('none'),
              ),
              if (runes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                ...runes.map((InventoryItem item) {
                  final EnhancementRuneType type = enhancementRuneTypeFromItemId(item.itemId);
                  final EnhancementRuneCatalogEntry? catalog = kEnhancementRuneCatalog[type];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RunePickerTile(
                      selected: selectedRune == type,
                      title: catalog?.label ?? item.name,
                      subtitle: catalog?.description ?? item.name,
                      trailing: '×${item.quantity}',
                      leading: ItemIconView(
                        iconValue: item.icon,
                        itemId: item.itemId,
                        itemType: item.itemType,
                        size: 36,
                        expand: true,
                        fallback: '🔮',
                      ),
                      onTap: () => Navigator.of(context).pop(type),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _RunePickerTile extends StatelessWidget {
  const _RunePickerTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onTap,
    this.trailing,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accentPurple.withValues(alpha: 0.12)
          : AppColors.darkObsidian.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.accentPurple.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(width: 40, height: 40, child: Center(child: leading)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedTitanium.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPurple,
                  ),
                ),
              if (selected) ...<Widget>[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, size: 18, color: AppColors.accentPurple),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
