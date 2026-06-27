import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../components/common/item_icon_view.dart';
import '../../models/mekan_model.dart';
import '../../providers/mekan_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'widgets/mekan_design.dart';
import 'widgets/mekan_scaffold.dart';
import 'widgets/mekan_theme.dart';

class MyMekanScreen extends ConsumerStatefulWidget {
  const MyMekanScreen({super.key});

  @override
  ConsumerState<MyMekanScreen> createState() => _MyMekanScreenState();
}

class _MyMekanScreenState extends ConsumerState<MyMekanScreen> with SingleTickerProviderStateMixin {
  Mekan? _mekan;
  MekanStats? _stats;
  List<MekanStockEntry> _stock = <MekanStockEntry>[];
  List<MekanInventoryEntry> _inventory = <MekanInventoryEntry>[];
  bool _loading = true;
  bool _busy = false;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  MekanRepository get _repo => ref.read(mekanRepositoryProvider);

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _loading = true);
    try {
      final Mekan? m = await _repo.fetchMyMekan();
      if (m == null) {
        if (mounted) {
          setState(() {
            _mekan = null;
            _loading = false;
          });
        }
        return;
      }
      final List<MekanStockEntry> stock = await _repo.fetchStock(m.id);
      final List<MekanInventoryEntry> inv = await _repo.fetchEligibleInventory();
      MekanStats? stats;
      try {
        stats = await _repo.fetchStats(m.id);
      } catch (_) {/* stats RPC optional */}
      if (mounted) {
        setState(() {
          _mekan = m;
          _stock = stock;
          _inventory = inv;
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppMessenger.showError(context, '$e');
      }
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && success != null) AppMessenger.showSuccess(context, success);
      await ref.read(playerProvider.notifier).loadProfile();
      await _load(silent: true);
    } catch (e) {
      if (mounted) AppMessenger.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Mekan? mekan = _mekan;
    final Color accent = MekanPalette.accent(mekan?.typeKey);

    return MekanSubScaffold(
      title: 'Benim Mekanim',
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.aqua))
          : mekan == null
              ? MekanEmpty(
                  icon: Icons.add_business_outlined,
                  title: 'Mekanin yok',
                  message: 'Han ticareti icin once bir mekan ac.',
                  action: NeonButton(
                    label: 'Mekan Ac',
                    icon: Icons.add_business_rounded,
                    onPressed: () => context.go(AppRoutes.mekanCreate),
                    expand: false,
                  ),
                )
              : Column(
                  children: <Widget>[
                    _vaultHeader(mekan, accent),
                    Material(
                      color: MekanPalette.void_.withValues(alpha: 0.6),
                      child: TabBar(
                        controller: _tab,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: accent,
                        labelColor: accent,
                        unselectedLabelColor: MekanPalette.textLow,
                        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                        tabs: const <Tab>[
                          Tab(text: 'Genel', icon: Icon(Icons.dashboard_rounded, size: 18)),
                          Tab(text: 'Stok', icon: Icon(Icons.inventory_2_rounded, size: 18)),
                          Tab(text: 'Istatistik', icon: Icon(Icons.insights_rounded, size: 18)),
                          Tab(text: 'Yukseltme', icon: Icon(Icons.upgrade_rounded, size: 18)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tab,
                        children: <Widget>[
                          _overviewTab(mekan, accent),
                          _stockTab(mekan, accent),
                          _statsTab(mekan, accent),
                          _upgradeTab(mekan, accent),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── The Vault header ──────────────────────────────────────────────────────
  Widget _vaultHeader(Mekan mekan, Color accent) {
    final int revenue = _stats?.totalRevenue ?? mekan.totalRevenue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: NeonPanel(
        accent: MekanPalette.gold,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.account_balance_rounded, color: MekanPalette.gold, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('THE VAULT',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: MekanPalette.textMid, letterSpacing: 1.5)),
                ),
                MekanStatusPill(isOpen: mekan.isOpen && !mekan.raidClosed),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.paid_rounded, color: MekanPalette.gold, size: 26),
                const SizedBox(width: 8),
                Text(
                  '$revenue',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: MekanPalette.gold, letterSpacing: 0.5),
                ),
              ],
            ),
            const Text('Toplam Gelir', style: TextStyle(fontSize: 11.5, color: MekanPalette.textLow, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: NeonButton(
                    label: mekan.isOpen ? 'Kapat' : 'Ac',
                    icon: mekan.isOpen ? Icons.lock_rounded : Icons.lock_open_rounded,
                    filled: false,
                    accent: mekan.isOpen ? MekanPalette.ruby : MekanPalette.neon,
                    busy: _busy,
                    onPressed: mekan.raidClosed
                        ? null
                        : () => _run(() => _repo.toggleStatus(mekanId: mekan.id, isOpen: !mekan.isOpen),
                            success: mekan.isOpen ? 'Mekan kapatildi' : 'Mekan acildi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeonButton(
                    label: mekan.happyHourActive ? 'Happy Bitir' : 'Happy Hour',
                    icon: Icons.celebration_rounded,
                    accent: MekanPalette.coral,
                    busy: _busy,
                    onPressed: () => _run(
                        () => _repo.setHappyHour(mekanId: mekan.id, active: !mekan.happyHourActive),
                        success: mekan.happyHourActive ? 'Happy Hour bitti' : 'Happy Hour basladi!'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Overview tab ────────────────────────────────────────────────────────────
  Widget _overviewTab(Mekan mekan, Color accent) {
    final MekanStats? s = _stats;
    return RefreshIndicator(
      color: accent,
      backgroundColor: MekanPalette.navy,
      onRefresh: () => _load(silent: true),
      child: ListView(
        padding: GameScrollLayout.fromLTRB(
          context,
          left: 14,
          top: 14,
          right: 14,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          NeonPanel(
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    MekanTypeBadge(typeKey: mekan.typeKey, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(mekan.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: MekanPalette.textHi)),
                          Text(mekanTypeLabelKey(mekan.typeKey),
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: accent)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    GlowChip(icon: Icons.military_tech_rounded, label: 'Lv ${mekan.level}', color: accent),
                    GlowChip(icon: Icons.star_rounded, label: '${mekan.fame} sohret', color: MekanPalette.gold),
                    GlowChip(
                      icon: Icons.inventory_2_rounded,
                      label: '${s?.usedCapacity ?? '?'}/${s?.capacity ?? '?'} kapasite',
                      color: MekanPalette.aqua,
                    ),
                  ],
                ),
                if (mekan.mekanType == MekanType.yeralti) ...<Widget>[
                  const SizedBox(height: 14),
                  SuspicionMeter(value: mekan.suspicion),
                ],
              ],
            ),
          ),
          if (mekan.happyHourActive) ...<Widget>[
            const SizedBox(height: 12),
            HappyHourBanner(until: DateTime.parse(mekan.happyHourUntil!)),
          ],
          const SizedBox(height: 12),
          _rentCard(mekan, s),
          const SizedBox(height: 12),
          NeonButton(
            label: 'Vitrini Goruntule',
            icon: Icons.visibility_rounded,
            filled: false,
            accent: accent,
            onPressed: () => context.go('/mekans/${mekan.id}'),
          ),
          if (mekanSupportsPvp(mekan.typeKey)) ...<Widget>[
            const SizedBox(height: 10),
            NeonButton(
              label: 'PvP Arena',
              icon: Icons.sports_mma_rounded,
              accent: MekanPalette.ruby,
              onPressed: mekan.isOpen ? () => context.go('/mekans/${mekan.id}/arena') : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _rentCard(Mekan mekan, MekanStats? s) {
    final bool overdue = s?.rentOverdue ?? false;
    final int rent = s?.monthlyRent ?? 0;
    return NeonPanel(
      accent: overdue ? MekanPalette.ruby : MekanPalette.titanium,
      child: Row(
        children: <Widget>[
          Icon(Icons.receipt_long_rounded, color: overdue ? MekanPalette.ruby : MekanPalette.titanium, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Aylik Kira', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: MekanPalette.textHi)),
                Text(
                  overdue ? 'Gecikmis! Mekan kapanabilir.' : 'Odeme guncel',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: overdue ? MekanPalette.ruby : MekanPalette.textMid,
                  ),
                ),
              ],
            ),
          ),
          NeonButton(
            label: rent > 0 ? formatMekanGold(rent) : 'Ode',
            icon: Icons.paid_rounded,
            accent: MekanPalette.gold,
            expand: false,
            busy: _busy,
            onPressed: () => _run(() => _repo.payRent(mekan.id), success: 'Kira odendi'),
          ),
        ],
      ),
    );
  }

  // ── Stock tab ────────────────────────────────────────────────────────────────
  Widget _stockTab(Mekan mekan, Color accent) {
    return RefreshIndicator(
      color: accent,
      backgroundColor: MekanPalette.navy,
      onRefresh: () => _load(silent: true),
      child: ListView(
        padding: GameScrollLayout.fromLTRB(
          context,
          left: 14,
          top: 14,
          right: 14,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          NeonButton(
            label: 'Stok Ekle / Guncelle',
            icon: Icons.add_circle_rounded,
            accent: accent,
            onPressed: _inventory.isEmpty ? null : () => _openStockSheet(mekan),
          ),
          if (_inventory.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Uygun envanter yok — iksir veya Han itemi gerekli.',
                  style: TextStyle(fontSize: 12, color: MekanPalette.textLow)),
            ),
          const SizedBox(height: 16),
          NeonSectionHeader(title: 'Mevcut Stok', subtitle: '${_stock.length} urun', accent: accent),
          const SizedBox(height: 10),
          if (_stock.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: MekanEmpty(
                icon: Icons.inventory_2_outlined,
                title: 'Stok bos',
                message: 'Yukaridan urun ekleyerek satisa basla.',
              ),
            )
          else
            ..._stock.map((MekanStockEntry s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StockManageRow(entry: s, onTap: () => _openStockSheet(mekan, existing: s)),
                )),
        ],
      ),
    );
  }

  Future<void> _openStockSheet(Mekan mekan, {MekanStockEntry? existing}) async {
    MekanInventoryEntry? selected;
    if (existing != null) {
      selected = MekanInventoryEntry(
        itemId: existing.itemId,
        name: existing.name,
        icon: existing.icon,
        rarity: existing.rarity,
        subType: existing.subType,
        isHanOnly: existing.isHanOnly,
        quantity: existing.quantity,
        eligible: true,
      );
    } else if (_inventory.isNotEmpty) {
      selected = _inventory.first;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StockSheet(
        inventory: _inventory,
        existing: existing,
        initialSelected: selected,
        onSave: (String itemId, int qty, int price) =>
            _repo.updateStock(mekanId: mekan.id, itemId: itemId, quantity: qty, sellPrice: price),
        onDone: () async {
          await ref.read(playerProvider.notifier).loadProfile();
          await _load(silent: true);
        },
      ),
    );
  }

  // ── Stats tab ──────────────────────────────────────────────────────────────
  Widget _statsTab(Mekan mekan, Color accent) {
    final MekanStats? s = _stats;
    if (s == null) {
      return const MekanEmpty(
        icon: Icons.insights_rounded,
        title: 'Istatistik yok',
        message: 'Veri henuz hazir degil. Birkac satistan sonra tekrar bak.',
      );
    }
    return RefreshIndicator(
      color: accent,
      backgroundColor: MekanPalette.navy,
      onRefresh: () => _load(silent: true),
      child: ListView(
        padding: GameScrollLayout.fromLTRB(
          context,
          left: 14,
          top: 14,
          right: 14,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          GameFixedGrid(
            crossAxisCount: 2,
            spacing: 10,
            itemCount: 6,
            itemBuilder: (BuildContext context, int index) {
              final List<Widget> boxes = <Widget>[
                _statBox(Icons.paid_rounded, 'Toplam Gelir', formatMekanGold(s.totalRevenue), MekanPalette.gold),
                _statBox(Icons.shopping_cart_rounded, 'Toplam Satis', '${s.totalSales}', MekanPalette.aqua),
                _statBox(Icons.today_rounded, 'Bugun Gelir', formatMekanGold(s.todayRevenue), MekanPalette.neon),
                _statBox(Icons.people_rounded, 'Haftalik Musteri', '${s.weekCustomers}', MekanPalette.amethyst),
                _statBox(Icons.sports_mma_rounded, 'PvP Mac', '${s.pvpMatchCount}', MekanPalette.ruby),
                _statBox(Icons.inventory_rounded, 'Kapasite', '${s.usedCapacity}/${s.capacity}', MekanPalette.coral),
              ];
              return boxes[index];
            },
          ),
          const SizedBox(height: 16),
          if (s.topItem != null)
            NeonPanel(
              accent: MekanPalette.gold,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.emoji_events_rounded, color: MekanPalette.gold, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('En Cok Satan',
                            style: TextStyle(fontSize: 12, color: MekanPalette.textMid, fontWeight: FontWeight.w700)),
                        Text(s.topItem!,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: MekanPalette.textHi)),
                      ],
                    ),
                  ),
                  Text('${s.topItemQty} adet',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: MekanPalette.gold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statBox(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[color.withValues(alpha: 0.16), MekanPalette.navy.withValues(alpha: 0.9)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: MekanPalette.textHi)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: MekanPalette.textLow, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Upgrade tab ──────────────────────────────────────────────────────────────
  Widget _upgradeTab(Mekan mekan, Color accent) {
    final MekanStats? s = _stats;
    final int? cost = s?.nextUpgradeCost;
    final bool maxed = mekan.level >= 10;
    return ListView(
      padding: GameScrollLayout.fromLTRB(
        context,
        left: 14,
        top: 14,
        right: 14,
      ),
      children: <Widget>[
        NeonPanel(
          accent: accent,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Text('SEVIYE ${mekan.level}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: accent, letterSpacing: 2)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: mekan.level / 10,
                  minHeight: 10,
                  backgroundColor: MekanPalette.obsidian,
                  color: accent,
                ),
              ),
              const SizedBox(height: 16),
              if (maxed)
                const Text('Maksimum seviyeye ulasildi!',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: MekanPalette.gold))
              else ...<Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    GlowChip(icon: Icons.arrow_upward_rounded, label: 'Lv ${mekan.level + 1}', color: MekanPalette.neon),
                    const SizedBox(width: 8),
                    GlowChip(icon: Icons.inventory_2_rounded, label: '+kapasite', color: MekanPalette.aqua),
                    const SizedBox(width: 8),
                    GlowChip(icon: Icons.trending_up_rounded, label: '+kar', color: MekanPalette.gold),
                  ],
                ),
                const SizedBox(height: 18),
                NeonButton(
                  label: cost != null ? 'Yukselt - ${formatMekanGold(cost)}' : 'Yukselt',
                  icon: Icons.upgrade_rounded,
                  accent: MekanPalette.gold,
                  busy: _busy,
                  onPressed: () => _confirmUpgrade(mekan, cost),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const NeonSectionHeader(title: 'Yukseltme Avantajlari', accent: MekanPalette.gold),
        const SizedBox(height: 10),
        NeonPanel(
          accent: MekanPalette.titanium,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _UpgradeBenefit(icon: Icons.inventory_2_rounded, text: 'Daha fazla stok kapasitesi'),
              SizedBox(height: 10),
              _UpgradeBenefit(icon: Icons.trending_up_rounded, text: 'Satislardan daha yuksek kar bonusu'),
              SizedBox(height: 10),
              _UpgradeBenefit(icon: Icons.star_rounded, text: 'Yukseltme basina +100 sohret'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmUpgrade(Mekan mekan, int? cost) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: MekanPalette.surfaceHi,
        title: const Text('Mekani Yukselt', style: TextStyle(color: MekanPalette.textHi, fontWeight: FontWeight.w900)),
        content: Text(
          'Seviye ${mekan.level + 1} icin ${cost != null ? formatMekanGold(cost) : '?'} altin harcanacak.',
          style: const TextStyle(color: MekanPalette.textMid),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgec')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yukselt')),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => _repo.upgrade(mekan.id), success: 'Mekan yukseltildi!');
    }
  }
}

class _UpgradeBenefit extends StatelessWidget {
  const _UpgradeBenefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: MekanPalette.neon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: MekanPalette.textHi, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _StockManageRow extends StatelessWidget {
  const _StockManageRow({required this.entry, required this.onTap});
  final MekanStockEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color rare = entry.isHanOnly ? MekanPalette.fuchsia : MekanPalette.aqua;
    return PressableScale(
      onTap: onTap,
      child: NeonPanel(
        accent: rare,
        padding: const EdgeInsets.all(10),
        glow: false,
        child: Row(
          children: <Widget>[
            ItemIconView(iconValue: entry.icon, itemId: entry.itemId, size: 40, fallback: '🧪'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: MekanPalette.textHi)),
                  Text('Stok: ${entry.quantity}',
                      style: const TextStyle(fontSize: 11.5, color: MekanPalette.textMid, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            GoldPriceBadge(amount: entry.sellPrice, small: true),
            const SizedBox(width: 6),
            const Icon(Icons.edit_rounded, size: 16, color: MekanPalette.textLow),
          ],
        ),
      ),
    );
  }
}

class _StockSheet extends StatefulWidget {
  const _StockSheet({
    required this.inventory,
    required this.existing,
    required this.initialSelected,
    required this.onSave,
    required this.onDone,
  });

  final List<MekanInventoryEntry> inventory;
  final MekanStockEntry? existing;
  final MekanInventoryEntry? initialSelected;
  final Future<void> Function(String itemId, int qty, int price) onSave;
  final Future<void> Function() onDone;

  @override
  State<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends State<_StockSheet> {
  late String? _itemId;
  late TextEditingController _qty;
  late TextEditingController _price;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _itemId = widget.initialSelected?.itemId;
    _qty = TextEditingController(text: '${widget.existing?.quantity ?? 1}');
    _price = TextEditingController(text: '${widget.existing?.sellPrice ?? _suggestedPrice(_itemId)}');
  }

  int _suggestedPrice(String? id) {
    if (id == null) return 100;
    final MekanPriceBand? b = mekanPriceBand(id);
    return b?.min ?? 100;
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_itemId == null) return;
    final int qty = int.tryParse(_qty.text) ?? -1;
    final int price = int.tryParse(_price.text) ?? -1;
    if (qty < 0 || price < 0) {
      AppMessenger.show(context, 'Adet ve fiyat 0+ olmali');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSave(_itemId!, qty, price);
      if (mounted) {
        Navigator.pop(context);
        await widget.onDone();
        if (context.mounted) AppMessenger.showSuccess(context, 'Stok guncellendi');
      }
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) AppMessenger.showError(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.existing != null;
    final MekanPriceBand? band = _itemId == null ? null : mekanPriceBand(_itemId!);
    final bool contraband = _itemId != null && mekanItemIsContraband(_itemId!);

    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.viewInsetsOf(context).bottom + 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[MekanPalette.surfaceHi, MekanPalette.void_],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: MekanPalette.gold, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(width: 44, height: 4, decoration: BoxDecoration(color: MekanPalette.textLow, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text(editing ? 'Stogu Guncelle' : 'Stok Ekle',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: MekanPalette.textHi)),
          const SizedBox(height: 16),
          if (!editing)
            DropdownButtonFormField<String>(
              initialValue: _itemId,
              dropdownColor: MekanPalette.surfaceHi,
              decoration: _dec('Urun sec', Icons.shopping_bag_outlined),
              style: const TextStyle(color: MekanPalette.textHi, fontSize: 14),
              items: widget.inventory
                  .map((MekanInventoryEntry e) => DropdownMenuItem<String>(
                        value: e.itemId,
                        child: Text('${e.name} (${e.quantity})', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (String? v) => setState(() {
                _itemId = v;
                _price.text = '${_suggestedPrice(v)}';
              }),
            )
          else
            Row(
              children: <Widget>[
                ItemIconView(iconValue: widget.existing!.icon, itemId: widget.existing!.itemId, size: 40, fallback: '🧪'),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.existing!.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: MekanPalette.textHi)),
                ),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: MekanPalette.textHi),
                  decoration: _dec('Adet', Icons.numbers_rounded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: MekanPalette.textHi),
                  decoration: _dec('Fiyat', Icons.paid_rounded),
                ),
              ),
            ],
          ),
          if (band != null) ...<Widget>[
            const SizedBox(height: 8),
            Text('Fiyat araligi: ${formatMekanGold(band.min)} - ${formatMekanGold(band.max)}',
                style: const TextStyle(fontSize: 11.5, color: MekanPalette.textMid, fontWeight: FontWeight.w600)),
          ],
          if (contraband) ...<Widget>[
            const SizedBox(height: 8),
            const Row(
              children: <Widget>[
                Icon(Icons.warning_amber_rounded, size: 14, color: MekanPalette.neon),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Kacak madde — sadece Yeralti, polis baskini riski.',
                      style: TextStyle(fontSize: 11.5, color: MekanPalette.neon, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Text('Stogu kaldirmak icin adeti 0 yap.',
              style: TextStyle(fontSize: 11, color: MekanPalette.textLow)),
          const SizedBox(height: 16),
          NeonButton(
            label: 'Kaydet',
            icon: Icons.save_rounded,
            accent: MekanPalette.gold,
            busy: _busy,
            onPressed: _itemId == null ? null : _save,
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: MekanPalette.textMid),
        prefixIcon: Icon(icon, size: 18, color: MekanPalette.textMid),
        filled: true,
        fillColor: MekanPalette.void_.withValues(alpha: 0.4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MekanPalette.gold, width: 1.4),
        ),
      );
}
