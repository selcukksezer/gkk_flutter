import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';

/// 2027 Aion 2 Mobile NPC Merchant Atmosphere Header.
/// Features Koranis, Astral Emissary, with animated speech bubble,
/// atmospheric dialogue cycling, and ornate glassmorphic filigree framing.
class MerchantVendorHeader extends StatefulWidget {
  const MerchantVendorHeader({
    super.key,
    this.hasKingdomBlessing = false,
    this.blessingDiscountPct = 0,
    this.onVendorTap,
  });

  final bool hasKingdomBlessing;
  final int blessingDiscountPct;
  final VoidCallback? onVendorTap;

  @override
  State<MerchantVendorHeader> createState() => _MerchantVendorHeaderState();
}

class _MerchantVendorHeaderState extends State<MerchantVendorHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;

  static const List<String> _dialogues = <String>[
    'Işık ve aether rehberin olsun, Daeva. En nadide eşyalarım hizmetinde.',
    'Sanctum kulelerinden gelen taze esanslar ve iksirler raflarda yerini aldı.',
    'İhtiyacın olmayan ganimetleri değerinde altına çevirebilirim.',
    'Krallık pazarında aether akışı güçlü; en karlı takaslar burada yapılır.',
    'Kadim mühürlerle kutsanmış eşyalar macerana güç katacak.',
  ];

  int _dialogueIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _nextDialogue() {
    setState(() {
      _dialogueIndex = (_dialogueIndex + 1) % _dialogues.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (BuildContext context, Widget? child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFF162138).withValues(alpha: 0.92),
                const Color(0xFF0F1726).withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: AppColors.liquidGold.withValues(alpha: _glowAnimation.value * 0.45),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.liquidGold.withValues(alpha: 0.08 * _glowAnimation.value),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.accentCyan.withValues(alpha: 0.05 * _glowAnimation.value),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Merchant Avatar & Crest
              GestureDetector(
                onTap: () {
                  _nextDialogue();
                  widget.onVendorTap?.call();
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            AppColors.liquidGold.withValues(alpha: 0.35),
                            AppColors.accentCyan.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.liquidGold.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '🧙‍♂️',
                          style: TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -1,
                      right: -1,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0D1424),
                          border: Border.all(
                            color: AppColors.accentCyan,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          size: 11,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Merchant Info & Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            'Koranis',
                            style: GoogleFonts.cinzel(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: AppColors.liquidGold.withValues(alpha: 0.16),
                            border: Border.all(
                              color: AppColors.liquidGold.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'Aether Tüccarı',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.liquidGold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Sanctum Emissary • Açık Pazar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedTitanium.withValues(alpha: 0.85),
                          ),
                        ),
                        if (widget.hasKingdomBlessing) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFF8B5CF6),
                                  Color(0xFF6366F1),
                                ],
                              ),
                            ),
                            child: Text(
                              '-%${widget.blessingDiscountPct} Kutsama',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Speech bubble toggle button
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: AppColors.liquidGold,
                ),
                tooltip: 'Tüccar Sözü',
                onPressed: _nextDialogue,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Interactive speech quote bubble
          GestureDetector(
            onTap: _nextDialogue,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 14,
                    color: AppColors.liquidGold,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _dialogues[_dialogueIndex],
                        key: ValueKey<int>(_dialogueIndex),
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.touch_app_outlined,
                    size: 13,
                    color: AppColors.mutedTitanium.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
