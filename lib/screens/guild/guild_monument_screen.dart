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
import '../../theme/app_text_styles.dart';
import '../../utils/logout_helper.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'widgets/guild_clinic_card.dart';
import 'widgets/guild_monument_hero_card.dart';
import 'widgets/guild_monument_ui.dart';
import 'widgets/monument_donate_amount_dialog.dart';

class GuildMonumentScreen extends ConsumerStatefulWidget {
  const GuildMonumentScreen({super.key});

  @override
  ConsumerState<GuildMonumentScreen> createState() => _GuildMonumentScreenState();
}

class _GuildMonumentScreenState extends ConsumerState<GuildMonumentScreen> {
  bool _bonusesExpanded = false;

  @override
  void initState() {
    super.initState();
    deferProviderUpdate(() => ref.read(guildMonumentProvider.notifier).bootstrap());
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
    final Widget row = Row(
      children: <Widget>[
        SizedBox(
          width: 30,
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
          child: Text(
            isMe ? '${contributor.username} (sen)' : contributor.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              fontWeight: isMe ? FontWeight.w800 : FontWeight.w500,
              color: isMe ? AppColors.toxicNeon : null,
            ),
          ),
        ),
        Text(
          '${contributor.contributionScore}',
          style: TextStyle(
            color: isMe ? AppColors.toxicNeon : AppColors.liquidGold,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    if (!isMe) return row;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.toxicNeon.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.toxicNeon.withValues(alpha: 0.3)),
      ),
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasGuild = ref.watch(hasGuildMembershipProvider);
    final GuildMonumentState monumentState = ref.watch(guildMonumentProvider);
    final profile = ref.watch(playerProvider).profile;
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
                              child: GuildClinicCard(
                                canUpgrade: canUpgrade,
                                mode: GuildClinicCardMode.compact,
                              ),
                            ),
                            if (dashboard.nextCost != null &&
                                dashboard.nextCost!['max_level'] == true)
                              GameScrollSection(
                                child: monumentPanel(
                                  borderColor: AppColors.toxicNeon.withValues(alpha: 0.35),
                                  child: Text(
                                    'Anıt maksimum seviyede (Lv.100).',
                                    style: AppTextStyles.label.copyWith(color: AppColors.toxicNeon),
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
                                        value: guild!.structural,
                                      ),
                                      monumentResourceTile(
                                        label: 'Mistik Kaynak',
                                        shortLabel: 'Mistik',
                                        value: guild.mystical,
                                        valueColor: AppColors.cyberFuchsia,
                                      ),
                                      monumentResourceTile(
                                        label: 'Kritik Kaynak',
                                        shortLabel: 'Kritik',
                                        value: guild.critical,
                                        valueColor: AppColors.coralFlare,
                                      ),
                                      monumentResourceTile(
                                        label: 'Lonca Kasası',
                                        shortLabel: 'Kasa 🪙',
                                        value: guild.goldPool,
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
                                      onTap: () => setState(() => _bonusesExpanded = !_bonusesExpanded),
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
                                            Icon(
                                              _bonusesExpanded
                                                  ? Icons.expand_less_rounded
                                                  : Icons.expand_more_rounded,
                                              color: AppColors.cyberFuchsia,
                                              size: 22,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_bonusesExpanded) ...<Widget>[
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
                                                    isMe: dashboard.contributors[i].userId ==
                                                        profile?.authId,
                                                  ),
                                                ),
                                              if (dashboard.myStats.contributionScore > 0 &&
                                                  !dashboard.contributors.any(
                                                    (MonumentContributor c) =>
                                                        c.userId == profile?.authId,
                                                  )) ...<Widget>[
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
                                                        '${dashboard.myStats.contributionScore}',
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
                                                bottom: i == dashboard.blueprints.length - 1 ? 0 : 6,
                                              ),
                                              child: Row(
                                                children: <Widget>[
                                                  Expanded(
                                                    child: Text(
                                                      dashboard.blueprints[i].blueprintType,
                                                      style: AppTextStyles.body.copyWith(fontSize: 13),
                                                    ),
                                                  ),
                                                  Text(
                                                    dashboard.blueprints[i].isComplete
                                                        ? 'Tamamlandı'
                                                        : '${dashboard.blueprints[i].fragments}/${dashboard.blueprints[i].fragmentsRequired}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: dashboard.blueprints[i].isComplete
                                                          ? AppColors.toxicNeon
                                                          : AppColors.mutedTitanium,
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
