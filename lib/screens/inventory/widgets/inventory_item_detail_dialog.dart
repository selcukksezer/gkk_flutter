import 'package:flutter/material.dart';

import '../../../models/inventory_model.dart';
import 'inventory_item_detail_panel.dart';

Future<void> showInventoryItemDetailDialog(
  BuildContext context, {
  required InventoryItem item,
  required InventoryItemDetailActions actions,
  required bool isFavorite,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (BuildContext dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 338),
          child: InventoryItemDetailPanel(
            item: item,
            actions: actions,
            isFavorite: isFavorite,
          ),
        ),
      );
    },
  );
}
