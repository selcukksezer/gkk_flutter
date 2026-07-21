import 'package:flutter/material.dart';

import 'bank_design.dart';

class BankQuantityDialog extends StatefulWidget {
  const BankQuantityDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.maxQuantity,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final int maxQuantity;
  final Color accent;

  static Future<int?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int maxQuantity,
    required Color accent,
  }) {
    return showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => BankQuantityDialog(
        title: title,
        subtitle: subtitle,
        maxQuantity: maxQuantity,
        accent: accent,
      ),
    );
  }

  @override
  State<BankQuantityDialog> createState() => _BankQuantityDialogState();
}

class _BankQuantityDialogState extends State<BankQuantityDialog> {
  late final TextEditingController _qtyCtrl;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.maxQuantity;
    _qtyCtrl = TextEditingController(text: '${widget.maxQuantity}');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _setQuantity(int next) {
    final int clamped = next.clamp(1, widget.maxQuantity);
    setState(() {
      _quantity = clamped;
      _qtyCtrl.value = TextEditingValue(
        text: '$clamped',
        selection: TextSelection.collapsed(offset: '$clamped'.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A2030),
      title: Text(
        widget.title,
        style: TextStyle(color: widget.accent, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Text('Miktar:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFF0F0F0F),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                  onChanged: (String value) {
                    _setQuantity(bankAsInt(value, fallback: 1));
                  },
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: 30,
                    child: IconButton(
                      splashRadius: 16,
                      onPressed: () => _setQuantity(_quantity + 1),
                      icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    child: IconButton(
                      splashRadius: 16,
                      onPressed: () => _setQuantity(_quantity - 1),
                      icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _quantity),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.accent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Onayla'),
        ),
      ],
    );
  }
}
