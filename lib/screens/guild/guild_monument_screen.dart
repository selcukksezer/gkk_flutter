import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../l10n/l10n.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/utils/gold_format.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../models/guild_model.dart';
import '../../providers/guild_monument_provider.dart';
import '../../providers/guild_provider.dart';
import '../../providers/player_provider.dart';
import '../../repositories/guild_monument_repository.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/logout_helper.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'widgets/guild_clinic_card.dart';
import 'widgets/guild_design.dart';
import 'widgets/guild_monument_hero_card.dart';
import 'widgets/guild_monument_ui.dart';
import 'widgets/monument_donate_amount_dialog.dart';

/// 5-Tier Aion-style celestial monument visual progression model.
class _MonumentTierInfo {
  const _MonumentTierInfo({
    required this.tier,
    required this.name,
    required this.icon,
    required this.minLevel,
    required this.maxLevel,
    required this.accentColor,
    required this.glowColor,
    required this.description,
    required this.signatureBonus,
  });

  final int tier;
  final String name;
  final String icon;
  final int minLevel;
  final int maxLevel;
  final Color accentColor;
  final Color glowColor;
  final String description;
  final String signatureBonus;

  static const List<_MonumentTierInfo> tiers = <_MonumentTierInfo>[
    _MonumentTierInfo(
      tier: 1,
      name: 'Uyanış Sütunu',
      icon: '🏛️',
      minLevel: 1,
      maxLevel: 24,
      accentColor: AppColors.mutedTitanium,
      glowColor: AppColors.spaceNavy,
      description: 'Loncanın temelleri atıldı. İlk kozmik enerji anıta nüfuz ediyor.',
      signatureBonus: 'Lonca XP & Gold Artışı',
    ),
    _MonumentTierInfo(
      tier: 2,
      name: 'Mistik Dikilitaş',
      icon: '🔮',
      minLevel: 25,
      maxLevel: 49,
      accentColor: AppColors.cyberFuchsia,
      glowColor: Color(0xFFA855F7),
      description: 'Kadim mühürler aktifleşti. Üretim hızı ve zindan şansı yayılıyor.',
      signatureBonus: 'Zindan Şansı & PvP Kalkanı',
    ),
    _MonumentTierInfo(
      tier: 3,
      name: 'Güneş Monoliti',
      icon: '⚡',
      minLevel: 50,
      maxLevel: 74,
      accentColor: AppColors.liquidGold,
      glowColor: Color(0xFFFFD54F),
      description: 'Yarı yol aşıldı! Lonca üyelerine güçlü enerji ve stat akışı sağlanıyor.',
      signatureBonus: 'Büyük Milestone (+10 Enerji, +%5 XP)',
    ),
    _MonumentTierInfo(
      tier: 4,
      name: 'Astral Mabed',
      icon: '✨',
      minLevel: 75,
      maxLevel: 99,
      accentColor: AppColors.toxicNeon,
      glowColor: Color(0xFF00E5FF),
      description: 'Efsanevi mabed formuna ulaştı. Phoenix ve Leviathan kadim güçleri aktif.',
      signatureBonus: 'Phoenix Dirilişi & Titan Gücü',
    ),
    _MonumentTierInfo(
      tier: 5,
      name: 'ETERNAL NEXUS',
      icon: '👑',
      minLevel: 100,
      maxLevel: 100,
      accentColor: Color(0xFF00E5FF),
      glowColor: Color(0xFFFF2E93),
      description: 'Anıt nihai kozmik formuna erişti! Sonsuz güç ve prestij aurası.',
      signatureBonus: '+20 Enerji, +%5 Stat, Sonsuzluk Aurası',
    ),
  ];

  static _MonumentTierInfo forLevel(int level) {
    if (level >= 100) return tiers[4];
    if (level >= 75) return tiers[3];
    if (level >= 50) return tiers[2];
    if (level >= 25) return tiers[1];
    return tiers[0];
  }
}

class GuildMonumentScreen extends ConsumerStatefulWidget {
  const GuildMonumentScreen({super.key});

  @override
  ConsumerState<GuildMonumentScreen> createState() => _GuildMonumentScreenState();
}

class _GuildMonumentScreenState extends ConsumerState<GuildMonumentScreen>
    with TickerProviderStateMixin {
  bool _bonusesExpanded = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _bonusesController;
  late final Animation<double> _bonusesAnimation;
  late final Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    deferProviderUpdate(() => ref.read(guildMonumentProvider.notifier).bootstrap());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );

    _bonusesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _bonusesAnimation = CurvedAnimation(
      parent: _bonusesController,
      curve: Curves.easeInOutCubic,
    );

    _arrowAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(_bonusesAnimation);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bonusesController.dispose();
    super.dispose();
  }

  void _toggleBonuses() {
    setState(() {
      _bonusesExpanded = !_bonusesExpanded;
      if (_bonusesExpanded) {
        _bonusesController.forward();
      } else {
        _bonusesController.reverse();
      }
    });
  }

  Future<void> _openDonate() async {
    await context.push(AppRoutes.guildMonumentDonate);
    if (mounted) {
      await ref.read(guildMonumentProvider.notifier).loadDashboard();
    }
  }

  Future<void> _donateResource(MonumentResourceKind kind) async {
    final MonumentDashboard? dashboard = ref.read(guildMonumentProvider).dashboard;
    if (dashboard == null) return;

    final int? amount = await MonumentDonateAmountDialog.show(
      context,
      kind: kind,
      stats: dashboard.myStats,
      accent: _kindAccent(kind),
    );
    if (!mounted || amount == null || amount <= 0) return;

    final MonumentDonateResult? result =
        await ref.read(guildMonumentProvider.notifier).donateKind(kind: kind, amount: amount);
    if (!mounted) return;

    if (result != null) {
      AppMessenger.show(
        context,
        '${kind.shortLabel}: $amount bağışlandı · +${result.scoreAdded} puan',
      );
      return;
    }

    final String? error = ref.read(guildMonumentProvider).errorMessage;
    if (error != null) {
      AppMessenger.showError(context, error);
    }
  }

  Color _kindAccent(MonumentResourceKind kind) => switch (kind) {
        MonumentResourceKind.structural => AppColors.cyberFuchsia,
        MonumentResourceKind.mystical => AppColors.liquidGold,
        MonumentResourceKind.critical => AppColors.coralFlare,
        MonumentResourceKind.gold => AppColors.warningSolar,
      };

  Future<void> _upgrade() async {
    final result = await ref.read(guildMonumentProvider.notifier).upgradeMonument();
    if (!mounted) return;

    if (result != null) {
      final String vaultNote = result.goldFromVault > 0
          ? ' · Kasadan −${formatCompactGold(result.goldFromVault)}g'
          : '';
      AppMessenger.show(
        context,
        'Anıt seviye ${result.newLevel} oldu$vaultNote',
      );
      return;
    }

    final String? error = ref.read(guildMonumentProvider).errorMessage;
    if (error != null) {
      AppMessenger.showError(context, error);
    }
  }

  Widget _buildMonumentProgressionStage({
    required int monLevel,
    required double screenWidth,
  }) {
    final _MonumentTierInfo currentTier = _MonumentTierInfo.forLevel(monLevel);
    final bool isMaxLevel = monLevel >= 100;
    final int tierStartLevel = currentTier.minLevel;
    final int tierTargetLevel = currentTier.maxLevel;
    final double tierProgress = isMaxLevel
        ? 1.0
        : ((monLevel - tierStartLevel + 1) / (tierTargetLevel - tierStartLevel + 1)).clamp(0.0, 1.0);
    final int nextThreshold = isMaxLevel ? 100 : (currentTier.maxLevel + 1);
    final int levelsToNextTier = isMaxLevel ? 0 : (nextThreshold - monLevel);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (BuildContext context, Widget? child) {
        final double pulse = _pulseAnimation.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: currentTier.accentColor.withValues(alpha: 0.12 + 0.14 * pulse),
                blurRadius: 18 + 10 * pulse,
                spreadRadius: 1 + 2 * pulse,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      currentTier.accentColor.withValues(alpha: 0.14 + 0.08 * pulse),
                      GuildPalette.celestialSurface.withValues(alpha: 0.90),
                      GuildPalette.celestialVoid.withValues(alpha: 0.95),
                    ],
                    stops: const <double>[0.0, 0.45, 1.0],
                  ),
                  border: Border.all(
                    color: currentTier.accentColor.withValues(alpha: 0.35 + 0.25 * pulse),
                    width: 1.4,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Header: Tier Chip + Level Badge
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: currentTier.accentColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: currentTier.accentColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                currentTier.icon,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'TIER ${currentTier.tier} · ${currentTier.name.toUpperCase()}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: currentTier.accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: <Color>[
                                currentTier.accentColor,
                                currentTier.accentColor.withValues(alpha: 0.75),
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: currentTier.accentColor.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            'Lv. $monLevel / 100',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppColors.carbonVoid,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Center Visual: Cosmic Monument Aura Showcase
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: GuildPalette.celestialVoid.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: currentTier.accentColor.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          // Glowing Monument Center Emblem
                          Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              // Pulsing Outer Aura Ring
                              Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: <Color>[
                                      currentTier.accentColor.withValues(alpha: 0.35 * pulse),
                                      currentTier.accentColor.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                              // Glass Core Emblem
                              Container(
                                width: 60,
                                height: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: currentTier.accentColor.withValues(alpha: 0.18),
                                  border: Border.all(
                                    color: currentTier.accentColor.withValues(alpha: 0.65),
                                    width: 1.8,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: currentTier.accentColor.withValues(alpha: 0.45 * pulse),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  currentTier.icon,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentTier.name,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h3.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              currentTier.description,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.mutedTitanium,
                                height: 1.35,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Signature Bonus Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: currentTier.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: currentTier.accentColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 13,
                                  color: currentTier.accentColor,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    currentTier.signatureBonus,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: currentTier.accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Tier Progress Bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              isMaxLevel
                                  ? 'Maksimum Seviyeye Ulaşıldı'
                                  : 'Tier ${currentTier.tier} İlerlemesi',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.mutedTitanium,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              isMaxLevel
                                  ? 'TAMAMLANDI'
                                  : levelsToNextTier == 0
                                      ? 'Yükseltmeye Hazır'
                                      : '$levelsToNextTier Seviye Kaldı',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isMaxLevel ? AppColors.toxicNeon : currentTier.accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 7,
                            color: AppColors.darkObsidian,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: tierProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: <Color>[
                                      currentTier.accentColor.withValues(alpha: 0.6),
                                      currentTier.accentColor,
                                    ],
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: currentTier.accentColor.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Milestone Stepper Nodes (5 Tiers)
                    _buildMilestoneNodesRow(monLevel: monLevel, screenWidth: screenWidth),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMilestoneNodesRow({
    required int monLevel,
    required double screenWidth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Kozmik Yükseliş Aşamaları',
          style: AppTextStyles.caption.copyWith(
            color: GuildPalette.titanium,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            for (int i = 0; i < _MonumentTierInfo.tiers.length; i++) ...<Widget>[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: monLevel >= _MonumentTierInfo.tiers[i].minLevel
                        ? _MonumentTierInfo.tiers[i].accentColor.withValues(alpha: 0.6)
                        : AppColors.mutedTitanium.withValues(alpha: 0.2),
                  ),
                ),
              _buildTierNode(
                tier: _MonumentTierInfo.tiers[i],
                monLevel: monLevel,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTierNode({
    required _MonumentTierInfo tier,
    required int monLevel,
  }) {
    final bool isCurrent = _MonumentTierInfo.forLevel(monLevel).tier == tier.tier;
    final bool isUnlocked = monLevel >= tier.minLevel;

    return Tooltip(
      message: '${tier.name} (Lv.${tier.minLevel}+)\n${tier.signatureBonus}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? tier.accentColor.withValues(alpha: 0.25)
                  : isUnlocked
                      ? tier.accentColor.withValues(alpha: 0.12)
                      : AppColors.darkObsidian.withValues(alpha: 0.8),
              border: Border.all(
                color: isCurrent
                    ? tier.accentColor
                    : isUnlocked
                        ? tier.accentColor.withValues(alpha: 0.5)
                        : AppColors.mutedTitanium.withValues(alpha: 0.25),
                width: isCurrent ? 1.8 : 1.2,
              ),
              boxShadow: isCurrent
                  ? <BoxShadow>[
                      BoxShadow(
                        color: tier.accentColor.withValues(alpha: 0.45),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              tier.icon,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lv.${tier.minLevel}',
            style: TextStyle(
              fontSize: 9,
              fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
              color: isCurrent
                  ? tier.accentColor
                  : isUnlocked
                      ? AppColors.textPrimary
                      : AppColors.mutedTitanium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contributorRow({
    required int rank,
    required MonumentContributor contributor,
    required bool isMe,
  }) {
    final String rankLabel = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '#$rank',
    };
    final String name = contributor.username.trim().isEmpty
        ? 'İsimsiz Savaşçı'
        : contributor.username.trim();
    final String scoreFormatted = formatCompactGold(contributor.contributionScore);

    final Widget row = Row(
      children: <Widget>[
        SizedBox(
          width: 32,
          child: Text(
            rankLabel,
            style: AppTextStyles.body.copyWith(
              fontSize: rank <= 3 ? 15 : 12,
              color: AppColors.mutedTitanium,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  isMe ? '$name (sen)' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: isMe ? FontWeight.w800 : FontWeight.w500,
                    color: isMe ? AppColors.toxicNeon : null,
                  ),
                ),
              ),
              if (isMe) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.toxicNeon.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SEN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.toxicNeon,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: '${contributor.contributionScore} puan',
          child: Text(
            contributor.contributionScore >= 100000
                ? '$scoreFormatted puan'
                : '${contributor.contributionScore} puan',
            style: TextStyle(
              color: isMe ? AppColors.toxicNeon : AppColors.liquidGold,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );

    if (!isMe) return row;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.toxicNeon.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.toxicNeon.withValues(alpha: 0.35)),
      ),
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool hasGuild = ref.watch(hasGuildMembershipProvider);
    final GuildMonumentState monumentState = ref.watch(guildMonumentProvider);
    final profile = ref.watch(playerProvider).profile;
    final String? myAuthId = profile?.authId;
    final bool isMyIdValid = myAuthId != null && myAuthId.isNotEmpty;
    final bool canUpgrade = canUpgradeMonument(profile?.guildRole);
    final MonumentDashboard? dashboard = monumentState.dashboard;
    final MonumentGuildSnapshot? guild = dashboard?.guild;
    final int monLevel = guild?.monumentLevel ?? 0;
    final MonumentUpgradeProgress? upgradeProgress = dashboard == null
        ? null
        : MonumentUpgradeProgress.compute(
            guild: dashboard.guild,
            nextCost: dashboard.nextCost,
            blueprints: dashboard.blueprints,
          );

    ref.listen<bool>(hasGuildMembershipProvider, (bool? prev, bool next) {
      if (next &&
          !monumentState.isLoading &&
          monumentState.dashboard == null &&
          !monumentState.loadFailed) {
        ref.read(guildMonumentProvider.notifier).loadDashboard();
      }
    });

    Future<void> logout() async => performLogout(ref);

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.screenTitleGuildMonument, onLogout: logout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.guildMonument, onLogout: logout),
      body: monumentScreenShell(
        child: !hasGuild
            ? monumentEmptyState(
                title: 'Bir Loncaya Üye Değilsiniz',
                message:
                    'Lonca anıtı, üyelerin kaynaklarını birleştirerek lonca bonusları açtığı kutsal yapıdır. Katılmak için bir lonca bul veya davet bekle.',
                primaryAction: monumentGoldButton(
                  label: 'Lonca Bul',
                  icon: Icons.groups_rounded,
                  onPressed: () => context.go(AppRoutes.guild),
                ),
                secondaryAction: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Geri Dön', style: TextStyle(color: AppColors.mutedTitanium)),
                ),
              )
            : monumentState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.liquidGold))
                : monumentState.loadFailed || dashboard == null
                    ? monumentErrorState(
                        onRetry: () => ref.read(guildMonumentProvider.notifier).loadDashboard(),
                        message: monumentState.loadError,
                      )
                    : RefreshIndicator(
                        color: AppColors.liquidGold,
                        onRefresh: () => ref.read(guildMonumentProvider.notifier).loadDashboard(),
                        child: ListView(
                          padding: MonumentUi.pagePadding(context),
                          children: <Widget>[
                            GameScrollSection(
                              leadingGap: false,
                              child: GuildMonumentHeroCard(
                                level: monLevel,
                                memberCount: dashboard.memberCount,
                                upgradeProgress: upgradeProgress,
                                canUpgrade: canUpgrade,
                                upgrading: monumentState.isUpgrading,
                                onDonate: _openDonate,
                                onUpgrade: _upgrade,
                              ),
                            ),
                            GameScrollSection(
                              child: _buildMonumentProgressionStage(
                                monLevel: monLevel,
                                screenWidth: screenWidth,
                              ),
                            ),
                            GameScrollSection(
                              child: GuildClinicCard(
                                canUpgrade: canUpgrade,
                                mode: GuildClinicCardMode.compact,
                              ),
                            ),
                            if ((dashboard.nextCost != null &&
                                    dashboard.nextCost!['max_level'] == true) ||
                                monLevel >= 100)
                              GameScrollSection(
                                child: monumentPanel(
                                  borderColor: AppColors.toxicNeon.withValues(alpha: 0.35),
                                  child: Row(
                                    children: <Widget>[
                                      const Text('👑', style: TextStyle(fontSize: 22)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              'Anıt maksimum seviyede (Lv.100)',
                                              style: AppTextStyles.label.copyWith(
                                                color: AppColors.toxicNeon,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Tüm kozmik bonuslar açıldı. Loncanız sonsuz güç kazandı!',
                                              style: AppTextStyles.caption.copyWith(
                                                color: AppColors.mutedTitanium,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            GameScrollSection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  monumentSectionTitle('Senin Katkın', accent: AppColors.toxicNeon),
                                  MonumentUi.titleSpacer,
                                  monumentPanel(
                                    borderColor: AppColors.toxicNeon.withValues(alpha: 0.28),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          'Katkı puanın: ${dashboard.myStats.contributionScore}',
                                          style: AppTextStyles.label.copyWith(
                                            color: AppColors.liquidGold,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Elinde olan kaynakları tek tek bağışlayabilirsin. Her satırdaki miktar, bugünkü limit ve stok birleşimidir.',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.mutedTitanium,
                                            height: 1.35,
                                          ),
                                        ),
                                        MonumentUi.itemSpacer,
                                        for (int i = 0; i < MonumentResourceKind.values.length; i++) ...<Widget>[
                                          if (i > 0) MonumentUi.itemSpacer,
                                          monumentMemberResourceRow(
                                            kind: MonumentResourceKind.values[i],
                                            stats: dashboard.myStats,
                                            accent: _kindAccent(MonumentResourceKind.values[i]),
                                            onDonate: monumentState.donatingKind != null
                                                ? null
                                                : () => _donateResource(MonumentResourceKind.values[i]),
                                          ),
                                        ],
                                        if (monumentState.donatingKind != null)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Center(
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.liquidGold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (upgradeProgress != null)
                              GameScrollSection(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    monumentSectionTitle('Sonraki seviye kaynakları'),
                                    MonumentUi.titleSpacer,
                                    monumentNextLevelResourcePanel(progress: upgradeProgress),
                                  ],
                                ),
                              ),
                            GameScrollSection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  monumentSectionTitle('Lonca anıt stoğu'),
                                  MonumentUi.titleSpacer,
                                  GameGridColumns(
                                    crossAxisCount: 2,
                                    children: <Widget>[
                                      monumentResourceTile(
                                        label: 'Yapısal Kaynak',
                                        shortLabel: 'Yapısal',
                                        value: guild?.structural ?? 0,
                                      ),
                                      monumentResourceTile(
                                        label: 'Mistik Kaynak',
                                        shortLabel: 'Mistik',
                                        value: guild?.mystical ?? 0,
                                        valueColor: AppColors.cyberFuchsia,
                                      ),
                                      monumentResourceTile(
                                        label: 'Kritik Kaynak',
                                        shortLabel: 'Kritik',
                                        value: guild?.critical ?? 0,
                                        valueColor: AppColors.coralFlare,
                                      ),
                                      monumentResourceTile(
                                        label: 'Lonca Kasası',
                                        shortLabel: 'Kasa 🪙',
                                        value: guild?.goldPool ?? 0,
                                        valueColor: AppColors.liquidGold,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GameScrollSection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _toggleBonuses,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: monumentSectionTitle(
                                                '✨ Anıt Bonusları',
                                                accent: AppColors.cyberFuchsia,
                                              ),
                                            ),
                                            Text(
                                              '${kMonumentBonuses.where((b) => monLevel >= b.$1).length}/${kMonumentBonuses.length}',
                                              style: AppTextStyles.caption.copyWith(
                                                color: AppColors.mutedTitanium,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            RotationTransition(
                                              turns: _arrowAnimation,
                                              child: const Icon(
                                                Icons.expand_more_rounded,
                                                color: AppColors.cyberFuchsia,
                                                size: 22,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizeTransition(
                                    sizeFactor: _bonusesAnimation,
                                    axisAlignment: -1.0,
                                    child: Column(
                                      children: <Widget>[
                                        MonumentUi.titleSpacer,
                                        for (int i = 0; i < kMonumentBonuses.length; i++) ...<Widget>[
                                          if (i > 0) MonumentUi.itemSpacer,
                                          monumentBonusRow(
                                            level: kMonumentBonuses[i].$1,
                                            title: kMonumentBonuses[i].$2,
                                            effect: kMonumentBonuses[i].$3,
                                            unlocked: monLevel >= kMonumentBonuses[i].$1,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GameScrollSection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  monumentSectionTitle('🏆 Katkı Liderleri'),
                                  MonumentUi.titleSpacer,
                                  monumentPanel(
                                    borderColor: AppColors.liquidGold.withValues(alpha: 0.28),
                                    child: dashboard.contributors.isEmpty
                                        ? Text(
                                            'Henüz katkı kaydı bulunmuyor. İlk bağışı yap, listenin başına geç!',
                                            style: AppTextStyles.caption.copyWith(
                                              color: AppColors.mutedTitanium,
                                            ),
                                          )
                                        : Column(
                                            children: <Widget>[
                                              for (int i = 0; i < dashboard.contributors.length; i++)
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: i == dashboard.contributors.length - 1
                                                        ? 0
                                                        : 6,
                                                  ),
                                                  child: _contributorRow(
                                                    rank: i + 1,
                                                    contributor: dashboard.contributors[i],
                                                    isMe: isMyIdValid &&
                                                        dashboard.contributors[i].userId == myAuthId,
                                                  ),
                                                ),
                                              if (dashboard.myStats.contributionScore > 0 &&
                                                  (!isMyIdValid ||
                                                      !dashboard.contributors.any(
                                                        (MonumentContributor c) =>
                                                            c.userId == myAuthId,
                                                      ))) ...<Widget>[
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.toxicNeon
                                                        .withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: AppColors.toxicNeon
                                                          .withValues(alpha: 0.3),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: <Widget>[
                                                      Text(
                                                        'Sen (liste dışı)',
                                                        style: AppTextStyles.body
                                                            .copyWith(fontSize: 13),
                                                      ),
                                                      const Spacer(),
                                                      Text(
                                                        '${dashboard.myStats.contributionScore} puan',
                                                        style: const TextStyle(
                                                          color: AppColors.toxicNeon,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            if (dashboard.blueprints.isNotEmpty)
                              GameScrollSection(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    monumentSectionTitle(
                                      '🧩 Blueprint İlerlemesi',
                                      accent: AppColors.toxicNeon,
                                    ),
                                    MonumentUi.titleSpacer,
                                    monumentPanel(
                                      borderColor: AppColors.toxicNeon.withValues(alpha: 0.28),
                                      child: Column(
                                        children: <Widget>[
                                          for (int i = 0; i < dashboard.blueprints.length; i++)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                bottom: i == dashboard.blueprints.length - 1 ? 0 : 8,
                                              ),
                                              child: Row(
                                                children: <Widget>[
                                                  Expanded(
                                                    child: Text(
                                                      dashboard.blueprints[i].blueprintType,
                                                      style: AppTextStyles.body.copyWith(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: dashboard.blueprints[i].isComplete
                                                          ? AppColors.toxicNeon
                                                              .withValues(alpha: 0.12)
                                                          : AppColors.darkObsidian
                                                              .withValues(alpha: 0.6),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: dashboard.blueprints[i].isComplete
                                                            ? AppColors.toxicNeon
                                                                .withValues(alpha: 0.4)
                                                            : AppColors.mutedTitanium
                                                                .withValues(alpha: 0.2),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      dashboard.blueprints[i].isComplete
                                                          ? 'Tamamlandı ✓'
                                                          : '${dashboard.blueprints[i].fragments}/${dashboard.blueprints[i].fragmentsRequired}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        color: dashboard.blueprints[i].isComplete
                                                            ? AppColors.toxicNeon
                                                            : AppColors.mutedTitanium,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
      ),
    );
  }
}
