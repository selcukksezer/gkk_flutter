import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

enum StaffBadgeType { admin, gm, king }

class StaffBadge extends StatelessWidget {
  const StaffBadge({super.key, required this.badge, this.compact = false});

  final String? badge;
  final bool compact;

  StaffBadgeType? get _type {
    switch (badge) {
      case 'admin':
        return StaffBadgeType.admin;
      case 'gm':
        return StaffBadgeType.gm;
      case 'king':
        return StaffBadgeType.king;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final StaffBadgeType? type = _type;
    if (type == null) return const SizedBox.shrink();

    final bool isAdmin = type == StaffBadgeType.admin;
    final bool isKing = type == StaffBadgeType.king;
    final Color accent = isKing
        ? AppColors.liquidGold
        : (isAdmin ? AppColors.liquidGold : AppColors.toxicNeon);
    final String label = isKing ? 'KING' : (isAdmin ? 'ADMIN' : 'GM');

    return Container(
      margin: EdgeInsets.only(left: compact ? 4 : 6),
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7, vertical: compact ? 1 : 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.75), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 6),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: accent,
          height: 1,
        ),
      ),
    );
  }
}
