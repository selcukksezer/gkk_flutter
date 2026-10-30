import 'dart:ui';
import 'package:flutter/material.dart';

import '../../mekans/widgets/mekan_design.dart';

/// Cinematic obsidian-glass banner shown on dungeon/PvP results when reputation was earned.
class ReputationGainBanner extends StatefulWidget {
  const ReputationGainBanner({
    super.key,
    required this.amount,
    this.label = 'İtibar kazanıldı',
  });

  final int amount;
  final String label;

  @override
  State<ReputationGainBanner> createState() => _ReputationGainBannerState();
}

class _ReputationGainBannerState extends State<ReputationGainBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.amount <= 0) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (BuildContext context, Widget? child) {
        final double shimmer = _shimmerController.value;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + (shimmer * 2.0), -1.0),
                    end: Alignment(1.0 + (shimmer * 2.0), 1.0),
                    stops: const <double>[0.0, 0.45, 0.55, 1.0],
                    colors: <Color>[
                      const Color(0xFF141A24).withValues(alpha: 0.90),
                      MekanPalette.gold.withValues(alpha: 0.22),
                      const Color(0xFFE01E5A).withValues(alpha: 0.20),
                      const Color(0xFF0F141E).withValues(alpha: 0.92),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: MekanPalette.gold.withValues(
                      alpha: 0.55 + (0.25 * (0.5 - (shimmer - 0.5).abs())),
                    ),
                    width: 1.1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: MekanPalette.gold.withValues(alpha: 0.20),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MekanPalette.gold.withValues(alpha: 0.18),
                        border: Border.all(
                          color: MekanPalette.gold.withValues(alpha: 0.60),
                          width: 0.9,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: MekanPalette.gold.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.military_tech_rounded,
                        color: MekanPalette.gold,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${widget.label}: +${widget.amount}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          shadows: const <Shadow>[
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
