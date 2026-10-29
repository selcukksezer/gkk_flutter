import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../models/reputation_model.dart';
import 'reputation_design.dart';

enum ReputationShopFilter {
  all,
  buffs,
  rarePlus,
  available,
}

String _formatNumber(int value) {
  final String s = value.toString();
  final StringBuffer sb = StringBuffer();
  final int offset = s.length % 3;
  if (offset > 0) {
    sb.write(s.substring(0, offset));
  }
  for (int i = offset; i < s.length; i += 3) {
    if (sb.isNotEmpty) sb.write('.');
    sb.write(s.substring(i, i + 3));
  }
  return sb.toString();
}

String _formatCompact(int v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(0)}K';
  return _formatNumber(v);
}

int requiredStandingFor(ReputationShopItem item) {
  final dynamic explicitReq = item.effectValue['required_rep'] ??
      item.effectValue['required_standing'] ??
      item.effectValue['min_rep'] ??
      item.effectValue['min_standing'] ??
      item.effectValue['standing'];
  if (explicitReq != null) {
    if (explicitReq is int) return explicitReq;
    if (explicitReq is num) return explicitReq.toInt();
    if (explicitReq is String) return int.tryParse(explicitReq) ?? 0;
  }
  switch (item.rarity.toLowerCase()) {
    case 'legendary':
      return 20000;
    case 'epic':
      return 5000;
    case 'rare':
      return 1500;
    case 'uncommon':
      return 500;
    default:
      return 0;
  }
}

String standingTierName(int points) {
  if (points >= 356000) return 'İmparator';
  if (points >= 280000) return 'Destansı';
  if (points >= 170000) return 'Efsanevi';
  if (points >= 80000) return 'Ünlü';
  if (points >= 20000) return 'Saygın';
  if (points >= 5000) return 'Tanınan';
  return 'Acemi';
}

class ReputationShopGrid extends StatefulWidget {
  const ReputationShopGrid({
    super.key,
    required this.items,
    required this.globalRep,
    required this.purchasingId,
    required this.onPurchase,
  });

  final List<ReputationShopItem> items;
  final int globalRep;
  final String? purchasingId;
  final void Function(ReputationShopItem item) onPurchase;

  @override
  State<ReputationShopGrid> createState() => _ReputationShopGridState();
}

class _ReputationShopGridState extends State<ReputationShopGrid> {
  ReputationShopFilter _activeFilter = ReputationShopFilter.all;

  List<ReputationShopItem> get _filteredItems {
    return widget.items.where((ReputationShopItem item) {
      final int reqStanding = requiredStandingFor(item);
      final bool isLocked = widget.globalRep < reqStanding;
      final bool affordable = canAffordShopItem(item: item, globalRep: widget.globalRep);

      switch (_activeFilter) {
        case ReputationShopFilter.all:
          return true;
        case ReputationShopFilter.buffs:
          return item.durationMinutes != null || item.effectKey.contains('boost');
        case ReputationShopFilter.rarePlus:
          final String r = item.rarity.toLowerCase();
          return r == 'rare' || r == 'epic' || r == 'legendary';
        case ReputationShopFilter.available:
          return !isLocked && affordable;
      }
    }).toList();
  }

  void _handleItemTap(BuildContext context, ReputationShopItem item) {
    final int reqStanding = requiredStandingFor(item);
    final bool isLocked = widget.globalRep < reqStanding;
    final bool affordable = canAffordShopItem(item: item, globalRep: widget.globalRep);
    final bool loading = widget.purchasingId == item.id;

    if (loading) return;

    if (isLocked) {
      _showLockedDialog(context, item, reqStanding);
      return;
    }

    if (!affordable) {
      _showInsufficientRepDialog(context, item);
      return;
    }

    _showPurchaseConfirmationDialog(context, item);
  }

  void _showPurchaseConfirmationDialog(BuildContext context, ReputationShopItem item) {
    final Color border = rarityBorderColor(item.rarity);
    final int remaining = widget.globalRep - item.costAmount;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (BuildContext ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: MekanPalette.navy.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border.withValues(alpha: 0.65), width: 1.5),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: border.withValues(alpha: 0.25),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: border.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.shopping_bag_rounded, color: border, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'SATIN ALMA ONAYI',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: MekanPalette.textHi,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: MekanPalette.textLow),
                        onPressed: () => Navigator.of(ctx).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: border.withValues(alpha: 0.14),
                      border: Border.all(color: border.withValues(alpha: 0.5), width: 1.5),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: border.withValues(alpha: 0.2),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(shopIconForKey(item.iconKey), color: border, size: 32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: MekanPalette.textHi,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: border.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: border.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      item.rarity.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: border,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 12, color: MekanPalette.textMid),
                    textAlign: TextAlign.center,
                  ),
                  if (item.durationMinutes != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MekanPalette.solar.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: MekanPalette.solar.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.timer_outlined, size: 12, color: MekanPalette.solar),
                          const SizedBox(width: 4),
                          Text(
                            '${item.durationMinutes} dakika aktif kalır',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: MekanPalette.solar,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MekanPalette.surface.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Mevcut İtibar:', style: TextStyle(fontSize: 12, color: MekanPalette.textMid)),
                            Row(
                              children: <Widget>[
                                const Icon(Icons.star_rounded, size: 14, color: MekanPalette.gold),
                                const SizedBox(width: 4),
                                Text(_formatNumber(widget.globalRep), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MekanPalette.textHi)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Eşya Bedeli:', style: TextStyle(fontSize: 12, color: MekanPalette.textMid)),
                            Row(
                              children: <Widget>[
                                const Icon(Icons.star_rounded, size: 14, color: MekanPalette.gold),
                                const SizedBox(width: 4),
                                Text('-${_formatNumber(item.costAmount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: MekanPalette.gold)),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 14, color: Colors.white12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Kalan İtibar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MekanPalette.textHi)),
                            Row(
                              children: <Widget>[
                                const Icon(Icons.star_rounded, size: 14, color: MekanPalette.gold),
                                const SizedBox(width: 4),
                                Text(_formatNumber(remaining), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: MekanPalette.neon)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MekanPalette.textMid,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Vazgeç', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: border,
                            foregroundColor: Colors.black,
                            elevation: 6,
                            shadowColor: border.withValues(alpha: 0.45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            widget.onPurchase(item);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(Icons.check_circle_rounded, size: 16, color: Colors.black),
                              const SizedBox(width: 6),
                              Text(
                                'Satın Al (${_formatNumber(item.costAmount)})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLockedDialog(BuildContext context, ReputationShopItem item, int requiredRep) {
    final String tierName = standingTierName(requiredRep);
    final int deficit = (requiredRep - widget.globalRep).clamp(0, 9999999);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (BuildContext ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MekanPalette.navy.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.6), width: 1.5),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: MekanPalette.ruby.withValues(alpha: 0.2),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MekanPalette.ruby.withValues(alpha: 0.15),
                      border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.lock_rounded, color: MekanPalette.ruby, size: 28),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'KİLİTLİ İTİBAR EŞYASI',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: MekanPalette.ruby,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MekanPalette.textHi,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MekanPalette.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Gereken Kademe:', style: TextStyle(fontSize: 12, color: MekanPalette.textMid)),
                            Text(tierName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MekanPalette.gold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Gereken İtibar:', style: TextStyle(fontSize: 12, color: MekanPalette.textMid)),
                            Text(_formatNumber(requiredRep), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MekanPalette.gold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Mevcut İtibarın:', style: TextStyle(fontSize: 12, color: MekanPalette.textMid)),
                            Text(_formatNumber(widget.globalRep), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MekanPalette.textHi)),
                          ],
                        ),
                        const Divider(height: 16, color: Colors.white12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Eksik Puan:', style: TextStyle(fontSize: 12, color: MekanPalette.ruby)),
                            Text('-${_formatNumber(deficit)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MekanPalette.ruby)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bu eşyayı açmak için Hanedan görevleri, Zindanlar veya PvP savaşlarına katılarak itibarını yükselt.',
                    style: TextStyle(fontSize: 11, color: MekanPalette.textLow),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MekanPalette.surfaceHi,
                        foregroundColor: MekanPalette.textHi,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Anladım', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInsufficientRepDialog(BuildContext context, ReputationShopItem item) {
    final int deficit = (item.costAmount - widget.globalRep).clamp(0, 9999999);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (BuildContext ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MekanPalette.navy.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MekanPalette.coral.withValues(alpha: 0.6), width: 1.5),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: MekanPalette.coral.withValues(alpha: 0.2),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MekanPalette.coral.withValues(alpha: 0.15),
                      border: Border.all(color: MekanPalette.coral.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.star_half_rounded, color: MekanPalette.coral, size: 28),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'YETERSİZ İTİBAR BAKİYESİ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: MekanPalette.coral,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MekanPalette.textHi,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MekanPalette.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Eşya Bedeli:', style: TextStyle(fontSize: 12, color: MekanPalette.textMid)),
                            Text('${_formatNumber(item.costAmount)} İtibar', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MekanPalette.gold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Mevcut Bakiye:', style: TextStyle(fontSize: 12, color: MekanPalette.textMid)),
                            Text('${_formatNumber(widget.globalRep)} İtibar', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MekanPalette.textHi)),
                          ],
                        ),
                        const Divider(height: 16, color: Colors.white12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Eksik Tutar:', style: TextStyle(fontSize: 12, color: MekanPalette.ruby)),
                            Text('-${_formatNumber(deficit)} İtibar', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MekanPalette.ruby)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MekanPalette.surfaceHi,
                        foregroundColor: MekanPalette.textHi,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ReputationShopFilter filter) {
    final bool active = _activeFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? MekanPalette.gold.withValues(alpha: 0.18) : MekanPalette.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? MekanPalette.gold : Colors.white.withValues(alpha: 0.08),
            width: active ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? MekanPalette.gold : MekanPalette.textMid,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: MekanPalette.navy.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.filter_list_off_rounded, size: 28, color: MekanPalette.textLow),
          const SizedBox(height: 8),
          const Text(
            'Bu filtreye uygun eşya bulunamadı',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MekanPalette.textMid),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _activeFilter = ReputationShopFilter.all),
            child: const Text('Filtreyi Temizle', style: TextStyle(fontSize: 11, color: MekanPalette.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ReputationShopItem> filtered = _filteredItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Expanded(
              child: ReputationSectionTitle(
                title: 'İTİBAR MAĞAZASI',
                subtitle: 'Kazandığın itibarı lütuf ve güce çevir',
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: MekanPalette.navy.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MekanPalette.gold.withValues(alpha: 0.4)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: MekanPalette.gold.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.star_rounded, size: 14, color: MekanPalette.gold),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(widget.globalRep),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: MekanPalette.gold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.items.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _buildFilterChip('Tümü (${widget.items.length})', ReputationShopFilter.all),
                const SizedBox(width: 6),
                _buildFilterChip('Bufflar', ReputationShopFilter.buffs),
                const SizedBox(width: 6),
                _buildFilterChip('Nadir+', ReputationShopFilter.rarePlus),
                const SizedBox(width: 6),
                _buildFilterChip('Açık Olanlar', ReputationShopFilter.available),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (widget.items.isEmpty)
          const _ReputationShopEmptyView()
        else if (filtered.isEmpty)
          _buildEmptyFilterState()
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int crossAxisCount;
              if (constraints.maxWidth >= 840) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth >= 540) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 1;
              }

              return GameFixedGrid(
                crossAxisCount: crossAxisCount,
                spacing: 10,
                itemCount: filtered.length,
                itemBuilder: (BuildContext context, int i) {
                  final ReputationShopItem item = filtered[i];
                  return ReputationSlideIn(
                    index: i,
                    child: crossAxisCount > 1
                        ? _ReputationShopVerticalCard(
                            item: item,
                            globalRep: widget.globalRep,
                            purchasingId: widget.purchasingId,
                            onTap: () => _handleItemTap(context, item),
                          )
                        : _ReputationShopHorizontalCard(
                            item: item,
                            globalRep: widget.globalRep,
                            purchasingId: widget.purchasingId,
                            onTap: () => _handleItemTap(context, item),
                          ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _ReputationShopHorizontalCard extends StatelessWidget {
  const _ReputationShopHorizontalCard({
    required this.item,
    required this.globalRep,
    required this.purchasingId,
    required this.onTap,
  });

  final ReputationShopItem item;
  final int globalRep;
  final String? purchasingId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = rarityBorderColor(item.rarity);
    final int reqStanding = requiredStandingFor(item);
    final bool isLocked = globalRep < reqStanding;
    final bool affordable = canAffordShopItem(item: item, globalRep: globalRep);
    final bool loading = purchasingId == item.id;

    return PressableScale(
      enabled: !loading,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked ? MekanPalette.ruby.withValues(alpha: 0.3) : border.withValues(alpha: 0.55),
            width: 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              isLocked
                  ? MekanPalette.navy.withValues(alpha: 0.75)
                  : MekanPalette.navy.withValues(alpha: 0.95),
              MekanPalette.void_.withValues(alpha: 0.98),
            ],
          ),
          boxShadow: isLocked
              ? null
              : <BoxShadow>[
                  BoxShadow(color: border.withValues(alpha: 0.12), blurRadius: 16),
                ],
        ),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(
                painter: DotGridPainter(spacing: 16, dotOpacity: 0.045),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isLocked
                          ? MekanPalette.ruby.withValues(alpha: 0.1)
                          : border.withValues(alpha: 0.12),
                      border: Border.all(
                        color: isLocked
                            ? MekanPalette.ruby.withValues(alpha: 0.35)
                            : border.withValues(alpha: 0.4),
                      ),
                    ),
                    child: loading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.gold),
                            ),
                          )
                        : Icon(
                            isLocked ? Icons.lock_outline_rounded : shopIconForKey(item.iconKey),
                            color: isLocked ? MekanPalette.ruby : border,
                            size: 26,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: MekanPalette.textHi,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: border.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.rarity.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: border,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isLocked) ...<Widget>[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: MekanPalette.ruby.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.lock_rounded, size: 10, color: MekanPalette.ruby),
                                const SizedBox(width: 4),
                                Text(
                                  'Gereken: ${standingTierName(reqStanding)} (${_formatCompact(reqStanding)})',
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: MekanPalette.ruby,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: const TextStyle(fontSize: 11, color: MekanPalette.textMid),
                        ),
                        if (item.durationMinutes != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.timer_outlined, size: 11, color: MekanPalette.solar.withValues(alpha: 0.9)),
                              const SizedBox(width: 3),
                              Text(
                                '${item.durationMinutes} dk süre',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: MekanPalette.solar.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      ReputationCurrencyBadge(
                        costAmount: item.costAmount,
                        costType: item.costType,
                        affordable: affordable,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLocked
                              ? MekanPalette.surfaceHi
                              : (affordable ? border : MekanPalette.surfaceHi),
                          foregroundColor: isLocked
                              ? MekanPalette.ruby
                              : (affordable ? Colors.black : MekanPalette.ruby),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: const Size(64, 28),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          side: isLocked
                              ? BorderSide(color: MekanPalette.ruby.withValues(alpha: 0.3))
                              : null,
                        ),
                        onPressed: loading ? null : onTap,
                        child: loading
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.gold),
                              )
                            : Text(
                                isLocked
                                    ? 'Kilitli'
                                    : (affordable ? 'Satın Al' : 'Yetersiz'),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReputationShopVerticalCard extends StatelessWidget {
  const _ReputationShopVerticalCard({
    required this.item,
    required this.globalRep,
    required this.purchasingId,
    required this.onTap,
  });

  final ReputationShopItem item;
  final int globalRep;
  final String? purchasingId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = rarityBorderColor(item.rarity);
    final int reqStanding = requiredStandingFor(item);
    final bool isLocked = globalRep < reqStanding;
    final bool affordable = canAffordShopItem(item: item, globalRep: globalRep);
    final bool loading = purchasingId == item.id;

    return PressableScale(
      enabled: !loading,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked ? MekanPalette.ruby.withValues(alpha: 0.3) : border.withValues(alpha: 0.55),
            width: 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              isLocked
                  ? MekanPalette.navy.withValues(alpha: 0.75)
                  : MekanPalette.navy.withValues(alpha: 0.95),
              MekanPalette.void_.withValues(alpha: 0.98),
            ],
          ),
          boxShadow: isLocked
              ? null
              : <BoxShadow>[
                  BoxShadow(color: border.withValues(alpha: 0.12), blurRadius: 16),
                ],
        ),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(
                painter: DotGridPainter(spacing: 14, dotOpacity: 0.04),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: border.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.rarity.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: border,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      if (isLocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: MekanPalette.ruby.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.lock_rounded, size: 9, color: MekanPalette.ruby),
                              const SizedBox(width: 3),
                              Text(
                                _formatCompact(reqStanding),
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: MekanPalette.ruby,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (item.durationMinutes != null)
                        Text(
                          '${item.durationMinutes} dk',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: MekanPalette.solar),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isLocked
                            ? MekanPalette.ruby.withValues(alpha: 0.1)
                            : border.withValues(alpha: 0.14),
                        border: Border.all(
                          color: isLocked
                              ? MekanPalette.ruby.withValues(alpha: 0.35)
                              : border.withValues(alpha: 0.45),
                        ),
                        boxShadow: isLocked
                            ? null
                            : <BoxShadow>[
                                BoxShadow(
                                  color: border.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                ),
                              ],
                      ),
                      child: loading
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.gold),
                              ),
                            )
                          : Icon(
                              isLocked ? Icons.lock_outline_rounded : shopIconForKey(item.iconKey),
                              color: isLocked ? MekanPalette.ruby : border,
                              size: 24,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: MekanPalette.textHi,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 10, color: MekanPalette.textMid),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Spacer(),
                  ReputationCurrencyBadge(
                    costAmount: item.costAmount,
                    costType: item.costType,
                    affordable: affordable,
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLocked
                          ? MekanPalette.surfaceHi
                          : (affordable ? border : MekanPalette.surfaceHi),
                      foregroundColor: isLocked
                          ? MekanPalette.ruby
                          : (affordable ? Colors.black : MekanPalette.ruby),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: const Size(double.infinity, 26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      side: isLocked
                          ? BorderSide(color: MekanPalette.ruby.withValues(alpha: 0.3))
                          : null,
                    ),
                    onPressed: loading ? null : onTap,
                    child: loading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: MekanPalette.gold),
                          )
                        : Text(
                            isLocked
                                ? 'Kilitli'
                                : (affordable ? 'Satın Al' : 'Yetersiz'),
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReputationCurrencyBadge extends StatelessWidget {
  const ReputationCurrencyBadge({
    super.key,
    required this.costAmount,
    required this.costType,
    required this.affordable,
  });

  final int costAmount;
  final String costType;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    final Color color = affordable ? MekanPalette.gold : MekanPalette.ruby;
    final IconData icon = costType == 'global'
        ? Icons.star_rounded
        : (costType == 'gold' ? Icons.monetization_on_rounded : Icons.toll_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            _formatNumber(costAmount),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            costType == 'global' ? 'İtibar' : costType.toUpperCase(),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReputationShopEmptyView extends StatelessWidget {
  const _ReputationShopEmptyView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: MekanPalette.navy.withValues(alpha: 0.6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MekanPalette.gold.withValues(alpha: 0.1),
                border: Border.all(color: MekanPalette.gold.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 32,
                color: MekanPalette.gold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'İTİBAR MAĞAZASI BOŞ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: MekanPalette.textHi,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Şu anda satın alınabilecek eşya bulunmuyor.\nYeni teçhizat ve lütuflar için daha sonra tekrar kontrol et.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: MekanPalette.textMid,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
