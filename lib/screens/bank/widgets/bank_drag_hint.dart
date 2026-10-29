import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'bank_design.dart';

/// Aion 2 subtle gesture indicator pill.
class BankDragHint extends StatelessWidget {
  const BankDragHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: BankDesign.royalObsidian.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.touch_app_outlined,
              size: 13,
              color: BankDesign.gold,
            ),
            SizedBox(width: 6),
            Text(
              'Uzun Bas: Sürükle & Aktar  ·  Dokun: Çoklu Seç',
              style: TextStyle(
                color: AppColors.mutedTitanium,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
