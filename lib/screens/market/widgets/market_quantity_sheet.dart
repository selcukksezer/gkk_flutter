import 'package:flutter/material.dart';

import '../../../models/market_model.dart';
import '../../../theme/app_colors.dart';
import 'market_design.dart';
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
    return MarketSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.mutedTitanium.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            widget.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (widget.allowPriceEdit) ...<Widget>[
            _field(
              controller: _priceController,
              label: 'Birim fiyat (altin)',
              style: const TextStyle(
                color: AppColors.liquidGold,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
          ],
          if (widget.isStackable) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _stepButton(Icons.remove_rounded, _quantity > 1 ? () => setState(() => _quantity--) : null),
                Container(
                  width: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.darkObsidian.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '$_quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.liquidGold,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _stepButton(Icons.add_rounded, _quantity < _effectiveMax ? () => setState(() => _quantity++) : null),
              ],
            ),
            if (_effectiveMax > 1) ...<Widget>[
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.liquidGold,
                  inactiveTrackColor: AppColors.darkObsidian,
                  thumbColor: AppColors.liquidGold,
                  overlayColor: AppColors.liquidGold.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: _quantity.toDouble(),
                  min: 1,
                  max: _effectiveMax.toDouble(),
                  divisions: _effectiveMax > 1 ? _effectiveMax - 1 : 1,
                  onChanged: (double value) => setState(() => _quantity = value.round()),
                ),
              ),
              Text(
                'Maksimum: $_effectiveMax adet',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 11),
              ),
            ],
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.darkObsidian.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkObsidian),
              ),
              child: const Text(
                'Bu esya stackable degil — 1 adet',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
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
                  style: TextStyle(color: AppColors.mysticRuby, fontWeight: FontWeight.w700),
                ),
              ),
          ],
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
                  label: widget.confirmLabel,
                  onPressed: _canConfirm
                      ? () => Navigator.of(context).pop(
                            MarketQuantityResult(quantity: _quantity, unitPrice: _unitPrice),
                          )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required TextStyle style,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: style,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.mutedTitanium),
        filled: true,
        fillColor: AppColors.darkObsidian.withValues(alpha: 0.75),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.liquidGold.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.darkObsidian),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.liquidGold),
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onPressed) {
    return MarketPressable(
      enabled: onPressed != null,
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.darkObsidian.withValues(alpha: 0.85),
          border: Border.all(
            color: onPressed != null
                ? AppColors.liquidGold.withValues(alpha: 0.35)
                : AppColors.darkObsidian,
          ),
        ),
        child: Icon(
          icon,
          color: onPressed != null ? AppColors.liquidGold : AppColors.mutedTitanium,
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
          Text(label, style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.toxicNeon : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
