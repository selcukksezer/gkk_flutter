import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/market_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'market_helpers.dart';

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

  @override
  Widget build(BuildContext context) {
    final int total = _price * widget.quantity;
    final int net = marketSellerReceives(_price, widget.quantity);

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
              'Fiyat Guncelle',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(widget.itemName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: AppSpacing.base),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 18),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: const BorderSide(color: AppColors.accentBlue),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Toplam: ${formatMarketGold(total)} altin • Net: ${formatMarketGold(net)} altin (%5 vergi)',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
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
                    child: const Text('Vazgec'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _price > 0 ? () => Navigator.of(context).pop(_price) : null,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accentBlue),
                    child: const Text('Kaydet'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
