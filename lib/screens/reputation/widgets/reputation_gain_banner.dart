import 'package:flutter/material.dart';

/// Banner shown on dungeon/PvP results when reputation was earned.
class ReputationGainBanner extends StatelessWidget {
  const ReputationGainBanner({
    super.key,
    required this.amount,
    this.label = 'İtibar kazanıldı',
  });

  final int amount;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            const Color(0xFFFFB800).withValues(alpha: 0.28),
            const Color(0xFFE01E5A).withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.55)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFFFB800).withValues(alpha: 0.15),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.military_tech_rounded, color: Color(0xFFFFB800), size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: +$amount',
            style: const TextStyle(
              color: Color(0xFFFDE68A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
