import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../l10n/l10n.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
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

class GuildMonumentDonateScreen extends ConsumerStatefulWidget {
  const GuildMonumentDonateScreen({super.key});

  @override
  ConsumerState<GuildMonumentDonateScreen> createState() => _GuildMonumentDonateScreenState();
}

class _GuildMonumentDonateScreenState extends ConsumerState<GuildMonumentDonateScreen> {
  MonumentDashboard? _dashboard;
  bool _loadingDashboard = true;
  MonumentResourceKind? _donatingKind;
  final Map<MonumentResourceKind, TextEditingController> _controllers =
      <MonumentResourceKind, TextEditingController>{
    for (final MonumentResourceKind kind in MonumentResourceKind.values) kind: TextEditingController(),
  };

  GuildMonumentRepository get _repository => ref.read(guildMonumentRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  @override
  void dispose() {
    for (final TextEditingController ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    final String? guildId = ref.read(playerProvider).profile?.guildId;
    if (guildId == null || guildId.isEmpty) {
      if (mounted) setState(() => _loadingDashboard = false);
      return;
    }
    setState(() => _loadingDashboard = true);
    try {
      final MonumentDashboard dashboard = await _repository.fetchDashboard(guildId);
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _loadingDashboard = false;
        });
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('GuildMonumentDonateScreen._loadDashboard: $e\n$st');
      if (mounted) setState(() => _loadingDashboard = false);
    }
  }

  Future<void> _donateKind(MonumentResourceKind kind, {int? amount}) async {
    final MonumentDashboard? dashboard = _dashboard;
    if (dashboard == null) return;

    final int requested = amount ??
        (int.tryParse(_controllers[kind]!.text.trim()) ??
            (amount == null ? dashboard.myStats.maxDonatable(kind) : 0));

    final int capped = monumentDonateCap(
      owned: dashboard.myStats.owned(kind),
      donatedToday: dashboard.myStats.donatedToday(kind),
      dailyMax: kind.dailyMax,
      requested: requested,
    );

    if (capped <= 0) {
      AppMessenger.show(context, '${kind.shortLabel} için bağışlanacak miktar yok');
      return;
    }

    setState(() => _donatingKind = kind);
    try {
      final MonumentDonateResult result = await monumentDonateKind(
        repository: _repository,
        kind: kind,
        amount: capped,
        stats: dashboard.myStats,
      );
      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      await ref.read(playerProvider.notifier).loadProfile();
      if (!mounted) return;
      _controllers[kind]!.clear();
      AppMessenger.show(context, '${kind.shortLabel}: $capped bağışlandı · +${result.scoreAdded} puan');
      await _loadDashboard();
    } catch (e, st) {
      if (kDebugMode) debugPrint('GuildMonumentDonateScreen._donateKind: $e\n$st');
      if (mounted) {
        AppMessenger.showError(
          context,
          userFacingErrorMessage(e, fallback: 'Bağış tamamlanamadı.'),
        );
      }
    } finally {
      if (mounted) setState(() => _donatingKind = null);
    }
  }

  void _fillMax(MonumentResourceKind kind) {
    final MonumentDashboard? dashboard = _dashboard;
    if (dashboard == null) return;
    final int max = dashboard.myStats.maxDonatable(kind);
    _controllers[kind]!.text = max > 0 ? '$max' : '';
  }

  Color _kindAccent(MonumentResourceKind kind) => switch (kind) {
        MonumentResourceKind.structural => AppColors.cyberFuchsia,
        MonumentResourceKind.mystical => AppColors.liquidGold,
        MonumentResourceKind.critical => AppColors.coralFlare,
        MonumentResourceKind.gold => AppColors.warningSolar,
      };

  Widget _donateCard(MonumentResourceKind kind) {
    final MonumentDashboard? dashboard = _dashboard;
    if (dashboard == null) return const SizedBox.shrink();

    final MonumentMyStats stats = dashboard.myStats;
    final int owned = stats.owned(kind);
    final int today = stats.donatedToday(kind);
    final int total = stats.donatedTotal(kind);
    final int maxDonate = stats.maxDonatable(kind);
    final bool busy = _donatingKind == kind;
    final TextEditingController ctrl = _controllers[kind]!;

    return monumentPanel(
      borderColor: _kindAccent(kind).withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(kind.label, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Toplam bağışın: $total · Bugün: $today/${kind.dailyMax}',
            style: AppTextStyles.caption.copyWith(color: AppColors.mutedTitanium),
          ),
          Text(
            kind == MonumentResourceKind.gold ? 'Elinde: $owned altın' : 'Elinde: $owned',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: owned > 0 ? AppColors.toxicNeon : AppColors.mysticRuby,
            ),
          ),
          if (maxDonate > 0) ...<Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              enabled: !busy && _donatingKind == null,
              decoration: InputDecoration(
                hintText: 'Miktar (en fazla $maxDonate)',
                filled: true,
                fillColor: AppColors.darkObsidian.withValues(alpha: 0.65),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(color: AppColors.mutedTitanium.withValues(alpha: 0.22)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(color: AppColors.mutedTitanium.withValues(alpha: 0.22)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (String v) {
                final int? n = int.tryParse(v);
                if (n != null && n > maxDonate) {
                  ctrl.value = TextEditingValue(
                    text: '$maxDonate',
                    selection: TextSelection.collapsed(offset: '$maxDonate'.length),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy || _donatingKind != null ? null : () => _fillMax(kind),
                    child: const Text('Elindekini yaz', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: monumentGoldButton(
                    label: busy ? '...' : 'Bağışla',
                    onPressed: busy || _donatingKind != null ? null : () => _donateKind(kind),
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                owned <= 0 ? 'Bu kaynaktan elinde yok.' : 'Bugünlük limit doldu.',
                style: AppTextStyles.caption.copyWith(color: AppColors.mysticRuby),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasGuild = ref.watch(hasGuildMembershipProvider);

    Future<void> logout() async => performLogout(ref);

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.screenTitleMonumentDonate, onLogout: logout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.guildMonumentDonate, onLogout: logout),
      body: monumentScreenShell(
        child: !hasGuild
            ? monumentEmptyState(
                title: 'Lonca bulunamadı',
                message: 'Bağış yapmak için önce bir loncaya katılman gerekir.',
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
            : _loadingDashboard
                ? const Center(child: CircularProgressIndicator(color: AppColors.liquidGold))
                : _dashboard == null
                    ? monumentErrorState(onRetry: _loadDashboard)
                    : ListView(
                        padding: MonumentUi.pagePadding(context),
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.pop(),
                              child: const Text('İptal', style: TextStyle(color: AppColors.mutedTitanium)),
                            ),
                          ),
                          GameScrollSection(
                            leadingGap: false,
                            child: monumentPanel(
                              child: Text(
                                'Her kaynağı ayrı bağışlayabilirsin. Dört alanı doldurman gerekmez — elinde ne varsa onu gönder.',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.mutedTitanium,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                          for (int i = 0; i < MonumentResourceKind.values.length; i++)
                            GameScrollSection(
                              child: _donateCard(MonumentResourceKind.values[i]),
                            ),
                        ],
                      ),
      ),
    );
  }
}
