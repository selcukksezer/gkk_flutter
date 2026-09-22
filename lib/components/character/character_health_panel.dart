import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/player_health.dart';
import '../../models/player_model.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../common/app_messenger.dart';
import '../common/player_health_bar.dart';
import '../common/universal_game_dialog.dart';

class CharacterHealthPanel extends ConsumerStatefulWidget {
  const CharacterHealthPanel({
    super.key,
    required this.profile,
    this.inHospital = false,
    this.inPrison = false,
  });

  final PlayerProfile profile;
  final bool inHospital;
  final bool inPrison;

  @override
  ConsumerState<CharacterHealthPanel> createState() => _CharacterHealthPanelState();
}

class _CharacterHealthPanelState extends ConsumerState<CharacterHealthPanel> {
  bool _healing = false;

  bool get _restricted => widget.inHospital || widget.inPrison;

  PlayerHealthStatus get _status => resolveHealthStatus(
        health: widget.profile.health,
        maxHealth: widget.profile.maxHealth,
        restricted: _restricted,
      );

  bool get _canGemHeal =>
      !_restricted &&
      widget.profile.maxHealth > 0 &&
      widget.profile.health < widget.profile.maxHealth;

  int get _gemCost => gemHealthHealCost(
        health: widget.profile.health,
        maxHealth: widget.profile.maxHealth,
        level: widget.profile.level,
      );

  int get _secondsToFull => estimateSecondsToFullHealth(
        health: widget.profile.health,
        maxHealth: widget.profile.maxHealth,
        alchemistBonus: widget.profile.characterClass == CharacterClass.alchemist,
      );

  Future<void> _healWithGems() async {
    if (!_canGemHeal || _healing) return;

    final bool? confirm = await UniversalGameDialog.show(
      context,
      title: 'Elmas ile Can Yenile',
      message:
          'Canin tamamen dolar.\nMaliyet: $_gemCost elmas\nMevcut: ${widget.profile.gems.floor()} elmas',
      confirmLabel: 'Iyilestir',
      cancelLabel: 'Iptal',
    );
    if (confirm != true || !mounted) return;

    setState(() => _healing = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc('heal_health_with_gems');
      final Map<String, dynamic> res =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (res['success'] == true) {
        await ref.read(playerProvider.notifier).loadProfile();
        if (mounted) {
          AppMessenger.showSuccess(
            context,
            'Can yenilendi (+${res['healed'] ?? ''})',
          );
        }
      } else {
        if (mounted) {
          AppMessenger.showError(
            context,
            res['error']?.toString() ?? 'Iyilestirme basarisiz',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Iyilestirme basarisiz');
      }
    } finally {
      if (mounted) setState(() => _healing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile.maxHealth <= 0) return const SizedBox.shrink();

    final PlayerHealthStatus status = _status;
    final Color statusColor = healthStatusColor(status);
    final bool showPenalty = hasWoundedCombatPenalty(
      health: widget.profile.health,
      maxHealth: widget.profile.maxHealth,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.bgSurface.withValues(alpha: 0.55),
            AppColors.darkObsidian.withValues(alpha: 0.85),
          ],
        ),
        border: Border.all(color: statusColor.withValues(alpha: 0.45)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: statusColor.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.favorite_rounded, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text(
                'Can Durumu',
                style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  healthStatusLabel(status),
                  style: AppTextStyles.micro.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PlayerHealthBar(
            health: widget.profile.health,
            maxHealth: widget.profile.maxHealth,
            height: 10,
            showLabel: false,
            status: status,
          ),
          const SizedBox(height: 8),
          Text(
            healthStatusTip(status),
            style: AppTextStyles.micro.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (!_restricted && widget.profile.health < widget.profile.maxHealth) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.schedule_rounded, size: 12, color: AppColors.mutedTitanium),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Tam dolma: ~${formatRegenDuration(_secondsToFull)} '
                    '(${healthRegenPercentPerHour(alchemistBonus: widget.profile.characterClass == CharacterClass.alchemist).toStringAsFixed(1)}%/sa)',
                    style: AppTextStyles.micro.copyWith(color: AppColors.mutedTitanium),
                  ),
                ),
              ],
            ),
          ],
          if (showPenalty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Yarali cezasi: PvP gucu -${(woundedPvpPowerPenalty * 100).round()}%',
              style: AppTextStyles.micro.copyWith(
                color: AppColors.warningSolar,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _HealthActionButton(
                  label: 'Iksirler',
                  icon: Icons.local_drink_outlined,
                  onTap: () => context.push(AppRoutes.inventory),
                ),
              ),
              const SizedBox(width: 8),
              if (_restricted)
                Expanded(
                  child: _HealthActionButton(
                    label: widget.inHospital ? 'Hastane' : 'Hapishane',
                    icon: Icons.local_hospital_outlined,
                    accent: AppColors.mysticRuby,
                    onTap: () => context.push(
                      widget.inHospital ? AppRoutes.hospital : AppRoutes.prison,
                    ),
                  ),
                )
              else
                Expanded(
                  child: _HealthActionButton(
                    label: _canGemHeal ? 'Elmas ($_gemCost)' : 'Dolu',
                    icon: Icons.diamond_outlined,
                    accent: AppColors.accentCyan,
                    loading: _healing,
                    onTap: _canGemHeal && widget.profile.gems >= _gemCost
                        ? _healWithGems
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthActionButton extends StatelessWidget {
  const _HealthActionButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.accent,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.liquidGold;
    final bool enabled = onTap != null && !loading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Ink(
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            color: enabled ? color.withValues(alpha: 0.12) : AppColors.darkObsidian,
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.45) : AppColors.mutedTitanium.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(icon, size: 14, color: enabled ? color : AppColors.mutedTitanium),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.micro.copyWith(
                  color: enabled ? color : AppColors.mutedTitanium,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
