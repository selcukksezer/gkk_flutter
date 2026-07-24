import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/common/universal_game_dialog.dart';
import '../../../core/utils/gold_format.dart';
import '../../../models/guild_model.dart';
import '../../../repositories/guild_monument_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// Lonca anıtı kaynak bağışı — miktar seçimi (preset + özel).
abstract final class MonumentDonateAmountDialog {
  static Future<int?> show(
    BuildContext context, {
    required MonumentResourceKind kind,
    required MonumentMyStats stats,
    Color accent = AppColors.liquidGold,
  }) {
    final int maxDonatable = stats.maxDonatable(kind);
    if (maxDonatable <= 0) return Future<int?>.value(null);

    return showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '${kind.shortLabel} bağışı',
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.52),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (
        BuildContext ctx,
        Animation<double> anim,
        Animation<double> secondary,
        Widget? child,
      ) {
        final double scale = Curves.easeOutBack.transform(anim.value);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: FadeTransition(
            opacity: anim,
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _MonumentDonateAmountSheet(
                    kind: kind,
                    stats: stats,
                    maxDonatable: maxDonatable,
                    accent: accent,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MonumentDonateAmountSheet extends StatefulWidget {
  const _MonumentDonateAmountSheet({
    required this.kind,
    required this.stats,
    required this.maxDonatable,
    required this.accent,
  });

  final MonumentResourceKind kind;
  final MonumentMyStats stats;
  final int maxDonatable;
  final Color accent;

  @override
  State<_MonumentDonateAmountSheet> createState() => _MonumentDonateAmountSheetState();
}

class _MonumentDonateAmountSheetState extends State<_MonumentDonateAmountSheet> {
  late final TextEditingController _controller;
  late int _amount;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = _defaultAmount();
    _controller = TextEditingController(text: '$_amount');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _defaultAmount() {
    for (final int preset in _presets()) {
      if (preset > 0) return preset;
    }
    return widget.maxDonatable;
  }

  List<int> _presets() {
    final List<int> candidates = widget.kind == MonumentResourceKind.gold
        ? <int>[100000, 500000, 1000000]
        : <int>[1, 10, 50, widget.maxDonatable];
    return candidates.where((int value) => value > 0 && value <= widget.maxDonatable).toSet().toList()
      ..sort();
  }

  void _setAmount(int value) {
    final int clamped = value.clamp(1, widget.maxDonatable);
    setState(() {
      _amount = clamped;
      _error = null;
    });
    final String text = '$clamped';
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _applyTextInput(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() => _error = 'Miktar gir');
      return;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      setState(() => _error = 'Geçerli miktar gir');
      return;
    }
    if (parsed > widget.maxDonatable) {
      setState(() => _error = 'En fazla ${widget.maxDonatable} bağışlayabilirsin');
      return;
    }
    _setAmount(parsed);
  }

  void _confirm() {
    _applyTextInput(_controller.text);
    if (_error != null) return;

    final int capped = monumentDonateCap(
      owned: widget.stats.owned(widget.kind),
      donatedToday: widget.stats.donatedToday(widget.kind),
      dailyMax: widget.stats.dailyMax(widget.kind),
      requested: _amount,
    );
    if (capped <= 0) {
      setState(() => _error = 'Bağışlanacak miktar yok');
      return;
    }
    Navigator.pop(context, capped);
  }

  String _presetLabel(int value) {
    if (widget.kind != MonumentResourceKind.gold &&
        value == widget.maxDonatable &&
        value > 1) {
      return 'Max';
    }
    return formatCompactGold(value);
  }

  @override
  Widget build(BuildContext context) {
    final int owned = widget.stats.owned(widget.kind);
    final int dailyLeft = widget.stats.dailyLeft(widget.kind);
    final List<int> presets = _presets();
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: UniversalDialogPanel(
          borderColor: widget.accent.withValues(alpha: 0.45),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
          Text('${widget.kind.shortLabel} Bağışı', style: AppTextStyles.dialogTitle),
          const SizedBox(height: 10),
          Text(
            widget.kind == MonumentResourceKind.gold
                ? 'Elinde: $owned altın · Bugün kalan: $dailyLeft'
                : 'Elinde: $owned · Bugün kalan: $dailyLeft',
            style: AppTextStyles.dialogBody,
          ),
          const SizedBox(height: 14),
          if (presets.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((int preset) {
                final bool selected = _amount == preset;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _setAmount(preset),
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: selected ? AppColors.liquidGoldGradient : null,
                        color: selected ? null : AppColors.darkObsidian.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.liquidGold
                              : AppColors.mutedTitanium.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        _presetLabel(preset),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected ? AppColors.carbonVoid : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              _MonumentDonateMaxFormatter(widget.maxDonatable),
            ],
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: 'Özel miktar (max ${widget.maxDonatable})',
              filled: true,
              fillColor: AppColors.darkObsidian.withValues(alpha: 0.65),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                borderSide: BorderSide(color: AppColors.mutedTitanium.withValues(alpha: 0.22)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                borderSide: BorderSide(color: AppColors.mutedTitanium.withValues(alpha: 0.22)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                borderSide: BorderSide(color: widget.accent.withValues(alpha: 0.55)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: _applyTextInput,
            onSubmitted: _applyTextInput,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              _error!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: AppColors.mysticRuby),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _ObsidianDialogButton(
                  label: 'Vazgeç',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GoldDialogButton(
                  label: 'Bağışla',
                  onPressed: _confirm,
                ),
              ),
            ],
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonumentDonateMaxFormatter extends TextInputFormatter {
  const _MonumentDonateMaxFormatter(this.maxValue);

  final int maxValue;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final String text = newValue.text;
    if (text.isEmpty) return newValue;

    final int? value = int.tryParse(text);
    if (value == null) return oldValue;
    if (value <= maxValue) return newValue;
    return oldValue;
  }
}

class _GoldDialogButton extends StatelessWidget {
  const _GoldDialogButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.liquidGoldGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.liquidGold.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Text(label, textAlign: TextAlign.center, style: AppTextStyles.dialogButton),
          ),
        ),
      ),
    );
  }
}

class _ObsidianDialogButton extends StatelessWidget {
  const _ObsidianDialogButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.darkObsidian,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.mutedTitanium.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Text(label, textAlign: TextAlign.center, style: AppTextStyles.dialogButtonMuted),
          ),
        ),
      ),
    );
  }
}
