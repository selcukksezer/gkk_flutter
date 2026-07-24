import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../components/common/gkk_tab_bar.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';

/// Oyuncu Pazarı — tasarim palette + shared UI primitives.
abstract final class MarketDesign {
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFD64A), AppColors.liquidGold, Color(0xFFE08A00)],
  );

  static const LinearGradient fuchsiaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.cyberFuchsia, Color(0xFF9B1240)],
  );

  static LinearGradient surfaceGradient({Color? accent}) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          AppColors.spaceNavy.withValues(alpha: 0.96),
          AppColors.carbonVoid.withValues(alpha: 0.98),
          if (accent != null) accent.withValues(alpha: 0.06) else AppColors.carbonVoid,
        ],
      );
}

/// Scale-down press feedback.
class MarketPressable extends StatefulWidget {
  const MarketPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<MarketPressable> createState() => _MarketPressableState();
}

class _MarketPressableState extends State<MarketPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Fade + slide-up list entry.
class MarketFadeSlide extends StatefulWidget {
  const MarketFadeSlide({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<MarketFadeSlide> createState() => _MarketFadeSlideState();
}

class _MarketFadeSlideState extends State<MarketFadeSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future<void>.delayed(Duration(milliseconds: 36 * widget.index.clamp(0, 12)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Hero banner — live economy strip (ref: Han Ticaret / Vault).
class MarketHeroBanner extends StatelessWidget {
  const MarketHeroBanner({
    super.key,
    required this.listingCount,
  });

  final int listingCount;

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      borderColor: AppColors.liquidGold.withValues(alpha: 0.28),
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: MarketDesign.fuchsiaGradient,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.cyberFuchsia.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Text(
                  'CANLI EKONOMI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.bolt_rounded,
                size: 18,
                color: AppColors.warningSolar.withValues(alpha: 0.9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'OYUNCU PAZARI',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Oyuncular arasi alim-satim — en ucuz fiyatlar burada.',
            style: TextStyle(
              color: AppColors.mutedTitanium,
              fontSize: 11,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _statPill(
                icon: Icons.storefront_rounded,
                label: '$listingCount ilan',
                accent: AppColors.accentCyan,
              ),
              const SizedBox(width: 8),
              _statPill(
                icon: Icons.percent_rounded,
                label: '%5 vergi',
                accent: AppColors.coralFlare,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.darkObsidian.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.92),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Main tab strip — Gözat / Sat / Pazarım.
class MarketTabStrip extends StatelessWidget {
  const MarketTabStrip({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return GkkSegmentedTabBar(
      labels: labels,
      activeIndex: activeIndex,
      onChanged: onChanged,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
    );
  }
}

/// Filter shell — search + pills container.
class MarketFilterPanel extends StatelessWidget {
  const MarketFilterPanel({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      borderColor: AppColors.darkObsidian.withValues(alpha: 0.65),
      borderRadius: 14,
      padding: const EdgeInsets.all(10),
      child: child,
    );
  }
}

/// Search field with dot inner surface.
class MarketSearchField extends StatelessWidget {
  const MarketSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Esya ara...',
  });

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.darkObsidian),
        gradient: MarketDesign.surfaceGradient(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(
                painter: DotGridPainter(spacing: 12, dotOpacity: 0.05),
              ),
            ),
            TextField(
              onChanged: onChanged,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.mutedTitanium),
                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal category / rarity pill strip.
class MarketPillStrip extends StatelessWidget {
  const MarketPillStrip({
    super.key,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
    this.accent = AppColors.accentCyan,
  });

  final List<MarketPillOption> options;
  final String selectedKey;
  final ValueChanged<String> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int index) {
          final MarketPillOption option = options[index];
          final bool selected = option.key == selectedKey;
          return MarketPressable(
            onTap: () => onSelected(option.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: selected
                    ? LinearGradient(
                        colors: <Color>[
                          accent.withValues(alpha: 0.35),
                          AppColors.spaceNavy,
                        ],
                      )
                    : null,
                color: selected ? null : AppColors.darkObsidian.withValues(alpha: 0.65),
                border: Border.all(
                  color: selected ? accent.withValues(alpha: 0.75) : AppColors.darkObsidian,
                  width: selected ? 1.2 : 1,
                ),
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.18),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (option.icon != null) ...<Widget>[
                    Icon(option.icon, size: 13, color: selected ? accent : AppColors.mutedTitanium),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    option.count != null ? '${option.label} (${option.count})' : option.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected ? AppColors.textPrimary : AppColors.mutedTitanium,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class MarketPillOption {
  const MarketPillOption({
    required this.key,
    required this.label,
    this.count,
    this.icon,
  });

  final String key;
  final String label;
  final int? count;
  final IconData? icon;
}

/// Sort chips — Ucuz / Pahali.
class MarketSortChips extends StatelessWidget {
  const MarketSortChips({
    super.key,
    required this.lowSelected,
    required this.onLow,
    required this.onHigh,
  });

  final bool lowSelected;
  final VoidCallback onLow;
  final VoidCallback onHigh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _chip('Ucuz', lowSelected, onLow),
        const SizedBox(width: 6),
        _chip('Pahali', !lowSelected, onHigh),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return MarketPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: selected ? MarketDesign.goldGradient : null,
          color: selected ? null : AppColors.darkObsidian.withValues(alpha: 0.7),
          border: Border.all(
            color: selected
                ? AppColors.liquidGold.withValues(alpha: 0.6)
                : AppColors.darkObsidian,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.carbonVoid : AppColors.mutedTitanium,
          ),
        ),
      ),
    );
  }
}

/// Primary CTA — gold gradient.
class MarketPrimaryButton extends StatelessWidget {
  const MarketPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return MarketPressable(
      enabled: enabled,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          gradient: enabled ? MarketDesign.goldGradient : null,
          color: enabled ? null : AppColors.darkObsidian.withValues(alpha: 0.5),
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 6 : 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: compact ? 12 : 14,
                  color: enabled ? AppColors.carbonVoid : AppColors.mutedTitanium,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  fontWeight: FontWeight.w900,
                  color: enabled ? AppColors.carbonVoid : AppColors.mutedTitanium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Secondary outline action.
class MarketSecondaryButton extends StatelessWidget {
  const MarketSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.accent = AppColors.cyberFuchsia,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MarketPressable(
      enabled: onPressed != null,
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 6 : 9,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          color: accent.withValues(alpha: 0.1),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ),
    );
  }
}

/// Empty / loading states.
class MarketEmptyState extends StatelessWidget {
  const MarketEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inventory_2_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 32, color: AppColors.mutedTitanium.withValues(alpha: 0.6)),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class MarketLoadingSpinner extends StatelessWidget {
  const MarketLoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.liquidGold,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet shell — blur + dotted panel.
class MarketSheetShell extends StatelessWidget {
  const MarketSheetShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: MarketDesign.surfaceGradient(accent: AppColors.liquidGold),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.2)),
          ),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(painter: DotGridPainter(spacing: 14, dotOpacity: 0.06)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section title with accent bar.
class MarketSectionHeader extends StatelessWidget {
  const MarketSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 3,
            height: subtitle != null ? 32 : 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: MarketDesign.goldGradient,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.35),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: AppColors.mutedTitanium, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
