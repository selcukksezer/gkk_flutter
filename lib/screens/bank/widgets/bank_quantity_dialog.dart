import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'bank_design.dart';

/// Aion 2 luxury quantity modal with quick-select crystal chips,
/// stepper controls, and frosted glass backdrop.
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
    return showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'BankQuantityDialog',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (BuildContext ctx, Animation<double> a1, Animation<double> a2) {
        return BankQuantityDialog(
          title: title,
          subtitle: subtitle,
          maxQuantity: maxQuantity,
          accent: accent,
        );
      },
      transitionBuilder: (
        BuildContext ctx,
        Animation<double> anim,
        Animation<double> secondaryAnim,
        Widget child,
      ) {
        final CurvedAnimation curve = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
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
    final bool isDeposit = widget.accent == BankDesign.deposit ||
        widget.title.toLowerCase().contains('yatır') ||
        widget.title.toLowerCase().contains('envanter');

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF1E2638),
                      Color(0xFF101624),
                      Color(0xFF090D14),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.accent.withValues(alpha: 0.5),
                    width: 1.4,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.2),
                      blurRadius: 26,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Direction Header & Icon
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: widget.accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            isDeposit
                                ? Icons.file_upload_rounded
                                : Icons.file_download_rounded,
                            color: widget.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.title,
                                style: TextStyle(
                                  color: widget.accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle,
                                style: const TextStyle(
                                  color: AppColors.mutedTitanium,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Quick Select Crystal Chips
                    if (widget.maxQuantity > 1) ...<Widget>[
                      Row(
                        children: <Widget>[
                          _QuickChip(
                            label: '1',
                            onTap: () => _setQuantity(1),
                            accent: widget.accent,
                          ),
                          const SizedBox(width: 6),
                          if (widget.maxQuantity >= 5) ...<Widget>[
                            _QuickChip(
                              label: '5',
                              onTap: () => _setQuantity(5),
                              accent: widget.accent,
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (widget.maxQuantity >= 10) ...<Widget>[
                            _QuickChip(
                              label: '10',
                              onTap: () => _setQuantity(10),
                              accent: widget.accent,
                            ),
                            const SizedBox(width: 6),
                          ],
                          _QuickChip(
                            label: '½',
                            onTap: () => _setQuantity(
                              (widget.maxQuantity / 2).ceil().clamp(1, widget.maxQuantity),
                            ),
                            accent: widget.accent,
                          ),
                          const SizedBox(width: 6),
                          _QuickChip(
                            label: 'Tümü',
                            onTap: () => _setQuantity(widget.maxQuantity),
                            accent: widget.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Stepper + Input Field
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: BankDesign.royalObsidian.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: widget.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          _StepButton(
                            icon: Icons.remove_rounded,
                            onPressed: _quantity > 1
                                ? () => _setQuantity(_quantity - 1)
                                : null,
                            accent: widget.accent,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _qtyCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: widget.accent,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                              onChanged: (String val) {
                                final int parsed = bankAsInt(val, fallback: 1);
                                if (parsed != _quantity) {
                                  _quantity = parsed.clamp(1, widget.maxQuantity);
                                }
                              },
                            ),
                          ),
                          _StepButton(
                            icon: Icons.add_rounded,
                            onPressed: _quantity < widget.maxQuantity
                                ? () => _setQuantity(_quantity + 1)
                                : null,
                            accent: widget.accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.mutedTitanium,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            child: const Text(
                              'İptal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context, _quantity),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: <Color>[
                                      widget.accent,
                                      widget.accent.withValues(alpha: 0.75),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: widget.accent.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'Onayla ($_quantity)',
                                    style: const TextStyle(
                                      color: AppColors.carbonVoid,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
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
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BankDesign.royalObsidian.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accent.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onPressed,
    required this.accent,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? accent : Colors.white24,
          ),
        ),
      ),
    );
  }
}
