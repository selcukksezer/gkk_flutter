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

  @override
  Widget build(BuildContext context) {
    final int total = _price * widget.quantity;
    final int net = marketSellerReceives(_price, widget.quantity);

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
          const Text(
            'Fiyat Guncelle',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.itemName,
            style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: AppColors.liquidGold,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              labelText: 'Birim fiyat (altin)',
              labelStyle: const TextStyle(color: AppColors.mutedTitanium),
              filled: true,
              fillColor: AppColors.darkObsidian.withValues(alpha: 0.75),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.liquidGold.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.darkObsidian),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.liquidGold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Toplam: ${formatMarketGold(total)} altin • Net: ${formatMarketGold(net)} altin (%5 vergi)',
            style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
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
                  onPressed: _price > 0 ? () => Navigator.of(context).pop(_price) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
