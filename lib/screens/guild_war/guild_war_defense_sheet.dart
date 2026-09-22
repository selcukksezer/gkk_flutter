import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../l10n/l10n.dart';
import 'widgets/guild_war_design.dart';

Future<int?> showGuildWarDefenseSheet(
  BuildContext context, {
  int minDefenseGems = 5,
  int? vaultGold,
  double? playerGems,
  String title = '💎 Elmas Savunma',
  String rateLabel = '1💎 = +10 savunma',
  String gainLabel = 'Savunma',
  String footnote =
      'Her an eklenebilir. Bölge kaybedilirse elmas savunması sıfırlanır. Garnizon gücü ayrı.',
  String? submitLabel,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (ctx) => _DefenseSheet(
      minDefenseGems: minDefenseGems,
      playerGems: playerGems,
      title: title,
      rateLabel: rateLabel,
      gainLabel: gainLabel,
      footnote: footnote,
      submitLabel: submitLabel,
    ),
  );
}

/// Attack-side gem boost sheet (same 1💎=+10 rate).
Future<int?> showGuildWarAttackGemSheet(
  BuildContext context, {
  int minGems = 5,
  double? playerGems,
}) {
  return showGuildWarDefenseSheet(
    context,
    minDefenseGems: minGems,
    playerGems: playerGems,
    title: '💎 Elmas Saldırı Desteği',
    rateLabel: '1💎 = +10 saldırı',
    gainLabel: 'Saldırı',
    footnote:
        'Açık plan varken eklenebilir. Süre yok — plan saldırıya dönüşene kadar kalır.',
    submitLabel: 'Saldırıya ekle',
  );
}

/// Legacy alias — gold mode removed; amount is always gems.
class GuildWarDefenseRequest {
  const GuildWarDefenseRequest({required this.amount});

  final int amount;
  bool get isGems => true;
}

class _DefenseSheet extends ConsumerStatefulWidget {
  const _DefenseSheet({
    required this.minDefenseGems,
    this.playerGems,
    this.title = '💎 Elmas Savunma',
    this.rateLabel = '1💎 = +10 savunma',
    this.gainLabel = 'Savunma',
    this.footnote =
        'Her an eklenebilir. Bölge kaybedilirse elmas savunması sıfırlanır. Garnizon gücü ayrı.',
    this.submitLabel,
  });

  final int minDefenseGems;
  final double? playerGems;
  final String title;
  final String rateLabel;
  final String gainLabel;
  final String footnote;
  final String? submitLabel;

  @override
  ConsumerState<_DefenseSheet> createState() => _DefenseSheetState();
}

class _DefenseSheetState extends ConsumerState<_DefenseSheet> {
  double _gems = 5;

  @override
  void initState() {
    super.initState();
    final int min = widget.minDefenseGems.clamp(1, _maxGems);
    _gems = min.toDouble();
  }

  int get _maxGems {
    final double available = widget.playerGems ?? 100;
    return available.floor().clamp(1, 500);
  }

  int get _minGems => widget.minDefenseGems.clamp(1, _maxGems);

  bool get _canAffordGems => (widget.playerGems ?? _gems) >= _gems;
  bool get _meetsMin => _gems.round() >= widget.minDefenseGems;
  bool get _canSubmit => _canAffordGems && _meetsMin && _maxGems >= widget.minDefenseGems;

  @override
  Widget build(BuildContext context) {
    final int defenseGain = (_gems * 10).round();
    final double? playerGems = widget.playerGems;
    final double sliderMin = _minGems.toDouble();
    final double sliderMax = _maxGems.toDouble();
    final bool tooPoor = _maxGems < widget.minDefenseGems;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
        MediaQuery.of(context).padding.bottom + AppSpacing.base,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (playerGems != null)
            Text(
              'Mevcut: 💎 ${playerGems.round()} Elmas',
              style: const TextStyle(
                color: WarPalette.gold,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Zorunlu min: ${widget.minDefenseGems} elmas · ${widget.rateLabel}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            widget.footnote,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          if (tooPoor)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Min elmas için yeterli bakiyen yok.',
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            )
          else
            Slider(
              value: _gems.clamp(sliderMin, sliderMax),
              min: sliderMin,
              max: sliderMax,
              divisions: (sliderMax - sliderMin).round().clamp(1, 499),
              activeColor: WarPalette.gold,
              onChanged: (double v) => setState(() => _gems = v),
            ),
          Text('💎 ${_gems.round()} Elmas', style: const TextStyle(color: WarPalette.gold)),
          if (!_canAffordGems)
            const Text(
              'Yetersiz elmas',
              style: TextStyle(color: AppColors.danger, fontSize: 11),
            ),
          const SizedBox(height: 4),
          Text(
            '+$defenseGain ${widget.gainLabel}',
            style: const TextStyle(color: AppColors.success, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit
                  ? () => Navigator.pop(context, _gems.round())
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(widget.submitLabel ?? context.l10n.savunma_ekle_2),
            ),
          ),
        ],
      ),
    );
  }
}
