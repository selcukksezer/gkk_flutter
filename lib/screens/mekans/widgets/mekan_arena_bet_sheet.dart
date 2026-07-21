import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../providers/mekan_provider.dart';
import 'mekan_design.dart';
import 'mekan_theme.dart';

class MekanArenaBetSheet extends StatefulWidget {
  const MekanArenaBetSheet({
    super.key,
    required this.opponent,
    required this.myGold,
  });

  final ArenaOpponent opponent;
  final int myGold;

  static const List<int> presets = <int>[0, 10000, 50000, 100000, 500000, 1000000, 5000000];

  @override
  State<MekanArenaBetSheet> createState() => _MekanArenaBetSheetState();
}

class _MekanArenaBetSheetState extends State<MekanArenaBetSheet> {
  static const int _maxWagerCap = 5000000;

  late int _maxWager;
  late int _wager;
  late final TextEditingController _wagerController;

  @override
  void initState() {
    super.initState();
    _maxWager = widget.myGold.clamp(0, _maxWagerCap);
    _wager = _pickDefaultWager();
    _wagerController = TextEditingController(text: '$_wager');
  }

  @override
  void dispose() {
    _wagerController.dispose();
    super.dispose();
  }

  int _pickDefaultWager() {
    for (final int preset in MekanArenaBetSheet.presets) {
      if (preset > 0 && preset <= _maxWager) return preset;
    }
    return 0;
  }

  void _setWager(int value) {
    final int clamped = value.clamp(0, _maxWager);
    setState(() => _wager = clamped);
    final String text = '$clamped';
    if (_wagerController.text != text) {
      _wagerController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _applyTextInput(String raw) {
    final int? parsed = int.tryParse(raw.replaceAll('.', '').replaceAll(',', '').trim());
    if (parsed == null) return;
    _setWager(parsed);
  }

  String _presetLabel(int value) {
    if (value == 0) return 'DOSTLUK';
    return formatMekanGold(value);
  }

  @override
  Widget build(BuildContext context) {
    final bool canWager = _maxWager > 0 || _wager == 0;

    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.viewInsetsOf(context).bottom + 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[MekanPalette.surfaceHi, MekanPalette.void_],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: MekanPalette.ruby, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: MekanPalette.textLow, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.opponent.username} ile bahis',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: MekanPalette.textHi),
          ),
          const SizedBox(height: 4),
          Text(
            _wager == 0
                ? '15 enerji harcanır. Dostluk maçı: altın yok, yalnızca rating/istatistik.'
                : '15 enerji harcanır. Kazanan havuzun %92\'sini alır.',
            style: const TextStyle(fontSize: 12, color: MekanPalette.textMid),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MekanArenaBetSheet.presets.map((int preset) {
              final bool selected = _wager == preset;
              final bool affordable = widget.myGold >= preset;
              return PressableScale(
                onTap: affordable ? () => _setWager(preset) : null,
                child: Opacity(
                  opacity: affordable ? 1 : 0.4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: selected ? MekanPalette.goldGrad : null,
                      color: selected ? null : MekanPalette.void_.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? MekanPalette.gold : Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      _presetLabel(preset),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: selected ? const Color(0xFF2A1E00) : MekanPalette.textHi,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_maxWager > 0) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              'Özel miktar: ${formatMekanGold(_wager)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MekanPalette.textMid),
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: MekanPalette.gold,
                inactiveTrackColor: MekanPalette.textLow.withValues(alpha: 0.25),
                thumbColor: MekanPalette.gold,
                overlayColor: MekanPalette.gold.withValues(alpha: 0.18),
              ),
              child: Slider(
                value: _wager.toDouble(),
                min: 0,
                max: _maxWager.toDouble(),
                divisions: _maxWager >= 1000 ? (_maxWager ~/ 1000).clamp(1, 500) : 1,
                label: formatMekanGold(_wager),
                onChanged: (double value) => _setWager(value.round()),
              ),
            ),
            TextField(
              controller: _wagerController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: MekanPalette.textHi, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: 'Altın miktarı',
                labelStyle: const TextStyle(color: MekanPalette.textMid),
                hintText: '0 – ${formatMekanGold(_maxWager)}',
                hintStyle: TextStyle(color: MekanPalette.textLow.withValues(alpha: 0.8)),
                filled: true,
                fillColor: MekanPalette.void_.withValues(alpha: 0.45),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MekanPalette.gold),
                ),
              ),
              onSubmitted: _applyTextInput,
              onEditingComplete: () => _applyTextInput(_wagerController.text),
            ),
          ],
          const SizedBox(height: 20),
          NeonButton(
            label: 'Dövüş Başla',
            icon: Icons.sports_mma_rounded,
            accent: MekanPalette.ruby,
            onPressed: canWager ? () => Navigator.pop(context, _wager) : null,
          ),
        ],
      ),
    );
  }
}
