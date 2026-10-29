import 'dart:ui' as ui;

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

class _MekanArenaBetSheetState extends State<MekanArenaBetSheet>
    with SingleTickerProviderStateMixin {
  static const int _maxWagerCap = 5000000;

  late int _maxWager;
  late int _wager;
  late final TextEditingController _wagerController;
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _maxWager = widget.myGold.clamp(0, _maxWagerCap);
    _wager = _pickDefaultWager();
    _wagerController = TextEditingController(text: '$_wager');

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _shimmerAnim = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _wagerController.dispose();
    super.dispose();
  }

  int _pickDefaultWager() {
    for (final int preset in MekanArenaBetSheet.presets) {
      if (preset > 0 && preset <= _maxWager) return preset;
    }
    return 0;
  }

  void _setWager(int value, {bool haptic = true}) {
    final int clamped = value.clamp(0, _maxWager);
    if (clamped != _wager) {
      if (haptic) {
        HapticFeedback.selectionClick();
      }
      if (mounted) {
        setState(() => _wager = clamped);
      }
    }
    final String text = '$clamped';
    if (_wagerController.text != text) {
      _wagerController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _applyPercentage(double fraction) {
    HapticFeedback.lightImpact();
    final int target = (_maxWager * fraction).round();
    _setWager(target, haptic: false);
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

  void _confirmFight() {
    HapticFeedback.heavyImpact();
    Navigator.pop(context, _wager);
  }

  @override
  Widget build(BuildContext context) {
    final bool canWager = _maxWager > 0 || _wager == 0;
    final int totalPool = _wager * 2;
    final int estimatedGain = (totalPool * 0.92).round();
    final int remainingGold = (widget.myGold - _wager).clamp(0, widget.myGold);
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xFA1E2740),
                Color(0xF5121826),
                Color(0xFC080B12),
              ],
              stops: <double>[0.0, 0.40, 1.0],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: MekanPalette.gold.withValues(alpha: 0.70),
                width: 1.5,
              ),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x66FFB800),
                blurRadius: 24,
                spreadRadius: -4,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(18, 14, 18, bottomInset + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Handle Grabber with ambient amber glow
                Center(
                  child: Container(
                    width: 48,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: MekanPalette.gold.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: MekanPalette.gold.withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Opponent Header Card with Aion 2 UI Target Frame
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        MekanPalette.surfaceHi.withValues(alpha: 0.85),
                        MekanPalette.navy.withValues(alpha: 0.95),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MekanPalette.ruby.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      // Boss frame asset with opponent avatar / initial
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: <Color>[
                                    MekanPalette.ruby.withValues(alpha: 0.45),
                                    MekanPalette.surfaceHi,
                                  ],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                widget.opponent.username.isNotEmpty
                                    ? widget.opponent.username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: MekanPalette.textHi,
                                ),
                              ),
                            ),
                            Image.asset(
                              'assets/images/aion2_ui/hud_target_boss_frame.png',
                              width: 52,
                              height: 52,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    widget.opponent.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: MekanPalette.textHi,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: MekanPalette.ruby.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.60)),
                                  ),
                                  child: const Text(
                                    'RAKİP',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: MekanPalette.ruby,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: <Widget>[
                                GlowChip(
                                  icon: Icons.military_tech_rounded,
                                  label: 'Sv ${widget.opponent.level}',
                                  color: MekanPalette.aqua,
                                ),
                                GlowChip(
                                  icon: Icons.emoji_events_rounded,
                                  label: '${widget.opponent.pvpRating} RP',
                                  color: MekanPalette.gold,
                                ),
                                if (widget.opponent.power > 0)
                                  GlowChip(
                                    icon: Icons.flash_on_rounded,
                                    label: '${widget.opponent.power}',
                                    color: MekanPalette.coral,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Player Wallet Balance Ribbon
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: MekanPalette.void_.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Image.asset(
                        'assets/images/aion2_ui/hud_quest_marker_gold.png',
                        width: 18,
                        height: 18,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.paid_rounded, size: 16, color: MekanPalette.gold),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Kasanız:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MekanPalette.textMid,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatMekanGold(widget.myGold),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: MekanPalette.gold,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Kalan:',
                        style: TextStyle(fontSize: 11.5, color: MekanPalette.textLow),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatMekanGold(remainingGold),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: (widget.myGold - _wager) >= 0
                              ? MekanPalette.textHi
                              : MekanPalette.ruby,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Wager Preset Chips with Gold Sheen
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const <Widget>[
                    Text(
                      'HIZLI BAHİS SEÇİMİ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: MekanPalette.textMid,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MekanArenaBetSheet.presets.map((int preset) {
                    final bool selected = _wager == preset;
                    final bool affordable = widget.myGold >= preset;
                    final bool isFree = preset == 0;

                    return PressableScale(
                      enabled: affordable,
                      onTap: affordable ? () => _setWager(preset) : null,
                      child: AnimatedBuilder(
                        animation: _shimmerAnim,
                        builder: (BuildContext context, Widget? child) {
                          final double shimmerVal = selected ? _shimmerAnim.value : 0.0;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8.5),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? LinearGradient(
                                      colors: <Color>[
                                        Color.lerp(
                                          const Color(0xFFFFDF70),
                                          Colors.white,
                                          shimmerVal * 0.25,
                                        )!,
                                        MekanPalette.gold,
                                        const Color(0xFFD67E00),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : LinearGradient(
                                      colors: <Color>[
                                        MekanPalette.surfaceHi.withValues(alpha: 0.65),
                                        MekanPalette.void_.withValues(alpha: 0.75),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? Color.lerp(
                                        MekanPalette.gold,
                                        Colors.white,
                                        shimmerVal * 0.4,
                                      )!
                                    : Colors.white.withValues(alpha: affordable ? 0.12 : 0.04),
                                width: selected ? 1.4 : 1.0,
                              ),
                              boxShadow: selected
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: MekanPalette.gold.withValues(
                                          alpha: 0.35 + (shimmerVal * 0.15),
                                        ),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  isFree ? Icons.handshake_rounded : Icons.paid_rounded,
                                  size: 14,
                                  color: selected
                                      ? const Color(0xFF241700)
                                      : (isFree
                                          ? MekanPalette.aqua
                                          : (affordable ? MekanPalette.gold : MekanPalette.textLow)),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _presetLabel(preset),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                    color: selected
                                        ? const Color(0xFF241700)
                                        : (affordable ? MekanPalette.textHi : MekanPalette.textLow),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),

                // Quick percentage selectors (if player has gold)
                if (_maxWager > 0) ...<Widget>[
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      _QuickFractionButton(
                        label: '%25',
                        onTap: () => _applyPercentage(0.25),
                      ),
                      const SizedBox(width: 8),
                      _QuickFractionButton(
                        label: '%50',
                        onTap: () => _applyPercentage(0.50),
                      ),
                      const SizedBox(width: 8),
                      _QuickFractionButton(
                        label: '%75',
                        onTap: () => _applyPercentage(0.75),
                      ),
                      const SizedBox(width: 8),
                      _QuickFractionButton(
                        label: 'MAX',
                        isAccent: true,
                        onTap: () => _applyPercentage(1.0),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // Live Prize Pool & Return Calculator Bento Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        MekanPalette.navy.withValues(alpha: 0.85),
                        MekanPalette.void_.withValues(alpha: 0.95),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (_wager > 0 ? MekanPalette.gold : MekanPalette.aqua)
                          .withValues(alpha: 0.30),
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: MekanPalette.void_.withValues(alpha: 0.50),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                _wager > 0 ? Icons.casino_rounded : Icons.shield_rounded,
                                size: 16,
                                color: _wager > 0 ? MekanPalette.gold : MekanPalette.aqua,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _wager > 0 ? 'ÖDÜL HAVUZU' : 'DOSTLUK KARŞILAŞMASI',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: _wager > 0 ? MekanPalette.gold : MekanPalette.aqua,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '15 ENERJİ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: MekanPalette.textMid,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _PoolMetric(
                              label: 'BAHSİNİZ',
                              value: _wager == 0 ? '0' : formatMekanGold(_wager),
                              color: MekanPalette.textHi,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 26,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          Expanded(
                            child: _PoolMetric(
                              label: 'TOPLAM HAVUZ',
                              value: _wager == 0 ? 'Dostluk' : formatMekanGold(totalPool),
                              color: MekanPalette.gold,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 26,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          Expanded(
                            child: _PoolMetric(
                              label: 'TAHMİNİ KAZANÇ',
                              value: _wager == 0 ? 'Prestij' : '+${formatMekanGold(estimatedGain)}',
                              color: MekanPalette.neon,
                              isHighlight: true,
                            ),
                          ),
                        ],
                      ),
                      if (_wager > 0) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Kazanan toplam havuzun %92\'sini alır (%8 mekan komisyonu).',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: MekanPalette.textLow.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),

                // Luminous Slider & Custom Input
                if (_maxWager > 0) ...<Widget>[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text(
                        'ÖZEL MİKTAR AYARLA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: MekanPalette.textMid,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        '${formatMekanGold(_wager)} / ${formatMekanGold(_maxWager)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: MekanPalette.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4.5,
                      activeTrackColor: MekanPalette.gold,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
                      thumbColor: MekanPalette.gold,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.5, elevation: 4),
                      overlayColor: MekanPalette.gold.withValues(alpha: 0.20),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                      valueIndicatorColor: MekanPalette.surfaceHi,
                      valueIndicatorTextStyle: const TextStyle(
                        color: MekanPalette.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    child: Slider(
                      value: _wager.toDouble().clamp(0.0, _maxWager.toDouble()),
                      min: 0,
                      max: _maxWager.toDouble(),
                      divisions: _maxWager >= 1000 ? (_maxWager ~/ 1000).clamp(1, 500) : 1,
                      label: formatMekanGold(_wager),
                      onChanged: (double value) => _setWager(value.round()),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _wagerController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      color: MekanPalette.textHi,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.paid_rounded, color: MekanPalette.gold, size: 20),
                      suffixIcon: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _applyPercentage(1.0),
                        child: const Text(
                          'MAX',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: MekanPalette.gold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      labelText: 'Manuel Altın Girişi',
                      labelStyle: const TextStyle(color: MekanPalette.textMid, fontSize: 13),
                      hintText: '0 – ${formatMekanGold(_maxWager)}',
                      hintStyle: TextStyle(
                        color: MekanPalette.textLow.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: MekanPalette.void_.withValues(alpha: 0.65),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: MekanPalette.gold, width: 1.5),
                      ),
                    ),
                    onSubmitted: _applyTextInput,
                    onEditingComplete: () => _applyTextInput(_wagerController.text),
                  ),
                ],

                // Action Fight Button
                const SizedBox(height: 18),
                PressableScale(
                  enabled: canWager,
                  onTap: canWager ? _confirmFight : null,
                  child: AnimatedBuilder(
                    animation: _shimmerAnim,
                    builder: (BuildContext context, Widget? child) {
                      final double s = canWager ? _shimmerAnim.value : 0.0;
                      return Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: canWager
                              ? LinearGradient(
                                  colors: <Color>[
                                    Color.lerp(
                                      const Color(0xFFFF5454),
                                      const Color(0xFFFF8A00),
                                      s,
                                    )!,
                                    MekanPalette.ruby,
                                    const Color(0xFF8E0E0E),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: <Color>[
                                    MekanPalette.surfaceHi.withValues(alpha: 0.5),
                                    MekanPalette.void_.withValues(alpha: 0.5),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: canWager
                                ? Color.lerp(
                                    Colors.white.withValues(alpha: 0.5),
                                    MekanPalette.gold,
                                    s,
                                  )!
                                : Colors.white.withValues(alpha: 0.08),
                            width: 1.3,
                          ),
                          boxShadow: canWager
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: MekanPalette.ruby.withValues(alpha: 0.40 + (s * 0.15)),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.sports_mma_rounded,
                              color: canWager ? Colors.white : MekanPalette.textLow,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _wager == 0
                                  ? 'DOSTLUK DÖVÜŞÜ BAŞLAT'
                                  : 'DÖVÜŞ BAŞLAT (${formatMekanGold(_wager)} ALTIN)',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: canWager ? Colors.white : MekanPalette.textLow,
                                letterSpacing: 0.6,
                                shadows: canWager
                                    ? const <Shadow>[
                                        Shadow(
                                          color: Colors.black45,
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickFractionButton extends StatelessWidget {
  const _QuickFractionButton({
    required this.label,
    required this.onTap,
    this.isAccent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.5),
          decoration: BoxDecoration(
            gradient: isAccent
                ? LinearGradient(
                    colors: <Color>[
                      MekanPalette.gold.withValues(alpha: 0.30),
                      MekanPalette.gold.withValues(alpha: 0.15),
                    ],
                  )
                : LinearGradient(
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.03),
                    ],
                  ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isAccent
                  ? MekanPalette.gold.withValues(alpha: 0.60)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              color: isAccent ? MekanPalette.gold : MekanPalette.textMid,
            ),
          ),
        ),
      ),
    );
  }
}

class _PoolMetric extends StatelessWidget {
  const _PoolMetric({
    required this.label,
    required this.value,
    required this.color,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: MekanPalette.textLow,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
            fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
            shadows: isHighlight
                ? <Shadow>[
                    Shadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}
