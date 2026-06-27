import 'dart:async';

import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../theme/app_colors.dart';
import 'mekan_theme.dart';
import '../../../l10n/l10n.dart';

/// Next-gen neon palette for the Mekan ("Han") experience.
/// Scoped to mekan screens only; the rest of the app keeps [AppColors].
abstract final class MekanPalette {
  static const Color void_ = Color(0xFF080B12); // Carbon Void
  static const Color navy = Color(0xFF121826); // Space Navy
  static const Color surface = Color(0xFF161D2E);
  static const Color surfaceHi = Color(0xFF1E2740);
  static const Color obsidian = Color(0xFF2A3042); // Dark Obsidian
  static const Color titanium = Color(0xFF8E9CAE); // Muted Titanium

  static const Color aqua = Color(0xFF00B4FF); // Telegram Aqua
  static const Color gold = Color(0xFFFFB800); // Liquid Gold
  static const Color fuchsia = Color(0xFFE01E5A); // Cyber Fuchsia

  static const Color ruby = Color(0xFFE52E2E); // Mystic Ruby
  static const Color neon = Color(0xFF00FF66); // Toxic Neon
  static const Color amethyst = Color(0xFF8A2BE2); // Royal Amethyst
  static const Color coral = Color(0xFFFF6B35); // Coral Flare
  static const Color cyan = Color(0xFF00FFFF); // Abyss Cyan
  static const Color solar = Color(0xFFFFD700); // Warning Solar

  static const Color textHi = Color(0xFFF2F6FF);
  static const Color textMid = Color(0xFFA9B7D0);
  static const Color textLow = Color(0xFF5C6B86);

  static const LinearGradient goldGrad = LinearGradient(
    colors: <Color>[Color(0xFFFFD64A), gold, Color(0xFFE08A00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Accent color for a mekan type key.
  static Color accent(String? typeKey) {
    switch (typeKey) {
      case 'bar':
        return aqua;
      case 'kahvehane':
        return gold;
      case 'dovus_kulubu':
        return ruby;
      case 'luks_lounge':
        return amethyst;
      case 'yeralti':
        return neon;
      default:
        return aqua;
    }
  }

  static IconData typeIcon(String? typeKey) {
    switch (typeKey) {
      case 'bar':
        return Icons.local_bar_rounded;
      case 'kahvehane':
        return Icons.coffee_rounded;
      case 'dovus_kulubu':
        return Icons.sports_mma_rounded;
      case 'luks_lounge':
        return Icons.diamond_rounded;
      case 'yeralti':
        return Icons.dark_mode_rounded;
      default:
        return Icons.storefront_rounded;
    }
  }
}

/// Full-bleed animated backdrop: deep gradient + dotted grid + glow orbs.
class MekanBackdrop extends StatelessWidget {
  const MekanBackdrop({super.key, required this.child, this.accent = MekanPalette.aqua});

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[MekanPalette.void_, MekanPalette.navy, MekanPalette.void_],
          stops: <double>[0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _BackdropPainter(accent: accent),
        child: child,
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // Ambient glow orbs.
    final Paint orb = Paint()
      ..shader = RadialGradient(
        colors: <Color>[accent.withValues(alpha: 0.16), accent.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.85, size.height * 0.12), radius: 220));
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.12), 220, orb);

    final Paint orb2 = Paint()
      ..shader = RadialGradient(
        colors: <Color>[MekanPalette.fuchsia.withValues(alpha: 0.10), MekanPalette.fuchsia.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.05, size.height * 0.65), radius: 240));
    canvas.drawCircle(Offset(size.width * 0.05, size.height * 0.65), 240, orb2);

    // Dotted grid.
    final Paint dot = Paint()..color = Colors.white.withValues(alpha: 0.035);
    const double gap = 26;
    for (double y = 12; y < size.height; y += gap) {
      for (double x = 12; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.0, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => oldDelegate.accent != accent;
}

/// Scale-down feedback on press for tappable surfaces.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.onTap, this.enabled = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Frosted neon panel with accent border + glow.
class NeonPanel extends StatelessWidget {
  const NeonPanel({
    super.key,
    required this.child,
    this.accent = MekanPalette.aqua,
    this.padding = const EdgeInsets.all(16),
    this.glow = true,
    this.radius = 18,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            MekanPalette.surfaceHi.withValues(alpha: 0.92),
            MekanPalette.navy.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withValues(alpha: 0.30), width: 1.2),
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 22, offset: const Offset(0, 8)),
                BoxShadow(color: MekanPalette.void_.withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(0, 4)),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class GlowChip extends StatelessWidget {
  const GlowChip({super.key, required this.icon, required this.label, this.color = MekanPalette.titanium});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

class NeonSectionHeader extends StatelessWidget {
  const NeonSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.accent = MekanPalette.aqua,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 4,
          height: 30,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
            boxShadow: <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: MekanPalette.textHi,
                  letterSpacing: 0.8,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 11.5, color: MekanPalette.textMid, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Hexagon-ish type badge with neon ring (matches the reference nav icons).
class MekanTypeBadge extends StatelessWidget {
  const MekanTypeBadge({super.key, required this.typeKey, this.size = 52});

  final String? typeKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color accent = MekanPalette.accent(typeKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[accent.withValues(alpha: 0.28), accent.withValues(alpha: 0.06)],
        ),
        borderRadius: BorderRadius.circular(size * 0.30),
        border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.4),
        boxShadow: <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 14)],
      ),
      child: Icon(MekanPalette.typeIcon(typeKey), color: accent, size: size * 0.46),
    );
  }
}

class MekanStatusPill extends StatelessWidget {
  const MekanStatusPill({super.key, required this.isOpen});
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final Color c = isOpen ? MekanPalette.neon : MekanPalette.ruby;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[BoxShadow(color: c.withValues(alpha: 0.9), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'ACIK' : 'KAPALI',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: c, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

class GoldPriceBadge extends StatelessWidget {
  const GoldPriceBadge({super.key, required this.amount, this.small = false, this.discounted = false});

  final int amount;
  final bool small;
  final bool discounted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 4 : 7),
      decoration: BoxDecoration(
        gradient: discounted
            ? const LinearGradient(colors: <Color>[Color(0xFF34D399), Color(0xFF10B981)])
            : MekanPalette.goldGrad,
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (discounted ? MekanPalette.neon : MekanPalette.gold).withValues(alpha: 0.45),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.paid_rounded, size: small ? 13 : 16, color: const Color(0xFF3A2A00)),
          const SizedBox(width: 4),
          Text(
            formatMekanGold(amount),
            style: TextStyle(
              fontSize: small ? 12 : 14.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2A1E00),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Glowing loot card for a sellable item, with rarity ring + price badge.
class LootStockCard extends StatelessWidget {
  const LootStockCard({
    super.key,
    required this.name,
    required this.itemId,
    required this.icon,
    required this.rarity,
    required this.quantity,
    required this.price,
    this.isHanOnly = false,
    this.contraband = false,
    this.discounted = false,
    this.onTap,
    this.trailing,
  });

  final String name;
  final String itemId;
  final String icon;
  final String rarity;
  final int quantity;
  final int price;
  final bool isHanOnly;
  final bool contraband;
  final bool discounted;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color rare = AppColors.forRarity(rarity);
    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[rare.withValues(alpha: 0.16), MekanPalette.navy.withValues(alpha: 0.95)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: rare.withValues(alpha: 0.55), width: 1.3),
          boxShadow: <BoxShadow>[BoxShadow(color: rare.withValues(alpha: 0.22), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  if (contraband)
                    GlowChip(icon: Icons.warning_amber_rounded, label: context.l10n.kacak, color: MekanPalette.neon)
                  else if (isHanOnly)
                    const GlowChip(icon: Icons.local_fire_department_rounded, label: 'HAN', color: MekanPalette.fuchsia)
                  else
                    GlowChip(icon: Icons.auto_awesome, label: rarity.toUpperCase(), color: rare),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: MekanPalette.void_.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'x$quantity',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: MekanPalette.textMid),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[BoxShadow(color: rare.withValues(alpha: 0.35), blurRadius: 18)],
                    ),
                    child: ItemIconView(iconValue: icon, itemId: itemId, size: 58, fallback: '🧪'),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: MekanPalette.textHi, height: 1.15),
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.center, child: GoldPriceBadge(amount: price, small: true, discounted: discounted)),
              if (trailing != null) ...<Widget>[const SizedBox(height: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary gold-gradient or accent-outline call to action.
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.accent = MekanPalette.gold,
    this.filled = true,
    this.busy = false,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color accent;
  final bool filled;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !busy;
    final Widget inner = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (busy)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: filled ? const Color(0xFF2A1E00) : accent),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: filled ? const Color(0xFF2A1E00) : accent),
        if (!busy || icon != null) const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: filled ? const Color(0xFF2A1E00) : accent,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: PressableScale(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: filled
                ? LinearGradient(colors: <Color>[accent.withValues(alpha: 0.95), accent])
                : null,
            color: filled ? null : accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: accent.withValues(alpha: 0.6), width: 1.3),
            boxShadow: filled && enabled
                ? <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))]
                : null,
          ),
          child: Center(child: inner),
        ),
      ),
    );
  }
}

/// Ruby/gold urgency banner with a live countdown (Happy Hour / raid lockout).
class HappyHourBanner extends StatelessWidget {
  const HappyHourBanner({super.key, required this.until});
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: <Color>[Color(0xFFFF8A00), MekanPalette.coral, MekanPalette.ruby]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[BoxShadow(color: MekanPalette.coral.withValues(alpha: 0.45), blurRadius: 18)],
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.celebration_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('HAPPY HOUR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                Text('Tum alimlarda %20 indirim', style: TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          CountdownText(until: until, color: Colors.white),
        ],
      ),
    );
  }
}

class SuspicionMeter extends StatelessWidget {
  const SuspicionMeter({super.key, required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final double pct = (value / 100).clamp(0, 1).toDouble();
    final Color c = value > 60 ? MekanPalette.ruby : (value > 30 ? MekanPalette.solar : MekanPalette.neon);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.visibility_rounded, size: 14, color: c),
            const SizedBox(width: 6),
            Text('Polis Suphesi', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MekanPalette.textMid)),
            const Spacer(),
            Text('$value/100', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: MekanPalette.obsidian,
            color: c,
          ),
        ),
      ],
    );
  }
}

/// Self-updating countdown that ticks every second until [until].
class CountdownText extends StatefulWidget {
  const CountdownText({super.key, required this.until, this.color = MekanPalette.textHi, this.onDone});

  final DateTime until;
  final Color color;
  final VoidCallback? onDone;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.until.isBefore(DateTime.now())) {
        _timer?.cancel();
        widget.onDone?.call();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00';
    final int h = d.inHours;
    final int m = d.inMinutes.remainder(60);
    final int s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}s ${m.toString().padLeft(2, '0')}d';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Duration left = widget.until.difference(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.timer_rounded, size: 13, color: widget.color),
          const SizedBox(width: 4),
          Text(
            _fmt(left),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: widget.color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class MekanEmpty extends StatelessWidget {
  const MekanEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent = MekanPalette.aqua,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.10),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
                boxShadow: <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 20)],
              ),
              child: Icon(icon, size: 40, color: accent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: MekanPalette.textHi),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: MekanPalette.textMid, height: 1.4),
            ),
            if (action != null) ...<Widget>[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Small numeric stat block used in hero headers / dashboards.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.color = MekanPalette.aqua});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MekanPalette.void_.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: MekanPalette.textHi)),
              Text(label, style: const TextStyle(fontSize: 10.5, color: MekanPalette.textLow, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
