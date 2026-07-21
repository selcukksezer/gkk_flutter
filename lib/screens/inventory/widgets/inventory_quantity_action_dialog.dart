import 'package:flutter/material.dart';

class InventoryQuantityActionDialog extends StatefulWidget {
  const InventoryQuantityActionDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.unitValue,
    required this.maxQuantity,
    this.showTotalValue = true,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final int unitValue;
  final int maxQuantity;
  final bool showTotalValue;

  @override
  State<InventoryQuantityActionDialog> createState() =>
      _InventoryQuantityActionDialogState();
}

class _InventoryQuantityActionDialogState
    extends State<InventoryQuantityActionDialog> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.maxQuantity < 1 ? 1 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.unitValue * _quantity;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.subtitle),
          const SizedBox(height: 12),
          Text('Miktar: $_quantity / ${widget.maxQuantity}'),
          Slider(
            value: _quantity.toDouble(),
            min: 1,
            max: widget.maxQuantity.toDouble(),
            divisions: widget.maxQuantity > 1 ? widget.maxQuantity - 1 : null,
            onChanged: widget.maxQuantity <= 1
                ? null
                : (value) {
                    setState(() {
                      _quantity = value.round();
                    });
                  },
          ),
          if (widget.showTotalValue)
            Text(
              'Toplam Deger: $total',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Iptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_quantity),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
