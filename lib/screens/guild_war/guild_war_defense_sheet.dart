import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../l10n/l10n.dart';
import 'widgets/guild_war_design.dart';

enum GuildWarDefenseMode { gems, gold }

Future<GuildWarDefenseRequest?> showGuildWarDefenseSheet(
  BuildContext context, {
  int minDefenseGems = 5,
  int? vaultGold,
  double? playerGems,
}) {
  return showModalBottomSheet<GuildWarDefenseRequest>(
    context: context,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (ctx) => _DefenseSheet(
      minDefenseGems: minDefenseGems,
      vaultGold: vaultGold,
      playerGems: playerGems,
    ),
  );
}

class GuildWarDefenseRequest {
  const GuildWarDefenseRequest({required this.mode, required this.amount});

  final GuildWarDefenseMode mode;
  final int amount;
}

class _DefenseSheet extends ConsumerStatefulWidget {
  const _DefenseSheet({
    required this.minDefenseGems,
    this.vaultGold,
    this.playerGems,
  });

  final int minDefenseGems;
  final int? vaultGold;
  final double? playerGems;

  @override
  ConsumerState<_DefenseSheet> createState() => _DefenseSheetState();
}

class _DefenseSheetState extends ConsumerState<_DefenseSheet> {
  GuildWarDefenseMode _mode = GuildWarDefenseMode.gems;
  double _gems = 5;
  double _gold = 500;

  @override
  void initState() {
    super.initState();
    _gems = widget.minDefenseGems.toDouble().clamp(1.0, _maxGems.toDouble());
    _gold = 500.0.clamp(500.0, _maxGold.toDouble());
  }

  int get _maxGems {
    final double available = widget.playerGems ?? 100;
    return available.floor().clamp(1, 100);
  }

  int get _maxGold {
    final int available = widget.vaultGold ?? 10000;
    if (available < 500) return 500;
    return available.clamp(500, 10000);
  }

  bool get _canAffordGems => (widget.playerGems ?? _gems) >= _gems;
  bool get _canAffordGold => (widget.vaultGold ?? _gold.round()) >= _gold.round();

  @override
  Widget build(BuildContext context) {
    final int defenseGain = _mode == GuildWarDefenseMode.gems
        ? (_gems * 10).round()
        : (_gold / 10).round();
    final int? vaultGold = widget.vaultGold;
    final double? playerGems = widget.playerGems;

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
          const Text(
            '🛡 Savunma Ekle',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              ChoiceChip(
                label: const Text('Elmas (prime)'),
                selected: _mode == GuildWarDefenseMode.gems,
                onSelected: (_) => setState(() => _mode = GuildWarDefenseMode.gems),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Kasa altını'),
                selected: _mode == GuildWarDefenseMode.gold,
                onSelected: (_) => setState(() => _mode = GuildWarDefenseMode.gold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_mode == GuildWarDefenseMode.gems) ...<Widget>[
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
              'Önerilen min: ${widget.minDefenseGems} elmas · 1💎 = +10 savunma',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 4),
            const Text(
              'Prime bitince elmas savunması sıfırlanır.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            Slider(
              value: _gems.clamp(1, _maxGems.toDouble()),
              min: 1,
              max: _maxGems.toDouble(),
              divisions: _maxGems > 1 ? _maxGems - 1 : 1,
              activeColor: WarPalette.gold,
              onChanged: (double v) => setState(() => _gems = v),
            ),
            Text('💎 ${_gems.round()} Elmas', style: const TextStyle(color: WarPalette.gold)),
            if (!_canAffordGems)
              const Text(
                'Yetersiz elmas',
                style: TextStyle(color: AppColors.danger, fontSize: 11),
              ),
          ] else ...<Widget>[
            if (vaultGold != null)
              Text(
                'Mevcut kasa: 🪙 $vaultGold Altın',
                style: const TextStyle(
                  color: WarPalette.neon,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              '500g = +50 kalıcı savunma · lonca kasasından düşer',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            Slider(
              value: _gold.clamp(500, _maxGold.toDouble()),
              min: 500,
              max: _maxGold.toDouble(),
              divisions: ((_maxGold - 500) ~/ 500).clamp(1, 19),
              activeColor: WarPalette.neon,
              onChanged: (double v) => setState(() => _gold = v),
            ),
            Text('🪙 ${_gold.round()} Altın', style: const TextStyle(color: WarPalette.neon)),
            if (vaultGold != null && vaultGold < 500)
              const Text(
                'Kasa en az 500g olmalı',
                style: TextStyle(color: AppColors.danger, fontSize: 11),
              )
            else if (!_canAffordGold)
              const Text(
                'Kasa yetersiz',
                style: TextStyle(color: AppColors.danger, fontSize: 11),
              ),
          ],
          const SizedBox(height: 4),
          Text(
            '+$defenseGain Savunma',
            style: const TextStyle(color: AppColors.success, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_mode == GuildWarDefenseMode.gems ? _canAffordGems : _canAffordGold)
                  ? () {
                      Navigator.pop(
                        context,
                        GuildWarDefenseRequest(
                          mode: _mode,
                          amount: _mode == GuildWarDefenseMode.gems
                              ? _gems.round()
                              : _gold.round(),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(context.l10n.savunma_ekle_2),
            ),
          ),
        ],
      ),
    );
  }
}
