import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/power_helpers.dart';
import '../../core/utils/stat_allocation.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/player_provider.dart';
import '../../providers/power_change_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/app_messenger.dart';
import '../layout/game_screen_background.dart';

/// Level ile kazanılan stat puanlarını Saldırı/Savunma/Şans'a dağıtma paneli.
/// `stat_points > 0` iken karakter ekranında görünür.
class StatAllocationPanel extends ConsumerStatefulWidget {
  const StatAllocationPanel({super.key, required this.availablePoints});

  final int availablePoints;

  @override
  ConsumerState<StatAllocationPanel> createState() =>
      _StatAllocationPanelState();
}

class _StatAllocationPanelState extends ConsumerState<StatAllocationPanel> {
  int _attack = 0;
  int _defense = 0;
  int _luck = 0;
  int _health = 0;
  bool _saving = false;

  int get _pending => _attack + _defense + _luck + _health;
  int get _remaining => widget.availablePoints - _pending;

  void _bump(String stat, int delta) {
    if (_saving) return;
    if (delta > 0 && _remaining <= 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      switch (stat) {
        case 'attack':
          _attack = (_attack + delta).clamp(0, widget.availablePoints);
        case 'defense':
          _defense = (_defense + delta).clamp(0, widget.availablePoints);
        case 'luck':
          _luck = (_luck + delta).clamp(0, widget.availablePoints);
        case 'health':
          _health = (_health + delta).clamp(0, widget.availablePoints);
      }
    });
  }

  Future<void> _confirm() async {
    if (_pending <= 0 || _saving) return;
    setState(() => _saving = true);
    final int powerBefore = readPlayerTotalPower(ref);
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'allocate_stat_points',
        params: <String, dynamic>{
          'p_attack': _attack,
          'p_defense': _defense,
          'p_luck': _luck,
          'p_health': _health,
        },
      );
      final bool ok = res is Map && res['success'] == true;
      if (!mounted) return;
      if (ok) {
        HapticFeedback.mediumImpact();
        final Map<String, dynamic> data = Map<String, dynamic>.from(res);
        final int healthGain = (data['health_gain'] as num?)?.toInt() ?? 0;
        final String extra = healthGain > 0 ? ' (+$healthGain can)' : '';
        AppMessenger.showSuccess(context, '✅ $_pending puan dagitildi!$extra');
        setState(() {
          _attack = 0;
          _defense = 0;
          _luck = 0;
          _health = 0;
        });
        await ref.read(playerProvider.notifier).loadProfile();
        if (!mounted) return;
        ref.read(powerChangeProvider.notifier).emit(
              oldPower: powerBefore,
              newPower: readPlayerTotalPower(ref),
            );
      } else {
        AppMessenger.showError(context, 'Puan dağıtımı başarısız.');
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'Puan dağıtımı başarısız.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      borderColor: AppColors.liquidGold.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '⬆️ Stat Puanı Dağıt',
                  style: AppTextStyles.titleBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.liquidGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '$_remaining puan',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.liquidGold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Her level +3 puan. Can: 1 puan = +$statPointHealthMultiplier max can.',
            style: AppTextStyles.micro.copyWith(color: AppColors.mutedTitanium),
          ),
          const SizedBox(height: 4),
          Text(
            'Yanlış dağıttın mı? Dükkan → Stat Sıfırlama Kağıdı (199 💎)',
            style: AppTextStyles.micro.copyWith(
              color: AppColors.mutedTitanium.withValues(alpha: 0.85),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          _statRow('Saldırı', '⚔️', _attack, 'attack', AppColors.coralFlare),
          const SizedBox(height: 6),
          _statRow('Savunma', '🛡️', _defense, 'defense', AppColors.accentCyan),
          const SizedBox(height: 6),
          _statRow('Sans', '🍀', _luck, 'luck', AppColors.toxicNeon),
          const SizedBox(height: 6),
          _healthRow(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _pending > 0 && !_saving ? _confirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.liquidGold,
                foregroundColor: AppColors.carbonVoid,
                disabledBackgroundColor:
                    AppColors.liquidGold.withValues(alpha: 0.25),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.carbonVoid,
                      ),
                    )
                  : Text(
                      _pending > 0 ? 'Onayla (+$_pending)' : 'Puan seç',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthRow() {
    return Row(
      children: <Widget>[
        const Text('❤️', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Can',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_health > 0)
                Text(
                  statPointHealthPreviewLabel(_health),
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.mysticRuby,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  'x$statPointHealthMultiplier can / puan',
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.mutedTitanium,
                  ),
                ),
            ],
          ),
        ),
        _roundButton(Icons.remove, _health > 0 ? () => _bump('health', -1) : null),
        SizedBox(
          width: 40,
          child: Text(
            _health > 0 ? '+$_health' : '0',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: _health > 0 ? AppColors.mysticRuby : AppColors.mutedTitanium,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _roundButton(Icons.add, _remaining > 0 ? () => _bump('health', 1) : null),
      ],
    );
  }

  Widget _statRow(
    String label,
    String emoji,
    int value,
    String key,
    Color color,
  ) {
    return Row(
      children: <Widget>[
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _roundButton(Icons.remove, value > 0 ? () => _bump(key, -1) : null),
        SizedBox(
          width: 40,
          child: Text(
            value > 0 ? '+$value' : '0',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: value > 0 ? color : AppColors.mutedTitanium,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _roundButton(Icons.add, _remaining > 0 ? () => _bump(key, 1) : null),
      ],
    );
  }

  Widget _roundButton(IconData icon, VoidCallback? onTap) {
    final bool enabled = onTap != null && !_saving;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? AppColors.liquidGold.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: enabled
                ? AppColors.liquidGold.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppColors.liquidGold : AppColors.mutedTitanium,
        ),
      ),
    );
  }
}
