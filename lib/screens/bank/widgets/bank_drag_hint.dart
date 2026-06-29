import 'package:flutter/material.dart';

import 'bank_design.dart';

class BankDragHint extends StatelessWidget {
  const BankDragHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Text(
        'Uzun bas: sürükle · Dokun: seç',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: BankDesign.muted.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
