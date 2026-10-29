import 'dart:ui' show ImageFilter;
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
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/logout_helper.dart';
import '../guild_war/widgets/guild_war_design.dart';
import '../guild_war/widgets/guild_war_sub_screen_scaffold.dart';
import '../support/widgets/support_design.dart';
import 'widgets/guild_design.dart';

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

String _formatExactGold(int v) {
  final String str = v.toString();
  final StringBuffer sb = StringBuffer();
  final int len = str.length;
  for (int i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) {
      sb.write('.');
    }
    sb.write(str[i]);
  }
  return sb.toString();
}

String _rarityLabel(Rarity r) {
  switch (r) {
    case Rarity.common:
      return 'Yaygın';
    case Rarity.uncommon:
      return 'Sıradışı';
    case Rarity.rare:
      return 'Nadir';
    case Rarity.epic:
      return 'Epik';
    case Rarity.legendary:
      return 'Efsanevi';
    case Rarity.mythic:
      return 'Mitik';
  }
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

  void _quickAddDeposit(int add) {
    final int current =
        int.tryParse(_depositAmount.text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0;
    final int next = (current + add).clamp(0, 200000000);
    setState(() {
      _depositAmount.text = next.toString();
    });
  }

  Future<void> _deposit() async {
    final int amount =
        int.tryParse(_depositAmount.text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0;
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

  Future<void> _confirmDistributeEqual(
    GuildVaultState vault,
    List<GuildMemberData> members,
  ) async {
    final int amount = int.tryParse(_equalAmount.text.trim()) ?? 0;
    if (amount <= 0) {
      AppMessenger.showError(context, 'Geçerli bir altın miktarı girin.');
      return;
    }
    if (amount > vault.vaultGold) {
      AppMessenger.showError(context, 'Kasada yeterli altın yok.');
      return;
    }
    if (members.isEmpty) {
      AppMessenger.showError(context, 'Loncada dağıtım yapılacak üye bulunamadı.');
      return;
    }

    final int perMember = amount ~/ members.length;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GuildGlassCard(
          accent: GuildPalette.gold,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, color: GuildPalette.gold, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Eşit Dağıtım Onayı',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: GuildPalette.textHi,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Toplam ${_vaultFmtGold(amount)}g (${_formatExactGold(amount)} altın), loncanın ${members.length} üyesine eşit paylaştırılacak.',
                style: supportBodyStyle.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: GuildPalette.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GuildPalette.gold.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'Üye Başı Düşen: ~${_vaultFmtGold(perMember)}g',
                  style: AppTextStyles.bodyBold.copyWith(color: GuildPalette.gold),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        'Vazgeç',
                        style: supportCaptionStyle.copyWith(color: GuildPalette.titanium),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SettingsPrimaryButton(
                      label: 'Onayla & Dağıt',
                      icon: Icons.check_circle_rounded,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final String? err = await ref.read(guildVaultProvider.notifier).distributeGoldEqual(amount);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      AppMessenger.showError(context, err);
    } else {
      AppMessenger.showSuccess(context, 'Altın ${members.length} üyeye eşit dağıtıldı.');
    }
  }

  Future<void> _confirmDistributeTargeted(
    GuildVaultState vault,
    List<GuildMemberData> members,
  ) async {
    final List<Map<String, dynamic>> allocations = <Map<String, dynamic>>[];
    int total = 0;
    final int cap = (vault.vaultGold * 0.40).floor().clamp(0, vault.vaultGold);
    for (final GuildMemberData m in members) {
      final int amount = int.tryParse(_amountFor(m.playerId).text.trim()) ?? 0;
      if (amount <= 0) continue;
      if (cap > 0 && amount > cap) {
        AppMessenger.showError(
          context,
          '${m.username} için miktar sınırı aşıyor (Max %40 = ${_vaultFmtGold(cap)}g).',
        );
        return;
      }
      final String targetId =
          (m.userId != null && m.userId!.isNotEmpty) ? m.userId! : m.playerId;
      allocations.add(<String, dynamic>{'user_id': targetId, 'amount': amount});
      total += amount;
    }
    if (allocations.isEmpty) {
      AppMessenger.showError(context, 'En az bir üyeye miktar girmelisin.');
      return;
    }
    if (total > vault.vaultGold) {
      AppMessenger.showError(context, 'Toplam dağıtım kasadaki altını aşıyor.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GuildGlassCard(
          accent: GuildPalette.fuchsia,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.send_rounded, color: GuildPalette.fuchsia, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Hedefli Dağıtım Onayı',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: GuildPalette.textHi,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Seçilen ${allocations.length} üyeye toplam ${_vaultFmtGold(total)}g altın dağıtılacaktır.',
                style: supportBodyStyle.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        'Vazgeç',
                        style: supportCaptionStyle.copyWith(color: GuildPalette.titanium),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SettingsPrimaryButton(
                      label: 'Onayla & Gönder',
                      icon: Icons.check_circle_rounded,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

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
      AppMessenger.showSuccess(context, 'Hedefli dağıtım tamamlandı.');
    }
  }

  void _inspectItem(
    GuildVaultItem item,
    List<GuildMemberData> members,
    bool canDistribute,
  ) {
    final Rarity rarity = RarityParsing.fromValue(item.rarity ?? 'common');
    final Color rarityColor = getRarityColor(rarity);
    final ItemType itemType = ItemTypeParsing.fromValue(item.itemType);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetCtx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1526).withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: rarityColor.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: rarityColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: rarityColor.withValues(alpha: 0.7),
                              width: 1.5,
                            ),
                            color: const Color(0xFF090D18),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: rarityColor.withValues(alpha: 0.25),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              ItemIconView(
                                iconValue: item.icon,
                                itemId: item.itemId,
                                itemType: itemType,
                                size: 44,
                              ),
                              if (item.enhancementLevel > 0)
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '+${item.enhancementLevel}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.enhancementLevel > 0
                                    ? '${item.itemName} (+${item.enhancementLevel})'
                                    : item.itemName,
                                style: GoogleFonts.urbanist(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: rarityColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: rarityColor.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: rarityColor.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      _rarityLabel(rarity).toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: rarityColor,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Miktar: ${item.quantity}',
                                      style: supportCaptionStyle.copyWith(fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Kasa Kaynağı: ${item.sourceType ?? 'Bölge Savaşı Fethi / Lonca Hazinesi'}',
                            style: supportCaptionStyle.copyWith(color: GuildPalette.titanium),
                          ),
                          if (item.createdAt != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              'Giriş Tarihi: ${item.createdAt!.day}.${item.createdAt!.month}.${item.createdAt!.year}',
                              style: supportCaptionStyle.copyWith(fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (canDistribute) ...<Widget>[
                      SettingsPrimaryButton(
                        label: 'Üyeye Gönder',
                        icon: Icons.send_rounded,
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _distributeItem(item, members);
                        },
                      ),
                    ] else ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Kasa eşyalarını yalnızca Lonca Lideri dağıtabilir.',
                          style: supportCaptionStyle.copyWith(color: GuildPalette.titanium),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _distributeItem(
    GuildVaultItem item,
    List<GuildMemberData> members,
  ) async {
    if (members.isEmpty) {
      AppMessenger.showError(context, 'Loncada dağıtılacak üye yok.');
      return;
    }

    final Rarity rarity = RarityParsing.fromValue(item.rarity ?? 'common');
    final Color rarityColor = getRarityColor(rarity);

    final GuildMemberData? target = await showDialog<GuildMemberData>(
      context: context,
      builder: (BuildContext ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (
            BuildContext dialogCtx,
            void Function(void Function()) setDialogState,
          ) {
            final List<GuildMemberData> filteredMembers = members.where((GuildMemberData m) {
              if (filter.isEmpty) return true;
              return m.username.toLowerCase().contains(filter.toLowerCase());
            }).toList();

            return Dialog(
              backgroundColor: Colors.transparent,
              child: GuildGlassCard(
                accent: GuildPalette.gold,
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: GuildPalette.gold.withValues(alpha: 0.15),
                            border: Border.all(
                              color: GuildPalette.gold.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.card_giftcard_rounded,
                            size: 16,
                            color: GuildPalette.gold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'EŞYA DAĞITIMI',
                                style: GoogleFonts.urbanist(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: GuildPalette.gold,
                                ),
                              ),
                              Text(
                                item.enhancementLevel > 0
                                    ? '${item.itemName} (+${item.enhancementLevel})'
                                    : item.itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: rarityColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (String val) =>
                          setDialogState(() => filter = val.trim()),
                      style: supportBodyStyle.copyWith(fontSize: 13),
                      decoration: supportInputDecoration(
                        label: 'Üye Ara',
                        hint: 'Kullanıcı adı yazın...',
                      ).copyWith(
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: GuildPalette.titanium,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: filteredMembers.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Eşleşen üye bulunamadı.',
                                  style: supportCaptionStyle,
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredMembers.length,
                              itemBuilder: (BuildContext context, int index) {
                                final GuildMemberData m = filteredMembers[index];
                                final bool isLeader =
                                    m.role == GuildRole.leader;
                                final bool isOfficer =
                                    m.role == GuildRole.officer;
                                final Color roleColor = isLeader
                                    ? GuildPalette.gold
                                    : (isOfficer
                                        ? GuildPalette.astralBlue
                                        : GuildPalette.titanium);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: GuildPressable(
                                    onTap: () => Navigator.pop(ctx, m),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.08),
                                        ),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor:
                                                roleColor.withValues(alpha: 0.2),
                                            child: Text(
                                              m.username.isNotEmpty
                                                  ? m.username[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: roleColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              m.username,
                                              style: supportBodyStyle.copyWith(
                                                color: GuildPalette.textHi,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: roleColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: roleColor.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Text(
                                              m.role.name,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: roleColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Vazgeç',
                            style: supportCaptionStyle.copyWith(
                              color: GuildPalette.titanium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (target == null || !mounted) return;

    setState(() => _busy = true);
    final String targetId =
        (target.userId != null && target.userId!.isNotEmpty)
            ? target.userId!
            : target.playerId;
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
      AppMessenger.showSuccess(
        context,
        '${item.itemName} → ${target.username} aktarıldı.',
      );
    }
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
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(color: GuildPalette.gold),
                  const SizedBox(height: 16),
                  Text(
                    'Lonca Kasası Yükleniyor...',
                    style: AppTextStyles.bodyBold.copyWith(color: GuildPalette.gold),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: GuildPalette.gold,
              onRefresh: () => ref.read(guildVaultProvider.notifier).load(),
              child: NestedScrollView(
                headerSliverBuilder: (
                  BuildContext context,
                  bool innerBoxIsScrolled,
                ) {
                  return <Widget>[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.sm,
                          AppSpacing.sm,
                          AppSpacing.sm,
                          vault.territories.isNotEmpty ? AppSpacing.xs : AppSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _VaultHeroCard(
                              vault: vault,
                              busy: _busy,
                              formatGold: _vaultFmtGold,
                              formatExactGold: _formatExactGold,
                              depositController: _depositAmount,
                              onDeposit: _deposit,
                              onQuickAdd: _quickAddDeposit,
                              onToggleAutoPayout: vault.canManage
                                  ? (bool enabled) async {
                                      setState(() => _busy = true);
                                      final String? err = await ref
                                          .read(guildVaultProvider.notifier)
                                          .setAutoPayout(enabled);
                                      if (!mounted || !context.mounted) return;
                                      setState(() => _busy = false);
                                      if (err != null) {
                                        AppMessenger.showError(context, err);
                                      }
                                    }
                                  : null,
                            ),
                            if (vault.territories.isNotEmpty) ...<Widget>[
                              const SizedBox(height: AppSpacing.sm),
                              _VaultTerritoriesCard(
                                territories: vault.territories,
                                formatGold: _vaultFmtGold,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _VaultTabBarDelegate(
                        tabBar: TabBar(
                          controller: _tabs,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: GuildPalette.goldGrad,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: GuildPalette.gold.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          labelColor: const Color(0xFF0A0D16),
                          unselectedLabelColor: GuildPalette.titanium,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          dividerColor: Colors.transparent,
                          tabs: <Widget>[
                            const Tab(
                              icon: Icon(Icons.monetization_on_rounded, size: 16),
                              text: 'Altın Dağıtım',
                            ),
                            Tab(
                              icon: const Icon(Icons.inventory_2_rounded, size: 16),
                              text: 'Eşyalar (${vault.items.length})',
                            ),
                            const Tab(
                              icon: Icon(Icons.history_edu_rounded, size: 16),
                              text: 'Geçmiş',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabs,
                  children: <Widget>[
                    _GoldTab(
                      vault: vault,
                      members: members,
                      busy: _busy,
                      equalController: _equalAmount,
                      amountFor: _amountFor,
                      formatGold: _vaultFmtGold,
                      onEqual: () => _confirmDistributeEqual(vault, members),
                      onTargeted: () => _confirmDistributeTargeted(vault, members),
                    ),
                    _ItemsTab(
                      vault: vault,
                      busy: _busy,
                      members: members,
                      onInspect: (GuildVaultItem item) => _inspectItem(
                        item,
                        members,
                        vault.canManage && !_busy,
                      ),
                      onDistribute: (GuildVaultItem item) => _distributeItem(item, members),
                    ),
                    _LedgerTab(entries: vault.ledger),
                  ],
                ),
              ),
            ),
    );
  }
}

class _VaultTabBarDelegate extends SliverPersistentHeaderDelegate {
  _VaultTabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height + 12;

  @override
  double get maxExtent => tabBar.preferredSize.height + 12;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: GuildPalette.celestialVoid.withValues(alpha: 0.95),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: GuildPalette.celestialSurface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: GuildPalette.gold.withValues(alpha: 0.28),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: tabBar,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _VaultTabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}

class _VaultHeroCard extends StatelessWidget {
  const _VaultHeroCard({
    required this.vault,
    required this.busy,
    required this.formatGold,
    required this.formatExactGold,
    required this.depositController,
    required this.onDeposit,
    required this.onQuickAdd,
    this.onToggleAutoPayout,
  });

  final GuildVaultState vault;
  final bool busy;
  final String Function(dynamic) formatGold;
  final String Function(int) formatExactGold;
  final TextEditingController depositController;
  final VoidCallback onDeposit;
  final ValueChanged<int> onQuickAdd;
  final Future<void> Function(bool enabled)? onToggleAutoPayout;

  @override
  Widget build(BuildContext context) {
    final String roleLabel = vault.isLeader
        ? 'Lonca Lideri ★'
        : (vault.isOfficer ? 'Yetkili ✦' : (vault.guildRole ?? 'Lonca Üyesi'));
    final Color roleColor = vault.isLeader
        ? GuildPalette.gold
        : (vault.isOfficer ? GuildPalette.astralBlue : GuildPalette.titanium);

    return GuildGlassCard(
      accent: GuildPalette.gold,
      glow: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Glowing Crest & Role Header
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFFFD54F), Color(0xFFE08A00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: GuildPalette.gold.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Color(0xFF0F1526),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'AION CELESTIAL VAULT',
                      style: GoogleFonts.urbanist(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                        color: GuildPalette.gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lonca Hazinesi & Krallık Kasası',
                      style: supportCaptionStyle.copyWith(
                        fontSize: 11,
                        color: GuildPalette.titanium,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: roleColor.withValues(alpha: 0.5)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: roleColor.withValues(alpha: 0.2), blurRadius: 8),
                  ],
                ),
                child: Text(
                  roleLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: roleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total Vault Balance Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  GuildPalette.gold.withValues(alpha: 0.12),
                  GuildPalette.celestialSurface.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: GuildPalette.gold.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            formatGold(vault.vaultGold),
                            style: GoogleFonts.urbanist(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: GuildPalette.gold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '🪙',
                            style: TextStyle(fontSize: 22),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatExactGold(vault.vaultGold)} Altın Mevcut Bakiye',
                        style: supportCaptionStyle.copyWith(
                          fontSize: 11,
                          color: GuildPalette.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3-Stat Metric Strip
          Row(
            children: <Widget>[
              Expanded(
                child: _VaultMetricChip(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Günlük Vergi',
                  value: '%${(vault.vaultTaxRate * 100).round()}',
                  accent: GuildPalette.coral,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VaultMetricChip(
                  icon: Icons.map_rounded,
                  label: 'Bölgeler',
                  value: '${vault.territories.length} Bölge',
                  accent: GuildPalette.neon,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VaultMetricChip(
                  icon: Icons.inventory_2_rounded,
                  label: 'Kasa Eşyası',
                  value: '${vault.items.length} Eşya',
                  accent: GuildPalette.fuchsia,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Deposit Gold Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'KASAYA ALTIN YATIR',
                      style: GoogleFonts.urbanist(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: GuildPalette.gold,
                      ),
                    ),
                    Text(
                      'Min 1.000g · Max 200M/gün',
                      style: supportCaptionStyle.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Quick shortcut chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _QuickChip(label: '+10k', onTap: () => onQuickAdd(10000)),
                      _QuickChip(label: '+100k', onTap: () => onQuickAdd(100000)),
                      _QuickChip(label: '+1M', onTap: () => onQuickAdd(1000000)),
                      _QuickChip(label: '+10M', onTap: () => onQuickAdd(10000000)),
                      _QuickChip(
                        label: 'Temizle',
                        onTap: () => depositController.clear(),
                        color: GuildPalette.coral,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: depositController,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        style: supportBodyStyle.copyWith(fontSize: 13),
                        decoration: supportInputDecoration(
                          label: 'Miktar (g)',
                          hint: 'Örn: 50000',
                        ).copyWith(
                          prefixIcon: const Icon(
                            Icons.monetization_on_outlined,
                            color: GuildPalette.gold,
                            size: 20,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
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
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Role Guidance & Auto Payout
          if (vault.isOfficer && !vault.isLeader) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GuildPalette.astralBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: GuildPalette.astralBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    color: GuildPalette.astralBlue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yetkili (Officer): Altın ve eşya dağıtımı yalnızca Lonca Lideri yetkisindedir. Anıt bağışları otomatik olarak kasaya aktarılır.',
                      style: supportCaptionStyle.copyWith(
                        fontSize: 11,
                        color: GuildPalette.textHi,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!vault.canManage) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Kasaya altın yatırma her lonca üyesine açıktır. Dağıtım yetkisi yalnızca Lonca Liderindedir.',
                style: supportCaptionStyle.copyWith(fontSize: 11),
              ),
            ),
          ],
          if (vault.canManage && onToggleAutoPayout != null) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Haftalık otomatik eşit ödeme',
                  style: supportBodyStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Pazar gecesi kasadaki altın tüm üyelere eşit paylaştırılır',
                  style: supportCaptionStyle.copyWith(fontSize: 10),
                ),
                value: vault.vaultAutoPayoutWeekly,
                activeColor: GuildPalette.gold,
                onChanged: busy
                    ? null
                    : (bool v) {
                        onToggleAutoPayout!(v);
                      },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VaultMetricChip extends StatelessWidget {
  const _VaultMetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 12, color: accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: supportCaptionStyle.copyWith(fontSize: 9.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    this.color = GuildPalette.gold,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GuildPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _VaultTerritoriesCard extends StatelessWidget {
  const _VaultTerritoriesCard({
    required this.territories,
    required this.formatGold,
  });

  final List<GuildVaultTerritorySummary> territories;
  final String Function(dynamic) formatGold;

  @override
  Widget build(BuildContext context) {
    return GuildGlassCard(
      accent: GuildPalette.neon,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.castle_rounded, color: GuildPalette.neon, size: 18),
              const SizedBox(width: 8),
              Text(
                'BÖLGE GELİRLERİ VE ÜRETİM',
                style: GoogleFonts.urbanist(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: GuildPalette.neon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...territories.map(
            (GuildVaultTerritorySummary t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      t.name,
                      style: supportBodyStyle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '+${formatGold(t.tradeIncome)}g/gün · ~7 eşya/gün',
                      style: supportCaptionStyle.copyWith(
                        color: GuildPalette.neon,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    required this.formatGold,
    required this.onEqual,
    required this.onTargeted,
  });

  final GuildVaultState vault;
  final List<GuildMemberData> members;
  final bool busy;
  final TextEditingController equalController;
  final TextEditingController Function(String playerId) amountFor;
  final String Function(dynamic) formatGold;
  final VoidCallback onEqual;
  final VoidCallback onTargeted;

  @override
  State<_GoldTab> createState() => _GoldTabState();
}

class _GoldTabState extends State<_GoldTab> {
  bool _targeted = false;
  final TextEditingController _memberSearch = TextEditingController();

  @override
  void dispose() {
    _memberSearch.dispose();
    super.dispose();
  }

  void _setEqualPercent(double factor) {
    final int amount = (widget.vault.vaultGold * factor).floor();
    setState(() {
      widget.equalController.text = amount.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int enteredEqual = int.tryParse(widget.equalController.text.trim()) ?? 0;
    final int memberCount = widget.members.isEmpty ? 1 : widget.members.length;
    final int perMemberEstimate = enteredEqual ~/ memberCount;
    final int remainingVault = (widget.vault.vaultGold - enteredEqual).clamp(0, widget.vault.vaultGold);
    final int cap = (widget.vault.vaultGold * 0.40).floor().clamp(0, widget.vault.vaultGold);

    return ListView(
      padding: GameScrollLayout.padding(context, top: 12),
      children: <Widget>[
        // Luxury Segmented Control
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1220),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: GuildPressable(
                  onTap: widget.vault.canManage
                      ? () => setState(() => _targeted = false)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !_targeted
                          ? GuildPalette.gold.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !_targeted
                            ? GuildPalette.gold.withValues(alpha: 0.6)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.groups_rounded,
                          size: 16,
                          color: !_targeted ? GuildPalette.gold : GuildPalette.titanium,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Eşit Dağıtım',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: !_targeted ? GuildPalette.gold : GuildPalette.titanium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GuildPressable(
                  onTap: widget.vault.canManage
                      ? () => setState(() => _targeted = true)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _targeted
                          ? GuildPalette.fuchsia.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _targeted
                            ? GuildPalette.fuchsia.withValues(alpha: 0.6)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.person_pin_circle_rounded,
                          size: 16,
                          color: _targeted ? GuildPalette.fuchsia : GuildPalette.titanium,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Hedefli Dağıtım',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _targeted ? GuildPalette.fuchsia : GuildPalette.titanium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _targeted
              ? GuildGlassCard(
                  key: const ValueKey<String>('targeted_card'),
                  accent: GuildPalette.fuchsia,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'ÜYE BAŞINA HEDEFLİ PAY',
                            style: GoogleFonts.urbanist(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: GuildPalette.fuchsia,
                            ),
                          ),
                          Text(
                            'Max %40 = ${widget.formatGold(cap)}g',
                            style: supportCaptionStyle.copyWith(
                              fontSize: 11,
                              color: GuildPalette.fuchsia,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Search field for members
                      TextField(
                        controller: _memberSearch,
                        onChanged: (_) => setState(() {}),
                        style: supportBodyStyle.copyWith(fontSize: 12),
                        decoration: supportInputDecoration(
                          label: 'Üye Ara',
                          hint: 'Kullanıcı adına göre filtrele...',
                        ).copyWith(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...widget.members
                          .where((GuildMemberData m) =>
                              _memberSearch.text.isEmpty ||
                              m.username
                                  .toLowerCase()
                                  .contains(_memberSearch.text.trim().toLowerCase()))
                          .map((GuildMemberData m) {
                        final bool isLeader = m.role == GuildRole.leader;
                        final bool isOfficer = m.role == GuildRole.officer;
                        final Color roleColor = isLeader
                            ? GuildPalette.gold
                            : (isOfficer ? GuildPalette.astralBlue : GuildPalette.titanium);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: roleColor.withValues(alpha: 0.18),
                                  child: Text(
                                    m.username.isNotEmpty ? m.username[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: roleColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        m.username,
                                        style: supportBodyStyle.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        m.role.name,
                                        style: supportCaptionStyle.copyWith(
                                          color: roleColor,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: widget.amountFor(m.playerId),
                                    enabled: widget.vault.canManage && !widget.busy,
                                    keyboardType: TextInputType.number,
                                    style: supportBodyStyle.copyWith(fontSize: 12),
                                    decoration: supportInputDecoration(label: 'Miktar (g)').copyWith(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      SettingsPrimaryButton(
                        label: 'Hedefli Dağıtımı Uygula',
                        icon: Icons.send_rounded,
                        loading: widget.busy,
                        onPressed: widget.vault.canManage && !widget.busy
                            ? widget.onTargeted
                            : null,
                      ),
                    ],
                  ),
                )
              : GuildGlassCard(
                  key: const ValueKey<String>('equal_card'),
                  accent: GuildPalette.gold,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'TÜM ÜYELERE EŞİT DAĞITIM',
                        style: GoogleFonts.urbanist(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: GuildPalette.gold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Shortcut chips for percentages
                      Row(
                        children: <Widget>[
                          _QuickChip(label: '%25', onTap: () => _setEqualPercent(0.25)),
                          _QuickChip(label: '%50', onTap: () => _setEqualPercent(0.50)),
                          _QuickChip(label: '%75', onTap: () => _setEqualPercent(0.75)),
                          _QuickChip(label: 'Tümü (%100)', onTap: () => _setEqualPercent(1.0)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: widget.equalController,
                        enabled: widget.vault.canManage && !widget.busy,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: supportBodyStyle.copyWith(fontSize: 13),
                        decoration: supportInputDecoration(
                          label: 'Dağıtılacak Toplam Altın',
                          hint: 'Örn: 100000',
                        ).copyWith(
                          prefixIcon: const Icon(
                            Icons.monetization_on_rounded,
                            color: GuildPalette.gold,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Live Calculation Preview Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text('👥 Toplam Üye', style: supportCaptionStyle),
                                Text(
                                  '${widget.members.length} Üye',
                                  style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text('🪙 Kişi Başı Düşen', style: supportCaptionStyle),
                                Text(
                                  '~${widget.formatGold(perMemberEstimate)}g',
                                  style: AppTextStyles.bodyBold.copyWith(
                                    fontSize: 13,
                                    color: GuildPalette.gold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text('🏦 Kalan Kasa', style: supportCaptionStyle),
                                Text(
                                  '${widget.formatGold(remainingVault)}g',
                                  style: supportCaptionStyle.copyWith(
                                    fontSize: 12,
                                    color: enteredEqual > widget.vault.vaultGold
                                        ? GuildPalette.coral
                                        : GuildPalette.textHi,
                                  ),
                                ),
                              ],
                            ),
                            if (enteredEqual > widget.vault.vaultGold) ...<Widget>[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: GuildPalette.coral.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⚠ Kasada yeterli altın yok!',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: GuildPalette.coral,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SettingsPrimaryButton(
                        label: 'Tüm Üyelere Eşit Dağıt',
                        icon: Icons.groups_rounded,
                        loading: widget.busy,
                        onPressed: widget.vault.canManage &&
                                !widget.busy &&
                                enteredEqual <= widget.vault.vaultGold
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
    required this.onInspect,
    required this.onDistribute,
  });

  final GuildVaultState vault;
  final bool busy;
  final List<GuildMemberData> members;
  final ValueChanged<GuildVaultItem> onInspect;
  final ValueChanged<GuildVaultItem> onDistribute;

  @override
  Widget build(BuildContext context) {
    if (vault.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: GuildGlassCard(
            accent: GuildPalette.titanium,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: GuildPalette.titanium.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kasada Henüz Eşya Yok',
                  style: AppTextStyles.bodyBold.copyWith(color: GuildPalette.textHi),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bölge fetihlerinden elde edilen ganimetler ve üyelerin bağışladığı eşyalar burada listelenir.',
                  textAlign: TextAlign.center,
                  style: supportCaptionStyle,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: GameScrollLayout.padding(context, top: 12),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'KASA ENVANTERİ',
              style: GoogleFonts.urbanist(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                color: Colors.white70,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: GuildPalette.fuchsia.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: GuildPalette.fuchsia.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${vault.items.length} Eşya',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: GuildPalette.fuchsia,
                ),
              ),
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
              onTap: () => onInspect(item),
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

    return GuildPressable(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: rarityColor.withValues(alpha: canDistribute ? 0.75 : 0.45),
                  width: canDistribute ? 1.4 : 1.0,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    rarityColor.withValues(alpha: 0.18),
                    const Color(0xFF0F1526).withValues(alpha: 0.95),
                    const Color(0xFF090D18).withValues(alpha: 0.98),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: rarityColor.withValues(alpha: canDistribute ? 0.22 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: <Color>[
                              rarityColor.withValues(alpha: 0.15),
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
                          gradient: const LinearGradient(
                            colors: <Color>[Color(0xFFFFDF70), Color(0xFFE5A100)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          '+${item.enhancementLevel}',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF160E00),
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
                          color: const Color(0xEE080D1A),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: rarityColor.withValues(alpha: 0.55),
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
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
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
        return GuildPalette.fuchsia;
      case 'territory_loot':
        return GuildPalette.neon;
      case 'accrue':
      case 'member_deposit':
      case 'monument_gold_to_vault':
      case 'tournament':
      case 'siege_reward':
      case 'credit':
        return GuildPalette.gold;
      case 'attack_spend':
      case 'vault_tax':
      case 'monument_upgrade_spend':
      case 'defense_gold':
        return GuildPalette.coral;
      default:
        return GuildPalette.titanium;
    }
  }

  IconData _iconFor(String action) {
    switch (action) {
      case 'distribute_gold':
        return Icons.group_remove_rounded;
      case 'distribute_item':
        return Icons.card_giftcard_rounded;
      case 'territory_loot':
        return Icons.terrain_rounded;
      case 'accrue':
      case 'collect':
        return Icons.savings_rounded;
      case 'member_deposit':
        return Icons.upload_rounded;
      case 'monument_gold_to_vault':
        return Icons.account_balance_rounded;
      case 'tournament':
      case 'siege_reward':
        return Icons.emoji_events_rounded;
      case 'attack_spend':
        return Icons.security_rounded;
      case 'vault_tax':
        return Icons.receipt_long_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }

  Widget _filterChip(String label, _VaultHistoryFilter value, IconData icon) {
    final bool selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 13,
          color: selected ? GuildPalette.gold : GuildPalette.titanium,
        ),
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _filter = value;
            _visible = _pageStart;
          });
        },
        selectedColor: GuildPalette.gold.withValues(alpha: 0.28),
        backgroundColor: Colors.white.withValues(alpha: 0.04),
        labelStyle: TextStyle(
          color: selected ? GuildPalette.gold : GuildPalette.titanium,
        ),
        side: BorderSide(
          color: selected
              ? GuildPalette.gold.withValues(alpha: 0.55)
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
      return Center(
        child: GuildGlassCard(
          accent: GuildPalette.titanium,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Text('Kasa geçmiş kaydı boş.', style: supportCaptionStyle),
        ),
      );
    }

    final List<({GuildVaultLedgerEntry entry, String title, String? detail})> filtered =
        _filtered();
    final int showCount = filtered.length < _visible ? filtered.length : _visible;
    final bool canMore = showCount < filtered.length;

    return ListView(
      padding: GameScrollLayout.padding(context, top: 12),
      children: <Widget>[
        TextField(
          controller: _search,
          onChanged: (_) {
            setState(() {
              _visible = _pageStart;
            });
          },
          style: supportBodyStyle.copyWith(fontSize: 13),
          decoration: supportInputDecoration(label: 'Kayıtlarda Ara').copyWith(
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: GuildPalette.titanium,
              size: 20,
            ),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: GuildPalette.titanium,
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
              _filterChip('Tümü', _VaultHistoryFilter.all, Icons.all_inclusive_rounded),
              _filterChip('Altın Gelen', _VaultHistoryFilter.goldIn, Icons.arrow_downward_rounded),
              _filterChip('Altın Giden', _VaultHistoryFilter.goldOut, Icons.arrow_upward_rounded),
              _filterChip('Eşya Gelen', _VaultHistoryFilter.itemIn, Icons.inventory_2_rounded),
              _filterChip('Eşya Giden', _VaultHistoryFilter.itemOut, Icons.outbox_rounded),
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
              child: Text('Aramaya uygun kayıt bulunamadı.', style: supportCaptionStyle),
            ),
          )
        else
          ...List<Widget>.generate(showCount, (int i) {
            final ({GuildVaultLedgerEntry entry, String title, String? detail}) row =
                filtered[i];
            final GuildVaultLedgerEntry e = row.entry;
            final Color accentColor = _accentFor(e.action);
            final IconData actionIcon = _iconFor(e.action);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GuildGlassCard(
                accent: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                      ),
                      child: Icon(actionIcon, size: 16, color: accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            row.title,
                            style: supportCaptionStyle.copyWith(
                              fontSize: 12.5,
                              color: GuildPalette.textHi,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (row.detail != null && row.detail!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 3),
                            Text(
                              row.detail!,
                              style: supportCaptionStyle.copyWith(
                                fontSize: 11,
                                color: GuildPalette.textMid,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            _when(e.createdAt),
                            style: supportCaptionStyle.copyWith(
                              fontSize: 10,
                              color: GuildPalette.titanium,
                            ),
                          ),
                        ],
                      ),
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
              label: 'Daha Fazla Göster (+$_pageStep)',
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
