import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/common/item_icon_view.dart';
import '../../../components/common/universal_game_dialog.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../core/constants/economy_constants.dart';
import '../../../models/battle_pass.dart';
import '../../../providers/battle_pass_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';

class BattlePassShopTab extends ConsumerStatefulWidget {
  const BattlePassShopTab({
    super.key,
    required this.playerGems,
  });

  final int playerGems;

  @override
  ConsumerState<BattlePassShopTab> createState() => _BattlePassShopTabState();
}

class _BattlePassShopTabState extends ConsumerState<BattlePassShopTab> {
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(battlePassProvider.notifier).loadAll();
    });
  }

  Future<void> _buyVipPass() async {
    if (_buying) return;

    final int cost = EconomyConstants.battlePassVipGemCost;
    final bool? confirmed = await UniversalGameDialog.show(
      context,
      title: 'VIP Battle Pass',
      message:
          'Sezon VIP Pass satın almak istediğine emin misin?\n'
          'Maliyet: $cost 💎',
      confirmLabel: 'Satın Al',
      cancelLabel: 'İptal',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _buying = true);
    try {
      final Map<String, dynamic> result =
          await ref.read(battlePassProvider.notifier).buyVipPass();
      if (!mounted) return;

      if (result['success'] == true) {
        AppMessenger.showSuccess(context, 'VIP Pass başarıyla aktif edildi!');
        await ref.read(playerProvider.notifier).loadProfile();
      } else {
        AppMessenger.showError(
          context,
          result['error']?.toString() ?? 'Satın alma başarısız.',
        );
      }
    } catch (e) {
      if (mounted) AppMessenger.showError(context, 'Hata: $e');
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bpState = ref.watch(battlePassProvider);
    final season = bpState.activeSeason;
    final status = bpState.status;
    final bool hasVip = status?.hasVip ?? false;
    final int cost = EconomyConstants.battlePassVipGemCost;
    final bool canAfford = widget.playerGems >= cost;

    if (bpState.isLoading && season == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (season == null) {
      return Center(
        child: Padding(
          padding: GameScrollLayout.withClearance(context, const EdgeInsets.all(24)),
          child: DottedPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.military_tech_outlined,
                    size: 48, color: AppColors.mutedTitanium),
                const SizedBox(height: 12),
                Text(
                  'Aktif sezon yok',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Yeni sezon başladığında VIP Pass burada satılacak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedTitanium, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final int level = status?.currentLevel ?? 1;
    final int bpp = status?.currentBpp ?? 0;
    final int xpInLevel = bpp % 1000;
    final double progress = (xpInLevel / 1000).clamp(0.0, 1.0);
    final List<BpSeasonRewardEntry> featuredVip = bpState.featuredVip;
    final List<BpSeasonRewardEntry> featuredFree = bpState.featuredFree;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: GameScrollLayout.fromLTRB(
        context,
        left: 14,
        top: 4,
        right: 14,
        bottomExtra: 32,
      ),
      children: <Widget>[
        _VipPassHeroPanel(
          cost: cost,
          hasVip: hasVip,
          canAfford: canAfford,
          buying: _buying,
          onBuy: _buyVipPass,
        ),
        if (featuredVip.isNotEmpty || featuredFree.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _RewardShowcaseRow(
            featuredVip: featuredVip,
            featuredFree: featuredFree,
          ),
        ],
        const SizedBox(height: 14),
        DottedPanel(
          borderColor: AppColors.liquidGold.withValues(alpha: 0.45),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.military_tech_rounded,
                      color: AppColors.liquidGold, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'SEZON ${season.seasonNumber}',
                          style: GoogleFonts.urbanist(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppColors.liquidGold,
                          ),
                        ),
                        Text(
                          'Bitiş: ${season.endAt.day}/${season.endAt.month}/${season.endAt.year}',
                          style: const TextStyle(
                            color: AppColors.mutedTitanium,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasVip)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.liquidGold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.liquidGold.withValues(alpha: 0.55),
                        ),
                      ),
                      child: const Text(
                        'VIP AKTİF',
                        style: TextStyle(
                          color: AppColors.liquidGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.liquidGold.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.liquidGold, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '$level',
                        style: const TextStyle(
                          color: AppColors.liquidGold,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'BPP İlerlemesi',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.liquidGold,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$xpInLevel / 1000 BPP',
                          style: const TextStyle(
                            color: AppColors.liquidGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.season),
          icon: const Icon(Icons.ac_unit_rounded, size: 18),
          label: const Text('Ödülleri & Görevleri Gör'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentCyan,
            side: BorderSide(color: AppColors.accentCyan.withValues(alpha: 0.45)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _VipPassHeroPanel extends StatefulWidget {
  const _VipPassHeroPanel({
    required this.cost,
    required this.hasVip,
    required this.canAfford,
    required this.buying,
    required this.onBuy,
  });

  final int cost;
  final bool hasVip;
  final bool canAfford;
  final bool buying;
  final VoidCallback onBuy;

  @override
  State<_VipPassHeroPanel> createState() => _VipPassHeroPanelState();
}

class _VipPassHeroPanelState extends State<_VipPassHeroPanel> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      borderColor: AppColors.liquidGold.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.liquidGold.withValues(alpha: 0.35),
                      AppColors.liquidGold.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.65),
                    width: 2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.25),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.liquidGold,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'VIP Battle Pass',
                      style: GoogleFonts.urbanist(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Premium ödül hattı · ekstra BPP görevleri',
                      style: TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Icon(Icons.diamond_rounded,
                  color: AppColors.accentCyan, size: 20),
              const SizedBox(width: 6),
              Text(
                '${widget.cost} 💎 / sezon',
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.hasVip)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.liquidGold.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.liquidGold.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                '✓ Bu sezon VIP Pass sahibisin',
                style: TextStyle(
                  color: AppColors.liquidGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            )
          else
            GestureDetector(
              onTapDown: (widget.buying || !widget.canAfford)
                  ? null
                  : (_) => setState(() => _pressed = true),
              onTapUp: (widget.buying || !widget.canAfford)
                  ? null
                  : (_) => setState(() => _pressed = false),
              onTapCancel: (widget.buying || !widget.canAfford)
                  ? null
                  : () => setState(() => _pressed = false),
              onTap: (widget.buying || !widget.canAfford) ? null : widget.onBuy,
              child: AnimatedScale(
                scale: _pressed && !widget.buying && widget.canAfford ? 0.96 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: (widget.buying || !widget.canAfford)
                        ? null
                        : AppColors.liquidGoldGradient,
                    color: (widget.buying || !widget.canAfford)
                        ? AppColors.darkObsidian.withValues(alpha: 0.55)
                        : null,
                    border: Border.all(
                      color: AppColors.liquidGold.withValues(
                        alpha: widget.canAfford ? 0.65 : 0.2,
                      ),
                    ),
                    boxShadow: widget.canAfford && !widget.buying
                        ? <BoxShadow>[
                            BoxShadow(
                              color: AppColors.liquidGold.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (widget.buying)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.carbonVoid,
                          ),
                        )
                      else ...<Widget>[
                        const Icon(Icons.diamond, size: 18, color: AppColors.carbonVoid),
                        const SizedBox(width: 8),
                        Text(
                          'VIP Pass Satın Al (${widget.cost} 💎)',
                          style: const TextStyle(
                            color: AppColors.carbonVoid,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (!widget.hasVip && !widget.canAfford) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Yetersiz elmas — Gem sekmesinden elmas al.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.danger, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardShowcaseRow extends StatelessWidget {
  const _RewardShowcaseRow({
    required this.featuredVip,
    required this.featuredFree,
  });

  final List<BpSeasonRewardEntry> featuredVip;
  final List<BpSeasonRewardEntry> featuredFree;

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      borderColor: AppColors.liquidGold.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Sezonun En İyi Ödülleri',
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'VIP ve ücretsiz hattın öne çıkan ödülleri',
            style: TextStyle(color: AppColors.mutedTitanium, fontSize: 11),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _ShowcaseColumn(
                    title: 'VIP Pass Ödülleri',
                    accent: AppColors.liquidGold,
                    rewards: featuredVip,
                    staggerOffset: 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ShowcaseColumn(
                    title: 'Ücretsiz Pass',
                    accent: AppColors.accentCyan,
                    rewards: featuredFree,
                    staggerOffset: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseColumn extends StatelessWidget {
  const _ShowcaseColumn({
    required this.title,
    required this.accent,
    required this.rewards,
    required this.staggerOffset,
  });

  final String title;
  final Color accent;
  final List<BpSeasonRewardEntry> rewards;
  final int staggerOffset;

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      padding: const EdgeInsets.all(10),
      borderColor: accent.withValues(alpha: 0.45),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                title.contains('VIP') ? Icons.workspace_premium_rounded : Icons.card_giftcard_rounded,
                color: accent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.urbanist(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rewards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Ödül yok',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedTitanium, fontSize: 11),
              ),
            )
          else
            ...rewards.asMap().entries.map((MapEntry<int, BpSeasonRewardEntry> e) {
              return Padding(
                padding: EdgeInsets.only(bottom: e.key < rewards.length - 1 ? 8 : 0),
                child: _StaggerRewardTile(
                  index: e.key + staggerOffset,
                  reward: e.value,
                  accent: accent,
                  isVip: title.contains('VIP'),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StaggerRewardTile extends StatefulWidget {
  const _StaggerRewardTile({
    required this.index,
    required this.reward,
    required this.accent,
    required this.isVip,
  });

  final int index;
  final BpSeasonRewardEntry reward;
  final Color accent;
  final bool isVip;

  @override
  State<_StaggerRewardTile> createState() => _StaggerRewardTileState();
}

class _StaggerRewardTileState extends State<_StaggerRewardTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color glow = AppColors.forRarity(widget.reward.effectiveRarity);

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('bp_show_${widget.reward.id}_${widget.index}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + widget.index * 70),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isVip
                    ? AppColors.liquidGold.withValues(alpha: 0.55)
                    : glow.withValues(alpha: 0.4),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: glow.withValues(alpha: 0.22),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.spaceNavy.withValues(alpha: 0.85),
                  AppColors.carbonVoid.withValues(alpha: 0.95),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: DotGridPainter(spacing: 12, dotOpacity: 0.05),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      if (widget.reward.itemId != null)
                        ItemIconView(
                          itemId: widget.reward.itemId,
                          iconValue: widget.reward.itemIcon ?? '',
                          size: 40,
                        )
                      else
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.accent.withValues(alpha: 0.15),
                            border: Border.all(color: widget.accent.withValues(alpha: 0.5)),
                          ),
                          child: Icon(
                            widget.reward.gold > 0
                                ? Icons.monetization_on_rounded
                                : Icons.diamond_rounded,
                            color: widget.accent,
                            size: 22,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Sv ${widget.reward.level}',
                              style: TextStyle(
                                color: widget.accent.withValues(alpha: 0.85),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              widget.reward.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
