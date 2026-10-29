import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../market/widgets/market_item_pedestal.dart';
import 'trade_filigree_frame.dart';

/// 2027 Aion 2 Mobile — Ornate Dark Fantasy Trade History / Ledger Log Card.
/// Stylized transaction ledger with runic seal badges, frosted dark-glass backdrop,
/// glowing gold/cyan borders, responsive overflow protection, and 3D pedestal inspection.
class TradeLogCard extends StatelessWidget {
  const TradeLogCard({
    super.key,
    required this.entry,
  });

  final Map<String, dynamic> entry;

  List<Map<String, dynamic>> _parseItems(dynamic raw) {
    if (raw is List) {
      return raw.map((dynamic item) {
        if (item is Map) return Map<String, dynamic>.from(item);
        return <String, dynamic>{'name': item.toString()};
      }).toList(growable: false);
    }
    return <Map<String, dynamic>>[];
  }

  ItemType? _parseItemType(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final ItemType type in ItemType.values) {
      if (type.name.toLowerCase() == raw.toLowerCase()) return type;
    }
    return null;
  }

  String _formatNumber(int value) {
    final String s = value.abs().toString();
    final StringBuffer sb = StringBuffer();
    final int len = s.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        sb.write('.');
      }
      sb.write(s[i]);
    }
    return (value < 0 ? '-' : '') + sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final String rawStatus = (entry['status']?.toString() ?? 'completed').toLowerCase().trim();
    final bool isCompleted = rawStatus == 'completed' ||
        rawStatus == 'success' ||
        rawStatus == 'tamamlandi' ||
        rawStatus == 'tamamlandı';
    final bool isCancelled = rawStatus == 'cancelled' ||
        rawStatus == 'canceled' ||
        rawStatus == 'iptal' ||
        rawStatus == 'rejected' ||
        rawStatus == 'reddedildi';

    final String partner = (entry['partner'] as String?)?.trim() ?? 'Bilinmeyen Oyuncu';
    final String date = ((entry['date'] ?? entry['timestamp'] ?? entry['created_at']) as String?)?.trim() ?? '';
    final String? tradeId = (entry['trade_id'] ?? entry['id'])?.toString();
    final String? note = (entry['note'] ?? entry['reason'] ?? entry['cancel_reason'])?.toString();

    final List<Map<String, dynamic>> myItems = _parseItems(entry['my_items']);
    final List<Map<String, dynamic>> theirItems = _parseItems(entry['their_items']);
    final int myGold = (entry['my_gold'] as num?)?.toInt() ?? 0;
    final int theirGold = (entry['their_gold'] as num?)?.toInt() ?? 0;
    final int netGold = theirGold - myGold;

    // 2027 Aion 2 High-Fantasy Palette (Celestial Cyan & Liquid Gold for completed, Mystic Ruby for cancelled)
    final Color accent = isCompleted
        ? AppColors.accentCyan
        : (isCancelled ? AppColors.mysticRuby : AppColors.gold);
    final Color secondaryAccent = isCompleted
        ? AppColors.liquidGold
        : (isCancelled ? AppColors.coralFlare : AppColors.accentBlue);

    final String statusLabel = isCompleted
        ? 'MÜHÜRLENDİ'
        : (isCancelled ? 'İPTAL EDİLDİ' : 'BEKLEMEDE');
    final IconData statusIcon = isCompleted
        ? Icons.verified_rounded
        : (isCancelled ? Icons.cancel_rounded : Icons.hourglass_top_rounded);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TradeFiligreePanel(
        accent: accent,
        secondaryAccent: secondaryAccent,
        glowOpacity: isCompleted ? 0.16 : 0.08,
        glowRadius: isCompleted ? 18.0 : 12.0,
        padding: const EdgeInsets.all(AppSpacing.md),
        fillGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.spaceNavy.withValues(alpha: 0.90),
            AppColors.bgSurface.withValues(alpha: 0.85),
            AppColors.bgDeep.withValues(alpha: 0.92),
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Header: Partner Crest & Runic Status Seal
                Row(
                  children: <Widget>[
                    // Runic Avatar Crest
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            accent.withValues(alpha: 0.35),
                            AppColors.carbonVoid.withValues(alpha: 0.85),
                          ],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.22),
                            blurRadius: 8,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          partner.isNotEmpty ? partner[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Partner Name & Date (Overflow-safe Flexible layouts)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  partner,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.handshake_rounded,
                                size: 13,
                                color: accent.withValues(alpha: 0.85),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              if (tradeId != null && tradeId.isNotEmpty) ...<Widget>[
                                Text(
                                  '#$tradeId',
                                  style: TextStyle(
                                    color: AppColors.mutedTitanium.withValues(alpha: 0.7),
                                    fontSize: 9.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.mutedTitanium.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              if (date.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    date,
                                    style: const TextStyle(
                                      color: AppColors.mutedTitanium,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Runic Seal Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: accent.withValues(alpha: 0.14),
                        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.0),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.22),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(statusIcon, size: 12, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Ornate Aion 2 Etched Rune Divider with Center Gem
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                accent.withValues(alpha: 0.0),
                                accent.withValues(alpha: 0.35),
                                AppColors.darkObsidian.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Container(
                          width: 5,
                          height: 5,
                          transform: Matrix4.rotationZ(0.785398),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.75),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: accent.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                AppColors.darkObsidian.withValues(alpha: 0.8),
                                accent.withValues(alpha: 0.35),
                                accent.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Dual Ledger Columns (Given vs Received)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Given Column
                    Expanded(
                      child: _buildLedgerColumn(
                        context,
                        title: 'VERİLENLER',
                        badgeIcon: Icons.arrow_upward_rounded,
                        titleColor: AppColors.coralFlare,
                        items: myItems,
                        gold: myGold,
                      ),
                    ),

                    // Center Sigil Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.carbonVoid.withValues(alpha: 0.85),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.4),
                                width: 0.9,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.18),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.swap_horiz_rounded,
                              size: 13,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Received Column
                    Expanded(
                      child: _buildLedgerColumn(
                        context,
                        title: 'ALINANLAR',
                        badgeIcon: Icons.arrow_downward_rounded,
                        titleColor: AppColors.accentCyan,
                        items: theirItems,
                        gold: theirGold,
                      ),
                    ),
                  ],
                ),

                // Note or Reason (if any)
                if (note != null && note.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: AppColors.carbonVoid.withValues(alpha: 0.6),
                      border: Border.all(
                        color: (isCancelled ? AppColors.mysticRuby : AppColors.darkObsidian).withValues(alpha: 0.4),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      note.trim(),
                      style: TextStyle(
                        color: isCancelled ? AppColors.coralFlare : AppColors.mutedTitanium,
                        fontSize: 9.5,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                // Net Gold Summary Footnote if any gold was transacted
                if (isCompleted && (myGold > 0 || theirGold > 0)) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppColors.carbonVoid.withValues(alpha: 0.85),
                          AppColors.spaceNavy.withValues(alpha: 0.75),
                        ],
                      ),
                      border: Border.all(
                        color: (netGold >= 0 ? AppColors.accentCyan : AppColors.coralFlare).withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              netGold >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              size: 13,
                              color: netGold >= 0 ? AppColors.accentCyan : AppColors.coralFlare,
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Net Bakiye:',
                              style: TextStyle(
                                color: AppColors.mutedTitanium,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            netGold > 0
                                ? '+${_formatNumber(netGold)} Altın'
                                : (netGold < 0 ? '${_formatNumber(netGold)} Altın' : '0 Altın'),
                            style: TextStyle(
                              color: netGold > 0
                                  ? AppColors.toxicNeon
                                  : (netGold < 0 ? AppColors.coralFlare : AppColors.mutedTitanium),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLedgerColumn(
    BuildContext context, {
    required String title,
    required IconData badgeIcon,
    required Color titleColor,
    required List<Map<String, dynamic>> items,
    required int gold,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Title Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: titleColor.withValues(alpha: 0.1),
            border: Border.all(color: titleColor.withValues(alpha: 0.35), width: 0.7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(badgeIcon, size: 10, color: titleColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Gold Pill (if gold > 0)
        if (gold > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.liquidGold.withValues(alpha: 0.16),
                  AppColors.carbonVoid.withValues(alpha: 0.75),
                ],
              ),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.45),
                width: 0.8,
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.monetization_on_rounded, size: 12, color: AppColors.liquidGold),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${_formatNumber(gold)} Altın',
                    style: const TextStyle(
                      color: AppColors.liquidGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Empty state
        if (items.isEmpty && gold == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: AppColors.carbonVoid.withValues(alpha: 0.35),
              border: Border.all(
                color: AppColors.darkObsidian.withValues(alpha: 0.5),
                width: 0.6,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.hourglass_empty_rounded,
                  size: 13,
                  color: AppColors.mutedTitanium.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 2),
                Text(
                  'Eşya yok',
                  style: TextStyle(
                    color: AppColors.mutedTitanium.withValues(alpha: 0.6),
                    fontSize: 9.5,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        else
          ...items.map((Map<String, dynamic> item) {
            final String name = (item['name'] as String?) ?? 'Eşya';
            final String rarity = (item['rarity'] as String?) ?? 'common';
            final Color itemRarityColor = AppColors.forRarity(rarity);
            final int qty = (item['quantity'] as num?)?.toInt() ?? 1;
            final String icon = (item['icon'] as String?) ?? '📦';
            final String? itemId = item['item_id']?.toString();
            final ItemType? itemType = _parseItemType(item['item_type']?.toString());

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    MarketPedestalInspectionSheet.show(
                      context,
                      itemName: name,
                      rarity: rarity,
                      price: 0,
                      itemId: itemId,
                      iconValue: icon,
                      itemType: itemType,
                      stockLabel: 'Geçmiş Kayıt • x$qty Adet',
                      canBuy: false,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          itemRarityColor.withValues(alpha: 0.12),
                          AppColors.carbonVoid.withValues(alpha: 0.75),
                        ],
                      ),
                      border: Border.all(
                        color: itemRarityColor.withValues(alpha: 0.38),
                        width: 0.8,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: itemRarityColor.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        MarketItemPedestal(
                          rarity: rarity,
                          iconValue: icon,
                          itemId: itemId,
                          itemType: itemType,
                          itemName: name,
                          size: 26,
                          interactive: false,
                          autoRotate: false,
                          showLightBeam: false,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: itemRarityColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (qty > 1) ...<Widget>[
                          const SizedBox(width: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: itemRarityColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: itemRarityColor.withValues(alpha: 0.5),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              'x$qty',
                              style: TextStyle(
                                color: itemRarityColor,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
