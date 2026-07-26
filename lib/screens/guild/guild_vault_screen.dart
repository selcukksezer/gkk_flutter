import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../models/guild_model.dart';
import '../../models/guild_vault_model.dart';
import '../../providers/guild_provider.dart';
import '../../providers/guild_vault_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/logout_helper.dart';
import '../guild_war/widgets/guild_war_design.dart';
import '../guild_war/widgets/guild_war_sub_screen_scaffold.dart';
import '../support/widgets/support_design.dart';

String vaultLedgerLabel(String action, Map<String, dynamic> payload) {
  switch (action) {
    case 'accrue':
      return 'Bölge geliri +${payload['amount'] ?? ''}g';
    case 'collect':
      return 'Toplandı +${payload['amount'] ?? ''}g';
    case 'distribute_gold':
      return 'Altın dağıtımı −${payload['amount'] ?? ''}g';
    case 'distribute_item':
      return 'Eşya dağıtımı';
    case 'attack_spend':
      return 'Saldırı −${payload['gold'] ?? ''}g';
    case 'defense_gold':
      return 'Savunma −${payload['gold'] ?? ''}g';
    case 'territory_loot':
      return 'Bölge loot: ${payload['item_id'] ?? ''}';
    case 'siege_reward':
    case 'credit':
      return 'Kuşatma/ödül +${payload['amount'] ?? ''}g';
    case 'tournament':
      return 'Turnuva ödülü +${payload['amount'] ?? ''}g';
    default:
      return action;
  }
}

Color vaultRarityAccent(String? rarity) {
  switch (rarity?.toLowerCase()) {
    case 'legendary':
    case 'mythic':
      return SettingsPalette.gold;
    case 'epic':
      return SettingsPalette.fuchsia;
    case 'rare':
      return AppColors.accentBlue;
    default:
      return SettingsPalette.coral;
  }
}

class GuildVaultScreen extends ConsumerStatefulWidget {
  const GuildVaultScreen({super.key});

  @override
  ConsumerState<GuildVaultScreen> createState() => _GuildVaultScreenState();
}

class _GuildVaultScreenState extends ConsumerState<GuildVaultScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _equalAmount = TextEditingController(text: '1000');
  final Map<String, TextEditingController> _targetAmounts = <String, TextEditingController>{};
  bool _busy = false;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(guildVaultProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _equalAmount.dispose();
    for (final TextEditingController c in _targetAmounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _amountFor(String playerId) {
    return _targetAmounts.putIfAbsent(
      playerId,
      () => TextEditingController(text: '0'),
    );
  }

  Future<void> _collect() async {
    setState(() => _busy = true);
    final String? err = await ref.read(guildVaultProvider.notifier).collectRewards();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
    } else {
      AppMessenger.showSuccess(context, 'Gelir kasaya aktarıldı.');
    }
  }

  Future<void> _distributeEqual(GuildVaultState vault) async {
    final int amount = int.tryParse(_equalAmount.text.trim()) ?? 0;
    if (amount <= 0) {
      AppMessenger.showError(context, 'Geçerli miktar girin.');
      return;
    }
    if (amount > vault.vaultGold) {
      AppMessenger.showError(context, 'Kasada yeterli altın yok.');
      return;
    }
    setState(() => _busy = true);
    final String? err =
        await ref.read(guildVaultProvider.notifier).distributeGoldEqual(amount);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
    } else {
      AppMessenger.showSuccess(context, 'Altın üyelere eşit dağıtıldı.');
    }
  }

  Future<void> _distributeTargeted(GuildVaultState vault, List<GuildMemberData> members) async {
    final List<Map<String, dynamic>> allocations = <Map<String, dynamic>>[];
    int total = 0;
    for (final GuildMemberData m in members) {
      final int amount = int.tryParse(_amountFor(m.playerId).text.trim()) ?? 0;
      if (amount <= 0) continue;
      allocations.add(<String, dynamic>{'user_id': m.playerId, 'amount': amount});
      total += amount;
    }
    if (allocations.isEmpty) {
      AppMessenger.showError(context, 'En az bir üyeye miktar girin.');
      return;
    }
    if (total > vault.vaultGold) {
      AppMessenger.showError(context, 'Toplam kasayı aşıyor.');
      return;
    }
    setState(() => _busy = true);
    final String? err = await ref.read(guildVaultProvider.notifier).distributeGoldTargeted(
          totalAmount: total,
          allocations: allocations,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
    } else {
      AppMessenger.showSuccess(context, 'Hedefli dağıtım tamam.');
    }
  }

  Future<void> _distributeItem(GuildVaultItem item, List<GuildMemberData> members) async {
    if (members.isEmpty) return;

    final GuildMemberData? target = await showDialog<GuildMemberData>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: SettingsGlassCard(
          accent: SettingsPalette.gold,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Eşya dağıt: ${item.itemName}',
                style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi),
              ),
              const SizedBox(height: 12),
              ...members.map(
                (GuildMemberData m) => SettingsPressable(
                  onTap: () => Navigator.pop(ctx, m),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${m.username} · ${m.role.name}',
                      style: supportBodyStyle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (target == null || !mounted) return;

    setState(() => _busy = true);
    final String? err = await ref.read(guildVaultProvider.notifier).distributeItem(
          vaultItemId: item.id,
          userId: target.playerId,
          quantity: 1,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
    } else {
      AppMessenger.showSuccess(context, '${item.itemName} → ${target.username}');
    }
  }

  String _formatGold(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final GuildVaultState vault = ref.watch(guildVaultProvider);
    final GuildData? guild = ref.watch(guildProvider).guild;
    final List<GuildMemberData> members = guild?.members ?? const <GuildMemberData>[];

    return GuildWarSubScreenScaffold(
      title: 'Lonca Kasası',
      currentRoute: AppRoutes.guild,
      backRoute: AppRoutes.guild,
      onLogout: () async => performLogout(ref),
      body: vault.isLoading && vault.totalGold == 0
          ? const Center(child: CircularProgressIndicator(color: WarPalette.gold))
          : RefreshIndicator(
              color: WarPalette.gold,
              onRefresh: () => ref.read(guildVaultProvider.notifier).load(),
              child: ListView(
                padding: GameScrollLayout.pagePadding(context),
                children: <Widget>[
                  _VaultHeroCard(
                    vault: vault,
                    busy: _busy,
                    formatGold: _formatGold,
                    onCollect: vault.canManage ? _collect : null,
                  ),
                  if (vault.territories.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    SettingsGlassCard(
                      accent: SettingsPalette.neon,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Bölge gelirleri',
                            style: AppTextStyles.captionBold.copyWith(color: SettingsPalette.neon),
                          ),
                          const SizedBox(height: 8),
                          ...vault.territories.map(
                            (GuildVaultTerritorySummary t) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${t.name}: ${_formatGold(t.tradeIncome)}g/gün'
                                '${t.lootItemId != null ? ' · loot ${((t.lootItemChance ?? 0) * 100).round()}%' : ''}',
                                style: supportCaptionStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.base),
                  TabBar(
                    controller: _tabs,
                    indicatorColor: WarPalette.gold,
                    labelColor: WarPalette.gold,
                    unselectedLabelColor: WarPalette.titanium,
                    tabs: const <Tab>[
                      Tab(text: 'Altın'),
                      Tab(text: 'Eşyalar'),
                      Tab(text: 'Kayıt'),
                    ],
                  ),
                  SizedBox(
                    height: 460,
                    child: TabBarView(
                      controller: _tabs,
                      children: <Widget>[
                        _GoldTab(
                          vault: vault,
                          members: members,
                          busy: _busy,
                          equalController: _equalAmount,
                          amountFor: _amountFor,
                          onEqual: () => _distributeEqual(vault),
                          onTargeted: () => _distributeTargeted(vault, members),
                        ),
                        _ItemsTab(
                          vault: vault,
                          busy: _busy,
                          members: members,
                          onDistribute: (GuildVaultItem item) => _distributeItem(item, members),
                        ),
                        _LedgerTab(entries: vault.ledger),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _VaultHeroCard extends StatelessWidget {
  const _VaultHeroCard({
    required this.vault,
    required this.busy,
    required this.formatGold,
    this.onCollect,
  });

  final GuildVaultState vault;
  final bool busy;
  final String Function(int) formatGold;
  final VoidCallback? onCollect;

  @override
  Widget build(BuildContext context) {
    return SettingsGlassCard(
      accent: SettingsPalette.gold,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'THE VAULT',
            style: GoogleFonts.urbanist(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: SettingsPalette.titanium,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatGold(vault.vaultGold)} 🪙',
            style: GoogleFonts.urbanist(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: SettingsPalette.gold,
            ),
          ),
          Text(
            'Biriken ${formatGold(vault.vaultGoldPending)} · Anıt ${formatGold(vault.monumentGoldPool)}',
            style: supportCaptionStyle,
          ),
          const SizedBox(height: 10),
          if (vault.canManage && onCollect != null)
            SettingsPrimaryButton(
              label: busy ? '…' : 'Birikeni topla',
              icon: Icons.download_rounded,
              loading: busy,
              onPressed: busy || vault.vaultGoldPending <= 0 ? null : onCollect,
            )
          else if (vault.isOfficer)
            Text(
              'Subay: görüntüleme. Dağıtım liderde.',
              style: supportCaptionStyle.copyWith(color: SettingsPalette.neon),
            )
          else if (!vault.canManage)
            Text(
              'Dağıtım yalnızca lonca liderine açık.',
              style: supportCaptionStyle,
            ),
        ],
      ),
    );
  }
}

class _GoldTab extends StatefulWidget {
  const _GoldTab({
    required this.vault,
    required this.members,
    required this.busy,
    required this.equalController,
    required this.amountFor,
    required this.onEqual,
    required this.onTargeted,
  });

  final GuildVaultState vault;
  final List<GuildMemberData> members;
  final bool busy;
  final TextEditingController equalController;
  final TextEditingController Function(String playerId) amountFor;
  final VoidCallback onEqual;
  final VoidCallback onTargeted;

  @override
  State<_GoldTab> createState() => _GoldTabState();
}

class _GoldTabState extends State<_GoldTab> {
  bool _targeted = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: ChoiceChip(
                label: const Text('Eşit pay'),
                selected: !_targeted,
                onSelected: widget.vault.canManage
                    ? (_) => setState(() => _targeted = false)
                    : null,
                selectedColor: SettingsPalette.gold.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Hedefli'),
                selected: _targeted,
                onSelected: widget.vault.canManage
                    ? (_) => setState(() => _targeted = true)
                    : null,
                selectedColor: SettingsPalette.fuchsia.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _targeted
              ? SettingsGlassCard(
                  key: const ValueKey<String>('targeted'),
                  accent: SettingsPalette.fuchsia,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('Üye başına miktar', style: supportCaptionStyle),
                      const SizedBox(height: 8),
                      ...widget.members.map(
                        (GuildMemberData m) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                flex: 2,
                                child: Text(m.username, style: supportBodyStyle),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: widget.amountFor(m.playerId),
                                  enabled: widget.vault.canManage && !widget.busy,
                                  keyboardType: TextInputType.number,
                                  decoration: supportInputDecoration(label: 'g'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SettingsPrimaryButton(
                        label: 'Hedefli dağıt',
                        icon: Icons.send_rounded,
                        loading: widget.busy,
                        onPressed: widget.vault.canManage && !widget.busy
                            ? widget.onTargeted
                            : null,
                      ),
                    ],
                  ),
                )
              : SettingsGlassCard(
                  key: const ValueKey<String>('equal'),
                  accent: SettingsPalette.neon,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: widget.equalController,
                        enabled: widget.vault.canManage && !widget.busy,
                        keyboardType: TextInputType.number,
                        decoration: supportInputDecoration(label: 'Toplam altın'),
                      ),
                      const SizedBox(height: 12),
                      SettingsPrimaryButton(
                        label: 'Eşit dağıt',
                        icon: Icons.groups_rounded,
                        loading: widget.busy,
                        onPressed: widget.vault.canManage && !widget.busy
                            ? widget.onEqual
                            : null,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _ItemsTab extends StatelessWidget {
  const _ItemsTab({
    required this.vault,
    required this.busy,
    required this.members,
    required this.onDistribute,
  });

  final GuildVaultState vault;
  final bool busy;
  final List<GuildMemberData> members;
  final ValueChanged<GuildVaultItem> onDistribute;

  @override
  Widget build(BuildContext context) {
    if (vault.items.isEmpty) {
      return Center(
        child: SettingsGlassCard(
          accent: SettingsPalette.titanium,
          child: Text('Kasada eşya yok.', style: supportCaptionStyle),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12),
      itemCount: vault.items.length,
      itemBuilder: (BuildContext context, int index) {
        final GuildVaultItem item = vault.items[index];
        final Color accent = vaultRarityAccent(item.rarity);
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 12, end: 0),
          duration: Duration(milliseconds: 180 + index * 40),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double offset, Widget? child) {
            return Transform.translate(
              offset: Offset(0, offset),
              child: Opacity(opacity: (12 - offset) / 12, child: child),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SettingsGlassCard(
              accent: accent,
              glow: item.rarity == 'legendary' || item.rarity == 'mythic',
              child: Row(
                children: <Widget>[
                  Icon(Icons.diamond_outlined, color: accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(item.itemName, style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi)),
                        Text(
                          'x${item.quantity} · ${item.rarity ?? '—'} · ${item.sourceType ?? ''}',
                          style: supportCaptionStyle,
                        ),
                      ],
                    ),
                  ),
                  if (vault.canManage)
                    TextButton(
                      onPressed: busy ? null : () => onDistribute(item),
                      child: const Text('Dağıt'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LedgerTab extends StatelessWidget {
  const _LedgerTab({required this.entries});

  final List<GuildVaultLedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(child: Text('Kayıt yok.', style: supportCaptionStyle));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int i) {
        final GuildVaultLedgerEntry e = entries[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SettingsGlassCard(
            accent: SettingsPalette.obsidian,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              vaultLedgerLabel(e.action, e.payload),
              style: supportCaptionStyle.copyWith(fontSize: 12),
            ),
          ),
        );
      },
    );
  }
}
