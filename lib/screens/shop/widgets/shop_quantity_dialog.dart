import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../theme/app_colors.dart';

enum ShopDialogMode {
  buy,
  sell,
}

class ShopQuantityDialog extends StatefulWidget {
  const ShopQuantityDialog({
    super.key,
    required this.mode,
    required this.item,
    required this.unitPrice,
    required this.currency,
    required this.walletBalance,
    this.baseUnitPrice,
    this.hasBlessingDiscount = false,
    this.blessingDiscountPct = 0,
    this.maxQuantityAvailable = 99,
    this.isFavorite = false,
    this.onConfirm,
  });

  final ShopDialogMode mode;
  final Map<String, dynamic> item;
  final int unitPrice;
  final String currency; // 'gold' or 'gems'
  final int walletBalance;
  final int? baseUnitPrice;
  final bool hasBlessingDiscount;
  final int blessingDiscountPct;
  final int maxQuantityAvailable;
  final bool isFavorite;
  final Future<void> Function(int quantity)? onConfirm;

  static Future<bool?> show(
    BuildContext context, {
    required ShopDialogMode mode,
    required Map<String, dynamic> item,
    required int unitPrice,
    required String currency,
    required int walletBalance,
    int? baseUnitPrice,
    bool hasBlessingDiscount = false,
    int blessingDiscountPct = 0,
    int maxQuantityAvailable = 99,
    bool isFavorite = false,
    Future<void> Function(int quantity)? onConfirm,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: item['name']?.toString() ?? 'Shop Dialog',
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim, secondary) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondary, child) {
        final double scale = Curves.easeOutBack.transform(anim.value);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: FadeTransition(
            opacity: anim,
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                  child: ShopQuantityDialog(
                    mode: mode,
                    item: item,
                    unitPrice: unitPrice,
                    currency: currency,
                    walletBalance: walletBalance,
                    baseUnitPrice: baseUnitPrice,
                    hasBlessingDiscount: hasBlessingDiscount,
                    blessingDiscountPct: blessingDiscountPct,
                    maxQuantityAvailable: maxQuantityAvailable,
                    isFavorite: isFavorite,
                    onConfirm: onConfirm,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  State<ShopQuantityDialog> createState() => _ShopQuantityDialogState();
}

class _ShopQuantityDialogState extends State<ShopQuantityDialog> {
  late int _quantity;
  late int _maxAllowed;
  late final TextEditingController _textController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == ShopDialogMode.buy) {
      // For buy: max allowed is capped by wallet balance (if > 0) or available limit
      final int affordable = widget.unitPrice > 0
          ? (widget.walletBalance ~/ widget.unitPrice).clamp(1, widget.maxQuantityAvailable)
          : widget.maxQuantityAvailable;
      _maxAllowed = affordable.clamp(1, widget.maxQuantityAvailable);
    } else {
      // For sell: max allowed is current owned quantity
      _maxAllowed = widget.maxQuantityAvailable.clamp(1, 9999);
    }
    _quantity = 1;
    _textController = TextEditingController(text: '$_quantity');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _updateQuantity(int next) {
    final int clamped = next.clamp(1, _maxAllowed > 0 ? _maxAllowed : 1);
    if (clamped != _quantity) {
      setState(() {
        _quantity = clamped;
        _textController.text = '$_quantity';
      });
    }
  }

  static String _fmtNumber(int num) {
    final String s = num.toString();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isGem = widget.currency == 'gems';
    final currencySymbol = isGem ? '💎' : '🪙';
    final currencyName = isGem ? 'Elmas' : 'Altın';
    final primaryAccent = widget.mode == ShopDialogMode.buy
        ? (isGem ? AppColors.accentCyan : AppColors.liquidGold)
        : AppColors.liquidGold;

    final String name = widget.item['name']?.toString() ?? 'Eşya';
    final String? description = widget.item['description']?.toString();
    final String rarity = widget.item['rarity']?.toString() ?? 'common';
    final Color rarityColor = AppColors.forRarity(rarity);

    final int totalCost = _quantity * widget.unitPrice;
    final bool isBuy = widget.mode == ShopDialogMode.buy;
    final bool canAfford = !isBuy || widget.walletBalance >= totalCost;
    final int remainingBalance = isBuy
        ? widget.walletBalance - totalCost
        : widget.walletBalance + totalCost;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF162138),
              Color(0xFF0F1626),
            ],
          ),
          border: Border.all(
            color: primaryAccent.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: primaryAccent.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header bar with filigree style
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      primaryAccent.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: primaryAccent.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      isBuy ? Icons.storefront_rounded : Icons.currency_exchange_rounded,
                      size: 20,
                      color: primaryAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isBuy ? 'Tüccardan Satın Al' : 'Tüccara Eşya Sat',
                        style: GoogleFonts.cinzel(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black38,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Item Information Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C1322),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: rarityColor.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: rarityColor.withValues(alpha: 0.12),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          // Item Icon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.black45,
                              border: Border.all(
                                color: rarityColor.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ItemIconView(
                                iconValue: (widget.item['icon']?.toString() ?? '📦').trim(),
                                itemId: widget.item['item_id']?.toString(),
                                size: 56,
                                expand: true,
                                fallback: '📦',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Name, Rarity & Unit Price
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: rarityColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: rarityColor.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        rarity.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: rarityColor,
                                        ),
                                      ),
                                    ),
                                    if (widget.item['is_stackable'] == true) ...<Widget>[
                                      const SizedBox(width: 6),
                                      Text(
                                        'Maks: ${widget.item['max_stack'] ?? 99}',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: AppColors.mutedTitanium,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      isBuy ? 'Birim Fiyat: ' : 'Birim Satış: ',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.mutedTitanium,
                                      ),
                                    ),
                                    Text(currencySymbol, style: const TextStyle(fontSize: 11)),
                                    const SizedBox(width: 2),
                                    if (isBuy && widget.hasBlessingDiscount && widget.baseUnitPrice != null && widget.baseUnitPrice! > widget.unitPrice) ...<Widget>[
                                      Text(
                                        '${widget.baseUnitPrice}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          decoration: TextDecoration.lineThrough,
                                          color: Colors.white38,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(
                                      '${widget.unitPrice}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: primaryAccent,
                                      ),
                                    ),
                                    if (isBuy && widget.hasBlessingDiscount) ...<Widget>[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentCyan.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          '-%${widget.blessingDiscountPct}',
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.accentCyan,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (description != null && description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    if (widget.isFavorite && !isBuy) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: <Widget>[
                            Icon(Icons.lock_rounded, size: 14, color: AppColors.warning),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Bu eşya favori olarak kilitlidir. Satmak için önce envanterden kilidi açın.',
                                style: TextStyle(fontSize: 10.5, color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Quantity Selector
                    Text(
                      'Miktar Belirle',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedTitanium.withValues(alpha: 0.9),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // -10 Button
                        _QuickStepButton(
                          label: '-10',
                          onTap: () => _updateQuantity(_quantity - 10),
                        ),
                        const SizedBox(width: 6),
                        // -1 Button
                        _QuickStepButton(
                          icon: Icons.remove,
                          onTap: () => _updateQuantity(_quantity - 1),
                        ),
                        const SizedBox(width: 10),

                        // Numeric input box
                        Container(
                          width: 72,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: primaryAccent.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: _textController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: primaryAccent,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (String v) {
                              final int? parsed = int.tryParse(v);
                              if (parsed != null) {
                                final int clamped = parsed.clamp(1, _maxAllowed > 0 ? _maxAllowed : 1);
                                if (clamped != _quantity) {
                                  setState(() => _quantity = clamped);
                                }
                              }
                            },
                          ),
                        ),

                        const SizedBox(width: 10),
                        // +1 Button
                        _QuickStepButton(
                          icon: Icons.add,
                          onTap: () => _updateQuantity(_quantity + 1),
                        ),
                        const SizedBox(width: 6),
                        // +10 Button
                        _QuickStepButton(
                          label: '+10',
                          onTap: () => _updateQuantity(_quantity + 10),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Smooth Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: primaryAccent,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: primaryAccent,
                        overlayColor: primaryAccent.withValues(alpha: 0.2),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: _quantity.toDouble().clamp(1.0, (_maxAllowed > 1 ? _maxAllowed : 1).toDouble()),
                        min: 1.0,
                        max: (_maxAllowed > 1 ? _maxAllowed : 1).toDouble(),
                        onChanged: (double val) => _updateQuantity(val.round()),
                      ),
                    ),

                    // Quick shortcut chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _ShortcutChip(
                          label: '1',
                          isSelected: _quantity == 1,
                          accent: primaryAccent,
                          onTap: () => _updateQuantity(1),
                        ),
                        if (_maxAllowed >= 5)
                          _ShortcutChip(
                            label: '5',
                            isSelected: _quantity == 5,
                            accent: primaryAccent,
                            onTap: () => _updateQuantity(5),
                          ),
                        if (_maxAllowed >= 10)
                          _ShortcutChip(
                            label: '10',
                            isSelected: _quantity == 10,
                            accent: primaryAccent,
                            onTap: () => _updateQuantity(10),
                          ),
                        _ShortcutChip(
                          label: isBuy ? 'Yarısı' : '%50',
                          isSelected: _quantity == (_maxAllowed / 2).ceil(),
                          accent: primaryAccent,
                          onTap: () => _updateQuantity((_maxAllowed / 2).ceil()),
                        ),
                        _ShortcutChip(
                          label: isBuy ? 'Maks' : 'Tümü',
                          isSelected: _quantity == _maxAllowed,
                          accent: primaryAccent,
                          onTap: () => _updateQuantity(_maxAllowed),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Ornate Cost / Gain Preview Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1627),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: canAfford
                              ? primaryAccent.withValues(alpha: 0.45)
                              : AppColors.danger.withValues(alpha: 0.65),
                          width: 1.2,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: canAfford
                                ? primaryAccent.withValues(alpha: 0.08)
                                : AppColors.danger.withValues(alpha: 0.14),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                isBuy ? 'Toplam Tutar:' : 'Kazanılacak Tutar:',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedTitanium,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: <Widget>[
                                  Text(currencySymbol, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${isBuy ? '' : '+'}${_fmtNumber(totalCost)} $currencyName',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: canAfford ? primaryAccent : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                isBuy ? 'Kalan Bakiye:' : 'Sonraki Bakiye:',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.mutedTitanium,
                                ),
                              ),
                              Row(
                                children: <Widget>[
                                  Text(
                                    '${_fmtNumber(widget.walletBalance)} $currencySymbol ➔ ',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${_fmtNumber(remainingBalance)} $currencySymbol',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: canAfford ? AppColors.textPrimary : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (!canAfford) ...<Widget>[
                            const SizedBox(height: 6),
                            const Text(
                              '⚠️ Yetersiz bakiye! Satın alma yapılamaz.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.danger,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Action Buttons
                    Row(
                      children: <Widget>[
                        // Cancel Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.carbonVoid.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: const Text(
                                'Vazgeç',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Primary CTA Button
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: (!canAfford || (widget.isFavorite && !isBuy) || _isLoading)
                                ? null
                                : () async {
                                    if (widget.onConfirm != null) {
                                      setState(() => _isLoading = true);
                                      try {
                                        await widget.onConfirm!(_quantity);
                                      } finally {
                                        if (mounted) setState(() => _isLoading = false);
                                      }
                                    }
                                    if (mounted) Navigator.pop(context, true);
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: (canAfford && (!widget.isFavorite || isBuy))
                                    ? AppColors.liquidGoldGradient
                                    : null,
                                color: (!canAfford || (widget.isFavorite && !isBuy))
                                    ? Colors.white12
                                    : null,
                                border: Border.all(
                                  color: (canAfford && (!widget.isFavorite || isBuy))
                                      ? AppColors.liquidGold
                                      : Colors.white10,
                                ),
                                boxShadow: (canAfford && (!widget.isFavorite || isBuy))
                                    ? <BoxShadow>[
                                        BoxShadow(
                                          color: AppColors.liquidGold.withValues(alpha: 0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: _isLoading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.carbonVoid,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Icon(
                                          isBuy ? Icons.shopping_bag_rounded : Icons.check_circle_rounded,
                                          size: 16,
                                          color: (canAfford && (!widget.isFavorite || isBuy))
                                              ? AppColors.carbonVoid
                                              : Colors.white38,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isBuy
                                              ? 'Satın Al (${_fmtNumber(totalCost)} $currencySymbol)'
                                              : 'Sat (+${_fmtNumber(totalCost)} $currencySymbol)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: (canAfford && (!widget.isFavorite || isBuy))
                                                ? AppColors.carbonVoid
                                                : Colors.white38,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
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
      ),
    );
  }
}

class _QuickStepButton extends StatelessWidget {
  const _QuickStepButton({
    this.label,
    this.icon,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF131D30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: icon != null
            ? Icon(icon, size: 16, color: Colors.white70)
            : Text(
                label!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.22) : Colors.black26,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? accent : Colors.white12,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? accent : AppColors.mutedTitanium,
          ),
        ),
      ),
    );
  }
}
