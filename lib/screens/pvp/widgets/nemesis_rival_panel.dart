import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../models/nemesis_model.dart';
import '../../../theme/app_colors.dart';

typedef NemesisAction = void Function(String rivalId);

class NemesisRivalPanel extends StatelessWidget {
  const NemesisRivalPanel({
    super.key,
    required this.rival,
    this.onRevenge,
    required this.onDismiss,
    this.dismissLoading = false,
  });

  final NemesisRival rival;
  final NemesisAction? onRevenge;
  final VoidCallback onDismiss;
  final bool dismissLoading;

  @override
  Widget build(BuildContext context) {
    if (!rival.hasRival) return const SizedBox.shrink();

    return DottedPanel(
      borderColor: AppColors.mysticRuby.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.mysticRuby.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppColors.mysticRuby.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'NEMESIS',
                  style: TextStyle(
                    color: AppColors.mysticRuby,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              if (rival.online)
                Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.toxicNeon,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Çevrimiçi',
                      style: TextStyle(color: AppColors.toxicNeon, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rival.rivalUsername ?? 'Rakip',
            style: GoogleFonts.urbanist(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${rival.losses} yenilgi · ${rival.wins} galibiyet · Lv ${rival.level}',
            style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
          ),
          if (rival.leaderboardGap > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Sıralama farkı: ${rival.leaderboardGap} güç',
                style: const TextStyle(color: AppColors.warningSolar, fontSize: 11),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: rival.rivalId == null ||
                          rival.level < 5 ||
                          onRevenge == null
                      ? null
                      : () => onRevenge!(rival.rivalId!),
                  icon: const Icon(Icons.sports_mma_rounded, size: 18),
                  label: const Text('Düello Gönder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mysticRuby,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.darkObsidian,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: dismissLoading ? null : onDismiss,
                tooltip: '24 saat gizle',
                icon: dismissLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close_rounded, color: AppColors.mutedTitanium),
              ),
            ],
          ),
          if (rival.level < 5)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Hedef 5. seviyenin altında — düello kapalı.',
                style: TextStyle(color: AppColors.coralFlare, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
