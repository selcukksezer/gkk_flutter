import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/market_model.dart';
import '../../../theme/app_colors.dart';
import 'market_design.dart';
import 'market_helpers.dart';
import '../../../l10n/l10n.dart';

class MarketPriceEditSheet extends StatefulWidget {
  const MarketPriceEditSheet({
    super.key,
    required this.itemName,
    required this.currentPrice,
    required this.quantity,
  });

  final String itemName;
  final int currentPrice;
  final int quantity;

  static Future<int?> show(
    BuildContext context, {
    required String itemName,
    required int currentPrice,
    required int quantity,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => MarketPriceEditSheet(
        itemName: itemName,
        currentPrice: currentPrice,
        quantity: quantity,
      ),
    );
  }

  @override
  State<MarketPriceEditSheet> createState() => _MarketPriceEditSheetState();
}

class _MarketPriceEditSheetState extends State<MarketPriceEditSheet> {
  late final TextEditingController _priceController;

  int get _price => int.tryParse(_priceController.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: '${widget.currentPrice}');
    _priceController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _applyMultiplier(double factor) {
    final int target = (widget.currentPrice * factor).round().clamp(1, 999999999);
    _priceController.text = '$target';
    _priceController.selection = TextSelection.fromPosition(
      TextPosition(offset: _priceController.text.length),
    );
    HapticFeedback.selectionClick();
  }

  void _resetPrice() {
    _priceController.text = '${widget.currentPrice}';
    _priceController.selection = TextSelection.fromPosition(
      TextPosition(offset: _priceController.text.length),
    );
    HapticFeedback.selectionClick();
  }

  Widget _buildDeltaBadge(int diff, double? pct) {
    if (diff == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.mutedTitanium.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Değişim Yok',
          style: TextStyle(
            color: AppColors.mutedTitanium,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final bool isUp = diff > 0;
    final Color color = isUp ? AppColors.toxicNeon : AppColors.mysticRuby;
    final String sign = isUp ? '+' : '';
    final String pctText = pct != null ? ' ($sign${pct.toStringAsFixed(1)}%)' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '$sign${formatMarketGold(diff)}$pctText',
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(
    String label,
    VoidCallback onTap, {
    Color accent = AppColors.liquidGold,
    bool isSelected = false,
  }) {
    return MarketPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? accent.withValues(alpha: 0.2)
              : AppColors.darkObsidian.withValues(alpha: 0.65),
          border: Border.all(
            color: isSelected ? accent : AppColors.darkObsidian,
            width: isSelected ? 1.2 : 1,
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? accent : AppColors.mutedTitanium,
          ),
        ),
      ),
    );
  }

  Widget _breakdownRow(
    String label,
    String value, {
    IconData? icon,
    Color valueColor = AppColors.textPrimary,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 13, color: AppColors.mutedTitanium),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: const TextStyle(
                color: AppColors.mutedTitanium,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final int total = _price * widget.quantity;
    final int fee = marketFeeAmount(_price, widget.quantity);
    final int net = marketSellerReceives(_price, widget.quantity);
    final int priceDiff = _price - widget.currentPrice;
    final double? percentDiff = widget.currentPrice > 0 ? (priceDiff / widget.currentPrice) * 100 : null;

    return MarketSheetShell(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.liquidGold.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.liquidGold.withValues(alpha: 0.18),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.darkObsidian.withValues(alpha: 0.8),
                      border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.35)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.liquidGold.withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.price_change_rounded,
                      color: AppColors.liquidGold,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          context.l10n.fiyat_guncelle,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                widget.itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.mutedTitanium,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (widget.quantity > 1) ...<Widget>[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.accentCyan.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.accentCyan.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'x${widget.quantity}',
                                  style: const TextStyle(
                                    color: AppColors.accentCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  MarketPressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.darkObsidian.withValues(alpha: 0.6),
                        border: Border.all(color: AppColors.darkObsidian),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: AppColors.mutedTitanium,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 14, bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.darkObsidian.withValues(alpha: 0.55),
                  border: Border.all(
                    color: AppColors.darkObsidian.withValues(alpha: 0.8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.history_rounded,
                          size: 14,
                          color: AppColors.mutedTitanium,
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Mevcut İlan:',
                          style: TextStyle(
                            color: AppColors.mutedTitanium,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${formatMarketGold(widget.currentPrice)} altin',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    _buildDeltaBadge(priceDiff, percentDiff),
                  ],
                ),
              ),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                cursorColor: AppColors.liquidGold,
                style: const TextStyle(
                  color: AppColors.liquidGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  labelText: 'Yeni Birim Fiyat (altin)',
                  labelStyle: const TextStyle(color: AppColors.mutedTitanium, fontSize: 13),
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: AppColors.liquidGold.withValues(alpha: 0.3),
                    fontSize: 20,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.monetization_on_rounded, color: AppColors.liquidGold, size: 22),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
                  suffixIcon: _priceController.text.isNotEmpty
                      ? MarketPressable(
                          onTap: () {
                            _priceController.clear();
                            HapticFeedback.selectionClick();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.cancel_rounded,
                              size: 18,
                              color: AppColors.mutedTitanium,
                            ),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.darkObsidian.withValues(alpha: 0.75),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.liquidGold.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _price > 0
                          ? AppColors.liquidGold.withValues(alpha: 0.35)
                          : AppColors.darkObsidian,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.liquidGold, width: 1.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: <Widget>[
                      _quickChip('-10%', () => _applyMultiplier(0.90)),
                      const SizedBox(width: 6),
                      _quickChip('-5%', () => _applyMultiplier(0.95)),
                      const SizedBox(width: 6),
                      _quickChip(
                        'Mevcut',
                        _resetPrice,
                        accent: AppColors.accentCyan,
                        isSelected: _price == widget.currentPrice,
                      ),
                      const SizedBox(width: 6),
                      _quickChip('+5%', () => _applyMultiplier(1.05)),
                      const SizedBox(width: 6),
                      _quickChip('+10%', () => _applyMultiplier(1.10)),
                      const SizedBox(width: 6),
                      _quickChip('+25%', () => _applyMultiplier(1.25)),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.darkObsidian.withValues(alpha: 0.5),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.carbonVoid.withValues(alpha: 0.6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _breakdownRow(
                      'Birim Fiyat',
                      '${formatMarketGold(_price)} altin',
                      icon: Icons.monetization_on_outlined,
                    ),
                    if (widget.quantity > 1) ...<Widget>[
                      const SizedBox(height: 6),
                      _breakdownRow(
                        'Toplam Satış (${widget.quantity} adet)',
                        '${formatMarketGold(total)} altin',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ],
                    const SizedBox(height: 6),
                    _breakdownRow(
                      'Pazar Vergisi (%5)',
                      '-${formatMarketGold(fee)} altin',
                      icon: Icons.percent_rounded,
                      valueColor: AppColors.cyberFuchsia,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.transparent,
                              AppColors.liquidGold.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 14,
                              color: AppColors.toxicNeon,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Net Kazanç (Tahmini)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${formatMarketGold(net)} altin',
                          style: const TextStyle(
                            color: AppColors.toxicNeon,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_price <= 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      'Lütfen geçerli bir birim fiyat girin',
                      style: TextStyle(
                        color: AppColors.mysticRuby,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: MarketSecondaryButton(
                      label: context.l10n.vazgec,
                      accent: AppColors.mutedTitanium,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MarketPrimaryButton(
                      label: context.l10n.kaydet,
                      icon: Icons.check_rounded,
                      onPressed: _price > 0 ? () => Navigator.of(context).pop(_price) : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
