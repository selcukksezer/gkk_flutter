import 'package:flutter/material.dart';

import '../../../models/dungeon_model.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';

class DungeonConfirmEntryDialog extends StatelessWidget {
  const DungeonConfirmEntryDialog({
    super.key,
    required this.dungeon,
    this.hospitalRiskPct,
    this.rewardMultiplierPreview,
    this.onConfirmTap,
  });

  final DungeonData dungeon;
  final double? hospitalRiskPct;
  final double? rewardMultiplierPreview;
  final VoidCallback? onConfirmTap;

  @override
  Widget build(BuildContext context) {
    final StringBuffer body = StringBuffer(
      '${dungeon.energyCost} enerji harcanacak.\nOperasyonu başlatmak istiyor musun?',
    );
    if (hospitalRiskPct != null && hospitalRiskPct! > 0) {
      body.write('\n\nYenilgi hastane riski: %${hospitalRiskPct!.toStringAsFixed(0)}');
    }
    if (rewardMultiplierPreview != null && rewardMultiplierPreview! < 0.99) {
      body.write('\nÖdül çarpanı: ×${rewardMultiplierPreview!.toStringAsFixed(2)}');
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF0D1525),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1A2540)),
      ),
      title: Text(
        dungeon.name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFFE8EDF8),
        ),
      ),
      content: Text(
        body.toString(),
        style: const TextStyle(color: Color(0xFF6070A0)),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('İptal', style: TextStyle(color: Color(0xFF4A5880))),
        ),
        TutorialAnchorScope(
          id: TutorialAnchorId.dungeonConfirmOk,
          child: FilledButton(
            onPressed: () {
              onConfirmTap?.call();
              Navigator.of(context).pop(true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF5C842),
              foregroundColor: Colors.black,
            ),
            child: const Text('Gir', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}
