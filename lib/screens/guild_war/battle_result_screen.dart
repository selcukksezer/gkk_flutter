import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/guild_war_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../l10n/l10n.dart';

class BattleResultScreen extends StatefulWidget {
  const BattleResultScreen({super.key, required this.result});

  final GuildWarAttackResult result;

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final success = widget.result.success;
    final accent = success ? AppColors.gold : AppColors.danger;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              accent.withValues(alpha: 0.15),
              AppColors.bgDeep,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
                  child: InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.gold),
                          SizedBox(width: 4),
                          Text('Geri', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnim.value,
                    child: Opacity(opacity: _fadeAnim.value, child: child),
                  );
                },
                child: Column(
                  children: [
                    Text(
                      success ? '⚔' : '💥',
                      style: const TextStyle(fontSize: 64),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    Text(
                      success ? 'Bölge Ele Geçirildi!' : 'Saldırı Püskürtüldü!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                    if (widget.result.territoryName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.result.territoryName!,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  padding: const EdgeInsets.all(AppSpacing.base),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Column(
                    children: [
                      _StatRow(
                        label: context.l10n.sald_r_g_c,
                        value: '${widget.result.attackPower}',
                        color: AppColors.danger,
                      ),
                      const Divider(color: AppColors.borderFaint),
                      _StatRow(
                        label: context.l10n.savunma_g_c,
                        value: '${widget.result.defensePower}',
                        color: AppColors.accentBlue,
                      ),
                      const Divider(color: AppColors.borderFaint),
                      _StatRow(
                        label: context.l10n.kazan_lan_puan,
                        value: '+${widget.result.pointsGained}',
                        color: AppColors.gold,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: AppColors.bgDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(context.l10n.devam),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
