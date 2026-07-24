import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/utils/reputation_tier.dart';
import '../../l10n/l10n.dart';
import '../../models/reputation_model.dart';
import '../../providers/player_provider.dart';
import '../../providers/reputation_provider.dart';
import '../../routing/app_router.dart';
import '../../utils/logout_helper.dart';
import '../mekans/widgets/mekan_design.dart';
import 'widgets/reputation_activity_log.dart';
import 'widgets/reputation_design.dart';
import 'widgets/reputation_earn_section.dart';
import 'widgets/reputation_shop_grid.dart';

class ReputationScreen extends ConsumerStatefulWidget {
  const ReputationScreen({super.key});

  @override
  ConsumerState<ReputationScreen> createState() => _ReputationScreenState();
}

class _ReputationScreenState extends ConsumerState<ReputationScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(reputationProvider.notifier).load());
  }

  Future<void> _refresh() async {
    await Future.wait<void>(<Future<void>>[
      ref.read(reputationProvider.notifier).load(),
      ref.read(playerProvider.notifier).loadProfile(),
    ]);
  }

  (double progress, String nextTier) _tierProgress(int rep) {
    const List<int> thresholds = <int>[5000, 20000, 80000, 170000, 280000, 356000];
    const List<String> names = <String>[
      'Tanınan',
      'Saygın',
      'Ünlü',
      'Efsanevi',
      'Destansı',
      'İmparator',
    ];
    if (rep >= 356000) return (1.0, 'Maksimum');
    int prev = 0;
    for (int i = 0; i < thresholds.length; i++) {
      if (rep < thresholds[i]) {
        final double p = (rep - prev) / (thresholds[i] - prev);
        return (p, names[i]);
      }
      prev = thresholds[i];
    }
    return (1.0, 'İmparator');
  }

  Future<void> _purchase(ReputationShopItem item) async {
    String? factionId;
    if (item.usesFactionRep) {
      factionId = await _pickFactionForPurchase();
      if (factionId == null) return;
    }

    final String? err = await ref.read(reputationProvider.notifier).purchase(
          item: item,
          factionId: factionId,
        );
    if (!mounted) return;
    if (err != null) {
      AppMessenger.showError(context, err);
      return;
    }
    await ref.read(playerProvider.notifier).loadProfile();
    if (!mounted) return;
    AppMessenger.showSuccess(context, '${item.name} satın alındı!');
  }

  Future<String?> _pickFactionForPurchase() async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: MekanPalette.navy,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Fraksiyon seç',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: MekanPalette.textHi,
                  ),
                ),
                const SizedBox(height: 12),
                ...kReputationFactions.map((ReputationFactionDef def) {
                  final int rep = ref.read(reputationProvider.notifier).factionRep(def.id);
                  return ListTile(
                    leading: Text(def.icon, style: const TextStyle(fontSize: 22)),
                    title: Text(def.name, style: const TextStyle(color: MekanPalette.textHi)),
                    subtitle: Text(
                      '$rep/100 itibar',
                      style: TextStyle(color: factionTierColor(rep)),
                    ),
                    onTap: () => Navigator.pop(ctx, def.id),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ReputationState state = ref.watch(reputationProvider);
    final ReputationOverview overview = state.overview;
    final int globalRep = overview.globalReputation;
    final ReputationTier tier = reputationTierFor(globalRep);
    final (double progress, String nextTier) = _tierProgress(globalRep);
    final List<String> buffLabels =
        overview.activeBuffs.map((ReputationActiveBuff b) => b.label()).toList();

    int factionRepFor(String id) => ref.read(reputationProvider.notifier).factionRep(id);

    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.i_tibar,
        onLogout: () async => performLogout(ref),
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.reputation,
        onLogout: () async => performLogout(ref),
      ),
      body: MekanBackdrop(
        accent: MekanPalette.gold,
        child: state.loading && overview.factions.isEmpty
            ? const Center(child: CircularProgressIndicator(color: MekanPalette.gold))
            : RefreshIndicator(
                color: MekanPalette.gold,
                onRefresh: _refresh,
                child: ListView(
                  padding: GameScrollLayout.fromLTRB(context, left: 16, top: 12, right: 16),
                  children: <Widget>[
                    ReputationVaultHeader(
                      totalRep: globalRep,
                      tierTitle: tier.title,
                      tierColor: tier.color,
                      nextTierTitle: nextTier,
                      progress: progress,
                      activeBuffs: buffLabels,
                    ),
                    const SizedBox(height: 16),
                    ReputationTabBar(index: _tab, onChanged: (int i) => setState(() => _tab = i)),
                    const SizedBox(height: 16),
                    if (state.error != null) ...<Widget>[
                      Text(state.error!, style: const TextStyle(color: MekanPalette.ruby, fontSize: 12)),
                      const SizedBox(height: 8),
                    ],
                    if (_tab == 0) ...<Widget>[
                      ReputationEarnSection(),
                      const SizedBox(height: 20),
                      ReputationFactionStrip(factions: overview.factions),
                    ] else if (_tab == 1) ...<Widget>[
                      ReputationShopGrid(
                        items: overview.shopItems,
                        globalRep: globalRep,
                        factionRepFor: factionRepFor,
                        purchasingId: state.purchasingId,
                        onPurchase: _purchase,
                      ),
                      const SizedBox(height: 16),
                      ReputationFactionStrip(factions: overview.factions),
                    ] else ...<Widget>[
                      ReputationActivityLog(entries: overview.activity),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
