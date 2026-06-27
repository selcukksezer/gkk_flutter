import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';
import 'guild_war_design.dart';

class GuildWarSkeleton extends StatefulWidget {
  const GuildWarSkeleton({super.key});

  @override
  State<GuildWarSkeleton> createState() => _GuildWarSkeletonState();
}

class _GuildWarSkeletonState extends State<GuildWarSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double opacity = 0.25 + (_controller.value * 0.35);
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: <Widget>[
            _ShimmerBlock(
              height: 140,
              opacity: opacity,
              glow: WarPalette.fuchsia,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ShimmerBlock(height: 44, opacity: opacity, glow: WarPalette.gold),
            const SizedBox(height: AppSpacing.md),
            ...List<Widget>.generate(3, (_) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ShimmerBlock(
                  height: 110,
                  opacity: opacity,
                  glow: WarPalette.neon,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.height,
    required this.opacity,
    required this.glow,
  });

  final double height;
  final double opacity;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: <Color>[
            WarPalette.obsidian.withValues(alpha: opacity),
            glow.withValues(alpha: opacity * 0.15),
          ],
        ),
        border: Border.all(color: glow.withValues(alpha: 0.12)),
      ),
    );
  }
}
