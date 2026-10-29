import 'dart:async';

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
import '../../season/widgets/season_reward_illustrations.dart';

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
  String? _claimingKey;

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
    if (widget.playerGems < cost) {
      AppMessenger.showError(
        context,
        'Yetersiz elmas (${widget.playerGems}/$cost). Mağazadan elmas alabilirsin.',
      );
      return;
    }

    final bool? confirmed = await UniversalGameDialog.show(
      context,
      title: 'Daeva VIP Battle Pass',
      message:
          'Sezon VIP Pass satın almak istediğine emin misin?\n\n'
          'Tüm özel Daeva ödüllerinin kilidi açılır ve sezonluk '
          'görev bonusu aktif edilir.\n\nMaliyet: $cost 💎',
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
        AppMessenger.showSuccess(
          context,
          '✨ Daeva VIP Pass başarıyla aktif edildi!',
        );
        unawaited(ref.read(playerProvider.notifier).loadProfile());
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

  Future<void> _claimReward(int level, bool isVip) async {
    final String key = 'r_${level}_${isVip ? 'vip' : 'free'}';
    if (_claimingKey != null) return;

    setState(() => _claimingKey = key);
    try {
      final bool success =
          await ref.read(battlePassProvider.notifier).claimReward(level, isVip);
      if (!mounted) return;

      if (success) {
        AppMessenger.showSuccess(
          context,
          '🎁 Seviye $level ${isVip ? 'Daeva VIP ' : ''}ödülü başarıyla alındı!',
        );
        unawaited(ref.read(playerProvider.notifier).loadProfile());
      } else {
        AppMessenger.showError(context, 'Ödül alınamadı — tekrar deneyin.');
      }
    } catch (e) {
      if (mounted) AppMessenger.showError(context, 'Hata: $e');
    } finally {
      if (mounted) setState(() => _claimingKey = null);
    }
  }

  List<BpSeasonRewardEntry> _getFeaturedVip(BattlePassState state) {
    if (state.featuredVip.isNotEmpty) return state.featuredVip;
    final List<BpSeasonRewardEntry> list = <BpSeasonRewardEntry>[];
    for (final BpLevelReward r in state.rewards) {
      if (r.vipRewardItemId != null || r.vipRewardGold > 0) {
        if (r.level == 5 || r.level == 10 || r.level == 15 || r.level == 20 || list.length < 3) {
          list.add(
            BpSeasonRewardEntry(
              track: 'vip',
              level: r.level,
              rewardType: r.vipRewardGold > 0 ? 'gold' : 'item',
              gold: r.vipRewardGold,
              gems: 0,
              quantity: r.vipRewardQuantity,
              itemId: r.vipRewardItemId,
              displayName: (r.vipRewardItem?['name'] as String?) ??
                  (r.vipRewardGold > 0 ? '${r.vipRewardGold} Altın' : 'VIP Ödülü'),
              displayRarity: (r.vipRewardItem?['rarity'] as String?) ?? 'epic',
              itemName: r.vipRewardItem?['name'] as String?,
              itemRarity: r.vipRewardItem?['rarity'] as String?,
              itemIcon: r.vipRewardItem?['icon'] as String?,
              isFeatured: true,
            ),
          );
          if (list.length >= 3) break;
        }
      }
    }
    return list;
  }

  List<BpSeasonRewardEntry> _getFeaturedFree(BattlePassState state) {
    if (state.featuredFree.isNotEmpty) return state.featuredFree;
    final List<BpSeasonRewardEntry> list = <BpSeasonRewardEntry>[];
    for (final BpLevelReward r in state.rewards) {
      if (r.normalRewardItemId != null || r.normalRewardGold > 0) {
        if (r.level == 5 || r.level == 10 || r.level == 15 || r.level == 20 || list.length < 3) {
          list.add(
            BpSeasonRewardEntry(
              track: 'free',
              level: r.level,
              rewardType: r.normalRewardGold > 0 ? 'gold' : 'item',
              gold: r.normalRewardGold,
              gems: 0,
              quantity: r.normalRewardQuantity,
              itemId: r.normalRewardItemId,
              displayName: (r.normalRewardItem?['name'] as String?) ??
                  (r.normalRewardGold > 0 ? '${r.normalRewardGold} Altın' : 'Ücretsiz Ödül'),
              displayRarity: (r.normalRewardItem?['rarity'] as String?) ?? 'rare',
              itemName: r.normalRewardItem?['name'] as String?,
              itemRarity: r.normalRewardItem?['rarity'] as String?,
              itemIcon: r.normalRewardItem?['icon'] as String?,
              isFeatured: true,
            ),
          );
          if (list.length >= 3) break;
        }
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final BattlePassState bpState = ref.watch(battlePassProvider);
    final BpSeason? season = bpState.activeSeason;
    final BpPlayerStatus? status = bpState.status;
    final bool hasVip = status?.hasVip ?? false;
    final int cost = EconomyConstants.battlePassVipGemCost;
    final bool canAfford = widget.playerGems >= cost;

    if (bpState.isLoading && season == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.liquidGold),
      );
    }

    if (season == null) {
      return Center(
        child: Padding(
          padding: GameScrollLayout.withClearance(context, const EdgeInsets.all(24)),
          child: _AionGlassPanel(
            borderColor: AppColors.liquidGold.withValues(alpha: 0.3),
            glowColor: AppColors.liquidGold.withValues(alpha: 0.1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        AppColors.liquidGold.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.liquidGold.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.military_tech_outlined,
                    size: 32,
                    color: AppColors.liquidGold,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Aktif Sezon Bulunamadı',
                  style: GoogleFonts.urbanist(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Yeni sezon başladığında VIP Pass ve özel ödül parkuru burada açılacak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedTitanium,
                    fontSize: 13,
                    height: 1.4,
                  ),
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
    final List<BpSeasonRewardEntry> featuredVip = _getFeaturedVip(bpState);
    final List<BpSeasonRewardEntry> featuredFree = _getFeaturedFree(bpState);

    // Unclaimed rewards count calculation
    int unclaimedRewardsCount = 0;
    final List<int> claimedNormal = status?.claimedNormal ?? const <int>[];
    final List<int> claimedVip = status?.claimedVip ?? const <int>[];
    for (final BpLevelReward r in bpState.rewards) {
      if (r.level <= 0 || r.level > level) continue;
      if (!claimedNormal.contains(r.level)) unclaimedRewardsCount++;
      if (hasVip && !claimedVip.contains(r.level)) unclaimedRewardsCount++;
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: GameScrollLayout.fromLTRB(
        context,
        left: 14,
        top: 6,
        right: 14,
        bottomExtra: 32,
      ),
      children: <Widget>[
        _VipPassHeroPanel(
          cost: cost,
          hasVip: hasVip,
          canAfford: canAfford,
          buying: _buying,
          playerGems: widget.playerGems,
          onBuy: _buyVipPass,
        ),
        if (unclaimedRewardsCount > 0) ...<Widget>[
          const SizedBox(height: 14),
          _UnclaimedRewardsBanner(
            count: unclaimedRewardsCount,
            level: level,
            onNavigate: () => context.push(AppRoutes.season),
          ),
        ],
        const SizedBox(height: 14),
        _SeasonInfoCard(
          season: season,
          level: level,
          progress: progress,
          xpInLevel: xpInLevel,
          hasVip: hasVip,
        ),
        if (featuredVip.isNotEmpty || featuredFree.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _RewardShowcaseRow(
            featuredVip: featuredVip,
            featuredFree: featuredFree,
            currentLevel: level,
            hasVip: hasVip,
            claimedNormal: claimedNormal,
            claimedVip: claimedVip,
            claimingKey: _claimingKey,
            onClaim: _claimReward,
          ),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => context.push(AppRoutes.season),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.accentCyan.withValues(alpha: 0.18),
                  AppColors.spaceNavy.withValues(alpha: 0.90),
                ],
              ),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.explore_rounded,
                  size: 20,
                  color: AppColors.accentCyan,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Tüm Sezon Parkurunu ve Görevlerini Gör →',
                      style: GoogleFonts.urbanist(
                        color: AppColors.accentCyan,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    required this.playerGems,
    required this.onBuy,
  });

  final int cost;
  final bool hasVip;
  final bool canAfford;
  final bool buying;
  final int playerGems;
  final VoidCallback onBuy;

  @override
  State<_VipPassHeroPanel> createState() => _VipPassHeroPanelState();
}

class _VipPassHeroPanelState extends State<_VipPassHeroPanel> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return _AionGlassPanel(
      borderColor: AppColors.liquidGold.withValues(alpha: widget.hasVip ? 0.45 : 0.65),
      glowColor: AppColors.liquidGold.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.liquidGold.withValues(alpha: 0.4),
                      AppColors.liquidGold.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.8),
                    width: 1.8,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.3),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.liquidGold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'DAEVA VIP PASS',
                              style: GoogleFonts.urbanist(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.liquidGold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.liquidGold.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'SEZONLUK',
                            style: TextStyle(
                              color: AppColors.liquidGold,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Özel Daeva Ödül Hattı & Sezonluk BPP Güçlendirmesi',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.8,
              ),
            ),
            child: const Column(
              children: <Widget>[
                _VipPerkBullet(
                  icon: Icons.auto_awesome_rounded,
                  text: '20+ Seçkin Daeva Ödülü (Kanatlar, Silahlar, Sandıklar)',
                ),
                SizedBox(height: 5),
                _VipPerkBullet(
                  icon: Icons.bolt_rounded,
                  text: 'Tüm Sezon Görevlerinde %50 Ekstra BPP Kazancı',
                ),
                SizedBox(height: 5),
                _VipPerkBullet(
                  icon: Icons.shield_rounded,
                  text: 'Altın Daeva İsimliği & Özel Profil Rozeti',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Icon(
                Icons.diamond_rounded,
                color: AppColors.accentCyan,
                size: 20,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${widget.cost} 💎 / Sezon',
                    style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Bakiye: ',
                      style: TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${widget.playerGems} 💎',
                      style: TextStyle(
                        color: widget.canAfford
                            ? Colors.white
                            : AppColors.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.hasVip)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.liquidGold.withValues(alpha: 0.14),
                border: Border.all(
                  color: AppColors.liquidGold.withValues(alpha: 0.55),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.liquidGold,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '✓ BU SEZON DAEVA VIP PASS AKTİF',
                        style: GoogleFonts.urbanist(
                          color: AppColors.liquidGold,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
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
                scale: _pressed && !widget.buying && widget.canAfford ? 0.96 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
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
                        alpha: widget.canAfford ? 0.75 : 0.2,
                      ),
                      width: 1.2,
                    ),
                    boxShadow: widget.canAfford && !widget.buying
                        ? <BoxShadow>[
                            BoxShadow(
                              color: AppColors.liquidGold.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
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
                        const Icon(
                          Icons.diamond_rounded,
                          size: 18,
                          color: AppColors.carbonVoid,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'VIP Pass Satın Al (${widget.cost} 💎)',
                              style: const TextStyle(
                                color: AppColors.carbonVoid,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.3,
                              ),
                            ),
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
              'Yetersiz elmas — Mağaza Gem sekmesinden elmas temin edebilirsin.',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VipPerkBullet extends StatelessWidget {
  const _VipPerkBullet({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 13, color: AppColors.liquidGold),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _UnclaimedRewardsBanner extends StatelessWidget {
  const _UnclaimedRewardsBanner({
    required this.count,
    required this.level,
    required this.onNavigate,
  });

  final int count;
  final int level;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return _AionGlassPanel(
      borderColor: AppColors.liquidGold.withValues(alpha: 0.65),
      glowColor: AppColors.liquidGold.withValues(alpha: 0.20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  AppColors.liquidGold.withValues(alpha: 0.4),
                  AppColors.liquidGold.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppColors.liquidGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$count Alınabilir Sezon Ödülü!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    color: AppColors.liquidGold,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sv $level\'e kadar kazandığın ödüller seni bekliyor.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedTitanium,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.loose,
            child: GestureDetector(
              onTap: onNavigate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  gradient: AppColors.liquidGoldGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Ödülleri Al',
                    style: TextStyle(
                      color: AppColors.carbonVoid,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonInfoCard extends StatelessWidget {
  const _SeasonInfoCard({
    required this.season,
    required this.level,
    required this.progress,
    required this.xpInLevel,
    required this.hasVip,
  });

  final BpSeason season;
  final int level;
  final double progress;
  final int xpInLevel;
  final bool hasVip;

  @override
  Widget build(BuildContext context) {
    final Duration remaining = season.endAt.difference(DateTime.now());
    final int daysLeft = remaining.inDays.clamp(0, 9999);
    final String countdownText = daysLeft > 0
        ? '$daysLeft gün kaldı'
        : (remaining.inHours > 0
            ? '${remaining.inHours} saat kaldı'
            : (remaining.inMinutes > 0 ? '${remaining.inMinutes} dk kaldı' : 'Son anlar!'));

    return _AionGlassPanel(
      borderColor: AppColors.liquidGold.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.military_tech_rounded,
                color: AppColors.liquidGold,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'SEZON ${season.seasonNumber}',
                              style: GoogleFonts.urbanist(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                color: AppColors.liquidGold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.timer_outlined,
                                size: 10,
                                color: AppColors.mutedTitanium,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                countdownText,
                                style: const TextStyle(
                                  color: AppColors.mutedTitanium,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bitiş: ${season.endAt.day.toString().padLeft(2, '0')}.${season.endAt.month.toString().padLeft(2, '0')}.${season.endAt.year}',
                      style: const TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasVip)
                Flexible(
                  fit: FlexFit.loose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.liquidGold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 12,
                          color: AppColors.liquidGold,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'VIP AKTİF',
                          style: TextStyle(
                            color: AppColors.liquidGold,
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.liquidGold.withValues(alpha: 0.28),
                      const Color(0xFF151928),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.liquidGold,
                    width: 1.8,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      'SV',
                      style: TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$level',
                          style: GoogleFonts.urbanist(
                            color: AppColors.liquidGold,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'BPP İlerlemesi',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '%${(progress * 100).toInt()}',
                          style: const TextStyle(
                            color: AppColors.liquidGold,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.liquidGold,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '$xpInLevel / 1000 BPP',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.liquidGold,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Seviye ${level + 1} için ${1000 - xpInLevel} BPP',
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.mutedTitanium,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardShowcaseRow extends StatelessWidget {
  const _RewardShowcaseRow({
    required this.featuredVip,
    required this.featuredFree,
    required this.currentLevel,
    required this.hasVip,
    required this.claimedNormal,
    required this.claimedVip,
    required this.claimingKey,
    required this.onClaim,
  });

  final List<BpSeasonRewardEntry> featuredVip;
  final List<BpSeasonRewardEntry> featuredFree;
  final int currentLevel;
  final bool hasVip;
  final List<int> claimedNormal;
  final List<int> claimedVip;
  final String? claimingKey;
  final void Function(int level, bool isVip) onClaim;

  @override
  Widget build(BuildContext context) {
    return _AionGlassPanel(
      borderColor: AppColors.liquidGold.withValues(alpha: 0.45),
      glowColor: AppColors.liquidGold.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.liquidGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Sezonun Seçkin Ödülleri',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'VIP ve Ücretsiz hatların öne çıkan prestij eşyaları',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _ShowcaseColumn(
                    title: 'Daeva VIP Hattı',
                    accent: AppColors.liquidGold,
                    rewards: featuredVip,
                    currentLevel: currentLevel,
                    hasVip: hasVip,
                    claimedNormal: claimedNormal,
                    claimedVip: claimedVip,
                    claimingKey: claimingKey,
                    isVipTrack: true,
                    staggerOffset: 0,
                    onClaim: onClaim,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShowcaseColumn(
                    title: 'Ücretsiz Hat',
                    accent: AppColors.accentCyan,
                    rewards: featuredFree,
                    currentLevel: currentLevel,
                    hasVip: hasVip,
                    claimedNormal: claimedNormal,
                    claimedVip: claimedVip,
                    claimingKey: claimingKey,
                    isVipTrack: false,
                    staggerOffset: 1,
                    onClaim: onClaim,
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
    required this.currentLevel,
    required this.hasVip,
    required this.claimedNormal,
    required this.claimedVip,
    required this.claimingKey,
    required this.isVipTrack,
    required this.staggerOffset,
    required this.onClaim,
  });

  final String title;
  final Color accent;
  final List<BpSeasonRewardEntry> rewards;
  final int currentLevel;
  final bool hasVip;
  final List<int> claimedNormal;
  final List<int> claimedVip;
  final String? claimingKey;
  final bool isVipTrack;
  final int staggerOffset;
  final void Function(int level, bool isVip) onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF090D18).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isVipTrack ? Icons.workspace_premium_rounded : Icons.card_giftcard_rounded,
                color: accent,
                size: 15,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    color: accent,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${rewards.length}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rewards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Ödül yok',
                  style: TextStyle(
                    color: AppColors.mutedTitanium,
                    fontSize: 11,
                  ),
                ),
              ),
            )
          else
            ...rewards.asMap().entries.map((MapEntry<int, BpSeasonRewardEntry> e) {
              final BpSeasonRewardEntry reward = e.value;
              final bool reached = currentLevel >= reward.level && reward.level > 0;
              final bool claimed = isVipTrack
                  ? claimedVip.contains(reward.level)
                  : claimedNormal.contains(reward.level);
              final bool canClaim = reached && (!isVipTrack || hasVip) && !claimed;
              final bool lockedByVip = reached && isVipTrack && !hasVip;
              final bool isClaiming = claimingKey == 'r_${reward.level}_${isVipTrack ? 'vip' : 'free'}';

              return Padding(
                padding: EdgeInsets.only(bottom: e.key < rewards.length - 1 ? 8 : 0),
                child: _StaggerRewardTile(
                  index: e.key + staggerOffset,
                  reward: reward,
                  accent: accent,
                  isVip: isVipTrack,
                  reached: reached,
                  claimed: claimed,
                  canClaim: canClaim,
                  lockedByVip: lockedByVip,
                  isClaiming: isClaiming,
                  onClaim: () => onClaim(reward.level, isVipTrack),
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
    required this.reached,
    required this.claimed,
    required this.canClaim,
    required this.lockedByVip,
    required this.isClaiming,
    required this.onClaim,
  });

  final int index;
  final BpSeasonRewardEntry reward;
  final Color accent;
  final bool isVip;
  final bool reached;
  final bool claimed;
  final bool canClaim;
  final bool lockedByVip;
  final bool isClaiming;
  final VoidCallback onClaim;

  @override
  State<_StaggerRewardTile> createState() => _StaggerRewardTileState();
}

class _StaggerRewardTileState extends State<_StaggerRewardTile> {
  bool _pressed = false;

  void _showRewardInfo() {
    UniversalGameDialog.show(
      context,
      title: 'Sezon Ödülü (Sv ${widget.reward.level})',
      message:
          '${widget.reward.label}\n'
          'Kademe: ${widget.isVip ? 'Daeva VIP Hattı' : 'Ücretsiz Hat'}\n'
          'Nadirlik: ${widget.reward.effectiveRarity.toUpperCase()}\n\n'
          '${widget.claimed ? "✓ Bu ödülü zaten teslim aldın." : widget.canClaim ? "🎁 Bu ödül alınabilir! Al butonuna dokun." : widget.lockedByVip ? "🔒 Bu ödülü almak için Daeva VIP Pass gereklidir." : "🔒 Bu ödüle ulaşmak için Seviye ${widget.reward.level} olmalısın."}',
      confirmLabel: 'Tamam',
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = AppColors.forRarity(widget.reward.effectiveRarity);
    final Color glowColor = widget.isVip ? AppColors.liquidGold : rarityColor;

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('bp_show_${widget.reward.id ?? widget.reward.level}_${widget.index}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + widget.index * 60),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.canClaim ? widget.onClaim : _showRewardInfo,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.canClaim
                    ? AppColors.liquidGold.withValues(alpha: 0.8)
                    : widget.isVip
                        ? AppColors.liquidGold.withValues(alpha: 0.45)
                        : rarityColor.withValues(alpha: 0.35),
                width: widget.canClaim ? 1.4 : 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: (widget.canClaim ? AppColors.liquidGold : glowColor).withValues(
                    alpha: widget.canClaim ? 0.28 : 0.12,
                  ),
                  blurRadius: widget.canClaim ? 12 : 8,
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  widget.canClaim
                      ? const Color(0xFF262015)
                      : const Color(0xFF131826),
                  const Color(0xFF090D16),
                ],
              ),
            ),
            child: Row(
              children: <Widget>[
                // Visual pedestal
                _buildVisualPedestal(rarityColor),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: widget.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Sv ${widget.reward.level}',
                              style: TextStyle(
                                color: widget.accent,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _buildStatusBadge(),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.reward.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualPedestal(Color rarityColor) {
    final bool useSpecialIllustration = widget.reward.level == 20 ||
        widget.reward.level == 15 ||
        widget.reward.level == 10 ||
        widget.reward.level == 5 ||
        widget.reward.gold > 0 ||
        (widget.reward.itemName?.toLowerCase().contains('kanat') ?? false) ||
        (widget.reward.itemName?.toLowerCase().contains('sandık') ?? false) ||
        (widget.reward.itemName?.toLowerCase().contains('silah') ?? false);

    if (useSpecialIllustration) {
      return SeasonRewardIllustrationView.fromReward(
        level: widget.reward.level,
        isVip: widget.isVip,
        itemId: widget.reward.itemId,
        item: <String, dynamic>{
          'name': widget.reward.itemName ?? widget.reward.displayName,
          'rarity': widget.reward.effectiveRarity,
          'icon': widget.reward.itemIcon,
        },
        gold: widget.reward.gold,
        size: 34,
      );
    }

    if (widget.reward.itemId != null) {
      return ItemIconView(
        itemId: widget.reward.itemId,
        iconValue: widget.reward.itemIcon ?? '',
        size: 34,
      );
    }

    return Container(
      width: 34,
      height: 34,
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
        size: 18,
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (widget.isClaiming) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.liquidGold,
        ),
      );
    }

    if (widget.claimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0x2222C55E),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0x6622C55E), width: 0.6),
        ),
        child: const Text(
          'ALINDI',
          style: TextStyle(
            color: Color(0xFF4ADE80),
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    if (widget.canClaim) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          gradient: AppColors.liquidGoldGradient,
          borderRadius: BorderRadius.circular(5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.liquidGold.withValues(alpha: 0.45),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Text(
          'AL',
          style: TextStyle(
            color: AppColors.carbonVoid,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    if (widget.lockedByVip) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0x26B8860B),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.liquidGold.withValues(alpha: 0.4),
            width: 0.6,
          ),
        ),
        child: const Text(
          'VIP',
          style: TextStyle(
            color: AppColors.liquidGold,
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return const Icon(
      Icons.lock_rounded,
      size: 11,
      color: Color(0x55FFFFFF),
    );
  }
}

class _AionGlassPanel extends StatelessWidget {
  const _AionGlassPanel({
    required this.child,
    this.padding,
    this.borderRadius = 16.0,
    this.borderColor,
    this.glowColor,
    this.glowRadius = 14.0,
    this.hasShine = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? glowColor;
  final double glowRadius;
  final bool hasShine;

  @override
  Widget build(BuildContext context) {
    final Color border = borderColor ?? AppColors.liquidGold.withValues(alpha: 0.28);
    final Color glow = glowColor ?? AppColors.liquidGold.withValues(alpha: 0.10);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1.0),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: glow,
            blurRadius: glowRadius,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF04060A).withValues(alpha: 0.65),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF131929).withValues(alpha: 0.90),
            const Color(0xFF090D16).withValues(alpha: 0.96),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(
                painter: DotGridPainter(spacing: 14, dotOpacity: 0.045),
              ),
            ),
            if (hasShine)
              Positioned(
                top: 0,
                left: 14,
                right: 14,
                height: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        border.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: padding ?? const EdgeInsets.all(14),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
