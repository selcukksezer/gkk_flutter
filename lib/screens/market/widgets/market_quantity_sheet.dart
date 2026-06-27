import 'package:flutter/material.dart';

import '../../../models/market_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'market_helpers.dart';
import '../../../l10n/l10n.dart';

enum MarketQuantityMode { buy, sell }

class MarketQuantityResult {
  const MarketQuantityResult({required this.quantity, required this.unitPrice});

  final int quantity;
  final int unitPrice;
}

class MarketQuantitySheet extends StatefulWidget {
  const MarketQuantitySheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.unitPrice,
    required this.maxQuantity,
    required this.isStackable,
    required this.mode,
    required this.confirmLabel,
    this.playerGold,
    this.allowPriceEdit = false,
  });

  final String title;
  final String subtitle;
  final int unitPrice;
  final int maxQuantity;
  final bool isStackable;
  final MarketQuantityMode mode;
  final String confirmLabel;
  final int? playerGold;
  final bool allowPriceEdit;

  static Future<MarketQuantityResult?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int unitPrice,
    required int maxQuantity,
    required bool isStackable,
    required MarketQuantityMode mode,
    required String confirmLabel,
    int? playerGold,
    bool allowPriceEdit = false,
  }) {
    return showModalBottomSheet<MarketQuantityResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => MarketQuantitySheet(
        title: title,
        subtitle: subtitle,
        unitPrice: unitPrice,
        maxQuantity: maxQuantity,
        isStackable: isStackable,
        mode: mode,
        confirmLabel: confirmLabel,
        playerGold: playerGold,
        allowPriceEdit: allowPriceEdit,
      ),
    );
  }

  @override
  State<MarketQuantitySheet> createState() => _MarketQuantitySheetState();
}

class _MarketQuantitySheetState extends State<MarketQuantitySheet> {
  late int _quantity;
  late final TextEditingController _priceController;

  int get _unitPrice {
    if (widget.allowPriceEdit) {
      return int.tryParse(_priceController.text) ?? 0;
    }
    return widget.unitPrice;
  }

  int get _effectiveMax => widget.isStackable ? widget.maxQuantity.clamp(1, 999999) : 1;

  int get _total => _unitPrice * _quantity;

  int get _sellerReceives => marketSellerReceives(_unitPrice, _quantity);

  int get _fee => marketFeeAmount(_unitPrice, _quantity);

  bool get _canConfirm {
    if (_quantity < 1 || _quantity > _effectiveMax) return false;
    if (_unitPrice <= 0) return false;
    if (widget.mode == MarketQuantityMode.buy && widget.playerGold != null) {
      return widget.playerGold! >= _total;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _quantity = 1;
    _priceController = TextEditingController(text: '${widget.unitPrice}');
    _priceController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.base),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderBright),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(widget.subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: AppSpacing.base),
            if (widget.allowPriceEdit) ...<Widget>[
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Birim fiyat (altin)',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.borderDefault),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.borderDefault),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
            ],
            if (widget.isStackable) ...<Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _stepButton(Icons.remove, _quantity > 1 ? () => setState(() => _quantity--) : null),
                  Container(
                    width: 72,
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _stepButton(Icons.add, _quantity < _effectiveMax ? () => setState(() => _quantity++) : null),
                ],
              ),
              if (_effectiveMax > 1) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Slider(
                  value: _quantity.toDouble(),
                  min: 1,
                  max: _effectiveMax.toDouble(),
                  divisions: _effectiveMax > 1 ? _effectiveMax - 1 : 1,
                  activeColor: AppColors.accentBlue,
                  onChanged: (double value) => setState(() => _quantity = value.round()),
                ),
                Text(
                  'Maksimum: $_effectiveMax adet',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ] else
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: const Text(
                  'Bu esya stackable degil — 1 adet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            const SizedBox(height: AppSpacing.base),
            _summaryRow('Birim fiyat', '${formatMarketGold(_unitPrice)} altin'),
            _summaryRow('Toplam', '${formatMarketGold(_total)} altin'),
            if (widget.mode == MarketQuantityMode.sell) ...<Widget>[
              _summaryRow('Pazar vergisi (%5)', '-${formatMarketGold(_fee)} altin'),
              _summaryRow('Alacagin', '${formatMarketGold(_sellerReceives)} altin', highlight: true),
            ],
            if (widget.mode == MarketQuantityMode.buy && widget.playerGold != null) ...<Widget>[
              _summaryRow('Altinin', '${formatMarketGold(widget.playerGold!)} altin'),
              if (!_canConfirm)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Yeterli altin yok',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.base),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.borderDefault),
                    ),
                    child: Text(context.l10n.vazgec),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _canConfirm
                        ? () => Navigator.of(context).pop(
                              MarketQuantityResult(quantity: _quantity, unitPrice: _unitPrice),
                            )
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: Text(widget.confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onPressed) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Icon(icon, color: onPressed != null ? AppColors.gold : AppColors.textDisabled),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.success : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
