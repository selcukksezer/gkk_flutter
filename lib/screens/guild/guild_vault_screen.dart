import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/item_icon_view.dart';
import '../../components/layout/game_screen_background.dart';
import '../../models/guild_model.dart';
import '../../models/guild_vault_model.dart';
import '../../models/item_model.dart';
import '../../providers/guild_provider.dart';
import '../../providers/guild_vault_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/logout_helper.dart';
import '../guild_war/widgets/guild_war_design.dart';
import '../guild_war/widgets/guild_war_sub_screen_scaffold.dart';
import '../support/widgets/support_design.dart';

String _vaultFmtGold(dynamic raw) {
  final int? n = raw is int
      ? raw
      : raw is num
          ? raw.toInt()
          : int.tryParse(raw?.toString() ?? '');
  if (n == null) return raw?.toString() ?? '—';
  if (n.abs() >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n.abs() >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

String _vaultItemLabel(Map<String, dynamic> payload) {
  final String name =
      (payload['item_name'] ?? payload['item_id'] ?? 'eşya').toString();
  final int qty = payload['quantity'] is num
      ? (payload['quantity'] as num).toInt()
      : int.tryParse(payload['quantity']?.toString() ?? '') ?? 1;
  final int enh = payload['enhancement_level'] is num
      ? (payload['enhancement_level'] as num).toInt()
      : int.tryParse(payload['enhancement_level']?.toString() ?? '') ?? 0;
  final String base = qty > 1 ? '$name ×$qty' : name;
  return enh > 0 ? '$base (+$enh)' : base;
}

String _vaultRecipientsLine(Map<String, dynamic> payload) {
  final dynamic raw = payload['recipients'];
  if (raw is! List || raw.isEmpty) return '';
  final List<String> parts = <String>[];
  for (final dynamic e in raw.take(6)) {
    if (e is! Map) continue;
    final Map<String, dynamic> m = Map<String, dynamic>.from(e);
    final String who = (m['username'] ?? 'üye').toString();
    parts.add('$who ${_vaultFmtGold(m['amount'])}g');
  }
  final String joined = parts.join(' · ');
  if (raw.length > 6) return '$joined · +${raw.length - 6}';
  return joined;
}

/// Title + optional detail for vault Geçmiş rows.
({String title, String? detail}) vaultHistoryCopy({
  required String action,
  required Map<String, dynamic> payload,
  String? actorName,
}) {
  final String actor = (actorName != null && actorName.isNotEmpty)
      ? actorName
      : (payload['auto'] == true || payload['auto_weekly'] == true ? 'Sistem' : '—');

  switch (action) {
    case 'accrue':
      return (
        title: 'Bölge geliri +${_vaultFmtGold(payload['amount'])}g → kasa',
        detail: null,
      );
    case 'vault_tax':
      return (
        title: 'Kasa vergisi −${_vaultFmtGold(payload['amount'])}g',
        detail: 'Krallık hazinesi',
      );
    case 'collect':
      return (
        title: 'Toplama +${_vaultFmtGold(payload['amount'])}g → kasa',
        detail: actor,
      );
    case 'distribute_gold':
      final String mode = (payload['mode'] ?? 'equal').toString();
      final String recipients = _vaultRecipientsLine(payload);
      if (mode == 'equal') {
        return (
          title: 'Altın eşit dağıtım −${_vaultFmtGold(payload['amount'])}g',
          detail: recipients.isNotEmpty
              ? 'Lider: $actor · $recipients'
              : 'Lider: $actor · tüm üyeler'
                  '${payload['per_member'] != null ? ' · kişi başı ${_vaultFmtGold(payload['per_member'])}g' : ''}',
        );
      }
      return (
        title: 'Altın hedefli dağıtım −${_vaultFmtGold(payload['amount'])}g',
        detail: recipients.isNotEmpty
            ? 'Lider: $actor · $recipients'
            : 'Lider: $actor',
      );
    case 'distribute_item':
      final String to = (payload['to_username'] ?? 'üye').toString();
      return (
        title: '${_vaultItemLabel(payload)} → $to',
        detail: 'Gönderen: $actor',
      );
    case 'territory_loot':
      final String zone =
          (payload['territory_name'] ?? 'Bölge').toString();
      return (
        title: '${_vaultItemLabel(payload)} → kasa',
        detail: 'Kaynak: $zone',
      );
    case 'attack_spend':
      final String def = (payload['defender'] ?? '—').toString();
      final bool ok = payload['success'] == true;
      return (
        title: 'Saldırı −${_vaultFmtGold(payload['gold'])}g'
            '${ok ? ' (kazanıldı)' : ' (başarısız)'}',
        detail: 'Lider: $actor · rakip: $def',
      );
    case 'defense_gold':
      return (
        title: 'Savunma −${_vaultFmtGold(payload['gold'] ?? payload['amount'])}g',
        detail: actor,
      );
    case 'siege_reward':
    case 'credit':
      return (
        title: 'Kuşatma/ödül +${_vaultFmtGold(payload['amount'])}g → kasa',
        detail: actor,
      );
    case 'member_deposit':
      return (
        title: 'Yatırma +${_vaultFmtGold(payload['amount'])}g → kasa',
        detail: 'Üye: $actor',
      );
    case 'monument_gold_to_vault':
      return (
        title: 'Anıt bağışı +${_vaultFmtGold(payload['amount'])}g → kasa',
        detail: actor,
      );
    case 'monument_upgrade_spend':
      return (
        title: 'Anıt yükseltme −${_vaultFmtGold(payload['amount'])}g',
        detail: actor,
      );
    case 'tournament':
      return (
        title: 'Turnuva ödülü +${_vaultFmtGold(payload['amount'])}g → kasa',
        detail: actor,
      );
    default:
      return (title: action, detail: actor == '—' ? null : actor);
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
  final TextEditingController _depositAmount = TextEditingController();
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
    _depositAmount.dispose();
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

  Future<void> _deposit() async {
    final int amount = int.tryParse(_depositAmount.text.trim().replaceAll(',', '')) ?? 0;
    if (amount < 1000) {
      AppMessenger.showError(context, 'Minimum 1.000g yatır.');
      return;
    }
    setState(() => _busy = true);
    final String? err = await ref.read(guildVaultProvider.notifier).depositGold(amount);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
    } else {
      _depositAmount.clear();
      AppMessenger.showSuccess(context, 'Kasaya yatırıldı.');
      await ref.read(playerProvider.notifier).loadProfile();
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
    final int cap = (vault.vaultGold * 0.40).floor().clamp(0, vault.vaultGold);
    for (final GuildMemberData m in members) {
      final int amount = int.tryParse(_amountFor(m.playerId).text.trim()) ?? 0;
      if (amount <= 0) continue;
      if (cap > 0 && amount > cap) {
        AppMessenger.showError(context, 'Üye başına max %40 ($cap g).');
        return;
      }
      final String targetId =
          (m.userId != null && m.userId!.isNotEmpty) ? m.userId! : m.playerId;
      allocations.add(<String, dynamic>{'user_id': targetId, 'amount': amount});
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
                'Kime gönder?',
                style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi),
              ),
              const SizedBox(height: 4),
              Text(
                item.enhancementLevel > 0
                    ? '${item.itemName} (+${item.enhancementLevel})'
                    : item.itemName,
                style: supportCaptionStyle.copyWith(color: SettingsPalette.gold),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Column(
                    children: members
                        .map(
                          (GuildMemberData m) => SettingsPressable(
                            onTap: () => Navigator.pop(ctx, m),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      m.username,
                                      style: supportBodyStyle.copyWith(
                                        color: SettingsPalette.textHi,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    m.role.name,
                                    style: supportCaptionStyle,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
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
    final String targetId =
        (target.userId != null && target.userId!.isNotEmpty) ? target.userId! : target.playerId;
    final String? err = await ref.read(guildVaultProvider.notifier).distributeItem(
          vaultItemId: item.id,
          userId: targetId,
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
                    depositController: _depositAmount,
                    onDeposit: _deposit,
                    onToggleAutoPayout: vault.canManage
                        ? (bool enabled) async {
                            setState(() => _busy = true);
                            final String? err = await ref
                                .read(guildVaultProvider.notifier)
                                .setAutoPayout(enabled);
                            if (!mounted) return;
                            setState(() => _busy = false);
                            if (err != null) {
                              AppMessenger.showError(context, err);
                            }
                          }
                        : null,
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
                                '${t.name}: ${_formatGold(t.tradeIncome)}g/gün · 6–7 eşya/gün',
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
                      Tab(text: 'Geçmiş'),
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
    required this.depositController,
    required this.onDeposit,
    this.onToggleAutoPayout,
  });

  final GuildVaultState vault;
  final bool busy;
  final String Function(int) formatGold;
  final TextEditingController depositController;
  final VoidCallback onDeposit;
  final Future<void> Function(bool enabled)? onToggleAutoPayout;

  @override
  Widget build(BuildContext context) {
    final String roleLabel = vault.isLeader
        ? 'Lider'
        : (vault.isOfficer ? 'Officer' : (vault.guildRole ?? 'Üye'));
    return SettingsGlassCard(
      accent: SettingsPalette.gold,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
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
              const Spacer(),
              Text(
                roleLabel,
                style: supportCaptionStyle.copyWith(color: SettingsPalette.neon),
              ),
            ],
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
            'Bölge geliri otomatik kasaya · Günlük vergi %${(vault.vaultTaxRate * 100).round()} (krallık hazinesi) · Anıt altını da buraya',
            style: supportCaptionStyle,
          ),
          const SizedBox(height: 10),
          Text(
            'Kasaya yatır (her üye) · min 1k · max 50M/tx · 200M/gün',
            style: supportCaptionStyle.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: depositController,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: supportInputDecoration(label: 'Miktar (g)'),
                ),
              ),
              const SizedBox(width: 8),
              SettingsPrimaryButton(
                label: busy ? '…' : 'Yatır',
                icon: Icons.upload_rounded,
                loading: busy,
                onPressed: busy ? null : onDeposit,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (vault.isOfficer && !vault.isLeader) ...<Widget>[
            Text(
              'Officer: dağıtım yok. Dağıtım sadece lider. Anıt gold → kasa.',
              style: supportCaptionStyle.copyWith(color: SettingsPalette.neon),
            ),
          ] else if (!vault.canManage)
            Text(
              'Dağıtım yalnızca lonca liderine açık. Yatırma her üyeye açık.',
              style: supportCaptionStyle,
            ),
          if (vault.canManage && onToggleAutoPayout != null) ...<Widget>[
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Haftalık otomatik eşit ödeme',
                style: supportCaptionStyle.copyWith(fontSize: 12),
              ),
              value: vault.vaultAutoPayoutWeekly,
              activeColor: SettingsPalette.gold,
              onChanged: busy
                  ? null
                  : (bool v) {
                      onToggleAutoPayout!(v);
                    },
            ),
          ],
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
                      Text('Üye başına miktar (max %40 toplam dağıtımdan)', style: supportCaptionStyle),
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

    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'KASA EŞYALARI',
              style: GoogleFonts.urbanist(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                color: Colors.white70,
              ),
            ),
            Text(
              '${vault.items.length} eşya',
              style: supportCaptionStyle.copyWith(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GameFixedGrid(
          crossAxisCount: 4,
          spacing: 8,
          itemCount: vault.items.length,
          itemBuilder: (BuildContext context, int index) {
            final GuildVaultItem item = vault.items[index];
            return _VaultInventorySlotCard(
              item: item,
              canDistribute: vault.canManage && !busy,
              onTap: vault.canManage && !busy
                  ? () => onDistribute(item)
                  : null,
            );
          },
        ),
      ],
    );
  }
}

class _VaultInventorySlotCard extends StatelessWidget {
  const _VaultInventorySlotCard({
    required this.item,
    required this.canDistribute,
    this.onTap,
  });

  final GuildVaultItem item;
  final bool canDistribute;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Rarity rarity = RarityParsing.fromValue(item.rarity ?? 'common');
    final Color rarityColor = getRarityColor(rarity);
    final ItemType itemType = ItemTypeParsing.fromValue(item.itemType);
    final String label = item.enhancementLevel > 0
        ? '${item.itemName} +${item.enhancementLevel}'
        : item.itemName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: rarityColor.withValues(alpha: canDistribute ? 0.55 : 0.35),
                    width: canDistribute ? 1.4 : 1.0,
                  ),
                  color: const Color(0xFF0D1424),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: rarityColor.withValues(alpha: 0.08),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: <Color>[
                                rarityColor.withValues(alpha: 0.12),
                                Colors.transparent,
                              ],
                              center: Alignment.center,
                              radius: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
                        child: Center(
                          child: ItemIconView(
                            iconValue: item.icon,
                            itemId: item.itemId,
                            itemType: itemType,
                            size: 40,
                            expand: true,
                          ),
                        ),
                      ),
                    ),
                    if (item.enhancementLevel > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xE6080D1A),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                              width: 0.7,
                            ),
                          ),
                          child: Text(
                            '+${item.enhancementLevel}',
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFD700),
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    if (item.quantity > 1)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xE6080D1A),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: rarityColor.withValues(alpha: 0.45),
                              width: 0.7,
                            ),
                          ),
                          child: Text(
                            'x${item.quantity}',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: rarityColor,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _VaultHistoryFilter {
  all,
  goldIn,
  goldOut,
  itemIn,
  itemOut,
}

class _LedgerTab extends StatefulWidget {
  const _LedgerTab({required this.entries});

  final List<GuildVaultLedgerEntry> entries;

  @override
  State<_LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends State<_LedgerTab> {
  static const int _pageStart = 20;
  static const int _pageStep = 50;

  final TextEditingController _search = TextEditingController();
  _VaultHistoryFilter _filter = _VaultHistoryFilter.all;
  int _visible = _pageStart;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _LedgerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length) {
      _visible = _pageStart;
    }
  }

  bool _matchesFilter(String action, _VaultHistoryFilter filter) {
    switch (filter) {
      case _VaultHistoryFilter.all:
        return true;
      case _VaultHistoryFilter.goldIn:
        return const <String>{
          'accrue',
          'collect',
          'member_deposit',
          'monument_gold_to_vault',
          'tournament',
          'siege_reward',
          'credit',
        }.contains(action);
      case _VaultHistoryFilter.goldOut:
        return const <String>{
          'distribute_gold',
          'attack_spend',
          'vault_tax',
          'monument_upgrade_spend',
          'defense_gold',
        }.contains(action);
      case _VaultHistoryFilter.itemIn:
        return action == 'territory_loot';
      case _VaultHistoryFilter.itemOut:
        return action == 'distribute_item';
    }
  }

  List<({GuildVaultLedgerEntry entry, String title, String? detail})> _filtered() {
    final String q = _search.text.trim().toLowerCase();
    final List<({GuildVaultLedgerEntry entry, String title, String? detail})> out =
        <({GuildVaultLedgerEntry entry, String title, String? detail})>[];
    for (final GuildVaultLedgerEntry e in widget.entries) {
      if (!_matchesFilter(e.action, _filter)) continue;
      final ({String title, String? detail}) copy = vaultHistoryCopy(
        action: e.action,
        payload: e.payload,
        actorName: e.actorName,
      );
      if (q.isNotEmpty) {
        final String hay = <String>[
          copy.title,
          copy.detail ?? '',
          e.actorName ?? '',
          e.action,
          e.payload['item_name']?.toString() ?? '',
          e.payload['item_id']?.toString() ?? '',
          e.payload['to_username']?.toString() ?? '',
          e.payload['territory_name']?.toString() ?? '',
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) continue;
      }
      out.add((entry: e, title: copy.title, detail: copy.detail));
    }
    return out;
  }

  String _when(DateTime? dt) {
    if (dt == null) return '';
    final DateTime local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.day}.${local.month}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Color _accentFor(String action) {
    switch (action) {
      case 'distribute_item':
      case 'distribute_gold':
        return SettingsPalette.fuchsia;
      case 'territory_loot':
      case 'accrue':
      case 'member_deposit':
      case 'monument_gold_to_vault':
      case 'tournament':
      case 'siege_reward':
      case 'credit':
        return SettingsPalette.gold;
      case 'attack_spend':
      case 'vault_tax':
      case 'monument_upgrade_spend':
        return SettingsPalette.coral;
      default:
        return SettingsPalette.obsidian;
    }
  }

  Widget _filterChip(String label, _VaultHistoryFilter value) {
    final bool selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _filter = value;
            _visible = _pageStart;
          });
        },
        selectedColor: SettingsPalette.gold.withValues(alpha: 0.28),
        backgroundColor: Colors.white.withValues(alpha: 0.04),
        labelStyle: TextStyle(
          color: selected ? SettingsPalette.gold : SettingsPalette.titanium,
        ),
        side: BorderSide(
          color: selected
              ? SettingsPalette.gold.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.08),
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Center(child: Text('Geçmiş boş.', style: supportCaptionStyle));
    }

    final List<({GuildVaultLedgerEntry entry, String title, String? detail})> filtered =
        _filtered();
    final int showCount = filtered.length < _visible ? filtered.length : _visible;
    final bool canMore = showCount < filtered.length;

    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: <Widget>[
        TextField(
          controller: _search,
          onChanged: (_) {
            setState(() {
              _visible = _pageStart;
            });
          },
          style: supportBodyStyle.copyWith(fontSize: 13),
          decoration: supportInputDecoration(label: 'Ara').copyWith(
            prefixIcon: Icon(
              Icons.search_rounded,
              color: SettingsPalette.titanium,
              size: 20,
            ),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: SettingsPalette.titanium,
                    onPressed: () {
                      _search.clear();
                      setState(() {
                        _visible = _pageStart;
                      });
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _filterChip('Tümü', _VaultHistoryFilter.all),
              _filterChip('Altın gelen', _VaultHistoryFilter.goldIn),
              _filterChip('Altın giden', _VaultHistoryFilter.goldOut),
              _filterChip('Eşya gelen', _VaultHistoryFilter.itemIn),
              _filterChip('Eşya giden', _VaultHistoryFilter.itemOut),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${filtered.length} sonuç · $showCount gösteriliyor',
          style: supportCaptionStyle.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text('Sonuç yok.', style: supportCaptionStyle),
            ),
          )
        else
          ...List<Widget>.generate(showCount, (int i) {
            final ({GuildVaultLedgerEntry entry, String title, String? detail}) row =
                filtered[i];
            final GuildVaultLedgerEntry e = row.entry;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SettingsGlassCard(
                accent: _accentFor(e.action),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      row.title,
                      style: supportCaptionStyle.copyWith(
                        fontSize: 12,
                        color: SettingsPalette.textHi,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (row.detail != null && row.detail!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        row.detail!,
                        style: supportCaptionStyle.copyWith(fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _when(e.createdAt),
                      style: supportCaptionStyle.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            );
          }),
        if (canMore)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: SettingsPrimaryButton(
              label: 'Daha fazla göster (+$_pageStep)',
              icon: Icons.expand_more_rounded,
              onPressed: () {
                setState(() {
                  _visible += _pageStep;
                });
              },
            ),
          ),
      ],
    );
  }
}
