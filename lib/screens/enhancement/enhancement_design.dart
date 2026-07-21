import 'dart:ui';

import 'package:flutter/material.dart';

import '../../components/layout/game_screen_background.dart';
import '../../theme/app_colors.dart';

/// Güçlendirme ekranı — /tasarim paleti + dot doku.
abstract final class EnhDesign {
  static const LinearGradient goldCta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFD64A), AppColors.liquidGold, Color(0xFFE08A00)],
  );

  static const LinearGradient fuchsiaCta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF4D7A), AppColors.cyberFuchsia, Color(0xFFB01040)],
  );

  static BoxDecoration rarityGlow(Color color) => BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      );
}

/// Küçük etiket — seviye, risk, şans.
class EnhPill extends StatelessWidget {
  const EnhPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bölüm başlığı + opsiyonel sağ aksiyon.
class EnhSectionHeader extends StatelessWidget {
  const EnhSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: AppColors.mutedTitanium,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.mutedTitanium.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Küçük ikon buton — tablo popup tetikleyici.
class EnhIconChipButton extends StatefulWidget {
  const EnhIconChipButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = AppColors.liquidGold,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  State<EnhIconChipButton> createState() => _EnhIconChipButtonState();
}

class _EnhIconChipButtonState extends State<EnhIconChipButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.darkObsidian.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.accent.withValues(alpha: 0.4)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(widget.icon, size: 13, color: widget.accent),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: widget.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Altın gradient ana CTA.
class EnhGoldButton extends StatefulWidget {
  const EnhGoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  State<EnhGoldButton> createState() => _EnhGoldButtonState();
}

class _EnhGoldButtonState extends State<EnhGoldButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && !widget.loading && widget.onTap != null;

    final Widget child = AnimatedScale(
      scale: _pressed && active ? 0.97 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: active ? EnhDesign.goldCta : null,
          color: active ? null : AppColors.darkObsidian.withValues(alpha: 0.5),
          border: Border.all(
            color: active
                ? AppColors.liquidGold.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            if (widget.loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.carbonVoid),
                ),
              )
            else if (widget.icon != null) ...<Widget>[
              Icon(widget.icon, size: 16, color: AppColors.carbonVoid),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.carbonVoid : AppColors.mutedTitanium,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      onTap: active ? widget.onTap : null,
      child: widget.expand ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}

/// İkincil outline buton.
class EnhGhostButton extends StatelessWidget {
  const EnhGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.darkObsidian.withValues(alpha: 0.55),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedTitanium,
            ),
          ),
        ),
      ),
    );
  }
}

/// Staggered giriş animasyonu.
class EnhFadeSlide extends StatefulWidget {
  const EnhFadeSlide({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<EnhFadeSlide> createState() => _EnhFadeSlideState();
}

class _EnhFadeSlideState extends State<EnhFadeSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future<void>.delayed(Duration(milliseconds: 40 * widget.index), () {
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
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// Blur popup kabuğu — envanter popup stili.
Future<T?> showEnhBlurDialog<T>({
  required BuildContext context,
  required Widget child,
  Color accent = AppColors.liquidGold,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dialog',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary, Widget? _) {
      final double scale = Curves.easeOutBack.transform(anim.value);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: FadeTransition(
          opacity: anim,
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: AppColors.carbonVoid.withValues(alpha: 0.62),
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {},
                child: Transform.scale(
                  scale: scale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: DottedPanel(
                      borderColor: accent.withValues(alpha: 0.42),
                      borderRadius: 18,
                      padding: const EdgeInsets.all(14),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
