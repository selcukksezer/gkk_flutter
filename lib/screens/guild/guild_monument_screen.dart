import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../l10n/l10n.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/services/supabase_service.dart';
import '../../models/guild_model.dart';
import '../../providers/guild_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../repositories/guild_monument_repository.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/logout_helper.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'widgets/guild_monument_ui.dart';

class GuildMonumentScreen extends ConsumerStatefulWidget {
  const GuildMonumentScreen({super.key});

  @override
  ConsumerState<GuildMonumentScreen> createState() => _GuildMonumentScreenState();
}

class _GuildMonumentScreenState extends ConsumerState<GuildMonumentScreen> {
  MonumentDashboard? _dashboard;
  bool _loading = true;
  bool _upgrading = false;
  bool _loadFailed = false;
  MonumentResourceKind? _donatingKind;

  GuildMonumentRepository get _repository => ref.read(guildMonumentRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(hasGuildMembershipProvider)) {
        await ref.read(guildProvider.notifier).loadGuild();
      }
      await _load();
    });
  }

  Future<void> _load() async {
    final guildState = ref.read(guildProvider);
    final String? guildId =
        guildState.guild?.guildId ?? ref.read(playerProvider).profile?.guildId;
    if (guildId == null || guildId.isEmpty) {
      setState(() {
        _loading = false;
        _loadFailed = false;
        _dashboard = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final MonumentDashboard dashboard = await _repository.fetchDashboard(guildId);
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _loading = false;
        });
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('GuildMonumentScreen._load failed: $e\n$st');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _dashboard = null;
        });
      }
    }
  }

  Future<void> _openDonate() async {
    await context.push(AppRoutes.guildMonumentDonate);
    if (mounted) await _load();
  }

  Future<void> _quickDonate(MonumentResourceKind kind) async {
    final MonumentDashboard? dashboard = _dashboard;
    if (dashboard == null) return;
    final int amount = dashboard.myStats.maxDonatable(kind);
    if (amount <= 0) {
      AppMessenger.show(context, 'Bağışlanacak ${kind.shortLabel.toLowerCase()} kaynağın yok');
      return;
    }
    setState(() => _donatingKind = kind);
    try {
      final MonumentDonateResult result = await monumentDonateKind(
        repository: _repository,
        kind: kind,
        amount: amount,
        stats: dashboard.myStats,
      );
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      await ref.read(playerProvider.notifier).loadProfile();
      if (!mounted) return;
      AppMessenger.show(
        context,
        '${kind.shortLabel}: $amount bağışlandı · +${result.scoreAdded} puan',
      );
      await _load();
    } catch (e, st) {
      if (kDebugMode) debugPrint('GuildMonumentScreen._quickDonate: $e\n$st');
      if (mounted) {
        AppMessenger.showError(
          context,
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Bağış tamamlanamadı',
        );
      }
    } finally {
      if (mounted) setState(() => _donatingKind = null);
    }
  }

  Color _kindAccent(MonumentResourceKind kind) => switch (kind) {
        MonumentResourceKind.structural => AppColors.cyberFuchsia,
        MonumentResourceKind.mystical => AppColors.liquidGold,
        MonumentResourceKind.critical => AppColors.coralFlare,
        MonumentResourceKind.gold => AppColors.warningSolar,
      };

  Future<void> _upgrade() async {
    final profile = ref.read(playerProvider).profile;
    if (!canUpgradeMonument(profile?.guildRole)) {
      AppMessenger.show(context, 'Yetkiniz yok!');
      return;
    }
    setState(() => _upgrading = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'upgrade_monument',
        params: <String, dynamic>{'p_user_id': profile?.authId},
      );
      if (raw is! Map) {
        if (mounted) AppMessenger.showError(context, 'Yükseltme yanıtı işlenemedi');
        return;
      }
      final Map<String, dynamic> result = Map<String, dynamic>.from(raw);
      if (result['success'] == true) {
        if (mounted) AppMessenger.show(context, 'Anıt seviye ${result['new_level']} oldu');
        await ref.read(guildProvider.notifier).loadGuild();
        await _load();
      } else {
        if (mounted) {
          AppMessenger.showError(context, result['error'] as String? ?? 'Yükseltme başarısız');
        }
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('GuildMonumentScreen._upgrade failed: $e\n$st');
      if (mounted) AppMessenger.showError(context, 'Yükseltme tamamlanamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasGuild = ref.watch(hasGuildMembershipProvider);
    final profile = ref.watch(playerProvider).profile;
    final bool canUpgrade = canUpgradeMonument(profile?.guildRole);
    final MonumentDashboard? dashboard = _dashboard;
    final MonumentGuildSnapshot? guild = dashboard?.guild;
    final int monLevel = guild?.monumentLevel ?? 0;
    final MonumentUpgradeProgress? upgradeProgress = dashboard == null
        ? null
        : MonumentUpgradeProgress.compute(
            guild: dashboard.guild,
            nextCost: dashboard.nextCost,
            blueprints: dashboard.blueprints,
          );

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
            : _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.liquidGold))
                : _loadFailed || dashboard == null
                    ? monumentErrorState(onRetry: _load)
                    : RefreshIndicator(
                        color: AppColors.liquidGold,
                        onRefresh: _load,
                        child: ListView(
                          padding: MonumentUi.pagePadding(context),
                          children: <Widget>[
                            GameScrollSection(
                              leadingGap: false,
                              child: _HeroCard(
                                level: monLevel,
                                memberCount: dashboard.memberCount,
                                upgradeProgress: upgradeProgress,
                                canUpgrade: canUpgrade,
                                upgrading: _upgrading,
                                onDonate: _openDonate,
                                onUpgrade: _upgrade,
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
                                            onDonateMax: _donatingKind != null
                                                ? null
                                                : () => _quickDonate(MonumentResourceKind.values[i]),
                                          ),
                                        ],
                                        if (_donatingKind != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
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
                            GameScrollSection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  monumentSectionTitle('Lonca Anıt Havuzu'),
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
                                        label: 'Altın Havuzu',
                                        shortLabel: 'Altın',
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
                                  monumentSectionTitle('✨ Anıt Bonusları', accent: AppColors.cyberFuchsia),
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
                                            'Henüz katkı kaydı bulunmuyor.',
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
                                                  child: Row(
                                                    children: <Widget>[
                                                      Text(
                                                        '#${i + 1} ${dashboard.contributors[i].username}',
                                                        style: AppTextStyles.body.copyWith(fontSize: 13),
                                                      ),
                                                      const Spacer(),
                                                      Text(
                                                        '${dashboard.contributors[i].contributionScore}',
                                                        style: const TextStyle(
                                                          color: AppColors.liquidGold,
                                                          fontWeight: FontWeight.w800,
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.level,
    required this.memberCount,
    required this.upgradeProgress,
    required this.canUpgrade,
    required this.upgrading,
    required this.onDonate,
    required this.onUpgrade,
  });

  final int level;
  final int memberCount;
  final MonumentUpgradeProgress? upgradeProgress;
  final bool canUpgrade;
  final bool upgrading;
  final VoidCallback onDonate;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return monumentPanel(
      borderColor: AppColors.cyberFuchsia.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.cyberFuchsia.withValues(alpha: 0.28),
                      AppColors.liquidGold.withValues(alpha: 0.12),
                    ],
                  ),
                  border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.45), width: 1.5),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: AppColors.liquidGold.withValues(alpha: 0.18), blurRadius: 14),
                  ],
                ),
                child: const Text('🏛️', style: TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Seviye $level Anıt', style: AppTextStyles.h2.copyWith(fontSize: 18)),
                    if (upgradeProgress != null) ...<Widget>[
                      const SizedBox(height: 8),
                      monumentUpgradeProgressCompact(progress: upgradeProgress!),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Lonca üyelerinin güçlerini birleştirerek yükselttiği kutsal yapı.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.mutedTitanium),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    monumentPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      borderColor: AppColors.mutedTitanium.withValues(alpha: 0.16),
                      child: Row(
                        children: <Widget>[
                          Text(
                            '$memberCount / 50 Aktif Üye',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                          ),
                          const Spacer(),
                          Text(
                            guildSizeLabel(memberCount),
                            style: const TextStyle(
                              color: AppColors.liquidGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
          const SizedBox(height: AppSpacing.md),
          monumentGoldButton(
            label: 'Bağış Yap',
            icon: Icons.volunteer_activism_rounded,
            onPressed: onDonate,
          ),
          if (canUpgrade) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            monumentAccentButton(
              label: upgrading ? 'Yükseltiliyor…' : 'Anıtı Yükselt',
              onPressed: upgrading ? null : onUpgrade,
            ),
          ],
        ],
      ),
    );
  }
}
