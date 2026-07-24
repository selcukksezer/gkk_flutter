import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/codex_model.dart';
import '../../../theme/app_colors.dart';

/// Zindan sonucu — yeni kodex keşfi chip'i.
class CodexDiscoveryChip extends StatelessWidget {
  const CodexDiscoveryChip({
    super.key,
    required this.discoveries,
    this.onTap,
  });

  final List<CodexDiscovery> discoveries;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (discoveries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: discoveries.take(3).map((CodexDiscovery d) {
          final Color glow = AppColors.forRarity(d.rarity ?? 'rare');
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(
                  colors: <Color>[
                    glow.withValues(alpha: 0.25),
                    AppColors.liquidGold.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.55)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: glow.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.menu_book_rounded,
                      color: AppColors.liquidGold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Kodex: ${d.displayName}',
                    style: GoogleFonts.urbanist(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
