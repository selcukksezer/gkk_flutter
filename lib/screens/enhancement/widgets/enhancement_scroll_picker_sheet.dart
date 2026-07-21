import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';

/// Envanterdeki parşömenlerden seçim. `null` = iptal, seçilen [InventoryItem] row.
Future<InventoryItem?> showEnhancementScrollPickerSheet({
  required BuildContext context,
  required List<InventoryItem> ownedScrolls,
  required String? requiredScrollId,
  InventoryItem? selectedScroll,
}) {
  Iterable<InventoryItem> filtered = ownedScrolls.where(
    (InventoryItem item) =>
        (item.itemType == ItemType.scroll || item.itemId.contains('scroll')) &&
        item.quantity > 0,
  );
  if (requiredScrollId != null && requiredScrollId.isNotEmpty) {
    filtered = filtered.where((InventoryItem item) => item.itemId == requiredScrollId);
  }
  final List<InventoryItem> scrolls = filtered.toList(growable: false)
    ..sort((InventoryItem a, InventoryItem b) => a.name.compareTo(b.name));

  return showModalBottomSheet<InventoryItem>(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                requiredScrollId != null
                    ? 'Gerekli parşömeni seç'
                    : 'Parşömen seç',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              if (requiredScrollId != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  requiredScrollId,
                  style: TextStyle(
                    color: AppColors.liquidGold.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (scrolls.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Uygun parşömen envanterde yok.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: scrolls.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final InventoryItem scroll = scrolls[index];
                      final bool isSelected =
                          selectedScroll?.rowId == scroll.rowId;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.liquidGold
                                : Colors.white12,
                          ),
                        ),
                        tileColor: const Color(0xFF121A2A),
                        leading: ItemIconView(
                          iconValue: scroll.icon,
                          itemId: scroll.itemId,
                          itemType: scroll.itemType,
                          size: 40,
                          fallback: '📜',
                        ),
                        title: Text(
                          scroll.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          'x${scroll.quantity}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: AppColors.liquidGold)
                            : null,
                        onTap: () => Navigator.pop(context, scroll),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
